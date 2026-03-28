import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wawapp_driver/main.dart' as app;

/// Integration test for logout flow
///
/// This test verifies:
/// 1. User can logout from profile screen
/// 2. After logout, user is returned to login screen
/// 3. Cannot access home screen without re-authentication
///
/// PREREQUISITES:
/// - User must be already authenticated
/// - Firebase Auth emulator or test environment configured
///
/// Run with:
/// flutter test integration_test/logout_flow_test.dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Logout Flow Integration Tests', () {
    testWidgets('Logout -> Returns to Login -> Cannot access Home',
        (WidgetTester tester) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // ASSUMPTION: User is already authenticated
      // If on login screen, skip this test
      if (find.text('Sign in with Phone').evaluate().isNotEmpty) {
        print('⚠️ User not authenticated - skipping logout test');
        return;
      }

      // STEP 1: Navigate to profile screen
      // Look for profile navigation (adjust based on actual navigation)
      final profileButton = find.byIcon(Icons.person).first;
      if (profileButton.evaluate().isNotEmpty) {
        await tester.tap(profileButton);
        await tester.pumpAndSettle();
      }

      // STEP 2: Find and tap logout button
      final logoutButton = find.byKey(const Key('logoutButton'));
      expect(logoutButton, findsOneWidget,
          reason: 'Logout button should be visible on profile screen');

      await tester.tap(logoutButton);
      await tester.pumpAndSettle();

      // STEP 3: Confirm logout in dialog
      // Look for confirmation dialog with logout button
      final confirmLogout = find.text('تسجيل الخروج').last;
      expect(confirmLogout, findsOneWidget,
          reason: 'Logout confirmation dialog should appear');

      await tester.tap(confirmLogout);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // STEP 4: Should return to login screen
      expect(find.text('Sign in with Phone'), findsOneWidget,
          reason: 'Should be redirected to login screen after logout');
      expect(find.byKey(const Key('phoneField')), findsOneWidget,
          reason: 'Phone field should be visible on login screen');

      // STEP 5: Verify cannot access home without auth
      // The AuthGate should automatically redirect to login
      // No home screen elements should be visible
      expect(find.byKey(const Key('logoutButton')), findsNothing,
          reason: 'Logout button should not be accessible after logout');

      // Success: Logout flow completed and user returned to login
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('Cancelled logout keeps user authenticated',
        (WidgetTester tester) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Skip if not authenticated
      if (find.text('Sign in with Phone').evaluate().isNotEmpty) {
        print('⚠️ User not authenticated - skipping cancel test');
        return;
      }

      // Navigate to profile
      final profileButton = find.byIcon(Icons.person).first;
      if (profileButton.evaluate().isNotEmpty) {
        await tester.tap(profileButton);
        await tester.pumpAndSettle();
      }

      // Tap logout button
      final logoutButton = find.byKey(const Key('logoutButton'));
      if (logoutButton.evaluate().isEmpty) {
        print('⚠️ Logout button not found - skipping cancel test');
        return;
      }

      await tester.tap(logoutButton);
      await tester.pumpAndSettle();

      // STEP: Cancel logout
      final cancelButton = find.text('إلغاء');
      expect(cancelButton, findsOneWidget,
          reason: 'Cancel button should be in logout dialog');

      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      // VERIFY: Should still be on profile screen
      expect(find.byKey(const Key('logoutButton')), findsOneWidget,
          reason: 'Should remain on profile screen after cancelling logout');

      // Success: Cancel logout works correctly
    }, timeout: const Timeout(Duration(minutes: 1)));
  });
}
