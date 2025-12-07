# WawApp Debugging Speed Optimization Guide

**Last Updated**: 2025-11-30
**Target**: Reduce debugging iteration time from minutes to seconds

---

## 🎯 Quick Wins (Immediate Impact)

### 1. Hot Reload vs Hot Restart vs Full Restart

**Use Hot Reload (r) for**:
- UI changes (widgets, colors, text)
- Business logic changes in existing methods
- **Speed**: ~0.5-2 seconds

**Use Hot Restart (R) for**:
- Provider changes (adding/removing providers)
- State initialization changes
- Global variable changes
- **Speed**: ~5-10 seconds

**Use Full Restart (stop + run) ONLY for**:
- Native code changes (Android/iOS)
- Dependency changes (pubspec.yaml)
- Firebase config changes
- **Speed**: ~30-60 seconds

**💡 Tip**: Press `r` in terminal instead of restarting. Save 90% of time.

---

### 2. Enhanced VSCode Launch Configurations

Your current [launch.json](.vscode/launch.json) is basic. Upgrade it:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "🚗 Client (Debug + Hot Reload)",
      "cwd": "apps/wawapp_client",
      "request": "launch",
      "type": "dart",
      "flutterMode": "debug",
      "args": [
        "--dart-define=ENVIRONMENT=dev",
        "--no-sound-null-safety"  // Only if needed
      ],
      "deviceId": "emulator-5554"  // Lock to specific device
    },
    {
      "name": "🚕 Driver (Debug + Hot Reload)",
      "cwd": "apps/wawapp_driver",
      "request": "launch",
      "type": "dart",
      "flutterMode": "debug",
      "deviceId": "emulator-5554"
    },
    {
      "name": "🚗 Client (Emulator Auto-Start)",
      "cwd": "apps/wawapp_client",
      "request": "launch",
      "type": "dart",
      "preLaunchTask": "start-emulator",  // Auto-start emulator
      "deviceId": "emulator-5554"
    },
    {
      "name": "🔥 Client (Firebase Emulator)",
      "cwd": "apps/wawapp_client",
      "request": "launch",
      "type": "dart",
      "preLaunchTask": "start-firebase-emulator",
      "args": [
        "--dart-define=USE_FIREBASE_EMULATOR=true"
      ]
    },
    {
      "name": "⚡ Client + Driver (Parallel)",
      "configurations": [
        "🚗 Client (Debug + Hot Reload)",
        "🚕 Driver (Debug + Hot Reload)"
      ]
    }
  ],
  "compounds": [
    {
      "name": "Both Apps + Firebase Emulator",
      "configurations": [
        "🔥 Client (Firebase Emulator)",
        "🚕 Driver (Debug + Hot Reload)"
      ],
      "preLaunchTask": "start-firebase-emulator"
    }
  ]
}
```

**Save to**: `.vscode/launch.json`

---

### 3. Add VSCode Tasks for One-Click Operations

Create **`.vscode/tasks.json`**:

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "start-emulator",
      "type": "shell",
      "command": "emulator -avd Pixel_7_API_34 -no-snapshot-load",
      "isBackground": true,
      "problemMatcher": {
        "pattern": {
          "regexp": "."
        },
        "background": {
          "activeOnStart": true,
          "beginsPattern": ".",
          "endsPattern": "boot completed"
        }
      }
    },
    {
      "label": "start-firebase-emulator",
      "type": "shell",
      "command": "firebase emulators:start --only firestore,auth,functions",
      "isBackground": true,
      "problemMatcher": {
        "pattern": {
          "regexp": "."
        },
        "background": {
          "activeOnStart": true,
          "beginsPattern": ".",
          "endsPattern": "All emulators ready"
        }
      }
    },
    {
      "label": "flutter-clean-client",
      "type": "shell",
      "command": "cd apps/wawapp_client && flutter clean && flutter pub get"
    },
    {
      "label": "flutter-clean-driver",
      "type": "shell",
      "command": "cd apps/wawapp_driver && flutter clean && flutter pub get"
    },
    {
      "label": "kill-all-flutter",
      "type": "shell",
      "command": "taskkill /F /IM flutter.exe /T 2>nul || killall flutter 2>/dev/null || echo 'No Flutter processes'"
    }
  ]
}
```

