import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a dispatch offer sent to a driver
///
/// Backend collection: dispatch_offers
/// ID format: {orderId}_{driverId}
class DispatchOffer {
  final String offerId;
  final String orderId;
  final String driverId;
  final String status; // 'sent', 'accepted', 'rejected', 'expired', 'cancelled'
  final int round; // Wave number (1, 2, 3)
  final int priority;
  final DateTime sentAt;
  final DateTime expiresAt;
  final DateTime? respondedAt;
  final double distance; // km from pickup location

  DispatchOffer({
    required this.offerId,
    required this.orderId,
    required this.driverId,
    required this.status,
    required this.round,
    required this.priority,
    required this.sentAt,
    required this.expiresAt,
    this.respondedAt,
    required this.distance,
  });

  /// Create from Firestore document
  factory DispatchOffer.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DispatchOffer(
      offerId: doc.id,
      orderId: data['orderId'] as String,
      driverId: data['driverId'] as String,
      status: data['status'] as String,
      round: data['round'] as int,
      priority: data['priority'] as int,
      sentAt: (data['sentAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      respondedAt: data['respondedAt'] != null
          ? (data['respondedAt'] as Timestamp).toDate()
          : null,
      distance: (data['distance'] as num).toDouble(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'offerId': offerId,
      'orderId': orderId,
      'driverId': driverId,
      'status': status,
      'round': round,
      'priority': priority,
      'sentAt': Timestamp.fromDate(sentAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'respondedAt':
          respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
      'distance': distance,
    };
  }

  /// Check if offer is still valid (not expired)
  bool get isValid => DateTime.now().isBefore(expiresAt);

  /// Get remaining time in seconds
  int get remainingSeconds {
    final diff = expiresAt.difference(DateTime.now());
    return diff.inSeconds > 0 ? diff.inSeconds : 0;
  }

  /// Check if offer is actionable (sent and not expired)
  bool get isActionable => status == 'sent' && isValid;

  @override
  String toString() =>
      'DispatchOffer(offerId: $offerId, orderId: $orderId, status: $status, round: $round)';
}
