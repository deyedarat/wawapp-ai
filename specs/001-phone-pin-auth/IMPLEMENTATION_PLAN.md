# Implementation Plan: Phone Number + PIN Authentication

**Feature**: Phone Number + 4-digit PIN Authentication  
**Branch**: `001-phone-pin-auth`  
**Created**: 2025-01-28  
**Apps**: Client & Driver  

## 1. Data Model Structure (Firestore)

### 1.1 Users Collection (`users`)
```typescript
{
  uid: string,                    // Firebase Auth UID (primary key)
  phoneNumber: string,            // E.164 format (+22212345678)
  pinHash: string,               // bcrypt hash of PIN
  pinSalt: string,               // Random salt for PIN hashing
  accountType: 'client' | 'driver',
  createdAt: Timestamp,
  lastLoginAt: Timestamp,
  isActive: boolean,
  lockoutInfo: {
    failedAttempts: number,      // 0-5
    lockedUntil: Timestamp?,     // null if not locked
    lockoutLevel: number         // 0-4 (exponential backoff level)
  }
}
```

### 1.2 Auth Events Collection (`auth_events`)
```typescript
{
  id: string,                    // Auto-generated document ID
  userId: string,                // Reference to user UID
  eventType: 'auth_start' | 'auth_success' | 'auth_fail' | 'otp_sent' | 'pin_reset',
  timestamp: Timestamp,
  deviceInfo: {
    platform: string,           // 'android' | 'ios'
    appVersion: string,
    deviceId: string
  },
  metadata: {
    ipAddress?: string,
    errorCode?: string,
    attemptNumber?: number
  }
}
```

### 1.3 Security Rules
```javascript
// Firestore Security Rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Auth events are write-only for authenticated users
    match /auth_events/{eventId} {
      allow create: if request.auth != null;
      allow read: if false; // Admin only via backend
    }
  }
}
```

## 2. Firebase Auth OTP Flow Integration

### 2.1 Phone Verification Service
```dart
// lib/features/auth/services/phone_auth_service.dart
class PhoneAuthService {
  static const int otpTimeoutSeconds = 300; // 5 minutes
  static const int resendCooldownSeconds = 30;
  
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
  });
  
  Future<UserCredential> verifyOTP({
    required String verificationId,
    required String otpCode,
  });
}
```

### 2.2 PIN Management Service
```dart
// lib/features/auth/services/pin_service.dart
class PinService {
  Future<String> hashPin(String pin, String salt);
  Future<bool> verifyPin(String pin, String hash, String salt);
  Future<void> updatePin(String userId, String newPin);
  Future<bool> checkLockoutStatus(String userId);
  Future<void> recordFailedAttempt(String userId);
  Future<void> clearLockout(String userId);
}
```

## 3. API Endpoints / Service Interfaces

### 3.1 Authentication Repository
```dart
// lib/features/auth/data/auth_repository.dart
abstract class AuthRepository {
  Future<void> sendOTP(String phoneNumber);
  Future<User> verifyOTPAndCreateAccount(String verificationId, String otp, String pin, AccountType type);
  Future<User> loginWithPhoneAndPin(String phoneNumber, String pin);
  Future<void> resetPin(String phoneNumber, String verificationId, String otp, String newPin);
  Future<void> logAuthEvent(AuthEvent event);
}
```

### 3.2 Firebase Implementation
```dart
// lib/features/auth/data/firebase_auth_repository.dart
class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final PhoneAuthService _phoneService;
  final PinService _pinService;
  
  // Implementation methods...
}
```

## 4. Screen Sequence & Navigation

### 4.1 Client App Flow
```
/auth/welcome → /auth/phone-input → /auth/otp-verification → /auth/pin-setup → /home
                                  ↓
/auth/login → /auth/pin-input → /home
            ↓
/auth/forgot-pin → /auth/phone-input → /auth/otp-verification → /auth/pin-reset → /home
```

