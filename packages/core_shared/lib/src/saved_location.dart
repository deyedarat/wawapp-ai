import 'package:cloud_firestore/cloud_firestore.dart';

/// Saved location model for client app
class SavedLocation {
  final String id;
  final String userId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final SavedLocationType type;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SavedLocation({
    required this.id,
    required this.userId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create SavedLocation from Firestore document
  factory SavedLocation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SavedLocation.fromJson({...data, 'id': doc.id});
  }

  /// Create SavedLocation from JSON map
  factory SavedLocation.fromJson(Map<String, dynamic> json) {
    return SavedLocation(
      id: json['id'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      type: SavedLocationType.fromString(json['type'] as String),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// Convert to JSON map for Firestore
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'type': type.toString(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Copy with new values
  SavedLocation copyWith({
    String? id,
    String? userId,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    SavedLocationType? type,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SavedLocation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedLocation &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          name == other.name &&
          address == other.address &&
          latitude == other.latitude &&
          longitude == other.longitude &&
          type == other.type;

  @override
  int get hashCode => Object.hash(
        id,
        userId,
        name,
        address,
        latitude,
        longitude,
        type,
      );

  @override
  String toString() => 'SavedLocation(id: $id, name: $name, type: $type)';
}

/// Types of saved locations
enum SavedLocationType {
  home,
  work,
  other;

  /// Create from string value
  static SavedLocationType fromString(String value) {
    switch (value) {
      case 'home':
        return SavedLocationType.home;
      case 'work':
        return SavedLocationType.work;
      case 'other':
        return SavedLocationType.other;
      default:
        return SavedLocationType.other;
    }
  }

  /// Get Arabic label for UI display
  String toArabicLabel() {
    switch (this) {
      case SavedLocationType.home:
        return 'المنزل';
      case SavedLocationType.work:
        return 'العمل';
      case SavedLocationType.other:
        return 'أخرى';
    }
  }

  @override
  String toString() {
    switch (this) {
      case SavedLocationType.home:
        return 'home';
      case SavedLocationType.work:
        return 'work';
      case SavedLocationType.other:
        return 'other';
    }
  }
}
