/**
 * Live Driver Marker Model
 * Represents a driver's location and status for map display
 */

import 'package:latlong2/latlong.dart';

class LiveDriverMarker {
  final String driverId;
  final String name;
  final String phone;
  final LatLng location;
  final bool isOnline;
  final bool isBlocked;
  final String? operator;
  final String? activeOrderId;
  final double? rating;
  final int totalTrips;

  LiveDriverMarker({
    required this.driverId,
    required this.name,
    required this.phone,
    required this.location,
    required this.isOnline,
    required this.isBlocked,
    this.operator,
    this.activeOrderId,
    this.rating,
    this.totalTrips = 0,
  });

  /// Get marker color based on driver status
  String get statusColor {
    if (isBlocked) return '#C1272D'; // Red (Accent Red)
    if (isOnline) return '#00704A'; // Green (Primary Green)
    return '#6C757D'; // Gray (Offline)
  }

  /// Get status label
  String get statusLabel {
    if (isBlocked) return 'محظور';
    if (isOnline) return 'متصل';
    return 'غير متصل';
  }

  /// Get operator label
  String get operatorLabel {
    switch (operator?.toLowerCase()) {
      case 'mauritel':
        return 'موريتل';
      case 'chinguitel':
        return 'شنقيتل';
      case 'mattel':
        return 'ماتل';
      default:
        return operator ?? '-';
    }
  }
}
