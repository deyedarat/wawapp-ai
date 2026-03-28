import 'dart:developer' as dev;

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:core_shared/core_shared.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'analytics_service.dart';

final ordersServiceProvider = Provider<OrdersService>((ref) {
  return OrdersService();
});

class OrdersService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Order>> getNearbyOrders(Position driverPosition) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (kDebugMode) {
        dev.log('[Matching] ❌ getNearbyOrders: No authenticated user');
      }
      return [];
    }

    if (kDebugMode) {
      dev.log('[Matching] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      dev.log('[Matching] 🔍 getNearbyOrders (Cloud Function) called');
      dev.log('[Matching] 📍 Driver ID: ${user.uid}');
      dev.log(
          '[Matching] 📍 Driver position: lat=${driverPosition.latitude.toStringAsFixed(6)}, lng=${driverPosition.longitude.toStringAsFixed(6)}');
    }

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('getNearbyOrders');
      final result = await callable.call({
        'lat': driverPosition.latitude,
        'lng': driverPosition.longitude,
      });

      final data = result.data as Map<dynamic, dynamic>;
      final rawOrders = data['orders'] as List<dynamic>;

      if (kDebugMode) {
        dev.log('[Matching] ✅ Cloud Function returned ${rawOrders.length} orders');
      }

      final orders = rawOrders.map((o) {
        final orderMap = Map<String, dynamic>.from(o as Map);

        // Handle Timestamp conversion if necessary
        // Cloud Functions might return ISO strings or Maps for Timestamps
        if (orderMap['createdAt'] is String) {
          orderMap['createdAt'] = Timestamp.fromDate(DateTime.parse(orderMap['createdAt']));
        } else if (orderMap['createdAt'] is Map) {
          // Handle {_seconds: ..., _nanoseconds: ...} structure if present
          final t = orderMap['createdAt'];
          if (t['_seconds'] != null) {
            orderMap['createdAt'] = Timestamp(t['_seconds'], t['_nanoseconds'] ?? 0);
          }
        }

        // Ensure ID is passed correctly (Cloud Function returns 'id' field)
        final id = orderMap['id'];
        return Order.fromFirestoreWithId(id, orderMap);
      }).toList();

      return orders;
    } catch (e) {
      if (kDebugMode) {
        dev.log('[Matching] ❌ Error calling Cloud Function: $e');
      }
      // Return empty list on error to avoid crashing UI
      return [];
    }
  }

  Future<void> acceptOrder(String orderId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const AppError(type: AppErrorType.permissionDenied, message: 'Driver not authenticated');
    }

    try {
      await _firestore.runTransaction((transaction) async {
        final orderRef = _firestore.collection('orders').doc(orderId);
        final orderDoc = await transaction.get(orderRef);

        if (!orderDoc.exists) {
          throw const AppError(type: AppErrorType.notFound, message: 'Order not found');
        }

        final currentStatus = OrderStatus.fromFirestore(orderDoc.data()!['status'] as String);
        if (currentStatus != OrderStatus.assigning) {
          throw const AppError(type: AppErrorType.permissionDenied, message: 'Order was already taken');
        }

        final update = OrderStatus.accepted.createTransitionUpdate(
          driverId: user.uid,
        );

        transaction.update(orderRef, update);
      });

      // Log analytics event after successful acceptance
      AnalyticsService.instance.logOrderAcceptedByDriver(orderId: orderId);
    } on Object catch (e) {
      if (e is AppError) rethrow;
      throw AppError.from(e);
    }
  }

  Future<void> transition(String orderId, OrderStatus to) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final orderRef = _firestore.collection('orders').doc(orderId);
        final orderDoc = await transaction.get(orderRef);

        if (!orderDoc.exists) {
          throw const AppError(type: AppErrorType.notFound, message: 'Order not found');
        }

        final currentStatus = OrderStatus.fromFirestore(orderDoc.data()!['status'] as String);

        if (!currentStatus.canTransitionTo(to)) {
          throw const AppError(type: AppErrorType.permissionDenied, message: 'Invalid status transition');
        }

        final update = to.createTransitionUpdate();
        transaction.update(orderRef, update);
      });

      // Log analytics event for completed orders
      if (to == OrderStatus.completed) {
        AnalyticsService.instance.logOrderCompletedByDriver(orderId: orderId);
      }
    } on Object catch (e) {
      if (e is AppError) rethrow;
      throw AppError.from(e);
    }
  }

  Future<void> cancelOrder(String orderId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const AppError(type: AppErrorType.permissionDenied, message: 'Driver not authenticated');
    }

    try {
      await _firestore.runTransaction((transaction) async {
        final orderRef = _firestore.collection('orders').doc(orderId);
        final orderDoc = await transaction.get(orderRef);

        if (!orderDoc.exists) {
          throw const AppError(type: AppErrorType.notFound, message: 'Order not found');
        }

        final data = orderDoc.data()!;
        final driverId = data['driverId'] as String?;

        if (driverId != user.uid) {
          throw const AppError(type: AppErrorType.permissionDenied, message: 'Not authorized to cancel this order');
        }

        final currentStatus = OrderStatus.fromFirestore(data['status'] as String);

        if (!currentStatus.canDriverCancel) {
          throw const AppError(type: AppErrorType.permissionDenied, message: 'Cannot cancel order in current status');
        }

        transaction.update(
          orderRef,
          OrderStatus.cancelledByDriver.createTransitionUpdate(),
        );
      });

      // Log analytics event after successful cancellation
      AnalyticsService.instance.logOrderCancelledByDriver(orderId: orderId);
    } on Object catch (e) {
      if (e is AppError) rethrow;
      throw AppError.from(e);
    }
  }

  Stream<List<Order>> getDriverActiveOrders(String driverId) {
    if (kDebugMode) {
      dev.log('[Matching] getDriverActiveOrders called for driver: $driverId');
      dev.log('[Matching] Query intent: driverId=$driverId, status IN [accepted, onRoute]');
    }

    // REQUIRED COMPOSITE INDEX: orders [driverId ASC, status ASC]
    // Note: whereIn queries may auto-create this index, but explicitly defined in firestore.indexes.json
    // Deploy via: firebase deploy --only firestore:indexes
    return _firestore
        .collection('orders')
        .where('driverId', isEqualTo: driverId)
        .where('status', whereIn: [
          OrderStatus.accepted.toFirestore(),
          OrderStatus.onRoute.toFirestore(),
        ])
        .snapshots()
        .map((snapshot) {
          if (kDebugMode) {
            dev.log('[Matching] Active orders snapshot: ${snapshot.docs.length} documents');
          }

          final orders = <Order>[];
          for (final doc in snapshot.docs) {
            try {
              final data = doc.data();
              final order = Order.fromFirestoreWithId(doc.id, data);
              orders.add(order);

              if (kDebugMode) {
                final createdAt = data['createdAt'];
                dev.log(
                    '[Matching] Active order ${order.id}: status=${order.status}, createdAt=$createdAt, price=${order.price}');
              }
            } on Object catch (e) {
              if (kDebugMode) {
                dev.log('[Matching] Error parsing active order ${doc.id}: $e');
              }
            }
          }

          if (kDebugMode) {
            if (orders.isNotEmpty) {
              final orderStatuses = orders
                  .map((o) =>
                      '${o.id != null && o.id!.length > 6 ? o.id!.substring(o.id!.length - 6) : o.id ?? 'N/A'}:${o.status}')
                  .join(', ');
              dev.log('[Matching] Final active orders for driver $driverId: [$orderStatuses]');
            } else {
              dev.log('[Matching] No active orders for driver $driverId');
            }
          }

          return orders;
        });
  }
}