**Usage**: Press `Ctrl+Shift+P` → "Tasks: Run Task" → Select task

---

## 🔥 Firebase Emulator Suite (10x Faster Iterations)

### Why Use Emulators?

| Real Firebase | Firebase Emulator |
|---------------|-------------------|
| ~2-5 sec latency per write | ~10ms latency |
| Costs money | FREE |
| Requires internet | Works offline |
| Hard to reset state | Reset in 1 command |
| Can't debug Cloud Functions locally | Full debugging support |

### Setup (5 Minutes)

**Step 1**: Install Firebase CLI (if not already):
```bash
npm install -g firebase-tools
firebase login
```

**Step 2**: Initialize emulators:
```bash
cd c:\Users\deye\Documents\wawapp
firebase init emulators
# Select: Firestore, Authentication, Functions, Storage
# Use default ports (8080, 9099, 5001, 9199)
```

**Step 3**: Start emulators:
```bash
firebase emulators:start
```

**Step 4**: Configure apps to use emulators in **dev mode**:

**File**: `apps/wawapp_client/lib/main.dart`
```dart
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // 🔥 USE EMULATORS IN DEBUG MODE
  if (kDebugMode) {
    const useEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR', defaultValue: false);
    if (useEmulator) {
      await _connectToFirebaseEmulator();
    }
  }

  runApp(const MyApp());
}

Future<void> _connectToFirebaseEmulator() async {
  FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
  print('🔥 Connected to Firebase Emulators');
}
```

**Step 5**: Launch with emulator flag:
```bash
flutter run --dart-define=USE_FIREBASE_EMULATOR=true
```

**Step 6**: Seed test data (one-time):
```bash
# Create seed script: scripts/seed-emulator.sh
firebase emulators:exec --only firestore "node scripts/seed-data.js"
```

---

## ⚡ Fast Test Data Reset

### Problem
After each test, you manually delete Firestore docs. **Wastes 2-5 minutes per test.**

### Solution: Emulator Reset Script

**File**: `scripts/reset-emulator-data.ps1`
```powershell
# Reset Firebase Emulator to clean state
Write-Host "🔥 Resetting Firebase Emulator data..." -ForegroundColor Yellow

# Kill existing emulator
taskkill /F /IM java.exe /FI "WINDOWTITLE eq Firebase*" 2>$null

# Clear emulator data
Remove-Item -Recurse -Force "firebase-debug.log" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force ".firebase/emulators" -ErrorAction SilentlyContinue

# Restart with clean state
firebase emulators:start --import=./emulator-seed-data --export-on-exit
```

**Usage**:
```bash
# Reset and restart emulator
.\scripts\reset-emulator-data.ps1

# Or via VSCode task (add to tasks.json)
```

---

## 🐛 Advanced Debugging Techniques

### 1. Riverpod DevTools

**Install**:
```yaml
# pubspec.yaml (both apps)
dev_dependencies:
  riverpod_lint: ^2.3.7
  flutter_riverpod: ^2.4.9
```

**Enable**:
```dart
// main.dart
void main() {
  runApp(
    ProviderScope(
      observers: [if (kDebugMode) RiverpodLogger()],  // 👈 Add this
      child: const MyApp(),
    ),
  );
}

class RiverpodLogger extends ProviderObserver {
  @override
  void didUpdateProvider(ProviderBase provider, Object? previousValue, Object? newValue, ProviderContainer container) {
    print('[Provider] ${provider.name ?? provider.runtimeType}: $newValue');
  }

  @override
  void didDisposeProvider(ProviderBase provider, ProviderContainer container) {
    print('[Provider DISPOSED] ${provider.name ?? provider.runtimeType}');
  }
}
```

**View in DevTools**:
1. Run app in debug mode
2. Press `p` in terminal → Opens DevTools
3. Go to "Provider" tab → See all provider states

