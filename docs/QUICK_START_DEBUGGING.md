# ⚡ WawApp - Get Started with Fast Debugging in 5 Minutes

**Goal**: Set up your environment for **95% faster debugging** iterations.

---

## 🎯 Why This Matters

| Old Workflow | New Workflow | Time Saved |
|--------------|--------------|------------|
| Stop → Restart → Wait 60s | Press `r` → Wait 1s | **59 seconds per change** |
| Manual Firestore cleanup | Emulator reset → 5s | **5 minutes per test** |
| Deploy function → Test | Local emulator → instant | **2 minutes per function test** |

**If you make 50 code changes per day**: You save **~4 hours daily**. 🚀

---

## 📋 5-Minute Setup Checklist

### ✅ Step 1: Run Setup Script (2 minutes)

Open PowerShell in project root:

```powershell
cd c:\Users\deye\Documents\wawapp
.\scripts\quick-debug-setup.ps1
```

This installs all dependencies and checks your environment.

---

### ✅ Step 2: Start Firebase Emulators (1 minute)

**First Time Only**:
```bash
firebase init emulators
# Select: Firestore, Authentication, Functions
# Accept all default ports
```

**Start Emulators**:
```bash
firebase emulators:start
```

Leave this running in a separate terminal. **Don't close it.**

💡 **Bookmark this terminal** - you'll use it every day!

---

### ✅ Step 3: Configure Firebase Emulator in Code (1 minute)

**File**: `apps/wawapp_client/lib/main.dart` (do the same for driver app)

Add this function:

```dart
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // 🔥 ADD THIS SECTION
  if (kDebugMode) {
    const useEmulator = bool.fromEnvironment(
      'USE_FIREBASE_EMULATOR',
      defaultValue: false
    );

    if (useEmulator) {
      FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
      await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
      FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
      debugPrint('🔥 Connected to Firebase Emulators');
    }
  }
  // END NEW SECTION

  runApp(const ProviderScope(child: MyApp()));
}
```

**Repeat for**: `apps/wawapp_driver/lib/main.dart`

---

### ✅ Step 4: Add Riverpod Logger (Optional but Recommended) (1 minute)

**Same files** (`main.dart` in both apps):

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // ... emulator setup from Step 3 ...

  runApp(
    ProviderScope(
      observers: [if (kDebugMode) RiverpodLogger()],  // 👈 Add this
      child: const MyApp(),
    ),
  );
}

// Add this class at the bottom of main.dart
class RiverpodLogger extends ProviderObserver {
  @override
  void didUpdateProvider(
    ProviderBase provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    debugPrint('[Provider] ${provider.name ?? provider.runtimeType}: $newValue');
  }

  @override
  void didDisposeProvider(ProviderBase provider, ProviderContainer container) {
    debugPrint('[Provider DISPOSED] ${provider.name ?? provider.runtimeType}');
  }
}
```

This logs every provider state change. Super helpful for debugging Riverpod issues!

---

## 🚀 You're Ready! Start Debugging

### Daily Workflow

**Terminal 1** (keep running all day):
```bash
firebase emulators:start
```

**VSCode**:
1. Press `F5`
2. Select **"🔥 Client (Firebase Emulator)"**
3. App launches connected to local Firebase

**Make changes → Press `r` → See changes in ~1 second!**

---

## 🎯 Common Tasks

### Task: Test Client App
1. **Terminal**: `firebase emulators:start` (if not running)
2. **VSCode**: `F5` → Select **"🔥 Client (Firebase Emulator)"**
3. Make code changes
4. Press `r` for hot reload

### Task: Test Driver App
Same as above, but select **"🔥 Driver (Firebase Emulator)"**

### Task: Test Both Apps Simultaneously
1. **VSCode**: `F5`
2. Select **"🔥 Both Apps (Firebase Emulator)"**
3. Both apps launch in parallel!

### Task: Test Cloud Function
```bash
# Terminal 1: Emulators running
firebase emulators:start

# Terminal 2: Trigger function manually
curl -X POST http://localhost:5001/wawapp/us-central1/notifyOrderEvents \
  -H "Content-Type: application/json" \
  -d '{"data": {"orderId": "test-123"}}'
```

### Task: Reset Test Data
Stop emulators (`Ctrl+C`) → Restart → Clean state!

### Task: Run Tests
```bash
# Run all tests
flutter test

# Run specific test
flutter test test/providers/earnings_provider_test.dart

# Watch mode (auto-rerun on save)
flutter test --watch
```

---

## 🔥 Hot Reload Cheat Sheet

**While app is running in debug mode:**

| Key | Action | When to Use |
|-----|--------|-------------|
| `r` | Hot Reload (~1s) | ✅ UI changes, widget updates, function edits |
| `R` | Hot Restart (~5s) | ✅ Provider changes, global variable changes |
| Stop + Run | Full Restart (~60s) | ⚠️ Only for: dependencies, native code, Firebase config |

**Golden Rule**: Try `r` first. If doesn't work, try `R`. Full restart is last resort.

---

## 💡 Pro Tips for New Users

### Tip 1: Lock to Your Physical Phone
**Faster than emulator!**

1. Enable USB Debugging on phone
2. Connect via USB
3. Run `flutter devices` to get device ID
4. [.vscode/launch.json](.vscode/launch.json) → Add:
   ```json
   "deviceId": "your-device-id-here"
   ```

### Tip 2: Use Tasks for Common Operations
`Ctrl+Shift+P` → Type "Tasks: Run Task" → Select from:
- 🔥 Start Firebase Emulators
- 🧹 Flutter Clean All
- 🧪 Run All Tests
- ⚡ Kill All Flutter Processes (fixes "startup lock" errors)

### Tip 3: View Provider States in DevTools
1. Press `p` while debugging
2. Go to **Provider** tab
3. See all provider states in real-time
4. Click provider → See value history

### Tip 4: Filter Logs
```bash
# Only errors
flutter logs | grep "Error"

