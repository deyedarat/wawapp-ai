import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wawapp_driver/main.dart' as app;

/// Integration test for critical auth flow: OTP -> PIN creation -> Home
///
/// This test verifies the happy path for new driver registration:
/// 1. Enter phone number
/// 2. Receive OTP (mocked in test environment)
/// 3. Enter OTP code
/// 4. Create PIN
/// 5. Land on Home screen
///
/// IMPORTANT: This test requires Firebase Test Lab or local emulator
/// with Firebase Auth configured for testing.
///
/// Run with:
/// flutter test integration_test/auth_flow_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Auth Flow Integration Tests', () {
    testWidgets('OTP -> PIN Creation -> Home happy path',
        (WidgetTester tester) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle();

      // STEP 1: Should land on Phone/PIN login screen
      expect(find.byKey(const Key('phoneField')), findsOneWidget);
      expect(find.byKey(const Key('continueButton')), findsOneWidget);

      // STEP 2: Enter valid Mauritania phone number
      // Using test phone number that works with Firebase Auth emulator
      await tester.enterText(
        find.byKey(const Key('phoneField')),
        '+22212345678', // Valid Mauritania number format
      );
      await tester.pump();

      // STEP 3: Tap Continue to send OTP
      await tester.tap(find.byKey(const Key('continueButton')));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // STEP 4: Should navigate to OTP screen
      expect(find.byKey(const Key('otpField')), findsOneWidget);
      expect(find.byKey(const Key('verifyButton')), findsOneWidget);

      // STEP 5: Enter OTP code
      // In Firebase Auth emulator or test environment, use test OTP
      await tester.enterText(
        find.byKey(const Key('otpField')),
        '123456', // Test OTP code
      );
      await tester.pump();

      // STEP 6: Tap Verify
      await tester.tap(find.byKey(const Key('verifyButton')));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // STEP 7: Should navigate to Create PIN screen (new user)
      expect(find.byKey(const Key('pinField')), findsOneWidget);
      expect(find.byKey(const Key('confirmPinField')), findsOneWidget);
      expect(find.byKey(const Key('savePinButton')), findsOneWidget);

      // STEP 8: Enter valid PIN
      await tester.enterText(
        find.byKey(const Key('pinField')),
        '1357', // Valid PIN (not sequential, not repeated)
      );
      await tester.pump();

      // STEP 9: Confirm PIN
      await tester.enterText(
        find.byKey(const Key('confirmPinField')),
        '1357', // Same PIN
      );
      await tester.pump();

      // STEP 10: Save PIN
      await tester.tap(find.byKey(const Key('savePinButton')));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // STEP 11: Should navigate to Home screen
      // Verify we're on home by checking for home screen elements
      // (Note: Add specific home screen key if needed for stricter verification)
      expect(find.text('Sign in with Phone'), findsNothing);
      expect(find.text('Enter SMS Code'), findsNothing);
      expect(find.text('Set PIN'), findsNothing);

      // Success: We've completed the full auth flow
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