---

### 2. Conditional Breakpoints (Save 80% Debug Time)

**Instead of**:
```dart
// BAD: Hit breakpoint 100 times to find specific user
void fetchUserOrders(String userId) {
  debugger();  // ❌ Breaks EVERY time
  // ...
}
```

**Use**:
```dart
// GOOD: Only break for specific user
void fetchUserOrders(String userId) {
  if (userId == 'test-user-123') {
    debugger();  // ✅ Breaks ONLY for this user
  }
  // ...
}
```

**Or in VSCode**: Right-click breakpoint → Edit Breakpoint → Add condition:
```
userId == "test-user-123"
```

---

### 3. Flutter Inspector Shortcuts

| Shortcut | Action | Speed Gain |
|----------|--------|------------|
| `i` | Toggle Inspector | Instant widget tree |
| `p` | Open DevTools | 2 sec vs 30 sec manual |
| `o` | Toggle platform (iOS/Android) | Test both OSs without restart |
| `w` | Toggle widget inspector | Find widget source instantly |

**Pro Tip**: Click widget in Inspector → Jumps to source code line

---

## 📊 Performance Profiling (Find Slow Code Instantly)

### Problem
App feels slow but you don't know why. **Guessing wastes hours.**

### Solution: Timeline Profiling

**Step 1**: Run in **profile mode**:
```bash
flutter run --profile
```

**Step 2**: Press `p` → DevTools → Performance tab

**Step 3**: Record 5 seconds of interaction

**Step 4**: Find slow frames (>16ms = janky)

**Step 5**: Click frame → See which widgets/functions caused it

**Example Output**:
```
Frame #45 - 48ms (SLOW!)
  ├─ districtMarkersProvider: 35ms ❌
  │   └─ _createTextMarker: 32ms (called 10 times)
  └─ Build: 13ms ✅
```

**Fix**: Cache markers (already done in Batch 5!)

---

## 🧪 Faster Testing Workflow

### Unit Tests (Run Specific Tests Only)

**Instead of**:
```bash
# BAD: Runs ALL 50 tests (30 seconds)
flutter test
```

**Use**:
```bash
# GOOD: Run one test file (2 seconds)
flutter test test/providers/earnings_provider_test.dart

# Or specific test by name
flutter test --name "provider disposes"

# Or with watch mode (auto-rerun on save)
flutter test --watch test/providers/earnings_provider_test.dart
```

---

### Widget Tests (Faster Than Manual UI Testing)

**Problem**: Manually tapping through UI to test QuoteScreen = 2 minutes

**Solution**: Widget test = 0.5 seconds

```dart
// test/widget/quote_screen_fast_test.dart
testWidgets('quote calculation updates instantly', (tester) async {
  await tester.pumpWidget(const QuoteScreen());

  // Enter pickup location
  await tester.enterText(find.byKey(Key('pickup-field')), 'Nouakchott');
  await tester.pumpAndSettle();

  // Enter dropoff
  await tester.enterText(find.byKey(Key('dropoff-field')), 'Nouadhibou');
  await tester.pumpAndSettle();

  // Verify price appears
  expect(find.textContaining('MRU'), findsOneWidget);
});
```

**Run**:
```bash
flutter test test/widget/quote_screen_fast_test.dart
```

---

## 🚀 Build Speed Optimization

### Problem
`flutter build apk` takes **5-10 minutes**. Too slow for testing.

### Solutions

**1. Use Debug APK (1 minute)**:
```bash
# Instead of release build (10 min)
flutter build apk --release

# Use debug build (1 min)
flutter build apk --debug
```

**2. Use Split APKs (50% faster)**:
```bash
flutter build apk --split-per-abi
# Generates: app-armeabi-v7a-release.apk (30MB instead of 60MB)
```

**3. Disable R8/ProGuard in Debug**:

**File**: `apps/wawapp_client/android/app/build.gradle`
```gradle
buildTypes {
    debug {
        minifyEnabled false  // 👈 Disable for debug builds
        shrinkResources false
    }
    release {
        minifyEnabled true
        shrinkResources true
    }
}
```

