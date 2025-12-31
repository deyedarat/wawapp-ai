# Firebase Crashlytics Verification Guide

This document provides step-by-step instructions to verify that Firebase Crashlytics is correctly integrated and working in all WawApp applications.

## 📋 Overview

Firebase Crashlytics has been integrated into:
- ✅ **WawApp Driver** (apps/wawapp_driver)
- ✅ **WawApp Client** (apps/wawapp_client)
- ✅ **WawApp Admin** (apps/wawapp_admin)

## 🎯 What Was Implemented

### 1. Error Handlers
All apps now have comprehensive error catching:

- **FlutterError.onError**: Catches all Flutter framework errors (widget errors, layout errors, etc.)
- **PlatformDispatcher.instance.onError**: Catches asynchronous errors and platform-level errors
- **runZonedGuarded**: Catches errors that occur outside the Flutter framework

### 2. Graceful Degradation
- Apps will continue to run even if Crashlytics fails to initialize
- Debug mode: Errors are printed to console AND sent to Crashlytics
- Release mode: Errors are silently sent to Crashlytics
- Web platform (admin app): Crashlytics gracefully degrades (not supported on web)

### 3. Debug Test Utilities
All apps include `lib/debug/crashlytics_test.dart` with test functions:
- `testRecordNonFatalError()`: Test non-fatal error reporting
- `testRecordFatalError()`: Test fatal error reporting
- `testForceCrash()`: Force a crash for end-to-end testing
- `testSetCustomKeys()`: Set custom crash context
- `runVerificationTests()`: Run complete verification suite

---

## 🧪 Verification Steps

### Step 1: Verify Dependencies Are Installed

```bash
# Check that firebase_crashlytics is in pubspec.yaml
cd apps/wawapp_driver
grep firebase_crashlytics pubspec.yaml

cd ../wawapp_client
grep firebase_crashlytics pubspec.yaml

cd ../wawapp_admin
grep firebase_crashlytics pubspec.yaml
```

**Expected output:**
```
firebase_crashlytics: ^4.1.3
```

### Step 2: Build and Run the App

```bash
cd apps/wawapp_driver
flutter run
```

**Expected console output:**
```
🟢 WawApp Driver starting...
✅ Crashlytics error handlers configured
✅ Firebase initialized, Crashlytics ready
```

If you see these messages, Crashlytics is initialized correctly!

### Step 3: Test Non-Fatal Error Reporting

Add this code temporarily to your app (e.g., in a debug button):

```dart
import 'package:flutter/foundation.dart';
import 'debug/crashlytics_test.dart';

// In your widget:
if (kDebugMode) {
  ElevatedButton(
    onPressed: () {
      CrashlyticsTestUtils.testRecordNonFatalError();
    },
    child: Text('Test Crashlytics'),
  );
}
```

**OR** add to `main.dart` after `runApp()`:

```dart
if (kDebugMode) {
  // Test Crashlytics 5 seconds after app launch
  Future.delayed(Duration(seconds: 5), () {
    CrashlyticsTestUtils.runVerificationTests();
  });
}
```

**Expected console output:**
```
📝 Recording test non-fatal error to Crashlytics...
✅ Non-fatal error recorded successfully!
   Check Firebase Console → Crashlytics → Non-fatals
```

### Step 4: Verify in Firebase Console

1. **Open Firebase Console:**
   - Go to https://console.firebase.google.com
   - Select your WawApp project
   - Navigate to **Crashlytics** in the left sidebar

2. **Wait 5-10 minutes** (Crashlytics batches reports)

3. **Check for test errors:**
   - **Non-fatals tab**: Look for "TEST: Non-fatal error from debug testing"
   - **Crashes tab**: Look for "TEST: Fatal error from debug testing"

4. **Verify crash details:**
   - Click on a crash report
   - Check that stack trace is present
   - Verify custom keys appear (if you ran `testSetCustomKeys()`)

### Step 5: Test Force Crash (Optional)

⚠️ **WARNING:** This will terminate the app!

```dart
import 'debug/crashlytics_test.dart';

// Trigger a crash
CrashlyticsTestUtils.testForceCrash();
```

**What happens:**
1. Console will print: "💥 FORCING CRASH IN 3 SECONDS..."
2. App will crash after 3 seconds
3. Relaunch the app
4. Wait 5-10 minutes
5. Check Firebase Console → Crashlytics → Crashes
6. You should see: "TEST: Forced crash for Crashlytics verification"

---

## 🔍 Manual Verification Without Test Utils

If you don't want to use test utilities, manually trigger an error:

```dart
// Add this to any button in your app
ElevatedButton(
  onPressed: () {
    throw Exception('Manual test error');
  },
  child: Text('Trigger Error'),
);
```

Then:
1. Tap the button
2. Wait 5-10 minutes
3. Check Firebase Console → Crashlytics
4. Look for "Manual test error"

---

## 📊 What to Check in Firebase Console

### ✅ Crash Report Should Include:

