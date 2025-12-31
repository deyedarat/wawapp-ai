# 🔍 WawApp Debug & Observability Kit

Complete debugging and observability solution for WawApp Client and Driver apps.

---

## 🚀 Quick Start (5 Minutes)

```powershell
# 1. Install dependencies
cd packages\core_shared && flutter pub get
cd ..\..\apps\wawapp_client && flutter pub get
cd ..\wawapp_driver && flutter pub get

# 2. Run client app
cd apps\wawapp_client
flutter run

# 3. Check console for logs
# Look for: [App][DEBUG] 🚀 WawApp Client initializing...
```

**See:** `docs/QUICK_DEBUG_SETUP.md` for detailed quick start

---

## 📦 What's Included

### ✅ Firebase Crashlytics
- Automatic crash reporting
- Non-fatal error tracking
- Stack traces and device info
- Integrated with both apps

### ✅ WawLog - Unified Logger
```dart
WawLog.d('Tag', 'Debug message');
WawLog.w('Tag', 'Warning message');
WawLog.e('Tag', 'Error message', error, stackTrace);
```
- Consistent log format: `[TAG][LEVEL] message`
- Auto-sends errors to Crashlytics
- Debug/Release mode aware

### ✅ Riverpod ProviderObserver
- Tracks all provider state changes
- Detects rebuild loops
- Logs provider failures
- Auto-enabled in debug builds

### ✅ Performance Monitoring
- Built-in performance overlay
- Flutter DevTools integration
- Frame timing analysis
- Memory profiling

### ✅ Debug Menu Screens
- Test crash button
- Log test buttons
- Config display
- Debug-only access

### ✅ DebugConfig
- Centralized debug flags
- Auto-adapts to build mode
- Easy customization

### ✅ VS Code Tasks
- Run debug/profile modes
- Build APKs
- Open DevTools
- One-click execution

### ✅ Documentation
- Comprehensive guides
- Quick setup instructions
- Troubleshooting help
- Verification checklist

---

## 📚 Documentation

| Document | Purpose |
|----------|---------|
| [DEBUG_OBSERVABILITY_GUIDE.md](docs/DEBUG_OBSERVABILITY_GUIDE.md) | Complete feature guide and usage |
| [QUICK_DEBUG_SETUP.md](docs/QUICK_DEBUG_SETUP.md) | 5-minute quick start |
| [DEBUG_KIT_IMPLEMENTATION_SUMMARY.md](docs/DEBUG_KIT_IMPLEMENTATION_SUMMARY.md) | All changes made |
| [DEBUG_KIT_VERIFICATION_CHECKLIST.md](docs/DEBUG_KIT_VERIFICATION_CHECKLIST.md) | Testing checklist |

---

## 🎯 Common Tasks

### Run App in Debug Mode
```bash
cd apps/wawapp_client
flutter run
```

### Run App in Profile Mode
```bash
flutter run --profile
```

### Build APK
```bash
flutter build apk
```

### Test Crashlytics
```dart
import 'package:core_shared/core_shared.dart';

CrashlyticsObserver.testCrash();
```

### Add Logging
```dart
import 'package:core_shared/core_shared.dart';

WawLog.d('MyFeature', 'Something happened');
WawLog.e('MyFeature', 'Error occurred', error, stackTrace);
```

### Open DevTools
```bash
flutter pub global run devtools
```

---

## 🔧 Configuration

Edit `packages/core_shared/lib/src/observability/debug_config.dart`:

```dart
class DebugConfig {
  static const bool enablePerformanceOverlay = kDebugMode;
  static const bool enableProviderObserver = kDebugMode;
  static const bool enableVerboseLogging = kDebugMode;
  static const bool enableNonFatalCrashlytics = true;
}
```

---

## 📱 Testing on Physical Device

```bash
# Connect device via USB
# Enable USB debugging

# Run app
cd apps/wawapp_client
flutter run

# View logs
adb logcat | findstr "WawLog"
```

