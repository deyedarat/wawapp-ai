# Data Model: Phone + PIN Authentication

## Entities

### UserEntity
```dart
class UserEntity {
  final String id;
  final String phoneNumber;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
}
```

### AuthState
```dart
sealed class AuthState {}
class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthOtpSent extends AuthState { final String verificationId; }
class AuthOtpVerified extends AuthState {}
class AuthPinRequired extends AuthState {}
class AuthAuthenticated extends AuthState { final UserEntity user; }
class AuthError extends AuthState { final String message; }
class AuthLocked extends AuthState { final DateTime unlockAt; }
```

## Storage

### Secure Storage (flutter_secure_storage)
- `user_pin_{userId}`: Encrypted PIN hash
- `auth_token`: Firebase auth token
- `user_id`: Current user ID

### Firestore Collections

#### users/{userId}
```json
{
  "phoneNumber": "+1234567890",
  "createdAt": "2024-12-19T10:00:00Z",
  "lastLoginAt": "2024-12-19T12:00:00Z",
  "pinSetup": true
}
```

#### security_events/{eventId}
```json
{
  "userId": "user123",
  "eventType": "login_success|login_failed|pin_reset",
  "timestamp": "2024-12-19T12:00:00Z",
  "metadata": {}
}
```

## API Contracts

### PhoneAuthService
```dart
Future<String> sendOtp(String phoneNumber);
Future<bool> verifyOtp(String verificationId, String code);
```

### PinService
```dart
Future<void> setPin(String userId, String pin);
Future<bool> verifyPin(String userId, String pin);
Future<void> resetPin(String userId);
Future<bool> isLocked(String userId);
```
