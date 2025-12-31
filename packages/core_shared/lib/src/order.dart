import 'package:cloud_firestore/cloud_firestore.dart';
import 'order_status.dart';

/// Unified Order model for WawApp
/// Merges fields from both Client and Driver app implementations
class Order {
  final String? id;
  final String? ownerId;
  final double distanceKm;
  final double price;

  // Address fields (from Client app)
  final String pickupAddress;
  final String dropoffAddress;

  // Location coordinates
  final LocationPoint pickup;
  final LocationPoint dropoff;

  final String? status;
  final String? driverId;

  // Driver-specific field: separate assigned driver tracking
  final String? assignedDriverId;

  // Timestamps
  final DateTime? createdAt;
  final DateTime? updatedAt; // from Driver app
  final DateTime? completedAt;

  // Rating fields
  final int? driverRating;
  final DateTime? ratedAt; // from Client app

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
    this.assignedDriverId,
    this.createdAt,
    this.updatedAt,
    this.completedAt,
    this.driverRating,
    this.ratedAt,
  });

  OrderStatus get orderStatus =>
      OrderStatus.fromFirestore(status ?? 'requested');

  /// Factory constructor for Client app compatibility
  /// Accepts data map without separate id parameter
  factory Order.fromFirestore(Map<String, dynamic> data) {
    final pickupData = data['pickup'] as Map<String, dynamic>;
    final dropoffData = data['dropoff'] as Map<String, dynamic>;

    return Order(
      id: data['id'] as String?,
      ownerId: data['ownerId'] as String?,
      distanceKm: (data['distanceKm'] as num).toDouble(),
      price: (data['price'] as num).toDouble(),
      pickupAddress: data['pickupAddress'] as String? ??
          pickupData['label'] as String? ??
          '',
      dropoffAddress: data['dropoffAddress'] as String? ??
          dropoffData['label'] as String? ??
          '',
      pickup: LocationPoint.fromMap(pickupData),
      dropoff: LocationPoint.fromMap(dropoffData),
      status: data['status'] as String?,
      driverId: data['driverId'] as String?,
      assignedDriverId: data['assignedDriverId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      driverRating: data['driverRating'] as int?,
      ratedAt: (data['ratedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Factory constructor for Driver app compatibility
  /// Accepts id as separate parameter
  factory Order.fromFirestoreWithId(String id, Map<String, dynamic> data) {
    final pickupData = data['pickup'] as Map<String, dynamic>;
    final dropoffData = data['dropoff'] as Map<String, dynamic>;

    return Order(
      id: id,
      ownerId: data['ownerId'] as String?,
      distanceKm: (data['distanceKm'] as num).toDouble(),
      price: (data['price'] as num).toDouble(),
      pickupAddress: data['pickupAddress'] as String? ??
          pickupData['label'] as String? ??
          '',
      dropoffAddress: data['dropoffAddress'] as String? ??
          dropoffData['label'] as String? ??
          '',
      pickup: LocationPoint.fromMap(pickupData),
      dropoff: LocationPoint.fromMap(dropoffData),
      status: data['status'] as String?,
      driverId: data['driverId'] as String?,
      assignedDriverId: data['assignedDriverId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      driverRating: data['driverRating'] as int?,
      ratedAt: (data['ratedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'ownerId': ownerId,
        'distanceKm': distanceKm,
        'price': price,
        'pickupAddress': pickupAddress,
        'dropoffAddress': dropoffAddress,
        'pickup': pickup.toMap(),
        'dropoff': dropoff.toMap(),
        'status': status,
        'driverId': driverId,
        'assignedDriverId': assignedDriverId,
        'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
        'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
        'completedAt':
            completedAt != null ? Timestamp.fromDate(completedAt!) : null,
        'driverRating': driverRating,
        'ratedAt': ratedAt != null ? Timestamp.fromDate(ratedAt!) : null,
      };

  Order copyWith({
    String? id,
    String? ownerId,
    double? distanceKm,
    double? price,
    String? pickupAddress,
    String? dropoffAddress,
    LocationPoint? pickup,
    LocationPoint? dropoff,
    String? status,
    String? driverId,
    String? assignedDriverId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    int? driverRating,
    DateTime? ratedAt,
  }) {
    return Order(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      distanceKm: distanceKm ?? this.distanceKm,
      price: price ?? this.price,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      dropoffAddress: dropoffAddress ?? this.dropoffAddress,
      pickup: pickup ?? this.pickup,
      dropoff: dropoff ?? this.dropoff,
      status: status ?? this.status,
      driverId: driverId ?? this.driverId,
      assignedDriverId: assignedDriverId ?? this.assignedDriverId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      driverRating: driverRating ?? this.driverRating,
      ratedAt: ratedAt ?? this.ratedAt,
    );
  }
}

/// Location point with coordinates and label
/// Used for pickup and dropoff locations
class LocationPoint {
  final double lat;
  final double lng;
  final String label;

  const LocationPoint({
    required this.lat,
    required this.lng,
    required this.label,
  });

  // Add these getters for Client app compatibility
  double get latitude => lat;
  double get longitude => lng;

  factory LocationPoint.fromMap(Map<String, dynamic> map) {
    return LocationPoint(
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      label: map['label'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'lat': lat,
        'lng': lng,
        'label': label,
      };
}
