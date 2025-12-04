# WawApp Debug & Observability Guide

## Overview

This guide covers the complete Debug & Observability Kit for WawApp, including Crashlytics, unified logging, performance monitoring, and debugging tools.

---

## 🔧 Setup

### 1. Install Dependencies

Run from project root:

```powershell
.\spec.ps1 flutter:pub-get
```

Or manually:

```bash
cd apps/wawapp_client && flutter pub get
cd apps/wawapp_driver && flutter pub get
cd packages/core_shared && flutter pub get
```

### 2. Verify Firebase Configuration

Ensure both apps have `google-services.json` in their `android/app/` directories.

---

## 📊 Features

### Firebase Crashlytics

**What it does:**
- Captures fatal crashes automatically
- Records non-fatal errors from WawLog.e()
- Provides stack traces and device info in Firebase Console

**Where to view:**
- Firebase Console → Crashlytics → Dashboard
- Filter by app (client vs driver)

### WawLog - Unified Logger

**Usage:**

```dart
import 'package:core_shared/core_shared.dart';

// Debug/Info
WawLog.d('AuthFlow', 'User signed in: $uid');

// Warning
WawLog.w('Matching', 'No drivers available in radius');

// Error (also sends to Crashlytics if enabled)
WawLog.e('OrderService', 'Failed to create order', error, stackTrace);
```

**Log Format:**
```
[TAG][LEVEL] message
```

**Behavior:**
- DEBUG builds: Verbose console output
- RELEASE builds: Minimal console, errors sent to Crashlytics

### ProviderObserver

**What it does:**
- Logs every Riverpod provider state change
- Detects rebuild loops
- Tracks provider failures

**How to use:**
- Automatically enabled in DEBUG builds
- Check console for `[ProviderObserver]` logs
- Look for repeated updates to same provider (indicates loop)

### Performance Overlay

**What it does:**
- Shows GPU/UI thread performance graphs
- Displays FPS and frame timing
- Identifies jank and rebuild issues

**How to enable:**
- Automatically enabled in DEBUG builds via `DebugConfig.enablePerformanceOverlay`
- Visible as overlay on app screen

---

## 🧪 Testing

### Trigger Test Crash

**Option 1: Debug Menu (Recommended)**

1. Run app in debug mode
2. Navigate to Debug Menu screen:
   - Client: Add route to `debug/debug_menu_screen.dart`
   - Driver: Add route to `debug/debug_menu_screen.dart`
3. Tap "Trigger Test Crash"

**Option 2: Code**

```dart
import 'package:core_shared/core_shared.dart';

CrashlyticsObserver.testCrash();
```

**Verify:**
- App crashes immediately
- Check Firebase Console → Crashlytics (may take 5-10 minutes)

### Test Non-Fatal Error

```dart
WawLog.e('TestTag', 'Test error message', 
  Exception('Test exception'), StackTrace.current);
```

**Verify:**
- App continues running
- Check Firebase Console → Crashlytics → Non-fatals

---

## 🔍 Debugging Workflows

### Debug Auth Flow

Add logs to critical auth points:

```dart
WawLog.d('Auth', 'OTP requested for phone: $phone');
WawLog.d('Auth', 'OTP verified, creating user profile');
WawLog.d('Auth', 'PIN created, navigating to home');
```

**Check logs for:**
- Missing steps in flow
- Unexpected navigation
- State inconsistencies

### Debug Driver Online/Offline

```dart
WawLog.d('DriverStatus', 'Toggling online: $isOnline');
WawLog.d('DriverStatus', 'Location updated: $lat, $lng');
```

### Debug Matching Flow

```dart
WawLog.d('Matching', 'Fetching nearby orders, radius: $radiusKm');
WawLog.d('Matching', 'Found ${orders.length} orders');
WawLog.d('Matching', 'Driver accepted order: $orderId');
```

### Debug Order Lifecycle

```dart
WawLog.d('Order', 'Order created: $orderId, status: matching');
WawLog.d('Order', 'Order accepted by driver: $driverId');
WawLog.d('Order', 'Order status changed: $oldStatus → $newStatus');
```

### Detect Rebuild Loops

1. Run app in debug mode
2. Watch console for repeated `[ProviderObserver]` logs
3. Look for patterns like:
   ```
   [ProviderObserver][DEBUG] authStateProvider updated
   [ProviderObserver][DEBUG] authStateProvider updated
   [ProviderObserver][DEBUG] authStateProvider updated
   ```