# Only specific class
flutter logs | grep "OrdersService"

# Save logs to file
flutter logs > debug.log
```

### Tip 5: Test Without Deploying
Use Firebase emulators for **everything**:
- No internet needed ✅
- Free (no Firebase costs) ✅
- 10x faster than real Firebase ✅
- Easy to reset test data ✅

---

## 🐛 Troubleshooting

### Problem: Hot Reload Shows "Not Supported"
**Solution**: You're probably in release mode. Use:
```bash
flutter run --debug  # NOT --release or --profile
```

### Problem: "Waiting for another flutter command..."
**Solution**: Kill all Flutter processes:
```bash
# Windows
taskkill /F /IM flutter.exe /T
taskkill /F /IM dart.exe /T

# Or use VSCode task: ⚡ Kill All Flutter Processes
```

### Problem: Changes Not Showing After Hot Reload
**Solution**:
1. Try `R` (Hot Restart)
2. Still not working? Full restart (`Shift+F5` then `F5`)

### Problem: Firebase Emulator Not Connecting
**Solution**: Check if emulator is running:
```bash
# Should see emulators on these ports:
# Firestore: localhost:8080
# Auth: localhost:9099
# Functions: localhost:5001

# Open in browser:
http://localhost:4000  # Emulator UI
```

### Problem: Tests Failing
**Solution**:
```bash
# Clean and reinstall
cd apps/wawapp_client
flutter clean
flutter pub get

# Regenerate mocks
flutter pub run build_runner build --delete-conflicting-outputs

# Run tests again
flutter test
```

---

## 📚 Next Steps

### Learn More
- **Full Guide**: [DEBUGGING_SPEED_GUIDE.md](DEBUGGING_SPEED_GUIDE.md)
- **Shortcuts**: [DEBUG_SHORTCUTS_REFERENCE.md](DEBUG_SHORTCUTS_REFERENCE.md)
- **Architecture**: [../ARCHITECTURE.md](../ARCHITECTURE.md)

### Practice Exercise
Try this to verify your setup:

1. **Start emulators**: `firebase emulators:start`
2. **Launch app**: `F5` → **"🔥 Client (Firebase Emulator)"**
3. **Find a widget**: e.g., `QuoteScreen`
4. **Change text**: e.g., change button label
5. **Press `r`**: See change in ~1 second!
6. **Add provider**: e.g., add new StateProvider
7. **Press `R`**: See change in ~5 seconds!

If both work: **✅ You're set up correctly!**

---

## 🎬 Complete Example: Debug Order Creation

**Scenario**: Test order creation without deploying anything.

### Setup (once)
```bash
# Terminal 1: Start emulators
firebase emulators:start
```

### Create Test User
```bash
# Open emulator UI
http://localhost:4000

# Go to Authentication
# Add test user manually:
# Email: test@example.com
# Password: password123
```

### Create Test Order Data
```bash
# Go to Firestore tab
# Create collection: orders
# Add document with ID: test-order-1
{
  "ownerId": "test-user-123",
  "status": "matching",
  "price": 500,
  "createdAt": [current timestamp],
  "pickup": {"lat": 18.0735, "lng": -15.9582},
  "dropoff": {"lat": 18.0800, "lng": -15.9600}
}
```

### Test in App
1. **VSCode**: `F5` → **"🔥 Client (Firebase Emulator)"**
2. Login with test user
3. Navigate to orders screen
4. See your test order!

### Make Changes
1. Edit order creation logic
2. Press `r`
3. Test again
4. Repeat!

**Total time**: ~30 seconds per iteration vs ~10 minutes with real Firebase!

---

## ✅ Success Checklist

You're ready when:
- [ ] Firebase emulators start successfully
- [ ] App connects to emulators (see 🔥 message in console)
- [ ] Hot reload works (press `r`, see changes in ~1s)
- [ ] Hot restart works (press `R`, see changes in ~5s)
- [ ] DevTools opens (press `p`)
- [ ] Provider states visible in DevTools
- [ ] Tests run successfully (`flutter test`)

---

## 🆘 Get Help

### Issue Not Resolved?
1. Check [DEBUGGING_SPEED_GUIDE.md](DEBUGGING_SPEED_GUIDE.md) for detailed solutions
2. Run `flutter doctor -v` and share output
3. Check Firebase emulator logs: `firebase emulators:start`
4. Create issue in repo with:
   - What you tried
   - Error messages
   - Screenshots

---

**Time to complete setup**: ~5 minutes
**Time saved daily**: ~4 hours
**ROI**: Infinite 🚀

**Happy debugging!** 🎉
