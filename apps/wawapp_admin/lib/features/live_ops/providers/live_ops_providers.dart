/**
 * Live Operations Providers
 * Riverpod providers for real-time driver and order data
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:core_shared/core_shared.dart';
import '../models/live_driver_marker.dart';
import '../models/live_order_marker.dart';
import '../models/live_ops_filters.dart';

// ============================================================================
// Filter State Provider
// ============================================================================

final liveOpsFiltersProvider = StateProvider<LiveOpsFilters>((ref) {
  return const LiveOpsFilters();
});

// ============================================================================
// Live Drivers Stream Provider
// ============================================================================

final liveDriversStreamProvider = StreamProvider<List<LiveDriverMarker>>((ref) {
  final filters = ref.watch(liveOpsFiltersProvider);
  final db = FirebaseFirestore.instance;

  // Build query based on filters
  Query<Map<String, dynamic>> query = db.collection('drivers');

  // Apply driver status filter
  switch (filters.driverStatus) {
    case DriverStatusFilter.onlineOnly:
      query = query.where('isOnline', isEqualTo: true);
      break;
    case DriverStatusFilter.offlineOnly:
      query = query.where('isOnline', isEqualTo: false);
      break;
    case DriverStatusFilter.blockedOnly:
      query = query.where('isBlocked', isEqualTo: true);
      break;
    case DriverStatusFilter.all:
      // No filter
      break;
  }

  // Limit to reasonable number for performance
  query = query.limit(200);

  return query.snapshots().map((snapshot) {
    final markers = <LiveDriverMarker>[];

    for (final doc in snapshot.docs) {
      try {
        final data = doc.data();
        
        // Skip if no location data
        if (data['location'] == null) continue;

        // Extract location
        LatLng? location;
        final locationData = data['location'];
        if (locationData is GeoPoint) {
          location = LatLng(locationData.latitude, locationData.longitude);
        } else if (locationData is Map) {
          final lat = locationData['lat'] ?? locationData['latitude'];
          final lng = locationData['lng'] ?? locationData['longitude'];
          if (lat != null && lng != null) {
            location = LatLng(lat.toDouble(), lng.toDouble());
          }
        }

        if (location == null) continue;

        // Get driver data
        final isOnline = data['isOnline'] as bool? ?? false;
        final isBlocked = data['isBlocked'] as bool? ?? false;
        final operator = data['operator'] as String?;

        // Apply operator filter (client-side since Firestore doesn't support OR)
        if (filters.operator != OperatorFilter.all) {
          final operatorLower = operator?.toLowerCase();
          switch (filters.operator) {
            case OperatorFilter.mauritel:
              if (operatorLower != 'mauritel') continue;
              break;
            case OperatorFilter.chinguitel:
              if (operatorLower != 'chinguitel') continue;
              break;
            case OperatorFilter.mattel:
              if (operatorLower != 'mattel') continue;
              break;
            case OperatorFilter.all:
              break;
          }
        }

        markers.add(LiveDriverMarker(
          driverId: doc.id,
          name: data['name'] as String? ?? 'Driver ${doc.id.substring(0, 6)}',
          phone: data['phone'] as String? ?? '',
          location: location,
          isOnline: isOnline,
          isBlocked: isBlocked,
          operator: operator,
          activeOrderId: data['activeOrderId'] as String?,
          rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
          totalTrips: data['totalTrips'] as int? ?? 0,
        ));
      } catch (e) {
        print('Error parsing driver ${doc.id}: $e');
      }
    }

    return markers;
  });
});

// ============================================================================
// Live Orders Stream Provider
// ============================================================================

final liveOrdersStreamProvider = StreamProvider<List<LiveOrderMarker>>((ref) {
  final filters = ref.watch(liveOpsFiltersProvider);
  final db = FirebaseFirestore.instance;

  // Build query based on filters
  Query<Map<String, dynamic>> query = db.collection('orders');

  // Apply time window filter
  final cutoffTime = filters.getTimeWindowCutoff();
  if (cutoffTime != null) {
    query = query.where('createdAt', isGreaterThan: Timestamp.fromDate(cutoffTime));
  }

  // Apply order status filter
  if (filters.orderStatus != OrderStatusFilter.all) {
    String? statusValue;
    switch (filters.orderStatus) {
      case OrderStatusFilter.assigning:
        statusValue = 'assigning';
        break;
      case OrderStatusFilter.accepted:
        statusValue = 'accepted';
        break;
      case OrderStatusFilter.onRoute:
        statusValue = 'on_route';
        break;
      case OrderStatusFilter.completed:
        statusValue = 'completed';
        break;
      case OrderStatusFilter.cancelled:
        // Handle multiple cancelled statuses client-side
        break;
      case OrderStatusFilter.all:
        break;
    }
    
    if (statusValue != null) {
      query = query.where('status', isEqualTo: statusValue);
    }
  }

  // Order by creation time (most recent first)
  query = query.orderBy('createdAt', descending: true);

  // Limit to reasonable number for performance
  query = query.limit(100);

  return query.snapshots().map((snapshot) {
    final markers = <LiveOrderMarker>[];

    for (final doc in snapshot.docs) {
      try {
        final data = doc.data();

        // Extract locations
        LatLng? pickupLocation;
        LatLng? dropoffLocation;

        final pickup = data['pickup'];
        if (pickup is GeoPoint) {
          pickupLocation = LatLng(pickup.latitude, pickup.longitude);
        } else if (pickup is Map) {
          final lat = pickup['lat'] ?? pickup['latitude'];
          final lng = pickup['lng'] ?? pickup['longitude'];
          if (lat != null && lng != null) {
            pickupLocation = LatLng(lat.toDouble(), lng.toDouble());
          }
        }

        final dropoff = data['dropoff'];
        if (dropoff is GeoPoint) {
          dropoffLocation = LatLng(dropoff.latitude, dropoff.longitude);
        } else if (dropoff is Map) {
          final lat = dropoff['lat'] ?? dropoff['latitude'];
          final lng = dropoff['lng'] ?? dropoff['longitude'];
          if (lat != null && lng != null) {
            dropoffLocation = LatLng(lat.toDouble(), lng.toDouble());
          }
        }

        if (pickupLocation == null || dropoffLocation == null) continue;

        final status = data['status'] as String? ?? 'unknown';
        
        // Apply cancelled status filter (client-side)
        if (filters.orderStatus == OrderStatusFilter.cancelled) {
          if (!status.startsWith('cancelled')) continue;
        }

        // Get timestamps
        DateTime? createdAt;
        DateTime? assignedAt;

        final createdAtData = data['createdAt'];
        if (createdAtData is Timestamp) {
          createdAt = createdAtData.toDate();
        }

        final assignedAtData = data['assignedAt'];
        if (assignedAtData is Timestamp) {
          assignedAt = assignedAtData.toDate();
        }

        if (createdAt == null) continue;

        final marker = LiveOrderMarker(
          orderId: doc.id,
          clientId: data['ownerId'] as String? ?? 'unknown',
          driverId: data['assignedDriverId'] as String? ?? data['driverId'] as String?,
          pickupLocation: pickupLocation,
          dropoffLocation: dropoffLocation,
          pickupAddress: data['pickupAddress'] as String? ?? '',
          dropoffAddress: data['dropoffAddress'] as String? ?? '',
          status: status,
          createdAt: createdAt,
          assignedAt: assignedAt,
          price: (data['price'] as num?)?.toDouble(),
          distanceKm: (data['distanceKm'] as num?)?.toDouble(),
        );

        // Apply anomaly filter if enabled
        if (filters.showAnomaliesOnly && !marker.isAnomalous()) {
          continue;
        }

        markers.add(marker);
      } catch (e) {
        print('Error parsing order ${doc.id}: $e');
      }
    }

    return markers;
  });
});

// ============================================================================
// Live Statistics Provider
// ============================================================================

class LiveOpsStats {
  final int totalOnlineDrivers;
  final int totalActiveOrders;
  final int unassignedOrders;
  final int anomalousOrders;
  final double? averageAssignmentTimeMinutes;

  LiveOpsStats({
    required this.totalOnlineDrivers,
    required this.totalActiveOrders,
    required this.unassignedOrders,
    required this.anomalousOrders,
    this.averageAssignmentTimeMinutes,
  });
}

final liveOpsStatsProvider = Provider<LiveOpsStats>((ref) {
  final driversAsync = ref.watch(liveDriversStreamProvider);
  final ordersAsync = ref.watch(liveOrdersStreamProvider);

  final drivers = driversAsync.maybeWhen(
    data: (data) => data,
    orElse: () => <LiveDriverMarker>[],
  );

  final orders = ordersAsync.maybeWhen(
    data: (data) => data,
    orElse: () => <LiveOrderMarker>[],
  );

  final totalOnlineDrivers = drivers.where((d) => d.isOnline && !d.isBlocked).length;
  final activeOrders = orders.where((o) => o.isActive).toList();
  final totalActiveOrders = activeOrders.length;
  final unassignedOrders = activeOrders.where((o) => o.driverId == null).length;
  final anomalousOrders = activeOrders.where((o) => o.isAnomalous()).length;

  // Calculate average assignment time for assigned orders
  final assignedOrders = orders.where((o) => o.assignmentTimeMinutes != null).toList();
  double? averageAssignmentTime;
  if (assignedOrders.isNotEmpty) {
    final totalMinutes = assignedOrders
        .map((o) => o.assignmentTimeMinutes!)
        .reduce((a, b) => a + b);
    averageAssignmentTime = totalMinutes / assignedOrders.length;
  }

  return LiveOpsStats(
    totalOnlineDrivers: totalOnlineDrivers,
    totalActiveOrders: totalActiveOrders,
    unassignedOrders: unassignedOrders,
    anomalousOrders: anomalousOrders,
    averageAssignmentTimeMinutes: averageAssignmentTime,
  );
});

// ============================================================================
// Anomalous Orders Provider
// ============================================================================

final anomalousOrdersProvider = Provider<List<LiveOrderMarker>>((ref) {
  final ordersAsync = ref.watch(liveOrdersStreamProvider);

  final orders = ordersAsync.maybeWhen(
    data: (data) => data,
    orElse: () => <LiveOrderMarker>[],
  );

  return orders.where((o) => o.isActive && o.isAnomalous()).toList();
});
