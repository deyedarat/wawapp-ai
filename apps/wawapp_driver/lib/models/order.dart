import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_shared/core_shared.dart';

class Order {
  final String id;
  final String ownerId;
  final String status;
  final LocationPoint pickup;
  final LocationPoint dropoff;
  final double distanceKm;
  final int price;
  final DateTime? createdAt;
  final DateTime? completedAt;
  final String? driverId;
  final String? assignedDriverId;

  const Order({
    required this.id,
    required this.ownerId,
    required this.status,
    required this.pickup,
    required this.dropoff,
    required this.distanceKm,
    required this.price,
    this.createdAt,
    this.completedAt,
    this.driverId,
    this.assignedDriverId,
  });

  OrderStatus get orderStatus => OrderStatus.fromFirestore(status);

  factory Order.fromFirestore(String id, Map<String, dynamic> data) {
    return Order(
      id: id,
      ownerId: data['ownerId'] as String,
      status: data['status'] as String,
      pickup: LocationPoint.fromMap(data['pickup'] as Map<String, dynamic>),
      dropoff: LocationPoint.fromMap(data['dropoff'] as Map<String, dynamic>),
      distanceKm: (data['distanceKm'] as num).toDouble(),
      price: data['price'] as int,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      driverId: data['driverId'] as String?,
      assignedDriverId: data['assignedDriverId'] as String?,
    );
  }
}

class LocationPoint {
  final double lat;
  final double lng;
  final String label;

  const LocationPoint({
    required this.lat,
    required this.lng,
    required this.label,
  });

  factory LocationPoint.fromMap(Map<String, dynamic> map) {
    return LocationPoint(
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      label: map['label'] as String,
    );
  }
}