---

## 🎯 Device Selection Strategy

### Speed Comparison

| Device Type | Boot Time | Install Time | Run Time |
|-------------|-----------|--------------|----------|
| Physical Phone | 0s (always on) | 5s | FAST |
| Android Emulator (x86) | 15s | 8s | Medium |
| Android Emulator (ARM) | 30s | 15s | Slow |
| iOS Simulator | 10s | 6s | FAST |

**Recommendation**:
1. **Primary**: Physical Android phone (USB debugging)
2. **Secondary**: Android Emulator (Pixel 7 API 34, x86_64)
3. **Avoid**: ARM emulators (unless testing ARM-specific code)

### Lock to Specific Device

**Instead of**: Selecting device every time (wastes 10 seconds)

**Use**:
```bash
# List devices
flutter devices

# Lock to specific device in launch.json
"deviceId": "emulator-5554"  // Or your phone's ID
```

---

## 🔍 Debugging Cloud Functions Locally

### Problem
Testing Cloud Functions in production = slow + expensive

### Solution: Functions Emulator

**Step 1**: Start Functions emulator:
```bash
firebase emulators:start --only functions
```

**Step 2**: Trigger function manually:
```bash
# Test notifyOrderEvents
curl -X POST http://localhost:5001/wawapp/us-central1/notifyOrderEvents \
  -H "Content-Type: application/json" \
  -d '{"orderId": "test-123"}'
```

**Step 3**: Add breakpoints in TypeScript:
```typescript
// functions/src/notifyOrderEvents.ts
export const notifyOrderEvents = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    debugger;  // 👈 Add this (requires Node debugger)
    // ...
  });
```

**Step 4**: Attach debugger:
```bash
cd functions
node --inspect-brk node_modules/.bin/firebase emulators:start --only functions
```

**Step 5**: Open Chrome → `chrome://inspect` → Click "inspect"

---

## 📝 Logging Best Practices (Find Bugs Faster)

### Structured Logging

**Instead of**:
```dart
// BAD: Hard to search
print('Error: $e');
```

**Use**:
```dart
// GOOD: Searchable, filterable
debugPrint('[OrdersService] Error fetching nearby orders: userId=$userId, error=$e');
```

**Filter logs**:
```bash
# Show only OrdersService logs
flutter logs | grep "OrdersService"

# Show only errors
flutter logs | grep "Error"
```

---

### Log Levels

```dart
// lib/utils/logger.dart
enum LogLevel { debug, info, warning, error }

class AppLogger {
  static void log(String message, {LogLevel level = LogLevel.debug}) {
    if (kDebugMode || level == LogLevel.error) {
      final prefix = {
        LogLevel.debug: '🐛',
        LogLevel.info: 'ℹ️',
        LogLevel.warning: '⚠️',
        LogLevel.error: '❌',
      }[level];
      debugPrint('$prefix [${DateTime.now().toIso8601String()}] $message');
    }
  }
}

// Usage
AppLogger.log('User logged in', level: LogLevel.info);
AppLogger.log('Payment failed', level: LogLevel.error);
```

---

## 🎬 Complete Fast Debug Workflow (End-to-End)

### Scenario: Debug order creation bug

**OLD WORKFLOW (15 minutes)**:
1. Stop app (10s)
2. Restart app (60s)
3. Manually create account (120s)
4. Manually enter order details (60s)
5. Wait for Firebase (5s)
6. Bug occurs
7. Add print statement
8. Repeat steps 1-6 (240s)
9. **Total: ~15 minutes**

**NEW WORKFLOW (30 seconds)**:
1. Firebase emulator running (0s - already running)
2. Hot reload after code change (2s)
3. Trigger test with pre-seeded data (5s)
4. Bug occurs
5. Check DevTools console (instant)
6. Fix code
7. Hot reload (2s)
8. **Total: ~30 seconds**

---

## 📚 Quick Reference Card

Print this and keep next to your keyboard:

