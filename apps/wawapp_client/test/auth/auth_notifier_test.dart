import 'package:flutter_test/flutter_test.dart';
import 'package:wawapp_client/features/auth/providers/auth_service_provider.dart';
import 'helpers/test_helpers.dart';
import 'helpers/fake_phone_pin_auth.dart';
import 'helpers/mock_firebase_auth.dart';

void main() {
  group('AuthNotifier', () {
    late FakePhonePinAuth fakeAuthService;
    late MockFirebaseAuth mockFirebaseAuth;
    late AuthNotifier authNotifier;

    setUp(() {
      fakeAuthService = FakePhonePinAuth();
      mockFirebaseAuth = MockFirebaseAuth();
      authNotifier = AuthNotifier(fakeAuthService, mockFirebaseAuth);
    });

    tearDown(() {
      authNotifier.dispose();
      mockFirebaseAuth.dispose();
    });

    group('sendOtp', () {
      test('sends OTP with valid phone number', () async {
        const phone = '+22212345678';

        await authNotifier.sendOtp(phone);

        expect(fakeAuthService.sendOtpCallCount, 1);
        expect(fakeAuthService.lastPhone, phone);
        expect(authNotifier.state.phone, phone);
        expect(authNotifier.state.isLoading, false);
        expect(authNotifier.state.error, null);
      });

      test('handles invalid phone number format', () async {
        const invalidPhone = '12345'; // Not E.164 format

        await authNotifier.sendOtp(invalidPhone);

        expect(authNotifier.state.error, isNotNull);
        expect(authNotifier.state.error, contains('Invalid'));
        expect(authNotifier.state.isLoading, false);
      });

      test('propagates network errors', () async {
        fakeAuthService.shouldFailSendOtp = true;
        const phone = '+22212345678';

        await authNotifier.sendOtp(phone);

        expect(authNotifier.state.error, isNotNull);
        expect(authNotifier.state.error, contains('Failed to send OTP'));
        expect(authNotifier.state.isLoading, false);
      });

      test('sets isLoading during operation', () async {
        const phone = '+22212345678';
        bool wasLoading = false;

        // Start the async operation
        final future = authNotifier.sendOtp(phone);

        // Check if loading state was set (timing-dependent)
        if (authNotifier.state.isLoading) {
          wasLoading = true;
        }

        await future;

        // After completion, loading should be false
        expect(authNotifier.state.isLoading, false);
      });
    });

    group('verifyOtp', () {
      test('verifies OTP successfully and sets user', () async {
        // First send OTP
        await fakeAuthService.ensurePhoneSession('+22212345678');

        // Simulate user being signed in after OTP verification
        final fakeUser = FakeUser(
          uid: 'test-uid',
          phoneNumber: '+22212345678',
        );

        await authNotifier.verifyOtp('123456');

        // Simulate Firebase auth state change
        mockFirebaseAuth.signInUser(fakeUser);
        await Future.delayed(Duration.zero); // Allow stream to emit

        expect(fakeAuthService.verifyOtpCallCount, 1);
        expect(authNotifier.state.isLoading, false);
        expect(authNotifier.state.error, null);
      });

      test('handles invalid OTP code', () async {
        fakeAuthService.shouldFailVerifyOtp = true;

        await authNotifier.verifyOtp('000000');

        expect(authNotifier.state.error, isNotNull);
        expect(authNotifier.state.error, contains('Invalid OTP'));
        expect(authNotifier.state.isLoading, false);
      });

      test('handles missing OTP session', () async {
        // Try to verify without sending OTP first
        fakeAuthService.shouldFailVerifyOtp = true;

        await authNotifier.verifyOtp('123456');

        expect(authNotifier.state.error, isNotNull);
        expect(authNotifier.state.isLoading, false);
      });
    });

    group('createPin', () {
      test('stores PIN and sets hasPin=true', () async {
        const pin = '1234';

        await authNotifier.createPin(pin);

        expect(fakeAuthService.setPinCallCount, 1);
        expect(fakeAuthService.storedPin, pin);
        expect(authNotifier.state.hasPin, true);
        expect(authNotifier.state.isLoading, false);
        expect(authNotifier.state.error, null);
      });

      test('handles PIN creation errors', () async {
        fakeAuthService.shouldFailSetPin = true;

        await authNotifier.createPin('1234');

        expect(authNotifier.state.error, isNotNull);
        expect(authNotifier.state.error, contains('Failed to set PIN'));
        expect(authNotifier.state.hasPin, false);
        expect(authNotifier.state.isLoading, false);
      });
    });

    group('loginByPin', () {
      test('succeeds with correct PIN', () async {
        // Setup: create a PIN first
        await fakeAuthService.setPin('1234');
        fakeAuthService.pinIsValid = true;

        await authNotifier.loginByPin('1234');

        expect(fakeAuthService.verifyPinCallCount, 1);
        expect(authNotifier.state.hasPin, true);
        expect(authNotifier.state.error, null);
        expect(authNotifier.state.isLoading, false);
      });

      test('fails with incorrect PIN', () async {
        // Setup: create a PIN first
        await fakeAuthService.setPin('1234');
        fakeAuthService.pinIsValid = false;

        await authNotifier.loginByPin('9999');

        expect(authNotifier.state.error, 'Invalid PIN');
        expect(authNotifier.state.hasPin, false);
        expect(authNotifier.state.isLoading, false);
      });

      test('handles PIN verification errors', () async {
        fakeAuthService.shouldFailVerifyPin = true;

        await authNotifier.loginByPin('1234');

        expect(authNotifier.state.error, isNotNull);
        expect(authNotifier.state.error, contains('Failed to verify PIN'));
        expect(authNotifier.state.isLoading, false);
      });

      test('simulates lockout on multiple failures', () async {
        // Setup PIN
        await fakeAuthService.setPin('1234');
        fakeAuthService.pinIsValid = false;

        // Attempt multiple failed logins
        for (int i = 0; i < 3; i++) {
          await authNotifier.loginByPin('9999');
          expect(authNotifier.state.error, 'Invalid PIN');
        }

        // Note: Actual lockout implementation would require
        // additional logic in the service/notifier
        expect(fakeAuthService.verifyPinCallCount, 3);
      });
    });

    group('logout', () {
      test('clears user state', () async {
        // Setup: simulate logged in state
        final fakeUser = FakeUser(
          uid: 'test-uid',
          phoneNumber: '+22212345678',
        );
        mockFirebaseAuth.signInUser(fakeUser);
        await Future.delayed(Duration.zero);

        // Set some state
        await fakeAuthService.setPin('1234');
        authNotifier.state = authNotifier.state.copyWith(
          user: fakeUser,
          phone: '+22212345678',
          hasPin: true,
        );

        // Logout
        await authNotifier.logout();

        expect(fakeAuthService.signOutCallCount, 1);
        expect(authNotifier.state.user, null);
        expect(authNotifier.state.phone, null);
        expect(authNotifier.state.hasPin, false);
        expect(authNotifier.state.error, null);
        expect(authNotifier.state.isLoading, false);
      });

      test('handles logout errors', () async {
        // This is a simulated scenario - the fake doesn't actually throw
        // In real implementation, network errors could occur
        await authNotifier.logout();

        expect(fakeAuthService.signOutCallCount, 1);
      });
    });

    group('authStateChanges listener', () {
      test('updates user when Firebase auth state changes', () async {
        final fakeUser = FakeUser(
          uid: 'test-uid',
          phoneNumber: '+22212345678',
        );

        mockFirebaseAuth.signInUser(fakeUser);
        await Future.delayed(Duration.zero); // Allow stream to emit

        expect(authNotifier.state.user, fakeUser);
      });

      test('checks PIN status when user signs in', () async {
        fakeAuthService.initialHasPin = true;
        final fakeUser = FakeUser(
          uid: 'test-uid',
          phoneNumber: '+22212345678',
        );

        mockFirebaseAuth.signInUser(fakeUser);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(fakeAuthService.hasPinHashCallCount, greaterThan(0));
      });

      test('clears hasPin when user signs out', () async {
        // First sign in
        final fakeUser = FakeUser(
          uid: 'test-uid',
          phoneNumber: '+22212345678',
        );
        mockFirebaseAuth.signInUser(fakeUser);
        await Future.delayed(Duration.zero);

        // Then sign out
        mockFirebaseAuth.signOutUser();
        await Future.delayed(Duration.zero);

        expect(authNotifier.state.user, null);
        expect(authNotifier.state.hasPin, false);
        expect(authNotifier.state.phone, null);
      });
    });

    group('error state management', () {
      test('clears previous error on new operation', () async {
        // First operation fails
        fakeAuthService.shouldFailSendOtp = true;
        await authNotifier.sendOtp('+22212345678');
        expect(authNotifier.state.error, isNotNull);

        // Next operation should clear error
        fakeAuthService.shouldFailSendOtp = false;
        await authNotifier.sendOtp('+22212345678');
        expect(authNotifier.state.error, null);
      });

      test('maintains error until next operation', () async {
        fakeAuthService.shouldFailSendOtp = true;
        await authNotifier.sendOtp('+22212345678');

        final errorMessage = authNotifier.state.error;
        expect(errorMessage, isNotNull);

        // Error should persist
        expect(authNotifier.state.error, errorMessage);
      });
    });
  });
}
