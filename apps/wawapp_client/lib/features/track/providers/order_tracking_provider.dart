import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

final orderTrackingProvider = StreamProvider.family
    .autoDispose<DocumentSnapshot?, String>((ref, orderId) {
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

// DEPRECATED: Direct driver location access is insecure.
// Use order-based tracking instead.
final driverLocationProvider =
    StreamProvider.family.autoDispose<DriverLocation?, String>((ref, orderId) {
  // Read location from the order document's driverLocation field.
  // The driver's tracking service writes here when the order is active.
  // Fallback: if driverLocation is not yet written, try reading from
  // driver_locations/{driverId} using the order's assignedDriverId.
  return FirebaseFirestore.instance
      .collection('orders')
      .doc(orderId)
      .snapshots()
      .asyncMap((snapshot) async {
    try {
      if (!snapshot.exists) return null;

      final data = snapshot.data();
      if (data == null) return null;

      // Primary: read from order.driverLocation
      if (data.containsKey('driverLocation') && data['driverLocation'] != null) {
        final locData = data['driverLocation'] as Map<String, dynamic>;
        final lat = (locData['lat'] as num?)?.toDouble();
        final lng = (locData['lng'] as num?)?.toDouble();

        DateTime? updatedAt;
        if (locData['updatedAt'] is Timestamp) {
          updatedAt = (locData['updatedAt'] as Timestamp).toDate();
        }

        if (lat != null && lng != null) {
          return DriverLocation(
            position: LatLng(lat, lng),
            lastUpdated: updatedAt ?? DateTime.now(),
          );
        }
      }

      // Fallback: read from driver_locations/{driverId}
      final driverId = data['driverId'] as String? ?? data['assignedDriverId'] as String?;
      if (driverId == null || driverId.isEmpty) return null;

      final locDoc = await FirebaseFirestore.instance
          .collection('driver_locations')
          .doc(driverId)
          .get();

      if (!locDoc.exists) return null;
      final locData = locDoc.data()!;
      final lat = (locData['lat'] as num?)?.toDouble();
      final lng = (locData['lng'] as num?)?.toDouble();

      if (lat == null || lng == null) return null;

      DateTime? updatedAt;
      if (locData['updatedAt'] is Timestamp) {
        updatedAt = (locData['updatedAt'] as Timestamp).toDate();
      }

      return DriverLocation(
        position: LatLng(lat, lng),
        lastUpdated: updatedAt ?? DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  });
});
