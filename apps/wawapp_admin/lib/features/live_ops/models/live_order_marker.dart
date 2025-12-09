/**
 * Live Order Marker Model
 * Represents an active order's locations for map display
 */

import 'package:latlong2/latlong.dart';

class LiveOrderMarker {
  final String orderId;
  final String clientId;
  final String? driverId;
  final LatLng pickupLocation;
  final LatLng dropoffLocation;
  final String pickupAddress;
  final String dropoffAddress;
  final String status;
  final DateTime createdAt;
  final DateTime? assignedAt;
  final double? price;
  final double? distanceKm;

  LiveOrderMarker({
    required this.orderId,
    required this.clientId,
    this.driverId,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.status,
    required this.createdAt,
    this.assignedAt,
    this.price,
    this.distanceKm,
  });

  /// Get status color
  String get statusColor {
    switch (status) {
      case 'assigning':
        return '#F5A623'; // Golden Yellow
      case 'accepted':
        return '#0D6EFD'; // Blue
      case 'on_route':
        return '#00704A'; // Green
      case 'completed':
        return '#28A745'; // Success Green
      case 'cancelled':
      case 'cancelled_by_admin':
      case 'cancelled_by_driver':
      case 'cancelled_by_client':
        return '#C1272D'; // Red
      default:
        return '#6C757D'; // Gray
    }
  }

  /// Get status label in Arabic
  String get statusLabel {
    switch (status) {
      case 'assigning':
        return 'قيد التعيين';
      case 'accepted':
        return 'مقبول';
      case 'on_route':
        return 'في الطريق';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
      case 'cancelled_by_admin':
      case 'cancelled_by_driver':
      case 'cancelled_by_client':
        return 'ملغى';
      default:
        return status;
    }
  }

  /// Check if order is active (ongoing)
  bool get isActive {
    return status == 'assigning' || 
           status == 'accepted' || 
           status == 'on_route';
  }

  /// Get order age in minutes
  int get ageMinutes {
    return DateTime.now().difference(createdAt).inMinutes;
  }

  /// Check if order is anomalous (stuck in assigning for too long)
  bool isAnomalous({int thresholdMinutes = 10}) {
    return status == 'assigning' && ageMinutes > thresholdMinutes;
  }

  /// Get assignment time in minutes (if assigned)
  int? get assignmentTimeMinutes {
    if (assignedAt == null) return null;
    return assignedAt!.difference(createdAt).inMinutes;
  }
}
