import 'dart:developer' as dev;
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../models/order.dart' as app_order;

class OrdersService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<app_order.Order>> getNearbyOrders(Position driverPosition) {
    dev.log('[nearby_stream] start');

    return _firestore
        .collection('orders')
        .where('status', isEqualTo: 'matching')
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        dev.log('[nearby_stream] empty');
        return <app_order.Order>[];
      }

      final orders = <app_order.Order>[];
      for (final doc in snapshot.docs) {
        try {
          final order = app_order.Order.fromFirestore(doc.id, doc.data());
          final distance = _calculateDistance(
            driverPosition.latitude,
            driverPosition.longitude,
            order.pickup.lat,
            order.pickup.lng,
          );

          if (distance <= 8.0) {
            orders.add(order);
            dev.log(
                '[nearby_stream] item: {id: ${order.id}, km: ${distance.toStringAsFixed(1)}, price: ${order.price}}');
          }
        } catch (e) {
          dev.log('[nearby_stream] error parsing order ${doc.id}: $e');
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

      return orders;
    }).handleError((error) {
      dev.log('[nearby_stream] error: $error');
      return <app_order.Order>[];
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
