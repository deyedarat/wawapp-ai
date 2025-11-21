import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:core_shared/core_shared.dart';
import '../../../core/utils/date_formatter.dart';

class Order {
  final String? id;
  final String? ownerId;
  final double distanceKm;
  final double price;
  final String pickupAddress;
  final String dropoffAddress;
  final LatLng pickup;
  final LatLng dropoff;
  final String? status;
  final String? driverId;
  final DateTime? createdAt;
  final DateTime? completedAt;

  const Order({
    this.id,
    this.ownerId,
    required this.distanceKm,
    required this.price,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.pickup,
    required this.dropoff,
    this.status,
    this.driverId,
    this.createdAt,
    this.completedAt,
  });

  OrderStatus get orderStatus =>
      OrderStatus.fromFirestore(status ?? 'requested');

  factory Order.fromFirestore(Map<String, dynamic> data) {
    final pickupData = data['pickup'] as Map<String, dynamic>;
    final dropoffData = data['dropoff'] as Map<String, dynamic>;

    return Order(
      id: data['id'] as String?,
      ownerId: data['ownerId'] as String?,
      distanceKm: (data['distanceKm'] as num).toDouble(),
      price: (data['price'] as num).toDouble(),
      pickupAddress: data['pickupAddress'] as String,
      dropoffAddress: data['dropoffAddress'] as String,
      pickup: LatLng(
        (pickupData['lat'] as num).toDouble(),
        (pickupData['lng'] as num).toDouble(),
      ),
      dropoff: LatLng(
        (dropoffData['lat'] as num).toDouble(),
        (dropoffData['lng'] as num).toDouble(),
      ),
      status: data['status'] as String?,
      driverId: data['driverId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'ownerId': ownerId,
        'distanceKm': distanceKm,
        'price': price,
        'pickupAddress': pickupAddress,
        'dropoffAddress': dropoffAddress,
        'pickup': {'lat': pickup.latitude, 'lng': pickup.longitude},
        'dropoff': {'lat': dropoff.latitude, 'lng': dropoff.longitude},
        'status': status,
        'driverId': driverId,
      };

  /// Format creation date for UI display in local device time
  String get formattedCreatedAt => DateFormatter.formatOrderCreated(createdAt);

  /// Format completion date for UI display in local device time
  String get formattedCompletedAt => DateFormatter.formatOrderCompleted(completedAt);

  /// Format creation date with relative time (e.g., "2 hours ago")
  String get relativeCreatedAt => DateFormatter.formatRelative(createdAt);
}
