import 'package:cloud_firestore/cloud_firestore.dart';

/// Driver profile model for WawApp driver app
class DriverProfile {
  final String id;
  final String name;
  final String phone;
  final String? photoUrl;
  final String? vehicleType;
  final String? vehiclePlate;
  final String? vehicleColor;
  final String? city;
  final String? region;
  final bool isVerified;
  final bool isOnline;
  final double rating;
  final int totalTrips;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DriverProfile({
    required this.id,
    required this.name,
    required this.phone,
    this.photoUrl,
    this.vehicleType,
    this.vehiclePlate,
    this.vehicleColor,
    this.city,
    this.region,
    this.isVerified = false,
    this.isOnline = false,
    this.rating = 0.0,
    this.totalTrips = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create DriverProfile from Firestore document
  factory DriverProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DriverProfile.fromJson({...data, 'id': doc.id});
  }

  /// Create DriverProfile from JSON map
  factory DriverProfile.fromJson(Map<String, dynamic> json) {
    return DriverProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      photoUrl: json['photoUrl'] as String?,
      vehicleType: json['vehicleType'] as String?,
      vehiclePlate: json['vehiclePlate'] as String?,
      vehicleColor: json['vehicleColor'] as String?,
      city: json['city'] as String?,
      region: json['region'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
      isOnline: json['isOnline'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalTrips: json['totalTrips'] as int? ?? 0,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// Convert to JSON map for Firestore
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'photoUrl': photoUrl,
      'vehicleType': vehicleType,
      'vehiclePlate': vehiclePlate,
      'vehicleColor': vehicleColor,
      'city': city,
      'region': region,
      'isVerified': isVerified,
      'isOnline': isOnline,
      'rating': rating,
      'totalTrips': totalTrips,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create update map for driver-editable fields only
  Map<String, dynamic> toDriverUpdateJson() {
    return {
      'name': name,
      'phone': phone,
      'photoUrl': photoUrl,
      'vehicleType': vehicleType,
      'vehiclePlate': vehiclePlate,
      'vehicleColor': vehicleColor,
      'city': city,
      'region': region,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Copy with new values
  DriverProfile copyWith({
    String? id,
    String? name,
    String? phone,
    String? photoUrl,
    String? vehicleType,
    String? vehiclePlate,
    String? vehicleColor,
    String? city,
    String? region,
    bool? isVerified,
    bool? isOnline,
    double? rating,
    int? totalTrips,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DriverProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      vehicleType: vehicleType ?? this.vehicleType,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      city: city ?? this.city,
      region: region ?? this.region,
      isVerified: isVerified ?? this.isVerified,
      isOnline: isOnline ?? this.isOnline,
      rating: rating ?? this.rating,
      totalTrips: totalTrips ?? this.totalTrips,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DriverProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          phone == other.phone &&
          photoUrl == other.photoUrl &&
          vehicleType == other.vehicleType &&
          vehiclePlate == other.vehiclePlate &&
          vehicleColor == other.vehicleColor &&
          city == other.city &&
          region == other.region &&
          isVerified == other.isVerified &&
          isOnline == other.isOnline &&
          rating == other.rating &&
          totalTrips == other.totalTrips;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        phone,
        photoUrl,
        vehicleType,
        vehiclePlate,
        vehicleColor,
        city,
        region,
        isVerified,
        isOnline,
        rating,
        totalTrips,
      );

  @override
  String toString() => 'DriverProfile(id: $id, name: $name, phone: $phone)';
}