1. **Error message**: The exception message
2. **Stack trace**: Full Dart stack trace
3. **Device info**: OS version, device model
4. **App version**: Your app version from pubspec.yaml
5. **Custom keys** (if set):
   - test_environment: debug
   - test_user_type: driver/client/admin
   - test_feature: crashlytics_verification
   - test_timestamp: ISO 8601 timestamp

### ✅ Crash Report Should NOT Include:

- User passwords
- API keys
- PII (personally identifiable information)
- Auth tokens

Firebase Crashlytics automatically sanitizes sensitive data.

---

## 🚨 Troubleshooting

### Issue: "Crashlytics initialization failed"

**Possible causes:**
1. Firebase not configured (`google-services.json` missing)
2. Crashlytics not enabled in Firebase Console
3. App not registered in Firebase project

**Solutions:**
1. Run `flutterfire configure` to regenerate Firebase config
2. Enable Crashlytics in Firebase Console:
   - Go to Firebase Console → Crashlytics
   - Click "Enable Crashlytics"
3. Download latest `google-services.json` from Firebase Console

### Issue: "No crashes appearing in Firebase Console"

**Possible causes:**
1. Not enough time has passed (reports are batched)
2. App is in debug mode but Crashlytics disabled
3. Network connectivity issues

**Solutions:**
1. Wait 10-15 minutes and refresh Firebase Console
2. Check console for "✅ Crashlytics error handlers configured"
3. Verify device has internet connection
4. Try force-quitting and relaunching app

### Issue: "Crashes appear but no stack trace"

**Possible causes:**
1. Debug symbols not uploaded (only affects iOS)
2. Obfuscated code without symbol maps

**Solutions:**
1. For Android: Stack traces work automatically
2. For iOS: Run `firebase crashlytics:symbols:upload` (see Firebase docs)
3. For obfuscated builds: Upload symbol maps

---

## 🎓 Best Practices

### In Production:

1. **Always enable Crashlytics** in release builds
2. **Set custom keys** for debugging context:
   ```dart
   FirebaseCrashlytics.instance.setCustomKey('user_id', userId);
   FirebaseCrashlytics.instance.setCustomKey('screen', 'home');
   ```

3. **Set user identifier** (non-PII):
   ```dart
   FirebaseCrashlytics.instance.setUserIdentifier('user_12345');
   ```

4. **Monitor Crashlytics dashboard** regularly:
   - Check crash-free users percentage
   - Set up alerts for new crash types
   - Prioritize fixing crashes affecting most users

### In Development:

1. **Use test utilities** to verify integration
2. **Test both fatal and non-fatal errors**
3. **Verify custom keys appear in reports**
4. **Remove test code** before production release

---

## 📝 Example: Adding Crash Context to Your App

```dart
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class OrderService {
  Future<void> createOrder(Order order) async {
    // Set custom context before critical operation
    FirebaseCrashlytics.instance.setCustomKey('order_id', order.id);
    FirebaseCrashlytics.instance.setCustomKey('order_type', order.type);
    FirebaseCrashlytics.instance.setCustomKey('order_amount', order.amount);

    try {
      // Your order creation logic
      await _saveOrderToFirestore(order);
    } catch (e, stack) {
      // Record non-fatal error (app continues)
      await FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'Failed to create order',
        fatal: false,
      );

      // Show user-friendly error message
      rethrow; // Or handle gracefully
    }
  }
}
```

---

## 🔗 Additional Resources

- [Firebase Crashlytics Docs](https://firebase.google.com/docs/crashlytics)
- [FlutterFire Crashlytics Plugin](https://firebase.flutter.dev/docs/crashlytics/overview)
- [Test Crashlytics Implementation](https://firebase.google.com/docs/crashlytics/test-implementation)

---

## ✅ Verification Checklist

Use this checklist to verify Crashlytics is working correctly:

### Driver App
- [ ] Dependency added to pubspec.yaml
- [ ] `flutter pub get` completed successfully
- [ ] App builds without errors
- [ ] Console shows "✅ Crashlytics error handlers configured"
- [ ] Test non-fatal error recorded
- [ ] Test fatal error recorded
- [ ] Errors appear in Firebase Console (wait 10 min)

### Client App
- [ ] Dependency added to pubspec.yaml
- [ ] `flutter pub get` completed successfully
- [ ] App builds without errors
- [ ] Console shows "✅ Crashlytics error handlers configured"
- [ ] Test non-fatal error recorded
- [ ] Test fatal error recorded
- [ ] Errors appear in Firebase Console (wait 10 min)

### Admin App (Web)
- [ ] Dependency added to pubspec.yaml
- [ ] `flutter pub get` completed successfully
- [ ] App builds without errors
- [ ] Console shows graceful degradation message (web)
- [ ] No crashes when Crashlytics fails (expected on web)

---

## 🎉 Success Criteria

Your Crashlytics integration is successful when:

1. ✅ All apps build and run without errors
2. ✅ Console shows "✅ Crashlytics error handlers configured" on app launch
3. ✅ Test errors appear in Firebase Console within 10 minutes
4. ✅ Stack traces are complete and readable
5. ✅ Custom keys appear in crash reports
6. ✅ Crash-free users metric appears in Firebase Console

**Congratulations!** 🎊 You now have production-ready crash reporting for all WawApp applications.
