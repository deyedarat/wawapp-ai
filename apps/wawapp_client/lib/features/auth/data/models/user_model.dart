import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.uid,
    required super.phoneNumber,
    required super.accountType,
    required super.createdAt,
    super.lastLoginAt,
    required super.isActive,
    required super.lockoutInfo,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      phoneNumber: data['phoneNumber'] ?? '',
      accountType: AccountType.values.firstWhere(
        (e) => e.name == data['accountType'],
        orElse: () => AccountType.client,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastLoginAt: data['lastLoginAt'] != null
          ? (data['lastLoginAt'] as Timestamp).toDate()
          : null,
      isActive: data['isActive'] ?? true,
      lockoutInfo: LockoutInfoModel.fromMap(data['lockoutInfo'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'phoneNumber': phoneNumber,
      'accountType': accountType.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
      'isActive': isActive,
      'lockoutInfo': (lockoutInfo as LockoutInfoModel).toMap(),
    };
  }
}

class LockoutInfoModel extends LockoutInfo {
  const LockoutInfoModel({
    required super.failedAttempts,
    super.lockedUntil,
    required super.lockoutLevel,
  });

  factory LockoutInfoModel.fromMap(Map<String, dynamic> map) {
    return LockoutInfoModel(
      failedAttempts: map['failedAttempts'] ?? 0,
      lockedUntil: map['lockedUntil'] != null
          ? (map['lockedUntil'] as Timestamp).toDate()
          : null,
      lockoutLevel: map['lockoutLevel'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'failedAttempts': failedAttempts,
      'lockedUntil': lockedUntil != null ? Timestamp.fromDate(lockedUntil!) : null,
      'lockoutLevel': lockoutLevel,
    };
  }
}