import 'package:cloud_firestore/cloud_firestore.dart';

/// Client profile model for WawApp client app
class ClientProfile {
  final String id;
  final String name;
  final String phone;
  final String? photoUrl;
  final String preferredLanguage;
  final int totalTrips;
  final double averageRating;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ClientProfile({
    required this.id,
    required this.name,
    required this.phone,
    this.photoUrl,
    this.preferredLanguage = 'ar',
    this.totalTrips = 0,
    this.averageRating = 0.0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create ClientProfile from Firestore document
  factory ClientProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClientProfile.fromJson({...data, 'id': doc.id});
  }

  /// Create ClientProfile from JSON map
  factory ClientProfile.fromJson(Map<String, dynamic> json) {
    return ClientProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'غير محدد',
      phone: json['phone'] as String? ?? 'غير محدد',
      photoUrl: json['photoUrl'] as String?,
      preferredLanguage: json['preferredLanguage'] as String? ?? 'ar',
      totalTrips: json['totalTrips'] as int? ?? 0,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  /// Convert to JSON map for Firestore
  ///
  /// ⚠️  WARNING: This includes ALL fields including protected ones (totalTrips, averageRating).
  /// DO NOT use this for profile updates from client apps.
  /// Use toClientUpdateJson() instead for client-initiated updates.
  ///
  /// This method is safe for:
  /// - Reading from Firestore (fromJson counterpart)
  /// - Server-side Cloud Functions (bypasses security rules)
  ///
  /// This method is UNSAFE for:
  /// - Client profile updates (use toClientUpdateJson())
  /// - Client profile creation (use toClientUpdateJson() + createdAt)
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'photoUrl': photoUrl,
      'preferredLanguage': preferredLanguage,
      'totalTrips': totalTrips,
      'averageRating': averageRating,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create update map for client-editable fields only
  Map<String, dynamic> toClientUpdateJson() {
    return {
      'name': name,
      'phone': phone,
      'photoUrl': photoUrl,
      'preferredLanguage': preferredLanguage,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Copy with new values
  ClientProfile copyWith({
    String? id,
    String? name,
    String? phone,
    String? photoUrl,
    String? preferredLanguage,
    int? totalTrips,
    double? averageRating,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ClientProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      totalTrips: totalTrips ?? this.totalTrips,
      averageRating: averageRating ?? this.averageRating,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClientProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          phone == other.phone &&
          photoUrl == other.photoUrl &&
          preferredLanguage == other.preferredLanguage &&
          totalTrips == other.totalTrips &&
          averageRating == other.averageRating;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        phone,
        photoUrl,
        preferredLanguage,
        totalTrips,
        averageRating,
      );

  @override
  String toString() => 'ClientProfile(id: $id, name: $name, phone: $phone)';
}
