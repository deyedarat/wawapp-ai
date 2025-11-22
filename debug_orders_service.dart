import 'dart:developer' as dev;
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:core_shared/core_shared.dart';

class DebugOrdersService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Map<String, dynamic>>> getAllOrdersDebug() {
    dev.log('[DEBUG] Fetching ALL orders for diagnosis');

    return _firestore.collection('orders').snapshots().map((snapshot) {
      dev.log('[DEBUG] Total orders in database: ${snapshot.docs.length}');

      final orders = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        orders.add(data);

        dev.log(
          '[DEBUG] Order ${doc.id}: status=${data['status']}, pickup=${data['pickup']}, dropoff=${data['dropoff']}',
        );
      }

      return orders;
    });
  }

  Stream<List<Map<String, dynamic>>> getOrdersByStatus(String status) {
    dev.log('[DEBUG] Fetching orders with status: $status');

    return _firestore
        .collection('orders')
        .where('status', isEqualTo: status)
        .snapshots()
        .map((snapshot) {
          dev.log(
            '[DEBUG] Orders with status "$status": ${snapshot.docs.length}',
          );

          final orders = <Map<String, dynamic>>[];
          for (final doc in snapshot.docs) {
            final data = doc.data();
            data['id'] = doc.id;
            orders.add(data);

            dev.log('[DEBUG] Order ${doc.id}: ${data}');
          }

          return orders;
        });
  }

  Stream<List<Map<String, dynamic>>> getNearbyOrdersUnlimited(
    Position driverPosition,
  ) {
    final targetStatus = OrderStatus.assigning.toFirestore();
    dev.log('[DEBUG] Looking for orders with status: "$targetStatus"');
    dev.log(
      '[DEBUG] Driver position: lat=${driverPosition.latitude}, lng=${driverPosition.longitude}',
    );

    return _firestore
        .collection('orders')
        .where('status', isEqualTo: targetStatus)
        .snapshots()
        .map((snapshot) {
          dev.log('[DEBUG] Query returned ${snapshot.docs.length} orders');

          final orders = <Map<String, dynamic>>[];
          for (final doc in snapshot.docs) {
            try {
              final data = doc.data();
              data['id'] = doc.id;

              dev.log('[DEBUG] Processing order ${doc.id}');
              dev.log('[DEBUG] Order data: ${data}');

              // Check if pickup exists and has correct structure
              if (data['pickup'] == null) {
                dev.log('[DEBUG] ERROR: Order ${doc.id} has no pickup field');
                continue;
              }

              final pickup = data['pickup'] as Map<String, dynamic>;
              if (pickup['lat'] == null || pickup['lng'] == null) {
                dev.log(
                  '[DEBUG] ERROR: Order ${doc.id} pickup missing lat/lng: $pickup',
                );
                continue;
              }

              final pickupLat = (pickup['lat'] as num).toDouble();
              final pickupLng = (pickup['lng'] as num).toDouble();

              final distance = _calculateDistance(
                driverPosition.latitude,
                driverPosition.longitude,
                pickupLat,
                pickupLng,
              );

              data['distance'] = distance;
              orders.add(data);

              dev.log(
                '[DEBUG] Order ${doc.id}: distance=${distance.toStringAsFixed(1)}km, pickup=($pickupLat,$pickupLng)',
              );
            } catch (e) {
              dev.log('[DEBUG] ERROR parsing order ${doc.id}: $e');
            }
          }

          dev.log('[DEBUG] Returning ${orders.length} valid orders');
          return orders;
        });
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371; // Earth radius in km
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
}