### 4.2 Driver App Flow
```
/auth/welcome → /auth/phone-input → /auth/otp-verification → /auth/pin-setup → /driver/dashboard
                                  ↓
/auth/login → /auth/pin-input → /driver/dashboard
            ↓
/auth/forgot-pin → /auth/phone-input → /auth/otp-verification → /auth/pin-reset → /driver/dashboard
```

### 4.3 Router Configuration Updates
```dart
// lib/core/router/app_router.dart - Add auth routes
GoRoute(
  path: '/auth',
  routes: [
    GoRoute(path: '/welcome', builder: (context, state) => const WelcomeScreen()),
    GoRoute(path: '/phone-input', builder: (context, state) => const PhoneInputScreen()),
    GoRoute(path: '/otp-verification', builder: (context, state) => const OTPVerificationScreen()),
    GoRoute(path: '/pin-setup', builder: (context, state) => const PinSetupScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/pin-input', builder: (context, state) => const PinInputScreen()),
    GoRoute(path: '/forgot-pin', builder: (context, state) => const ForgotPinScreen()),
  ],
),
```

## 5. Security Validations

### 5.1 App Check Integration
```dart
// lib/core/security/app_check_service.dart
class AppCheckService {
  static Future<void> initialize() async {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.deviceCheck,
    );
  }
}
```

### 5.2 PIN Security Implementation
```dart
// lib/features/auth/utils/pin_security.dart
class PinSecurity {
  static String generateSalt() => _generateRandomString(32);
  
  static Future<String> hashPin(String pin, String salt) async {
    final bytes = utf8.encode(pin + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  static bool isValidPin(String pin) {
    return RegExp(r'^\d{4}$').hasMatch(pin);
  }
}
```

### 5.3 Lockout Mechanism
```dart
// lib/features/auth/utils/lockout_manager.dart
class LockoutManager {
  static const List<int> lockoutDurations = [60, 300, 900, 3600, 86400]; // seconds
  
  static Future<Duration?> getLockoutDuration(String userId) async;
  static Future<void> recordFailedAttempt(String userId) async;
  static Future<void> clearLockout(String userId) async;
}
```

## 6. Localization & UI Strings

### 6.1 Arabic Strings (intl_ar.arb)
```json
{
  "auth_welcome_title": "مرحباً بك في واو أب",
  "auth_phone_input_title": "أدخل رقم هاتفك",
  "auth_phone_input_hint": "رقم الهاتف",
  "auth_phone_input_button": "إرسال رمز التحقق",
  "auth_otp_title": "أدخل رمز التحقق",
  "auth_otp_subtitle": "تم إرسال رمز التحقق إلى {phoneNumber}",
  "auth_otp_resend": "إعادة إرسال الرمز",
  "auth_otp_verify": "تحقق",
  "auth_pin_setup_title": "إنشاء رمز PIN",
  "auth_pin_setup_subtitle": "أدخل رمز PIN مكون من 4 أرقام",
  "auth_pin_confirm_title": "تأكيد رمز PIN",
  "auth_pin_login_title": "أدخل رمز PIN",
  "auth_forgot_pin": "نسيت رمز PIN؟",
  "auth_error_invalid_phone": "رقم الهاتف غير صحيح",
  "auth_error_invalid_otp": "رمز التحقق غير صحيح",
  "auth_error_invalid_pin": "رمز PIN غير صحيح",
  "auth_error_account_locked": "تم قفل الحساب. حاول مرة أخرى بعد {duration}",
  "auth_success_account_created": "تم إنشاء الحساب بنجاح"
}
```

### 6.2 English Strings (intl_en.arb)
```json
{
  "auth_welcome_title": "Welcome to WawApp",
  "auth_phone_input_title": "Enter your phone number",
  "auth_phone_input_hint": "Phone number",
  "auth_phone_input_button": "Send verification code",
  "auth_otp_title": "Enter verification code",
  "auth_otp_subtitle": "Verification code sent to {phoneNumber}",
  "auth_otp_resend": "Resend code",
  "auth_otp_verify": "Verify",
  "auth_pin_setup_title": "Create PIN",
  "auth_pin_setup_subtitle": "Enter a 4-digit PIN",
  "auth_pin_confirm_title": "Confirm PIN",
  "auth_pin_login_title": "Enter PIN",
  "auth_forgot_pin": "Forgot PIN?",
  "auth_error_invalid_phone": "Invalid phone number",
  "auth_error_invalid_otp": "Invalid verification code",
  "auth_error_invalid_pin": "Invalid PIN",
  "auth_error_account_locked": "Account locked. Try again after {duration}",
  "auth_success_account_created": "Account created successfully"
}
```

