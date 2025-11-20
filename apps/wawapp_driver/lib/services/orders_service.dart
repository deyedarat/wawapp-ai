import 'dart:developer' as dev;
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:core_shared/core_shared.dart';
import '../models/order.dart' as app_order;
import 'driver_status_service.dart';

class OrdersService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<app_order.Order>> getNearbyOrders(Position driverPosition) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (kDebugMode) {
        dev.log('[Matching] getNearbyOrders: No authenticated user');
      }
      return Stream.value([]);
    }

    final statusValue = OrderStatus.assigning.toFirestore();

    if (kDebugMode) {
      dev.log('[Matching] getNearbyOrders called');
      dev.log('[Matching] Driver position: lat=${driverPosition.latitude.toStringAsFixed(4)}, lng=${driverPosition.longitude.toStringAsFixed(4)}');
      dev.log('[Matching] Query filters: status=$statusValue, assignedDriverId=null, maxDistance=8.0km');
    }

    // Check if driver is online before querying orders
    return DriverStatusService.instance.watchOnlineStatus(user.uid).asyncExpand((isOnline) {
      if (!isOnline) {
        if (kDebugMode) {
          dev.log('[Matching] Driver is OFFLINE - returning empty stream');
        }
        return Stream.value(<app_order.Order>[]);
      }

      if (kDebugMode) {
        dev.log('[Matching] Driver is ONLINE - querying orders');
      }

      // TODO: MIGRATION - Ensure Firestore schema supports these fields:
      // - 'assignedDriverId' field should exist and be null for open orders
      // - 'createdAt' field should be indexed for orderBy query
      // - If schema uses different field names, update query accordingly

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
          dev.log('[Matching] Snapshot received: ${snapshot.docs.length} documents');
        }

        if (snapshot.docs.isEmpty) {
          if (kDebugMode) dev.log('[Matching] No orders matching filters: status=$statusValue, assignedDriverId=null');
          return <app_order.Order>[];
        }

        final orders = <app_order.Order>[];
        for (final doc in snapshot.docs) {
          try {
            final data = doc.data();

            // Additional safety check: ensure order is truly unassigned
            final assignedDriverId = data['assignedDriverId'];
            if (assignedDriverId != null) {
              if (kDebugMode) {
                dev.log('[Matching] ⚠️ Order ${doc.id} has assignedDriverId=$assignedDriverId, skipping');
              }
              continue;
            }

            final order = app_order.Order.fromFirestore(doc.id, data);
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
              dev.log('[Matching] Order ${order.id}: status=${order.status}, assignedDriverId=$assignedDriverId, createdAt=$createdAt, pickup=($pickupLat,$pickupLng), distance=${distance.toStringAsFixed(2)}km, price=${order.price}');
            }

            if (distance <= 8.0) {
              orders.add(order);
              if (kDebugMode) {
                dev.log('[Matching] ✓ Order ${order.id} within range (${distance.toStringAsFixed(1)}km)');
              }
            } else {
              if (kDebugMode) {
                dev.log('[Matching] ✗ Order ${order.id} too far (${distance.toStringAsFixed(1)}km)');
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
          dev.log('[Matching] Final result: ${orders.length} matching orders');
          for (var i = 0; i < orders.length; i++) {
            final o = orders[i];
            final dist = _calculateDistance(
              driverPosition.latitude,
              driverPosition.longitude,
              o.pickup.lat,
              o.pickup.lng,
            );
            dev.log('[Matching] #${i + 1}: ${o.id} (${dist.toStringAsFixed(1)}km, ${o.price}MRU)');
          }
        }

        return orders;
      }).handleError((error) {
        if (kDebugMode) {
          dev.log('[Matching] Stream error: $error');
          if (error.toString().contains('index')) {
            dev.log('[Matching] ⚠️ Firestore index missing. Create composite index for: collection=orders, fields=[status,assignedDriverId,createdAt]');
          }
          if (error.toString().contains('assignedDriverId')) {
            dev.log('[Matching] ⚠️ assignedDriverId field missing in schema. Consider migration or use fallback query.');
          }
        }
        return <app_order.Order>[];
      });
    });
  }

  Future<void> acceptOrder(String orderId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Driver not authenticated');
    }

    await _firestore.runTransaction((transaction) async {
      final orderRef = _firestore.collection('orders').doc(orderId);
      final orderDoc = await transaction.get(orderRef);

      if (!orderDoc.exists) {
        throw Exception('Order not found');
      }

      final currentStatus =
          OrderStatus.fromFirestore(orderDoc.data()!['status'] as String);
      if (currentStatus != OrderStatus.assigning) {
        throw Exception('Order was already taken');
      }

      final update = OrderStatus.accepted.createTransitionUpdate(
        driverId: user.uid,
      );

      transaction.update(orderRef, update);
    });

    // Log analytics event after successful acceptance
    AnalyticsService.instance.logOrderAcceptedByDriver(orderId: orderId);
  }

  Future<void> transition(String orderId, OrderStatus to) async {
    await _firestore.runTransaction((transaction) async {
      final orderRef = _firestore.collection('orders').doc(orderId);
      final orderDoc = await transaction.get(orderRef);

      if (!orderDoc.exists) {
        throw Exception('Order not found');
      }

      final currentStatus =
          OrderStatus.fromFirestore(orderDoc.data()!['status'] as String);

      if (!currentStatus.canTransitionTo(to)) {
        throw Exception('Invalid status transition');
      }

      final update = to.createTransitionUpdate();
      transaction.update(orderRef, update);
    });

    // Log analytics event for completed orders
    if (to == OrderStatus.completed) {
      AnalyticsService.instance.logOrderCompletedByDriver(orderId: orderId);
    }
  }

  Future<void> cancelOrder(String orderId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Driver not authenticated');
    }

    await _firestore.runTransaction((transaction) async {
      final orderRef = _firestore.collection('orders').doc(orderId);
      final orderDoc = await transaction.get(orderRef);

      if (!orderDoc.exists) {
        throw Exception('Order not found');
      }

      final data = orderDoc.data()!;
      final driverId = data['driverId'] as String?;

      if (driverId != user.uid) {
        throw Exception('Not authorized to cancel this order');
      }

      final currentStatus = OrderStatus.fromFirestore(data['status'] as String);

      if (!currentStatus.canDriverCancel) {
        throw Exception('Cannot cancel order in current status');
      }

      transaction.update(
        orderRef,
        OrderStatus.cancelledByDriver.createTransitionUpdate(),
      );
    });

    // Log analytics event after successful cancellation
    AnalyticsService.instance.logOrderCancelledByDriver(orderId: orderId);
  }

  Stream<List<app_order.Order>> getDriverActiveOrders(String driverId) {
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

          final orders = <app_order.Order>[];
          for (final doc in snapshot.docs) {
            try {
              final data = doc.data();
              final order = app_order.Order.fromFirestore(doc.id, data);
              orders.add(order);

              if (kDebugMode) {
                final createdAt = data['createdAt'];
                dev.log('[Matching] Active order ${order.id}: status=${order.status}, createdAt=$createdAt, price=${order.price}');
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
                  .map((o) => '${o.id.substring(o.id.length - 6)}:${o.status}')
                  .join(', ');
              dev.log('[Matching] Final active orders for driver $driverId: [$orderStatuses]');
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
