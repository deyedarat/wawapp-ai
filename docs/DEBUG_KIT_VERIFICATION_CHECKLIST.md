# Debug & Observability Kit - Verification Checklist

Use this checklist to verify the Debug & Observability Kit is working correctly.

---

## ✅ Pre-Flight Checks

### 1. Dependencies Installed

```powershell
cd packages\core_shared
flutter pub get
# ✅ Should complete without errors

cd ..\..\apps\wawapp_client
flutter pub get
# ✅ Should complete without errors

cd ..\wawapp_driver
flutter pub get
# ✅ Should complete without errors
```

**Expected:** All packages resolve successfully, no version conflicts

---

### 2. Build Verification

```powershell
cd apps\wawapp_client
flutter build apk --debug
# ✅ Should build successfully

cd ..\wawapp_driver
flutter build apk --debug
# ✅ Should build successfully
```

**Expected:** Both APKs build without Gradle or compilation errors

---

## 📱 Client App Tests

### Test 1: App Launches with Observability

```bash
cd apps/wawapp_client
flutter run
```

**Check Console Output:**
- [ ] `[App][DEBUG] 🚀 WawApp Client initializing...`
- [ ] `[App][DEBUG] ✅ Firebase & Crashlytics initialized`
- [ ] `[App][DEBUG] 📍 Ensuring location ready...`
- [ ] `[App][DEBUG] ✅ WawApp initialization complete`

**Check App Screen:**
- [ ] Performance overlay visible (two bars at top)
- [ ] App launches normally

---

### Test 2: ProviderObserver Logging

**Action:** Navigate through app (sign in, view screens)

**Check Console:**
- [ ] See `[ProviderObserver][DEBUG]` logs
- [ ] Provider names appear in logs
- [ ] Updates logged when navigating

**Example:**
```
[ProviderObserver][DEBUG] authStateProvider updated
[ProviderObserver][DEBUG] routerProvider updated
```

---

### Test 3: WawLog Functionality

**Add test code temporarily:**

```dart
import 'package:core_shared/core_shared.dart';

// In any screen or button
WawLog.d('TestTag', 'Debug message');
WawLog.w('TestTag', 'Warning message');
WawLog.e('TestTag', 'Error message', Exception('Test'), StackTrace.current);
```

**Check Console:**
- [ ] `[TestTag][DEBUG] Debug message`
- [ ] `[TestTag][WARN] Warning message`
- [ ] `[TestTag][ERROR] Error message`
- [ ] Error details and stack trace printed

---

### Test 4: Crashlytics Test Crash

**Option A: Via Debug Menu (if route added)**

1. Navigate to `/debug`
2. Tap "Trigger Test Crash"
3. App crashes immediately

**Option B: Via Code**

```dart
import 'package:core_shared/core_shared.dart';

CrashlyticsObserver.testCrash();
```

**Verify:**
- [ ] App crashes immediately
- [ ] Wait 5-10 minutes
- [ ] Open Firebase Console → Crashlytics
- [ ] See crash report for "Test crash from WawApp"
- [ ] Stack trace visible
- [ ] Device info visible

---

### Test 5: Non-Fatal Error Logging

**Add test code:**

```dart
WawLog.e('TestError', 'Non-fatal test error', 
  Exception('Test non-fatal'), StackTrace.current);
```