### 6.3 French Strings (intl_fr.arb)
```json
{
  "auth_welcome_title": "Bienvenue sur WawApp",
  "auth_phone_input_title": "Entrez votre numéro de téléphone",
  "auth_phone_input_hint": "Numéro de téléphone",
  "auth_phone_input_button": "Envoyer le code de vérification",
  "auth_otp_title": "Entrez le code de vérification",
  "auth_otp_subtitle": "Code de vérification envoyé à {phoneNumber}",
  "auth_otp_resend": "Renvoyer le code",
  "auth_otp_verify": "Vérifier",
  "auth_pin_setup_title": "Créer un code PIN",
  "auth_pin_setup_subtitle": "Entrez un code PIN à 4 chiffres",
  "auth_pin_confirm_title": "Confirmer le code PIN",
  "auth_pin_login_title": "Entrez le code PIN",
  "auth_forgot_pin": "Code PIN oublié?",
  "auth_error_invalid_phone": "Numéro de téléphone invalide",
  "auth_error_invalid_otp": "Code de vérification invalide",
  "auth_error_invalid_pin": "Code PIN invalide",
  "auth_error_account_locked": "Compte verrouillé. Réessayez après {duration}",
  "auth_success_account_created": "Compte créé avec succès"
}
```

## 7. Testing Strategy

### 7.1 Unit Tests
```dart
// test/features/auth/services/pin_service_test.dart
void main() {
  group('PinService', () {
    test('should hash PIN correctly', () async {});
    test('should verify PIN correctly', () async {});
    test('should handle lockout logic', () async {});
  });
}

// test/features/auth/utils/lockout_manager_test.dart
void main() {
  group('LockoutManager', () {
    test('should calculate lockout duration correctly', () {});
    test('should reset lockout after successful login', () {});
  });
}
```

### 7.2 Integration Tests
```dart
// integration_test/auth_flow_test.dart
void main() {
  group('Authentication Flow', () {
    testWidgets('complete registration flow', (tester) async {
      // Test phone input → OTP → PIN setup → login
    });
    
    testWidgets('login with existing account', (tester) async {
      // Test phone + PIN login
    });
    
    testWidgets('PIN recovery flow', (tester) async {
      // Test forgot PIN → phone verification → new PIN
    });
  });
}
```

### 7.3 Golden Tests
```dart
// test/features/auth/widgets/pin_input_widget_test.dart
void main() {
  group('PIN Input Widget Golden Tests', () {
    testWidgets('renders correctly in Arabic', (tester) async {
      await tester.pumpWidget(createTestApp(
        locale: Locale('ar'),
        child: PinInputWidget(),
      ));
      await expectLater(find.byType(PinInputWidget), matchesGoldenFile('pin_input_ar.png'));
    });
  });
}
```

## 8. Logging Events

### 8.1 Auth Event Logger
```dart
// lib/features/auth/services/auth_logger.dart
class AuthLogger {
  static Future<void> logAuthStart(String userId, String eventType) async {
    await _logEvent(AuthEvent(
      userId: userId,
      eventType: 'auth_start',
      timestamp: DateTime.now(),
      metadata: {'flow': eventType},
    ));
  }
  
  static Future<void> logAuthSuccess(String userId, String method) async {
    await _logEvent(AuthEvent(
      userId: userId,
      eventType: 'auth_success',
      timestamp: DateTime.now(),
      metadata: {'method': method},
    ));
  }
  
  static Future<void> logAuthFail(String userId, String error, int attemptNumber) async {
    await _logEvent(AuthEvent(
      userId: userId,
      eventType: 'auth_fail',
      timestamp: DateTime.now(),
      metadata: {
        'error': error,
        'attemptNumber': attemptNumber.toString(),
      },
    ));
  }
}
```

