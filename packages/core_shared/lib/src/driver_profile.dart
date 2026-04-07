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
  final bool isVerified;
  final bool isOnline;
  final bool isBlocked;
  final String? blockReason;
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
    this.isVerified = false,
    this.isOnline = false,
    this.isBlocked = false,
    this.blockReason,
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
    // Helper function to safely parse timestamp
    DateTime _parseTimestamp(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      // Fallback for any other type
      return DateTime.now();
    }

    return DriverProfile(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      photoUrl: json['photoUrl'] as String?,
      vehicleType: json['vehicleType'] as String?,
      vehiclePlate: json['vehiclePlate'] as String?,
      vehicleColor: json['vehicleColor'] as String?,
      city: json['city'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
      isOnline: json['isOnline'] as bool? ?? false,
      isBlocked: json['isBlocked'] as bool? ?? false,
      blockReason: json['blockReason'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalTrips: json['totalTrips'] as int? ?? 0,
      createdAt: _parseTimestamp(json['createdAt']),
      updatedAt: _parseTimestamp(json['updatedAt']),
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
      'isVerified': isVerified,
      'isOnline': isOnline,
      'isBlocked': isBlocked,
      'blockReason': blockReason,
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
    bool? isVerified,
    bool? isOnline,
    bool? isBlocked,
    String? blockReason,
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
      isVerified: isVerified ?? this.isVerified,
      isOnline: isOnline ?? this.isOnline,
      isBlocked: isBlocked ?? this.isBlocked,
      blockReason: blockReason ?? this.blockReason,
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
          isVerified == other.isVerified &&
          isOnline == other.isOnline &&
          isBlocked == other.isBlocked &&
          blockReason == other.blockReason &&
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
        isVerified,
        isOnline,
        isBlocked,
        blockReason,
        rating,
        totalTrips,
      );

  @override
  String toString() => 'DriverProfile(id: $id, name: $name, phone: $phone)';
}

/// Extension for validating driver profile completeness
extension DriverProfileValidation on DriverProfile {
  /// Check if profile has all required fields for going online and accepting orders
  bool get isCompleteForOrders {
    return name.isNotEmpty &&
        vehicleType != null &&
        vehicleType!.isNotEmpty &&
        vehiclePlate != null &&
        vehiclePlate!.isNotEmpty &&
        city != null &&
        city!.isNotEmpty;
  }

  /// Get list of missing required fields
  List<String> get missingRequiredFields {
    final missing = <String>[];
    if (name.isEmpty) missing.add('الاسم');
    if (vehicleType == null || vehicleType!.isEmpty) missing.add('نوع السيارة');
    if (vehiclePlate == null || vehiclePlate!.isEmpty) missing.add('رقم اللوحة');
    if (city == null || city!.isEmpty) missing.add('المدينة');
    return missing;
  }
}
