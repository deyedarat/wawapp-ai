import 'package:cloud_firestore/cloud_firestore.dart';

/// A shared place created by admin, visible to all users (clients + drivers + admins).
/// Stored in Firestore collection: shared_places
class SharedPlace {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String? category;
  final bool isActive;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SharedPlace({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.category,
    this.isActive = true,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create SharedPlace from Firestore document
  factory SharedPlace.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SharedPlace.fromJson({...data, 'id': doc.id});
  }

  /// Create SharedPlace from JSON map
  factory SharedPlace.fromJson(Map<String, dynamic> json) {
    return SharedPlace(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      category: json['category'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: json['createdAt'] is Timestamp ? (json['createdAt'] as Timestamp).toDate() : DateTime.now(),
      updatedAt: json['updatedAt'] is Timestamp ? (json['updatedAt'] as Timestamp).toDate() : DateTime.now(),
    );
  }

  /// Convert to JSON map for Firestore
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'category': category,
      'isActive': isActive,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Copy with new values
  SharedPlace copyWith({
    String? id,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    String? category,
    bool? isActive,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SharedPlace(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SharedPlace &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => Object.hash(id, name, latitude, longitude);

  @override
  String toString() => 'SharedPlace(id: $id, name: $name)';
}
