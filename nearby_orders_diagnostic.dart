import 'dart:developer' as dev;
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class NearbyOrdersDiagnostic {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> runFullDiagnostic(Position driverPosition) async {
    dev.log('=== NEARBY ORDERS DIAGNOSTIC START ===');
    
    // 1. Check what status we're looking for
    final targetStatus = 'matching'; // OrderStatus.assigning.toFirestore()
    dev.log('Target status: "$targetStatus"');
    dev.log('Driver position: ${driverPosition.latitude}, ${driverPosition.longitude}');
    
    // 2. Get ALL orders first
    final allOrdersSnapshot = await _firestore.collection('orders').get();
    dev.log('Total orders in database: ${allOrdersSnapshot.docs.length}');
    
    if (allOrdersSnapshot.docs.isEmpty) {
      dev.log('❌ NO ORDERS EXIST IN DATABASE');
      return;
    }
    
    // 3. Check status distribution
    final statusCounts = <String, int>{};
    for (final doc in allOrdersSnapshot.docs) {
      final status = doc.data()['status'] as String?;
      statusCounts[status ?? 'null'] = (statusCounts[status ?? 'null'] ?? 0) + 1;
    }
    dev.log('Status distribution: $statusCounts');
    
    // 4. Check orders with target status
    final matchingOrdersSnapshot = await _firestore
        .collection('orders')
        .where('status', isEqualTo: targetStatus)
        .get();
    dev.log('Orders with status "$targetStatus": ${matchingOrdersSnapshot.docs.length}');
    
    if (matchingOrdersSnapshot.docs.isEmpty) {
      dev.log('❌ NO ORDERS WITH STATUS "$targetStatus"');
      
      // Check if there are orders with similar statuses
      final similarStatuses = ['assigning', 'requested', 'pending'];
      for (final status in similarStatuses) {
        final snapshot = await _firestore
            .collection('orders')
            .where('status', isEqualTo: status)
            .get();
        if (snapshot.docs.isNotEmpty) {
          dev.log('Found ${snapshot.docs.length} orders with status "$status"');
        }
      }
      return;
    }
    
    // 5. Check each matching order
    for (final doc in matchingOrdersSnapshot.docs) {
      final data = doc.data();
      dev.log('--- Order ${doc.id} ---');
      dev.log('Full data: $data');
      
      // Check pickup structure
      final pickup = data['pickup'];
      if (pickup == null) {
        dev.log('❌ No pickup field');
        continue;
      }
      
      if (pickup is! Map<String, dynamic>) {
        dev.log('❌ Pickup is not a map: ${pickup.runtimeType}');
        continue;
      }
      
      final lat = pickup['lat'];
      final lng = pickup['lng'];
      final label = pickup['label'];
      
      dev.log('Pickup: lat=$lat, lng=$lng, label=$label');
      
      if (lat == null || lng == null) {
        dev.log('❌ Missing lat/lng in pickup');
        continue;
      }
      
      try {
        final pickupLat = (lat as num).toDouble();
        final pickupLng = (lng as num).toDouble();
        
        final distance = _calculateDistance(
          driverPosition.latitude,
          driverPosition.longitude,
          pickupLat,
          pickupLng,
        );
        
        dev.log('✅ Distance: ${distance.toStringAsFixed(1)}km');
        
        if (distance <= 8.0) {
          dev.log('✅ Within 8km limit - SHOULD APPEAR');
        } else {
          dev.log('❌ Outside 8km limit - FILTERED OUT');
        }
        
      } catch (e) {
        dev.log('❌ Error calculating distance: $e');
      }
    }
    
    dev.log('=== DIAGNOSTIC COMPLETE ===');
  }
  
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371;
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