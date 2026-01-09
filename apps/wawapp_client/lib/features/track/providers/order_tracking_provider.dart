import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

final orderTrackingProvider = StreamProvider.family.autoDispose<DocumentSnapshot?, String>((ref, orderId) {
  return FirebaseFirestore.instance.collection('orders').doc(orderId).snapshots();
});

class DriverLocation {
  final LatLng position;
  final DateTime lastUpdated;

  const DriverLocation({
    required this.position,
    required this.lastUpdated,
  });
}

// DEPRECATED: Direct driver location access is insecure.
// Use order-based tracking instead.
final driverLocationProvider = StreamProvider.family.autoDispose<DriverLocation?, String>((ref, orderId) {
  // P0-FATAL FIX: Read location from the order document, not driver_locations
  return FirebaseFirestore.instance.collection('orders').doc(orderId).snapshots().map((snapshot) {
    try {
      if (!snapshot.exists) return null;

      final data = snapshot.data();
      if (data == null || !data.containsKey('driverLocation')) return null;

      final locData = data['driverLocation'] as Map<String, dynamic>;
      final lat = (locData['lat'] as num?)?.toDouble();
      final lng = (locData['lng'] as num?)?.toDouble();

      // Parse timestamp
      DateTime? updatedAt;
      if (locData['updatedAt'] is Timestamp) {
        updatedAt = (locData['updatedAt'] as Timestamp).toDate();
      } else if (locData['updatedAt'] is String) {
        updatedAt = DateTime.tryParse(locData['updatedAt']);
      }

      if (lat == null || lng == null) return null;

      return DriverLocation(
        position: LatLng(lat, lng),
        lastUpdated: updatedAt ?? DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  });
});
