import 'dart:developer' as dev;
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_shared/core_shared.dart';

import 'driver_status_service.dart';
import 'analytics_service.dart';

final ordersServiceProvider = Provider<OrdersService>((ref) {
  return OrdersService();
});

class OrdersService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Order>> getNearbyOrders(Position driverPosition) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (kDebugMode) {
        dev.log('[Matching] ❌ getNearbyOrders: No authenticated user');
      }
      return Stream.value([]);
    }

    final statusValue = OrderStatus.assigning.toFirestore();

    if (kDebugMode) {
      dev.log('[Matching] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      dev.log('[Matching] 🔍 getNearbyOrders called');
      dev.log('[Matching] 📍 Driver ID: ${user.uid}');
      dev.log('[Matching] 📍 Driver position: lat=${driverPosition.latitude.toStringAsFixed(6)}, lng=${driverPosition.longitude.toStringAsFixed(6)}');
      dev.log('[Matching] 🔎 Query filters:');
      dev.log('[Matching]    - status = "$statusValue" (enum: OrderStatus.matching)');
      dev.log('[Matching]    - assignedDriverId = null');
      dev.log('[Matching]    - maxDistance = 8.0km');
      dev.log('[Matching] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }

    // Check if driver is online before querying orders
    return DriverStatusService.instance
        .watchOnlineStatus(user.uid)
        .asyncExpand((isOnline) {
      if (!isOnline) {
        if (kDebugMode) {
          dev.log('[Matching] ⚠️ Driver is OFFLINE - returning empty stream');
          dev.log('[Matching] 💡 Solution: Driver must go ONLINE to see orders');
          dev.log('[Matching] 📝 Check: drivers/${user.uid} document has isOnline=true');
        }
        return Stream.value(<Order>[]);
      }

      if (kDebugMode) {
        dev.log('[Matching] ✅ Driver is ONLINE - proceeding to query Firestore');
      }

      // REQUIRED COMPOSITE INDEX: orders [status ASC, assignedDriverId ASC, createdAt DESC]
      // Deploy via: firebase deploy --only firestore:indexes
      // Or create manually in Firebase Console: https://console.firebase.google.com/project/_/firestore/indexes
      return _firestore
          .collection('orders')
          .where('status', isEqualTo: statusValue)
          .where('assignedDriverId', isNull: true)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        if (kDebugMode) {
          dev.log('[Matching] 📦 Firestore snapshot received: ${snapshot.docs.length} documents');
        }

        if (snapshot.docs.isEmpty) {
          if (kDebugMode) {
            dev.log('[Matching] ❌ No orders found in Firestore matching filters');
            dev.log('[Matching] 📋 Filters used:');
            dev.log('[Matching]    - status = "$statusValue"');
            dev.log('[Matching]    - assignedDriverId = null');
            dev.log('[Matching] 💡 Possible reasons:');
            dev.log('[Matching]    1. No orders created by clients yet');
            dev.log('[Matching]    2. All orders have status != "$statusValue"');
            dev.log('[Matching]    3. All orders already have assignedDriverId set');
            dev.log('[Matching] 🔧 To debug: Check Firebase Console > Firestore > orders collection');
          }
          return <Order>[];
        }

        if (kDebugMode) {
          dev.log('[Matching] ✅ Found ${snapshot.docs.length} raw documents, filtering by distance...');
        }

        final orders = <Order>[];
        for (final doc in snapshot.docs) {
          try {
            final data = doc.data();

            // Additional safety check: ensure order is truly unassigned
            final assignedDriverId = data['assignedDriverId'];
            if (assignedDriverId != null) {
              if (kDebugMode) {
                dev.log(
                    '[Matching] ⚠️ Order ${doc.id} has assignedDriverId=$assignedDriverId, skipping');
              }
              continue;
            }

            final order = Order.fromFirestoreWithId(doc.id, data);
            final distance = _calculateDistance(
              driverPosition.latitude,
              driverPosition.longitude,
              order.pickup.lat,
              order.pickup.lng,
            );

            if (kDebugMode) {
              final createdAt = data['createdAt'];
              final pickupLat = data['pickup']?['lat'];
              final pickupLng = data['pickup']?['lng'];
              dev.log('[Matching] 📄 Order ${doc.id}:');
              dev.log('[Matching]    - status: ${order.status}');
              dev.log('[Matching]    - assignedDriverId: $assignedDriverId');
              dev.log('[Matching]    - createdAt: $createdAt');
              dev.log('[Matching]    - pickup: ($pickupLat, $pickupLng)');
              dev.log('[Matching]    - distance: ${distance.toStringAsFixed(2)} km');
              dev.log('[Matching]    - price: ${order.price} MRU');
            }

            if (distance <= 8.0) {
              orders.add(order);
              if (kDebugMode) {
                dev.log('[Matching]    ✅ INCLUDED (within 8km radius)');
              }
            } else {
              if (kDebugMode) {
                dev.log('[Matching]    ❌ EXCLUDED (too far: ${distance.toStringAsFixed(1)}km > 8km)');
              }
            }
          } on Object catch (e) {
            if (kDebugMode) {
              dev.log('[Matching] Error parsing order ${doc.id}: $e');
            }
          }
        }

        orders.sort((a, b) {
          final distA = _calculateDistance(
            driverPosition.latitude,
            driverPosition.longitude,
            a.pickup.lat,
            a.pickup.lng,
          );
          final distB = _calculateDistance(
            driverPosition.latitude,
            driverPosition.longitude,
            b.pickup.lat,
            b.pickup.lng,
          );
          return distA.compareTo(distB);
        });

        if (kDebugMode) {
          dev.log('[Matching] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          dev.log('[Matching] 📊 FINAL RESULT: ${orders.length} matching orders');
          if (orders.isEmpty) {
            dev.log('[Matching] ⚠️ No orders to display to driver');
          } else {
            dev.log('[Matching] 📋 Orders sorted by distance:');
            for (var i = 0; i < orders.length; i++) {
              final o = orders[i];
              final dist = _calculateDistance(
                driverPosition.latitude,
                driverPosition.longitude,
                o.pickup.lat,
                o.pickup.lng,
              );
              dev.log('[Matching]    ${i + 1}. ${o.id} - ${dist.toStringAsFixed(1)}km - ${o.price}MRU');
            }
          }
          dev.log('[Matching] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        }

        return orders;
      }).handleError((error) {
        if (kDebugMode) {
          dev.log('[Matching] Stream error: $error');
          if (error.toString().contains('index')) {
            dev.log(
                '[Matching] ⚠️ Firestore index missing. Create composite index for: collection=orders, fields=[status,assignedDriverId,createdAt]');
          }
          if (error.toString().contains('assignedDriverId')) {
            dev.log(
                '[Matching] ⚠️ assignedDriverId field missing in schema. Consider migration or use fallback query.');
          }
        }
        throw AppError.from(error);
      });
    });
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

        final currentStatus =
            OrderStatus.fromFirestore(orderDoc.data()!['status'] as String);
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

        final currentStatus =
            OrderStatus.fromFirestore(orderDoc.data()!['status'] as String);

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
      dev.log(
          '[Matching] Query intent: driverId=$driverId, status IN [accepted, onRoute]');
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
            dev.log(
                '[Matching] Active orders snapshot: ${snapshot.docs.length} documents');
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
                  .map((o) => '${o.id != null && o.id!.length > 6 ? o.id!.substring(o.id!.length - 6) : o.id ?? 'N/A'}:${o.status}')
                  .join(', ');
              dev.log(
                  '[Matching] Final active orders for driver $driverId: [$orderStatuses]');
            } else {
              dev.log('[Matching] No active orders for driver $driverId');
            }
          }

          return orders;
        });
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // Earth radius in km
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
}
