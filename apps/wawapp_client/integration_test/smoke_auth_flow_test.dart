import 'dart:async';

import 'package:auth_shared/auth_shared.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wawapp_client/features/auth/providers/auth_service_provider.dart';
import 'package:wawapp_client/firebase_options.dart';
import 'package:wawapp_client/main.dart';

// Copying minimal Mocks to avoid path import issues across test/integration boundaries
// This approach ensures the integration test is self-contained.

/// Fake PhonePinAuth service
class FakePhonePinAuth implements PhonePinAuth {
  String? _storedPin;
  bool _otpSent = false;

  @override
  final String userCollection = 'users';

  @override
  Future<void> ensurePhoneSession(String phoneE164, {bool forceNewSession = false}) async {
    _otpSent = true;
  }

  @override
  Future<bool> phoneExists(String phoneE164) async {
    return false; // Default new user
  }

  @override
  Future<void> confirmOtp(String smsCode) async {
    if (!_otpSent) throw Exception('No OTP session');
  }

  @override
  Future<void> setPin(String pin) async {
    _storedPin = pin;
  }

  @override
  Future<bool> verifyPin(String pin, String phoneE164) async {
    return pin == _storedPin;
  }

  @override
  Future<bool> hasPinHash() async {
    return _storedPin != null;
  }

  @override
  Future<void> signOut() async {
    _storedPin = null;
    _otpSent = false;
  }

  @override
  String? get lastVerificationId => 'fake-verification-id';
}

/// Fake ClientAuthNotifier
/// Allows explicit state setting for testing routing
class FakeClientAuthNotifier extends ClientAuthNotifier {
  FakeClientAuthNotifier(super.authService, super.firebaseAuth);

  void setTestState(AuthState newState) {
    state = newState;
  }
}

/// Minimal Mock FirebaseAuth
class MockFirebaseAuth extends Fake implements FirebaseAuth {
  final _authStateController = StreamController<User?>.broadcast();
  User? _currentUser;

  @override
  Stream<User?> authStateChanges() => _authStateController.stream;

  @override
  Stream<User?> userChanges() => _authStateController.stream;

  @override
  Stream<User?> idTokenChanges() => _authStateController.stream;

  @override
  User? get currentUser => _currentUser;

  void signInTestUser(User user) {
    _currentUser = user;
    _authStateController.add(user);
  }

  void signOutTestUser() {
    _currentUser = null;
    _authStateController.add(null);
  }

  @override
  Future<void> signOut() async {
    signOutTestUser();
  }

  // Stubs for other methods to satisfy interface
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Mock User
class MockUser extends Fake implements User {
  @override
  final String uid;
  @override
  final String? phoneNumber;

  MockUser({required this.uid, this.phoneNumber});
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Client Auth Routing Smoke Test', () {
    late FakeClientAuthNotifier fakeAuthNotifier;
    late MockFirebaseAuth mockFirebaseAuth;
    late FakePhonePinAuth fakePhonePinAuth;

    setUpAll(() async {
      // Initialize Firebase (needed for CrashlyticsObserver in real code)
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (e) {
        // Ignore if already initialized
        debugPrint('Firebase init error (ignored): $e');
      }
    });

    setUp(() {
      mockFirebaseAuth = MockFirebaseAuth();
      fakePhonePinAuth = FakePhonePinAuth();
      fakeAuthNotifier = FakeClientAuthNotifier(fakePhonePinAuth, mockFirebaseAuth);
    });

    testWidgets('Verify Auth Routing Transitions', (WidgetTester tester) async {
      // 1. Start App - Default state (Logged Out)
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => fakeAuthNotifier),
          ],
          // Using MyApp but we must skip the main() initialization calling runApp
          child: const MyApp(),
        ),
      );
      await tester.pumpAndSettle();

      print('STEP 1: Checking Login Screen');
      expect(find.byKey(const Key('login_screen')), findsOneWidget);

      // 2. Simulate Login (User authenticated but PinStatus unknown/loading)
      final user = MockUser(uid: 'test_user_123', phoneNumber: '+22222123456');

      // We set state manually to test Router reaction
      fakeAuthNotifier.setTestState(AuthState(
        isLoading: false,
        user: user,
        pinStatus: PinStatus.unknown, // Should trigger PinGate
      ));
      await tester.pumpAndSettle();

      print('STEP 2: Checking Pin Gate Screen');
      expect(find.byKey(const Key('pin_gate_screen')), findsOneWidget);

      // 3. Simulate PinStatus.noPin (Should go to Create Pin)
      fakeAuthNotifier.setTestState(AuthState(
        isLoading: false,
        user: user,
        pinStatus: PinStatus.noPin,
        phoneE164: '+22222123456',
      ));
      await tester.pumpAndSettle();

      print('STEP 3: Checking Create Pin Screen');
      expect(find.byKey(const Key('create_pin_screen')), findsOneWidget);

      // 4. Simulate OTP Flow (Priority)
      fakeAuthNotifier.setTestState(AuthState(
        isLoading: false,
        user: user,
        pinStatus: PinStatus.noPin,
        otpFlowActive: true,
        otpStage: OtpStage.codeSent,
        phoneE164: '+22222123456',
      ));
      await tester.pumpAndSettle();

      print('STEP 4: Checking OTP Screen');
      expect(find.byKey(const Key('otp_screen')), findsOneWidget);

      // 5. Simulate HasPin (Should go to Home)
      fakeAuthNotifier.setTestState(AuthState(
        isLoading: false,
        user: user,
        pinStatus: PinStatus.hasPin,
      ));
      await tester.pumpAndSettle();

      print('STEP 5: Checking Home Screen');
      expect(find.byKey(const Key('home_screen')), findsOneWidget);
    });
  });
}
