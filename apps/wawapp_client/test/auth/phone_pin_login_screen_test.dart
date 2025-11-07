import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wawapp_client/features/auth/providers/auth_service_provider.dart';
import 'package:wawapp_client/features/auth/phone_pin_login_screen.dart';
import 'helpers/test_helpers.dart';
import 'helpers/fake_phone_pin_auth.dart';
import 'helpers/mock_firebase_auth.dart';

void main() {
  group('PhonePinLoginScreen Widget Tests', () {
    late FakePhonePinAuth fakeAuthService;
    late MockFirebaseAuth mockFirebaseAuth;

    setUp(() {
      fakeAuthService = FakePhonePinAuth();
      mockFirebaseAuth = MockFirebaseAuth();
    });

    tearDown(() {
      mockFirebaseAuth.dispose();
    });

    testWidgets('renders phone and PIN input fields', (tester) async {
      await pumpWithProviders(
        tester,
        const PhonePinLoginScreen(),
        overrides: [
          phonePinAuthServiceProvider.overrideWithValue(fakeAuthService),
          authProvider.overrideWith((ref) {
            return AuthNotifier(fakeAuthService, mockFirebaseAuth);
          }),
        ],
      );

      // Check that the screen renders
      expect(find.byType(PhonePinLoginScreen), findsOneWidget);

      // Check for the AppBar title
      expect(find.text('Sign in with Phone'), findsOneWidget);

      // Check for input fields
      expect(find.byType(TextField), findsNWidgets(2));

      // Check for the Continue button
      expect(find.text('Continue'), findsOneWidget);

      // Check for the SMS verification link
      expect(
          find.text('New device or forgot PIN? Verify by SMS'), findsOneWidget);
    });

    testWidgets('phone field accepts E.164 format', (tester) async {
      await pumpWithProviders(
        tester,
        const PhonePinLoginScreen(),
        overrides: [
          phonePinAuthServiceProvider.overrideWithValue(fakeAuthService),
          authProvider.overrideWith((ref) {
            return AuthNotifier(fakeAuthService, mockFirebaseAuth);
          }),
        ],
      );

      final phoneField = find.byType(TextField).first;

      // Enter phone number
      await tester.enterText(phoneField, '+22212345678');
      await tester.pump();

      expect(find.text('+22212345678'), findsOneWidget);
    });

    testWidgets('PIN field is obscured', (tester) async {
      await pumpWithProviders(
        tester,
        const PhonePinLoginScreen(),
        overrides: [
          phonePinAuthServiceProvider.overrideWithValue(fakeAuthService),
          authProvider.overrideWith((ref) {
            return AuthNotifier(fakeAuthService, mockFirebaseAuth);
          }),
        ],
      );

      final pinField = find.byType(TextField).last;
      final pinFieldWidget = tester.widget<TextField>(pinField);

      expect(pinFieldWidget.obscureText, true);
      expect(pinFieldWidget.maxLength, 4);
      expect(pinFieldWidget.keyboardType, TextInputType.number);
    });

    testWidgets('shows error for invalid phone format', (tester) async {
      await pumpWithProviders(
        tester,
        const PhonePinLoginScreen(),
        overrides: [
          phonePinAuthServiceProvider.overrideWithValue(fakeAuthService),
          authProvider.overrideWith((ref) {
            return AuthNotifier(fakeAuthService, mockFirebaseAuth);
          }),
        ],
      );

      final phoneField = find.byType(TextField).first;
      final continueButton = find.text('Continue');

      // Enter invalid phone
      await tester.enterText(phoneField, '12345');
      await tester.pump();

      // Tap Continue
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      // Check for error message
      expect(find.textContaining('Invalid phone format'), findsOneWidget);
    });

    testWidgets('shows error for incorrect PIN', (tester) async {
      fakeAuthService.pinIsValid = false;

      await pumpWithProviders(
        tester,
        const PhonePinLoginScreen(),
        overrides: [
          phonePinAuthServiceProvider.overrideWithValue(fakeAuthService),
          authProvider.overrideWith((ref) {
            return AuthNotifier(fakeAuthService, mockFirebaseAuth);
          }),
        ],
      );

      // Sign in the user first
      final fakeUser = FakeUser(
        uid: 'test-uid',
        phoneNumber: '+22212345678',
      );
      mockFirebaseAuth.signInUser(fakeUser);

      final phoneField = find.byType(TextField).first;
      final pinField = find.byType(TextField).last;
      final continueButton = find.text('Continue');

      // Enter phone and PIN
      await tester.enterText(phoneField, '+22212345678');
      await tester.enterText(pinField, '9999');
      await tester.pump();

      // Tap Continue
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      // Check for error message
      expect(find.text('Invalid PIN'), findsOneWidget);
    });

    testWidgets('disables button while loading', (tester) async {
      await pumpWithProviders(
        tester,
        const PhonePinLoginScreen(),
        overrides: [
          phonePinAuthServiceProvider.overrideWithValue(fakeAuthService),
          authProvider.overrideWith((ref) {
            // Return a notifier with loading state
            final notifier = AuthNotifier(fakeAuthService, mockFirebaseAuth);
            notifier.state = notifier.state.copyWith(isLoading: true);
            return notifier;
          }),
        ],
      );

      await tester.pump();

      final continueButton = find.byType(ElevatedButton).first;
      final buttonWidget = tester.widget<ElevatedButton>(continueButton);

      // Button should be disabled when loading
      expect(buttonWidget.onPressed, isNull);
    });

    testWidgets('displays auth errors from state', (tester) async {
      await pumpWithProviders(
        tester,
        const PhonePinLoginScreen(),
        overrides: [
          phonePinAuthServiceProvider.overrideWithValue(fakeAuthService),
          authProvider.overrideWith((ref) {
            final notifier = AuthNotifier(fakeAuthService, mockFirebaseAuth);
            notifier.state = notifier.state.copyWith(
              error: 'Network error occurred',
            );
            return notifier;
          }),
        ],
      );

      await tester.pump();

      // Check for error message
      expect(find.text('Network error occurred'), findsOneWidget);
    });

    testWidgets('SMS verification button works', (tester) async {
      await pumpWithProviders(
        tester,
        const PhonePinLoginScreen(),
        overrides: [
          phonePinAuthServiceProvider.overrideWithValue(fakeAuthService),
          authProvider.overrideWith((ref) {
            return AuthNotifier(fakeAuthService, mockFirebaseAuth);
          }),
        ],
      );

      final phoneField = find.byType(TextField).first;
      final smsButton = find.text('New device or forgot PIN? Verify by SMS');

      // Enter valid phone
      await tester.enterText(phoneField, '+22212345678');
      await tester.pump();

      // Tap SMS verification
      await tester.tap(smsButton);
      await tester.pumpAndSettle();

      // Verify sendOtp was called
      expect(fakeAuthService.sendOtpCallCount, 1);
    });

    testWidgets('validates PIN length', (tester) async {
      // Sign in the user first
      final fakeUser = FakeUser(
        uid: 'test-uid',
        phoneNumber: '+22212345678',
      );
      mockFirebaseAuth.signInUser(fakeUser);

      await pumpWithProviders(
        tester,
        const PhonePinLoginScreen(),
        overrides: [
          phonePinAuthServiceProvider.overrideWithValue(fakeAuthService),
          authProvider.overrideWith((ref) {
            return AuthNotifier(fakeAuthService, mockFirebaseAuth);
          }),
        ],
      );

      final phoneField = find.byType(TextField).first;
      final pinField = find.byType(TextField).last;
      final continueButton = find.text('Continue');

      // Enter phone and short PIN
      await tester.enterText(phoneField, '+22212345678');
      await tester.enterText(pinField, '12'); // Too short
      await tester.pump();

      // Tap Continue
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      // Check for PIN length error
      expect(find.text('PIN must be 4 digits'), findsOneWidget);
    });

    testWidgets('has proper keyboard types', (tester) async {
      await pumpWithProviders(
        tester,
        const PhonePinLoginScreen(),
        overrides: [
          phonePinAuthServiceProvider.overrideWithValue(fakeAuthService),
          authProvider.overrideWith((ref) {
            return AuthNotifier(fakeAuthService, mockFirebaseAuth);
          }),
        ],
      );

      final phoneField = find.byType(TextField).first;
      final pinField = find.byType(TextField).last;

      final phoneFieldWidget = tester.widget<TextField>(phoneField);
      final pinFieldWidget = tester.widget<TextField>(pinField);

      expect(phoneFieldWidget.keyboardType, TextInputType.phone);
      expect(pinFieldWidget.keyboardType, TextInputType.number);
    });

    testWidgets('has proper field labels', (tester) async {
      await pumpWithProviders(
        tester,
        const PhonePinLoginScreen(),
        overrides: [
          phonePinAuthServiceProvider.overrideWithValue(fakeAuthService),
          authProvider.overrideWith((ref) {
            return AuthNotifier(fakeAuthService, mockFirebaseAuth);
          }),
        ],
      );

      // Check for field labels
      expect(find.text('Phone (+222...)'), findsOneWidget);
      expect(find.text('PIN (4 digits)'), findsOneWidget);
    });

    testWidgets('layout structure is correct', (tester) async {
      await pumpWithProviders(
        tester,
        const PhonePinLoginScreen(),
        overrides: [
          phonePinAuthServiceProvider.overrideWithValue(fakeAuthService),
          authProvider.overrideWith((ref) {
            return AuthNotifier(fakeAuthService, mockFirebaseAuth);
          }),
        ],
      );

      // Verify layout components
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(Column), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
    });
  });

  group('PhonePinLoginScreen Integration', () {
    late FakePhonePinAuth fakeAuthService;
    late MockFirebaseAuth mockFirebaseAuth;

    setUp(() {
      fakeAuthService = FakePhonePinAuth();
      mockFirebaseAuth = MockFirebaseAuth();
    });

    tearDown() {
      mockFirebaseAuth.dispose();
    }

    testWidgets('successful login flow', (tester) async {
      // Setup: user with existing PIN
      final fakeUser = FakeUser(
        uid: 'test-uid',
        phoneNumber: '+22212345678',
      );
      mockFirebaseAuth.signInUser(fakeUser);
      await fakeAuthService.setPin('1234');
      fakeAuthService.pinIsValid = true;

      await pumpWithProviders(
        tester,
        const PhonePinLoginScreen(),
        overrides: [
          phonePinAuthServiceProvider.overrideWithValue(fakeAuthService),
          authProvider.overrideWith((ref) {
            return AuthNotifier(fakeAuthService, mockFirebaseAuth);
          }),
        ],
      );

      final phoneField = find.byType(TextField).first;
      final pinField = find.byType(TextField).last;
      final continueButton = find.text('Continue');

      // Enter credentials
      await tester.enterText(phoneField, '+22212345678');
      await tester.enterText(pinField, '1234');
      await tester.pump();

      // Tap Continue
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      // Verify login was attempted
      expect(fakeAuthService.verifyPinCallCount, 1);
    });
  });
}