---

## 🐛 Troubleshooting

### Crashlytics not working?
1. Wait 10 minutes after crash
2. Check `google-services.json` exists
3. Verify Firebase Console → Crashlytics enabled

### Logs not showing?
1. Ensure debug mode: `flutter run` (not `--release`)
2. Check `DebugConfig.enableVerboseLogging = true`

### Build errors?
```bash
flutter clean
cd android && ./gradlew clean
flutter pub get
```

**Full troubleshooting:** See `docs/DEBUG_OBSERVABILITY_GUIDE.md`

---

## 📊 Features by Build Mode

| Feature | Debug | Profile | Release |
|---------|-------|---------|---------|
| Performance Overlay | ✅ | ❌ | ❌ |
| ProviderObserver | ✅ | ❌ | ❌ |
| Verbose Logging | ✅ | ❌ | ❌ |
| Crashlytics | ✅ | ✅ | ✅ |
| WawLog.e() → Crashlytics | ✅ | ✅ | ✅ |

---

## 🎓 Learning Resources

- **Crashlytics:** [Firebase Docs](https://firebase.google.com/docs/crashlytics)
- **DevTools:** [Flutter Docs](https://docs.flutter.dev/tools/devtools)
- **Riverpod:** [Riverpod Docs](https://riverpod.dev)

---

## ✨ Key Benefits

1. **Catch Crashes Early:** Automatic crash reporting before users complain
2. **Debug Faster:** Consistent logging across entire codebase
3. **Find Performance Issues:** Built-in overlay + DevTools
4. **Track State Changes:** ProviderObserver shows all updates
5. **Production-Ready:** Auto-adapts to build mode
6. **Easy Testing:** Debug menu for quick tests
7. **Well-Documented:** Comprehensive guides included

---

## 🏗️ Architecture

```
WawApp/
├── packages/core_shared/
│   └── lib/src/observability/
│       ├── debug_config.dart          # Centralized flags
│       ├── waw_log.dart                # Unified logger
│       ├── crashlytics_observer.dart   # Error handling
│       └── provider_observer.dart      # State tracking
│
├── apps/wawapp_client/
│   ├── lib/
│   │   ├── main.dart                   # Integrated observability
│   │   └── debug/
│   │       └── debug_menu_screen.dart  # Debug UI
│   └── android/
│       ├── build.gradle.kts            # Crashlytics setup
│       └── app/build.gradle.kts        # Crashlytics plugin
│
├── apps/wawapp_driver/
│   ├── lib/
│   │   ├── main.dart                   # Integrated observability
│   │   └── debug/
│   │       └── debug_menu_screen.dart  # Debug UI
│   └── android/
│       ├── build.gradle.kts            # Crashlytics setup
│       └── app/build.gradle.kts        # Crashlytics plugin
│
├── .vscode/
│   └── tasks.json                      # VS Code tasks
│
└── docs/
    ├── DEBUG_OBSERVABILITY_GUIDE.md
    ├── QUICK_DEBUG_SETUP.md
    ├── DEBUG_KIT_IMPLEMENTATION_SUMMARY.md
    └── DEBUG_KIT_VERIFICATION_CHECKLIST.md
```

---

## 🔄 Next Steps

1. **Install Dependencies:** Run `flutter pub get` in all packages
2. **Test Build:** Run `flutter build apk --debug`
3. **Run on Device:** Connect device and run `flutter run`
4. **Test Crashlytics:** Trigger test crash and check Firebase Console
5. **Add Logging:** Add `WawLog` calls to your critical flows
6. **Verify:** Use `docs/DEBUG_KIT_VERIFICATION_CHECKLIST.md`

---

## 📞 Support

**Issues?** Check troubleshooting in `docs/DEBUG_OBSERVABILITY_GUIDE.md`

**Questions?** Review the comprehensive documentation in `docs/`

---

**Status:** ✅ Complete and Ready for Use

**Last Updated:** 2025-01-XX