```
╔════════════════════════════════════════════════════════════╗
║              WAWAPP DEBUG SHORTCUTS                        ║
╠════════════════════════════════════════════════════════════╣
║  r  →  Hot Reload (UI changes)              ~1 sec         ║
║  R  →  Hot Restart (provider changes)       ~5 sec         ║
║  p  →  Open DevTools                        instant        ║
║  i  →  Toggle Inspector                     instant        ║
║  o  →  Switch platform (iOS/Android)        instant        ║
║  w  →  Widget inspector overlay             instant        ║
║  q  →  Quit debug session                   instant        ║
╠════════════════════════════════════════════════════════════╣
║  Ctrl+F5       →  Run without debugging (faster start)     ║
║  F5            →  Start debugging                          ║
║  Shift+F5      →  Stop debugging                           ║
║  Ctrl+Shift+F5 →  Restart debugging                        ║
╠════════════════════════════════════════════════════════════╣
║  EMULATOR                                                  ║
║  firebase emulators:start  →  Start all emulators          ║
║  flutter run --dart-define=USE_FIREBASE_EMULATOR=true      ║
╠════════════════════════════════════════════════════════════╣
║  TESTS                                                     ║
║  flutter test --watch test/file.dart  →  Auto-rerun        ║
║  flutter test --name "test name"      →  Run specific      ║
╚════════════════════════════════════════════════════════════╝
```

---

## 🎯 Immediate Action Items

### Do These Right Now (10 Minutes):

1. **Update launch.json** (copy enhanced config above) → **Save 30 sec per launch**
2. **Create tasks.json** → **One-click emulator start**
3. **Install Firebase emulators**: `firebase init emulators` → **10x faster iterations**
4. **Add Riverpod logger to main.dart** → **Instant provider debugging**
5. **Bookmark this guide** → **Reference during debugging**

### Expected Results:

| Task | Before | After | Time Saved |
|------|--------|-------|------------|
| UI change iteration | 60s (full restart) | 2s (hot reload) | **97% faster** |
| Test data reset | 300s (manual Firestore) | 5s (emulator reset) | **98% faster** |
| Cloud Function test | 120s (deploy + test) | 10s (local emulator) | **91% faster** |
| Find slow widget | 30min (guessing) | 2min (profiler) | **93% faster** |
| **Total per debug cycle** | **~10 min** | **~30 sec** | **95% faster** |

---

## 🆘 Troubleshooting

### Issue: Hot Reload Doesn't Work

**Symptom**: Pressing `r` shows "hot reload not supported"

**Fix**:
```bash
# Ensure you're in debug mode (not release)
flutter run --debug

# If using profile mode, hot reload is limited
flutter run --profile  # Limited hot reload
```

---

### Issue: Emulator Too Slow

**Symptom**: Android emulator lags/freezes

**Fix**:
1. Enable hardware acceleration (HAXM on Intel, WHPX on AMD)
2. Allocate more RAM:
   - AVD Manager → Edit → Advanced → RAM: 4096 MB
3. Use x86_64 system image (NOT ARM)
4. Disable animations:
   ```bash
   adb shell settings put global window_animation_scale 0
   adb shell settings put global transition_animation_scale 0
   adb shell settings put global animator_duration_scale 0
   ```

---

### Issue: "Waiting for another flutter command to release the startup lock"

**Fix**:
```bash
# Windows
taskkill /F /IM dart.exe /T
taskkill /F /IM flutter.exe /T

# Mac/Linux
killall -9 dart flutter
```

---

## 📖 Additional Resources

- [Flutter DevTools Guide](https://docs.flutter.dev/tools/devtools/overview)
- [Firebase Emulator Suite Docs](https://firebase.google.com/docs/emulator-suite)
- [Riverpod DevTools](https://riverpod.dev/docs/concepts/reading#using-refwatch-to-observe-a-provider)
- [VSCode Flutter Extensions](https://marketplace.visualstudio.com/items?itemName=Dart-Code.flutter)

---

**Last Updated**: 2025-11-30
**Maintained By**: WawApp Development Team
**Questions?**: Create an issue in the repo
