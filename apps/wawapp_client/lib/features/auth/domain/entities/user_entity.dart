enum AccountType { client, driver }

class UserEntity {
  final String uid;
  final String phoneNumber;
  final AccountType accountType;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final bool isActive;
  final LockoutInfo lockoutInfo;

  const UserEntity({
    required this.uid,
    required this.phoneNumber,
    required this.accountType,
    required this.createdAt,
    this.lastLoginAt,
    required this.isActive,
    required this.lockoutInfo,
  });
}

class LockoutInfo {
  final int failedAttempts;
  final DateTime? lockedUntil;
  final int lockoutLevel;

  const LockoutInfo({
    required this.failedAttempts,
    this.lockedUntil,
    required this.lockoutLevel,
  });

  bool get isLocked => lockedUntil != null && DateTime.now().isBefore(lockedUntil!);
}