**Verify:**
- [ ] App continues running (doesn't crash)
- [ ] Error logged to console
- [ ] Wait 5-10 minutes
- [ ] Check Firebase Console → Crashlytics → Non-fatals
- [ ] See error report with tag "[TestError]"

---

## 🚗 Driver App Tests

### Test 6: Driver App Launches

```bash
cd apps/wawapp_driver
flutter run
```

**Check Console Output:**
- [ ] `[App][DEBUG] 🚀 WawApp Driver initializing...`
- [ ] `[App][DEBUG] ✅ Firebase & Crashlytics initialized`
- [ ] `[App][DEBUG] ✅ WawApp Driver initialization complete`

**Check App Screen:**
- [ ] Performance overlay visible
- [ ] App launches normally

---

### Test 7: Driver ProviderObserver

**Action:** Navigate through driver app

**Check Console:**
- [ ] `[ProviderObserver][DEBUG]` logs appear
- [ ] Provider updates tracked

---

### Test 8: Driver Crashlytics

**Test crash:**

```dart
CrashlyticsObserver.testCrash();
```

**Verify:**
- [ ] App crashes
- [ ] Wait 5-10 minutes
- [ ] Firebase Console shows crash for driver app
- [ ] Separate from client app crashes

---

## 🎛️ Configuration Tests

### Test 9: Debug Config Values

**Check in Debug Menu or add code:**

```dart
import 'package:core_shared/core_shared.dart';

print('Performance Overlay: ${DebugConfig.enablePerformanceOverlay}');
print('Provider Observer: ${DebugConfig.enableProviderObserver}');
print('Verbose Logging: ${DebugConfig.enableVerboseLogging}');
print('Crashlytics Non-Fatal: ${DebugConfig.enableNonFatalCrashlytics}');
```

**Expected in DEBUG builds:**
- [ ] `enablePerformanceOverlay: true`
- [ ] `enableProviderObserver: true`
- [ ] `enableVerboseLogging: true`
- [ ] `enableNonFatalCrashlytics: true`

---

### Test 10: Profile Mode

```bash
flutter run --profile
```

**Verify:**
- [ ] No performance overlay visible
- [ ] No ProviderObserver logs
- [ ] Minimal console output
- [ ] App runs smoothly

---

### Test 11: Release Mode

```bash
flutter run --release
```

**Verify:**
- [ ] No debug features visible
- [ ] No verbose logging
- [ ] Crashlytics still active
- [ ] Production-ready behavior

---

## 🔧 DevTools Integration

### Test 12: DevTools Connection

```bash
# Terminal 1: Run app
flutter run --profile

# Terminal 2: Open DevTools
flutter pub global activate devtools
flutter pub global run devtools
```

**Verify:**
- [ ] DevTools opens in browser
- [ ] Can connect to running app
- [ ] Performance tab shows timeline
- [ ] Memory tab shows heap usage
- [ ] Can record and analyze frames

---

## 📊 Performance Monitoring

### Test 13: Performance Overlay

**In debug mode:**

**Check overlay bars:**
- [ ] Top bar (GPU thread) visible
- [ ] Bottom bar (UI thread) visible
- [ ] Bars are mostly green (good performance)
- [ ] Red spikes indicate jank (expected during heavy operations)

---

### Test 14: Rebuild Loop Detection

**Create intentional loop (test only):**

```dart
// DON'T commit this - test only!
final testProvider = StateProvider<int>((ref) {
  final value = ref.watch(testProvider);
  return value + 1; // Circular dependency
});
```

**Verify:**
- [ ] Console floods with `[ProviderObserver][DEBUG]` logs
- [ ] Same provider name repeats rapidly
- [ ] Identifies rebuild loop

**Remove test code after verification**

---

## 🚀 VS Code Tasks

### Test 15: VS Code Tasks

**Open Command Palette:** `Ctrl+Shift+P` → "Tasks: Run Task"

**Verify tasks exist:**
- [ ] Client: Run Debug
- [ ] Client: Run Profile
- [ ] Driver: Run Debug
- [ ] Driver: Run Profile
- [ ] Client: Build APK
- [ ] Driver: Build APK
- [ ] Open DevTools

**Test one task:**
- [ ] Select "Client: Run Debug"
- [ ] App builds and runs
- [ ] Output appears in VS Code terminal

---

## 📚 Documentation

### Test 16: Documentation Complete

**Verify files exist:**
- [ ] `docs/DEBUG_OBSERVABILITY_GUIDE.md`
- [ ] `docs/QUICK_DEBUG_SETUP.md`
- [ ] `docs/DEBUG_KIT_IMPLEMENTATION_SUMMARY.md`
- [ ] `docs/DEBUG_KIT_VERIFICATION_CHECKLIST.md` (this file)

**Verify content:**
- [ ] Guides are readable and clear
- [ ] Code examples are correct
- [ ] Links work (if any)

---

## 🎯 Real-World Usage Tests

### Test 17: Auth Flow Logging

**Add logs to auth flow:**

```dart
WawLog.d('Auth', 'OTP requested for: $phone');
WawLog.d('Auth', 'OTP verified successfully');
WawLog.d('Auth', 'User profile created: $uid');
```

**Test auth flow:**
- [ ] Logs appear in correct order
- [ ] Phone number visible (or masked)
- [ ] UID logged after profile creation

---

### Test 18: Driver Online/Offline Logging

**Add logs to driver status toggle:**

```dart
WawLog.d('DriverStatus', 'Toggling online: $isOnline');
WawLog.d('DriverStatus', 'Location: $lat, $lng');
```

**Test toggle:**
- [ ] Logs appear when toggling
- [ ] Location coordinates visible
- [ ] Status changes tracked

---

### Test 19: Order Lifecycle Logging

**Add logs to order service:**

```dart
WawLog.d('Order', 'Creating order: $orderId');
WawLog.d('Order', 'Status changed: $oldStatus → $newStatus');
WawLog.d('Order', 'Order completed: $orderId');
```

**Test order flow:**
- [ ] Order creation logged
- [ ] Status transitions logged
- [ ] Completion logged

---

### Test 20: Error Handling

**Test error scenarios:**

```dart
try {
  // Some operation that might fail
  await riskyOperation();
} catch (e, stack) {
  WawLog.e('OrderService', 'Failed to create order', e, stack);
}
```

**Verify:**
- [ ] Error logged to console
- [ ] Stack trace visible
- [ ] Error sent to Crashlytics (check Firebase Console)
- [ ] App continues running

---

## 🏁 Final Checks

### Test 21: Production Build

```bash
flutter build apk --release
```

**Verify:**
- [ ] Build succeeds
- [ ] APK size reasonable
- [ ] No debug code in release
- [ ] Crashlytics still included

---

### Test 22: Physical Device Testing

**Install on physical device:**

```bash
flutter install
```

**Test on device:**
- [ ] App installs successfully
- [ ] Runs smoothly
- [ ] Crashlytics works
- [ ] Logs visible via `adb logcat`

---

## 📋 Summary

**Total Tests:** 22

**Completed:** _____ / 22

**Issues Found:**
- [ ] None
- [ ] List issues below:

---

**Issues:**

1. 
2. 
3. 

---

**Tested By:** _______________

**Date:** _______________

**Status:** ⬜ Pass | ⬜ Fail | ⬜ Partial

---

## 🆘 If Tests Fail

### Common Issues

**Crashlytics not showing:**
- Wait 10-15 minutes (not just 5)
- Check Firebase Console → Project Settings → Apps
- Verify `google-services.json` is correct
- Try force-stopping and restarting app

**Logs not appearing:**
- Verify debug mode: `flutter run` (not `--release`)
- Check `DebugConfig.enableVerboseLogging`
- Clear console and try again

**Build errors:**
- Run `flutter clean`
- Delete `build/` folders
- Run `flutter pub get` again
- Check Gradle version compatibility

**Performance overlay not showing:**
- Only visible in debug mode
- Check `DebugConfig.enablePerformanceOverlay = true`
- Restart app

---

**Need Help?**

See: `docs/DEBUG_OBSERVABILITY_GUIDE.md` → Troubleshooting section
