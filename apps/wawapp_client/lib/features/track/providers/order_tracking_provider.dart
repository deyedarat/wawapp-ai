import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

final orderTrackingProvider =
    StreamProvider.family<DocumentSnapshot?, String>((ref, orderId) {
  return FirebaseFirestore.instance
      .collection('orders')
      .doc(orderId)
      .snapshots();
});

class DriverLocation {
  final LatLng position;
  final DateTime lastUpdated;

  const DriverLocation({
    required this.position,
    required this.lastUpdated,
  });
}

final driverLocationProvider =
    StreamProvider.family<DriverLocation?, String>((ref, driverId) {
  return FirebaseFirestore.instance
      .collection('driver_locations')
      .doc(driverId)
      .snapshots()
      .map((snapshot) {
    try {
      if (!snapshot.exists) return null;

      final data = snapshot.data();
      if (data == null) return null;

      final lat = (data['lat'] as num?)?.toDouble();
      final lng = (data['lng'] as num?)?.toDouble();
      final updatedAt = data['updatedAt'] as Timestamp?;

      if (lat == null || lng == null) return null;

      return DriverLocation(
        position: LatLng(lat, lng),
        lastUpdated: updatedAt?.toDate() ?? DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  });
});