### 8.2 Structured Logging Format
```json
{
  "timestamp": "2025-01-28T10:30:00Z",
  "level": "INFO",
  "event": "auth_success",
  "userId": "user123",
  "sessionId": "session456",
  "deviceInfo": {
    "platform": "android",
    "appVersion": "1.0.1",
    "deviceId": "device789"
  },
  "metadata": {
    "method": "phone_pin",
    "duration_ms": 1250
  }
}
```

## 9. Rollout Plan

### 9.1 Phase 1: Infrastructure Setup (Week 1)
- [ ] Set up Firestore collections and security rules
- [ ] Implement core authentication services
- [ ] Add App Check integration
- [ ] Create basic UI components

### 9.2 Phase 2: Core Authentication (Week 2)
- [ ] Implement phone verification flow
- [ ] Add PIN setup and validation
- [ ] Create authentication screens
- [ ] Add localization strings

### 9.3 Phase 3: Security & Testing (Week 3)
- [ ] Implement lockout mechanism
- [ ] Add comprehensive logging
- [ ] Write unit and integration tests
- [ ] Security audit and penetration testing

### 9.4 Phase 4: Migration Strategy (Week 4)
- [ ] Create migration script for existing anonymous users
- [ ] Implement gradual rollout with feature flags
- [ ] Monitor authentication metrics
- [ ] Handle edge cases and error scenarios

### 9.5 Migration for Existing Users
```dart
// lib/features/auth/services/migration_service.dart
class MigrationService {
  static Future<void> migrateAnonymousUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && currentUser.isAnonymous) {
      // Prompt user to register with phone + PIN
      // Link anonymous account to phone credential
      // Migrate user data to new authenticated account
    }
  }
}
```

### 9.6 Feature Flag Configuration
```dart
// lib/core/config/feature_flags.dart
class FeatureFlags {
  static const bool enablePhonePinAuth = true;
  static const bool requireAuthForNewUsers = false; // Gradual rollout
  static const double authRequiredPercentage = 0.1; // 10% initially
}
```

## 10. Dependencies & Package Updates

### 10.1 Required Packages
```yaml
# Add to pubspec.yaml
dependencies:
  crypto: ^3.0.3              # For PIN hashing
  firebase_app_check: ^0.2.1  # App security
  flutter_secure_storage: ^9.0.0  # Secure token storage
  
dev_dependencies:
  golden_toolkit: ^0.15.0     # Golden tests
  mockito: ^5.4.2            # Mocking for tests
```

### 10.2 Firebase Configuration Updates
```json
// firebase.json - Add App Check
{
  "appCheck": {
    "debug": true
  }
}
```

## 11. Monitoring & Analytics

### 11.1 Key Metrics to Track
- Registration completion rate
- Login success rate
- OTP delivery time
- PIN reset frequency
- Account lockout incidents
- Authentication error rates

### 11.2 Alerts & Monitoring
- High authentication failure rates (>5%)
- OTP delivery delays (>60 seconds)
- Unusual lockout patterns
- Firebase service availability

## 12. Success Criteria Validation

### 12.1 Performance Benchmarks
- [ ] Registration flow completes in <3 minutes
- [ ] Login completes in <30 seconds
- [ ] OTP delivery within 60 seconds (95% success rate)
- [ ] PIN recovery in <2 minutes

### 12.2 Security Validation
- [ ] Zero plaintext PINs in database
- [ ] App Check blocks unauthorized requests
- [ ] Lockout mechanism prevents brute force
- [ ] All auth events logged accurately

### 12.3 Localization Testing
- [ ] All screens work correctly in AR/EN/FR
- [ ] RTL layout proper for Arabic
- [ ] Cultural appropriateness of messaging

---

**Implementation Timeline**: 4 weeks  
**Risk Level**: Medium  
**Dependencies**: Firebase services, SMS delivery reliability  
**Rollback Plan**: Feature flag disable + anonymous auth fallback