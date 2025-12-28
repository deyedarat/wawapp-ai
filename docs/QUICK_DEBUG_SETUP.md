# Quick Debug Setup - 5 Minutes

## Step 1: Install Dependencies (2 min)

```powershell
# From project root
cd packages\core_shared
flutter pub get

cd ..\..\apps\wawapp_client
flutter pub get

cd ..\wawapp_driver
flutter pub get
```

## Step 2: Verify Build (2 min)

```powershell
# Test client build
cd apps\wawapp_client
flutter build apk --debug

# Test driver build
cd ..\wawapp_driver
flutter build apk --debug
```

## Step 3: Run on Device (1 min)

```powershell
# Connect physical device via USB
# Enable USB debugging on device

# Run client
cd apps\wawapp_client
flutter run

# OR run driver
cd apps\wawapp_driver
flutter run
```

## Step 4: Test Crashlytics

### Option A: Via Debug Menu

1. Add debug route to your router (see below)
2. Navigate to Debug Menu
3. Tap "Trigger Test Crash"
4. Wait 5-10 minutes
5. Check Firebase Console → Crashlytics

### Option B: Via Code

Add anywhere in your app:

```dart
import 'package:core_shared/core_shared.dart';

// In a button or test function
CrashlyticsObserver.testCrash();
```

## Adding Debug Menu Route

### Client App

Edit `apps/wawapp_client/lib/core/router/app_router.dart`:

```dart
import '../../debug/debug_menu_screen.dart';

// Add to routes:
GoRoute(
  path: '/debug',
  builder: (context, state) => const DebugMenuScreen(),
),
```

### Driver App

Edit `apps/wawapp_driver/lib/core/router/app_router.dart`:

```dart
import '../../debug/debug_menu_screen.dart';

// Add to routes:
GoRoute(
  path: '/debug',
  builder: (context, state) => const DebugMenuScreen(),
),
```

### Navigate to Debug Menu

```dart
context.go('/debug');
```

## Viewing Logs

### Console Logs

Watch your IDE console for:

```
[App][DEBUG] 🚀 WawApp Client initializing...
[App][DEBUG] ✅ Firebase & Crashlytics initialized
[ProviderObserver][DEBUG] authStateProvider updated
[Auth][DEBUG] User signed in: abc123
```

### Filter Logs

**VS Code / Android Studio:**
- Search console for `[TAG]` where TAG is your component
- Examples: `[Auth]`, `[Matching]`, `[Order]`, `[DriverStatus]`

**ADB Logcat:**

```bash
adb logcat | findstr "WawLog"
```

## Performance Monitoring

### Enable Performance Overlay

Already enabled in debug builds! Look for graphs at top of screen showing:
- GPU thread (top bar)
- UI thread (bottom bar)

**Green = Good, Red = Jank**

### Use DevTools

```bash
flutter pub global activate devtools
flutter pub global run devtools
```

1. Run app: `flutter run`
2. Open DevTools URL from console
3. Go to Performance tab
4. Record timeline while using app
5. Analyze frame rendering

## Common Issues

### "Crashlytics not initialized"

**Fix:** Ensure Firebase is initialized before using WawLog:

```dart
await Firebase.initializeApp();
await CrashlyticsObserver.initialize();
```

### "google-services.json not found"

**Fix:** Copy from Firebase Console:
1. Firebase Console → Project Settings → Your apps
2. Download `google-services.json`
3. Place in `apps/wawapp_client/android/app/`
4. Place in `apps/wawapp_driver/android/app/`

### Logs not showing

**Fix:** Verify debug mode:

```bash
flutter run  # NOT flutter run --release
```

## Next Steps

Read full guide: `docs/DEBUG_OBSERVABILITY_GUIDE.md`
