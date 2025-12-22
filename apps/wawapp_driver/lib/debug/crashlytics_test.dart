// DEBUG ONLY: Crashlytics Testing Utilities
// This file provides utilities to test crash reporting in development
// DO NOT use these functions in production code

import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Test utilities for Firebase Crashlytics
/// Only available in debug mode
class CrashlyticsTestUtils {
  CrashlyticsTestUtils._();

  /// Test recording a non-fatal error to Crashlytics
  /// This will appear in Firebase Console under "Non-fatals"
  static Future<void> testRecordNonFatalError() async {
    if (!kDebugMode) {
      print('⚠️ Crashlytics test functions only work in debug mode');
      return;
    }

    try {
      print('📝 Recording test non-fatal error to Crashlytics...');

      await FirebaseCrashlytics.instance.recordError(
        Exception('TEST: Non-fatal error from debug testing'),
        StackTrace.current,
        reason: 'Manual test triggered by developer',
        information: [
          'This is a test error',
          'Triggered from CrashlyticsTestUtils',
          'Should appear in Firebase Console',
        ],
        fatal: false,
      );

      print('✅ Non-fatal error recorded successfully!');
      print('   Check Firebase Console → Crashlytics → Non-fatals');
    } catch (e) {
      print('❌ Failed to record non-fatal error: $e');
    }
  }

  /// Test recording a fatal error to Crashlytics
  /// This will appear in Firebase Console under "Crashes"
  static Future<void> testRecordFatalError() async {
    if (!kDebugMode) {
      print('⚠️ Crashlytics test functions only work in debug mode');
      return;
    }

    try {
      print('📝 Recording test fatal error to Crashlytics...');

      await FirebaseCrashlytics.instance.recordError(
        Exception('TEST: Fatal error from debug testing'),
        StackTrace.current,
        reason: 'Manual crash test triggered by developer',
        information: [
          'This is a simulated crash',
          'Triggered from CrashlyticsTestUtils',
          'Should appear in Firebase Console',
        ],
        fatal: true,
      );

      print('✅ Fatal error recorded successfully!');
      print('   Check Firebase Console → Crashlytics → Crashes');
    } catch (e) {
      print('❌ Failed to record fatal error: $e');
    }
  }

  /// Force an immediate crash for testing
  /// ⚠️ WARNING: This will terminate the app!
  /// Use only for testing crash reporting pipeline
  static void testForceCrash() {
    if (!kDebugMode) {
      print('⚠️ Crashlytics test functions only work in debug mode');
      return;
    }

    print('💥 FORCING CRASH IN 3 SECONDS...');
    print('   This will terminate the app!');
    print('   Check Firebase Console after relaunch.');

    Future.delayed(const Duration(seconds: 3), () {
      // This will trigger a crash that Crashlytics will catch
      throw Exception('TEST: Forced crash for Crashlytics verification');
    });
  }

  /// Set custom keys for crash context
  static Future<void> testSetCustomKeys() async {
    if (!kDebugMode) {
      print('⚠️ Crashlytics test functions only work in debug mode');
      return;
    }

    try {
      print('📝 Setting custom crash context keys...');

      final crashlytics = FirebaseCrashlytics.instance;

      await crashlytics.setCustomKey('test_environment', 'debug');
      await crashlytics.setCustomKey('test_user_type', 'driver');
      await crashlytics.setCustomKey('test_feature', 'crashlytics_verification');
      await crashlytics.setCustomKey('test_timestamp', DateTime.now().toIso8601String());

      print('✅ Custom keys set successfully!');
      print('   These will appear with any crash reports.');
    } catch (e) {
      print('❌ Failed to set custom keys: $e');
    }
  }

  /// Comprehensive Crashlytics verification
  /// Runs all tests and reports status
  static Future<void> runVerificationTests() async {
    if (!kDebugMode) {
      print('⚠️ Crashlytics verification only works in debug mode');
      return;
    }

    print('\n${'=' * 60}');
    print('🧪 CRASHLYTICS VERIFICATION TEST SUITE');
    print('=' * 60);
    print('');

    // Test 1: Set custom keys
    print('Test 1/3: Setting custom crash context...');
    await testSetCustomKeys();
    await Future.delayed(const Duration(seconds: 1));

    // Test 2: Record non-fatal error
    print('\nTest 2/3: Recording non-fatal error...');
    await testRecordNonFatalError();
    await Future.delayed(const Duration(seconds: 1));

    // Test 3: Record fatal error
    print('\nTest 3/3: Recording fatal error...');
    await testRecordFatalError();
    await Future.delayed(const Duration(seconds: 1));

    print('\n${'=' * 60}');
    print('✅ VERIFICATION COMPLETE');
    print('=' * 60);
    print('');
    print('Next steps:');
    print('1. Wait 5-10 minutes for reports to appear in Firebase');
    print('2. Open Firebase Console → Crashlytics');
    print('3. Verify you see:');
    print('   - Non-fatal error: "TEST: Non-fatal error from debug testing"');
    print('   - Fatal error: "TEST: Fatal error from debug testing"');
    print('4. Check that custom keys appear in crash details');
    print('');
    print('Optional: Run testForceCrash() to verify end-to-end crash flow');
    print('');
  }

  /// Print usage instructions
  static void printUsageInstructions() {
    print('\n${'=' * 60}');
    print('📚 CRASHLYTICS TEST UTILITIES - USAGE GUIDE');
    print('=' * 60);
    print('');
    print('To test Crashlytics integration, add this to your app:');
    print('');
    print('Example 1: Add a test button in debug builds');
    print('```dart');
    print('if (kDebugMode) {');
    print('  FloatingActionButton(');
    print('    onPressed: () {');
    print('      CrashlyticsTestUtils.runVerificationTests();');
    print('    },');
    print('    child: Icon(Icons.bug_report),');
    print('  );');
    print('}');
    print('```');
    print('');
    print('Example 2: Test from main.dart');
    print('```dart');
    print('if (kDebugMode) {');
    print('  // Test Crashlytics 10 seconds after app launch');
    print('  Future.delayed(Duration(seconds: 10), () {');
    print('    CrashlyticsTestUtils.runVerificationTests();');
    print('  });');
    print('}');
    print('```');
    print('');
    print('Available test functions:');
    print('- testRecordNonFatalError(): Record non-fatal error');
    print('- testRecordFatalError(): Record fatal error');
    print('- testForceCrash(): Force immediate crash (⚠️ terminates app!)');
    print('- testSetCustomKeys(): Set custom crash context');
    print('- runVerificationTests(): Run all tests');
    print('');
    print('=' * 60);
    print('');
  }
}
