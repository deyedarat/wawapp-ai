import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus {
  matching,
  accepted,
  onRoute,
  completed,
  cancelled;

  static OrderStatus fromString(String status) {
    return OrderStatus.values.firstWhere((e) => e.name == status);
  }

  static bool canTransition(OrderStatus from, OrderStatus to) {
    const transitions = {
      OrderStatus.matching: [OrderStatus.accepted, OrderStatus.cancelled],
      OrderStatus.accepted: [OrderStatus.onRoute, OrderStatus.cancelled],
      OrderStatus.onRoute: [OrderStatus.completed],
      OrderStatus.completed: <OrderStatus>[],
      OrderStatus.cancelled: <OrderStatus>[],
    };
    return transitions[from]?.contains(to) ?? false;
  }

  static Map<String, dynamic> createTransitionUpdate({
    required OrderStatus to,
    String? driverId,
  }) {
    final update = {
      'status': to.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (to == OrderStatus.accepted && driverId != null) {
      update['driverId'] = driverId;
    }
    return update;
  }
}

class Order {
  final String id;
  final String ownerId;
  final String status;
  final LocationPoint pickup;
  final LocationPoint dropoff;
  final double distanceKm;
  final int price;
  final DateTime? createdAt;
  final String? driverId;

  const Order({
    required this.id,
    required this.ownerId,
    required this.status,
    required this.pickup,
    required this.dropoff,
    required this.distanceKm,
    required this.price,
    this.createdAt,
    this.driverId,
  });

  OrderStatus get orderStatus => OrderStatus.fromString(status);

  factory Order.fromFirestore(String id, Map<String, dynamic> data) {
    return Order(
      id: id,
      ownerId: data['ownerId'] as String,
      status: data['status'] as String,
      pickup: LocationPoint.fromMap(data['pickup'] as Map<String, dynamic>),
      dropoff: LocationPoint.fromMap(data['dropoff'] as Map<String, dynamic>),
      distanceKm: (data['distanceKm'] as num).toDouble(),
      price: data['price'] as int,
      createdAt: data['createdAt']?.toDate(),
      driverId: data['driverId'] as String?,
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