4. Investigate provider logic for circular dependencies

---

## 🚀 Running Apps

### Debug Mode (Default)

```bash
# Client
cd apps/wawapp_client
flutter run

# Driver
cd apps/wawapp_driver
flutter run
```

**Features enabled:**
- Performance overlay
- ProviderObserver
- Verbose logging
- Crashlytics

### Profile Mode (Performance Testing)

```bash
# Client
cd apps/wawapp_client
flutter run --profile

# Driver
cd apps/wawapp_driver
flutter run --profile
```

**Features:**
- No debug overlays
- Optimized performance
- DevTools profiling available

**Open DevTools:**
```bash
flutter pub global activate devtools
flutter pub global run devtools
```

Then connect to running app via URL shown in console.

### Release Mode

```bash
flutter run --release
```

**Features:**
- Production-ready
- Minimal logging
- Crashlytics enabled

---

## 📱 Building APKs

### Debug APK

```bash
cd apps/wawapp_client
flutter build apk --debug

cd apps/wawapp_driver
flutter build apk --debug
```

### Release APK

```bash
cd apps/wawapp_client
flutter build apk --release

cd apps/wawapp_driver
flutter build apk --release
```

**Location:**
- `apps/wawapp_client/build/app/outputs/flutter-apk/app-release.apk`
- `apps/wawapp_driver/build/app/outputs/flutter-apk/app-release.apk`

---

## 🎛️ Configuration

### DebugConfig

Located in: `packages/core_shared/lib/src/observability/debug_config.dart`

```dart
class DebugConfig {
  static const bool enablePerformanceOverlay = kDebugMode;
  static const bool enableProviderObserver = kDebugMode;
  static const bool enableVerboseLogging = kDebugMode;
  static const bool enableNonFatalCrashlytics = true;
}
```

**Customize:**
- Change `kDebugMode` to `true`/`false` for specific features
- Set `enableNonFatalCrashlytics = false` to disable non-fatal error reporting

---

## 📋 VS Code Tasks

Use Command Palette (`Ctrl+Shift+P`) → "Tasks: Run Task"

Available tasks:
- **Client: Run Debug** - Run client in debug mode
- **Client: Run Profile** - Run client in profile mode
- **Driver: Run Debug** - Run driver in debug mode
- **Driver: Run Profile** - Run driver in profile mode
- **Client: Build APK** - Build client APK
- **Driver: Build APK** - Build driver APK
- **Open DevTools** - Launch Flutter DevTools

---

## 🐛 Troubleshooting

### Crashlytics not showing crashes

1. Wait 5-10 minutes after crash
2. Verify `google-services.json` is present
3. Check Firebase Console → Project Settings → Apps registered
4. Ensure Crashlytics is enabled in Firebase Console

### Logs not appearing

1. Check `DebugConfig.enableVerboseLogging` is `true`
2. Verify running in debug mode: `flutter run` (not `--release`)
3. Check console output for `[TAG][LEVEL]` format

### Performance overlay not showing

1. Verify `DebugConfig.enablePerformanceOverlay = true`
2. Ensure running in debug mode
3. Check `MaterialApp.showPerformanceOverlay` is set

### ProviderObserver not logging

1. Verify `DebugConfig.enableProviderObserver = true`
2. Check `ProviderScope` has `observers: [WawProviderObserver()]`
3. Ensure providers are actually updating

---

## 📚 Additional Resources

- [Flutter DevTools](https://docs.flutter.dev/tools/devtools/overview)
- [Firebase Crashlytics](https://firebase.google.com/docs/crashlytics)
- [Riverpod Debugging](https://riverpod.dev/docs/concepts/reading#using-reflistenmanual)

---

## 🎯 Quick Reference

| Task | Command |
|------|---------|
| Run client debug | `cd apps/wawapp_client && flutter run` |
| Run driver debug | `cd apps/wawapp_driver && flutter run` |
| Run profile mode | `flutter run --profile` |
| Build APK | `flutter build apk` |
| Open DevTools | `flutter pub global run devtools` |
| View Crashlytics | Firebase Console → Crashlytics |
| Test crash | `CrashlyticsObserver.testCrash()` |
| Log error | `WawLog.e('Tag', 'msg', error, stack)` |

---

**Last Updated:** 2025-01-XX
