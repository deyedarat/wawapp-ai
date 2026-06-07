import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Represents the role of a user in the system.
enum UserRole {
  customer,
  laundryOwner,
  staff,
}

/// User model representing both customers and laundry staff.
class UserModel extends Equatable {
  final String uid;
  final String phoneNumber;
  final String name;
  final UserRole role;
  final String? fcmToken;
  final String preferredLanguage;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final bool isActive;

  const UserModel({
    required this.uid,
    required this.phoneNumber,
    required this.name,
    required this.role,
    this.fcmToken,
    this.preferredLanguage = 'ar',
    required this.createdAt,
    this.lastLoginAt,
    this.isActive = true,
  });

  /// Creates a UserModel from a Firestore document snapshot.
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      phoneNumber: data['phoneNumber'] ?? '',
      name: data['name'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == data['role'],
        orElse: () => UserRole.customer,
      ),
      fcmToken: data['fcmToken'],
      preferredLanguage: data['preferredLanguage'] ?? 'ar',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] ?? true,
    );
  }

  /// Converts the UserModel to a Map for Firestore storage.
  Map<String, dynamic> toFirestore() {
    return {
      'phoneNumber': phoneNumber,
      'name': name,
      'role': role.name,
      'fcmToken': fcmToken,
      'preferredLanguage': preferredLanguage,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
      'isActive': isActive,
    };
  }

  /// Creates a copy of this UserModel with the given fields replaced.
  UserModel copyWith({
    String? uid,
    String? phoneNumber,
    String? name,
    UserRole? role,
    String? fcmToken,
    String? preferredLanguage,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? isActive,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      name: name ?? this.name,
      role: role ?? this.role,
      fcmToken: fcmToken ?? this.fcmToken,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props => [
        uid,
        phoneNumber,
        name,
        role,
        fcmToken,
        preferredLanguage,
        createdAt,
        lastLoginAt,
        isActive,
      ];

  @override
  String toString() => 'UserModel(uid: $uid, name: $name, phone: $phoneNumber, role: ${role.name})';
}
