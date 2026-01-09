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

  @override
  Future<void> checkHasPin() async {
    // No-op for testing to prevent side-effects from PinGateScreen
    debugPrint('[TEST] checkHasPin() ignored in fake');
  }
}

Future<void> settle(WidgetTester tester, {int ms = 300}) async {
  await tester.pump(const Duration(milliseconds: 50));
  // Wait for a fixed duration instead of settling, to support infinite animations
  await tester.pump(Duration(milliseconds: ms));
}

Future<void> pushState(WidgetTester tester, FakeClientAuthNotifier fake, AuthState s, {String? label}) async {
  debugPrint(
      '[TEST] setTestState: ${label ?? ''} pinStatus=${s.pinStatus} otp=${s.otpFlowActive} stage=${s.otpStage} user=${s.user?.uid}');
  fake.setTestState(s);
  // Give router + listeners time to process
  await tester.pump(const Duration(milliseconds: 16));
}

extension PumpUntilFound on WidgetTester {
  Future<void> pumpUntilFound(
    Finder finder, {
    Duration timeout = const Duration(seconds: 10),
    Duration step = const Duration(milliseconds: 100),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await pump(step);
      if (any(finder)) return;
    }
    throw TestFailure('pumpUntilFound timeout after $timeout for: $finder');
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

// Debug helper to verify step execution
String _lastStep = 'BOOT';

void step(String s) {
  _lastStep = s;
  // ignore: avoid_print
  print('STEP: $s');
}

Timer? _watchdog;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _watchdog?.cancel();
    _watchdog = Timer(const Duration(seconds: 45), () {
      // ignore: avoid_print
      print('❌ WATCHDOG TIMEOUT. Last step = $_lastStep');
    });
  });

  tearDown(() {
    _watchdog?.cancel();
  });

  group('Client Auth Routing Smoke Test', () {
    late FakeClientAuthNotifier fakeAuthNotifier;
    late MockFirebaseAuth mockFirebaseAuth;
    late FakePhonePinAuth fakePhonePinAuth;

    setUpAll(() async {
      // Initialize Firebase safely (guard against duplicate initialization)
      if (Firebase.apps.isEmpty) {
        try {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        } catch (e) {
          debugPrint('Firebase init error: $e');
        }
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
      await settle(tester, ms: 500);

      step('1: Checking Login Screen');
      await tester.pumpUntilFound(find.byKey(const ValueKey('screen_login')));
      expect(find.byKey(const ValueKey('screen_login')), findsOneWidget);

      await settle(tester);

      // 2. Simulate Login
      final user = MockUser(uid: 'test_user_123', phoneNumber: '+22222123456');

      await pushState(
          tester,
          fakeAuthNotifier,
          AuthState(
            isLoading: false,
            user: user,
            pinStatus: PinStatus.unknown,
          ),
          label: 'STEP 2 -> Login');

      step('2: Checking Pin Gate Screen');
      await tester.pumpUntilFound(find.byKey(const ValueKey('screen_pin_gate')));
      expect(find.byKey(const ValueKey('screen_pin_gate')), findsOneWidget);

      await settle(tester);

      // 3. Simulate PinStatus.noPin
      await pushState(
          tester,
          fakeAuthNotifier,
          AuthState(
            isLoading: false,
            user: user,
            pinStatus: PinStatus.noPin,
            phoneE164: '+22222123456',
          ),
          label: 'STEP 3 -> NoPin');

      step('3: Checking Create Pin Screen');
      await tester.pumpUntilFound(find.byKey(const ValueKey('screen_create_pin')));
      expect(find.byKey(const ValueKey('screen_create_pin')), findsOneWidget);

      await settle(tester);

      // 4. Simulate OTP Flow
      await pushState(
          tester,
          fakeAuthNotifier,
          AuthState(
            isLoading: false,
            user: user,
            pinStatus: PinStatus.noPin,
            otpFlowActive: true,
            otpStage: OtpStage.codeSent,
            phoneE164: '+22222123456',
          ),
          label: 'STEP 4 -> OTP');

      step('4: Checking OTP Screen');
      await tester.pumpUntilFound(find.byKey(const ValueKey('screen_otp')));
      expect(find.byKey(const ValueKey('screen_otp')), findsOneWidget);

      await settle(tester);

      // 5. Simulate HasPin
      await pushState(
          tester,
          fakeAuthNotifier,
          AuthState(
            isLoading: false,
            user: user,
            pinStatus: PinStatus.hasPin,
          ),
          label: 'STEP 5 -> Home');

      step('5: Checking Home Screen');
      await tester.pumpUntilFound(find.byKey(const ValueKey('screen_home')));
      expect(find.byKey(const ValueKey('screen_home')), findsOneWidget);
    });
  });
}
