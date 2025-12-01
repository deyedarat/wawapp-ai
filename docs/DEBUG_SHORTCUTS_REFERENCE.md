# 🎯 WawApp Debug Shortcuts - Quick Reference Card

**Print this and keep next to your keyboard!**

---

## 🔥 Hot Reload Commands (While Debugging)

| Key | Action | Speed | Use For |
|-----|--------|-------|---------|
| `r` | **Hot Reload** | ~1 sec | UI changes, widget updates, method edits |
| `R` | **Hot Restart** | ~5 sec | Provider changes, global variables, state init |
| `q` | **Quit** | instant | Stop debugging |
| `p` | **DevTools** | instant | Open performance profiler, inspector |
| `i` | **Inspector** | instant | Toggle widget inspector overlay |
| `w` | **Widget Overlay** | instant | Highlight widget boundaries |
| `o` | **Platform Switch** | instant | Switch iOS ↔ Android rendering |

---

## 💻 VSCode Shortcuts

### Debugging
| Shortcut | Action |
|----------|--------|
| `F5` | Start debugging |
| `Ctrl+F5` | Run without debugging (faster start) |
| `Shift+F5` | Stop debugging |
| `Ctrl+Shift+F5` | Restart debugging |
| `F9` | Toggle breakpoint |
| `F10` | Step over |
| `F11` | Step into |
| `Shift+F11` | Step out |

### Tasks
| Shortcut | Action |
|----------|--------|
| `Ctrl+Shift+P` | Command palette |
| `Ctrl+Shift+B` | Run build task |
| `Ctrl+Shift+T` | Reopen closed tab |

### Code Navigation
| Shortcut | Action |
|----------|--------|
| `F12` | Go to definition |
| `Ctrl+Click` | Go to definition |
| `Alt+F12` | Peek definition |
| `Shift+F12` | Find all references |
| `Ctrl+P` | Quick open file |
| `Ctrl+Shift+O` | Go to symbol in file |

---

## 🎯 Quick Tasks (Ctrl+Shift+P → Tasks: Run Task)

| Task | Use For |
|------|---------|
| 🔥 Start Firebase Emulators | Local backend (10x faster) |
| 🚀 Start Android Emulator | Launch device |
| 🧹 Flutter Clean All | Fix dependency issues |
| ⚡ Kill All Flutter Processes | Fix "startup lock" errors |
| 🧪 Run All Tests (Client) | Test client app |
| 🧪 Watch Tests (Client) | Auto-rerun on save |
| 📊 Flutter Analyze (All) | Find code issues |
| 🏗️ Build APK (Debug) | Fast debug build |

---

## 🚀 Command Line (Terminal)

### Flutter Commands
```bash
# Install to device
flutter install

# View logs
flutter logs

# Show devices
flutter devices

# Run specific file
flutter run lib/main.dart

# Run with Firebase emulator
flutter run --dart-define=USE_FIREBASE_EMULATOR=true

# Build debug APK (fast)
flutter build apk --debug

# Run tests
flutter test

# Watch tests (auto-rerun)
flutter test --watch

# Analyze code
flutter analyze

# Clean build
flutter clean && flutter pub get
```

### Firebase Commands
```bash
# Start all emulators
firebase emulators:start

# Start specific emulators
firebase emulators:start --only firestore,auth

# Deploy functions
firebase deploy --only functions

# Deploy specific function
firebase deploy --only functions:notifyOrderEvents

# View function logs
firebase functions:log

# View Firestore rules
firebase firestore:rules:get
```

### Git Commands
```bash
# Quick status
git status

# Stage and commit
git add . && git commit -m "message"

# Push
git push

# Pull
git pull

# Create branch
git checkout -b feature-name

# Switch branch
git checkout branch-name

# Discard changes
git restore .
```

---

## 🐛 Debugging Techniques

### Conditional Breakpoint
Right-click breakpoint → **Edit Breakpoint** → Add condition:
```dart
userId == "test-user-123"
```

### Log Only Breakpoint
Right-click breakpoint → **Edit Breakpoint** → Log message:
```
User {userId} called function
```
No pause, just logs!

### Quick Debug Print
```dart
debugPrint('[ClassName] Message: $variable');
```

### Provider State Inspector
Press `p` (DevTools) → **Provider** tab → See all states

---

## 🔧 Troubleshooting

### Issue: Hot Reload Not Working
**Fix**: Stop + Restart (`Shift+F5` then `F5`)

### Issue: "Startup Lock" Error
**Fix**: `Ctrl+Shift+P` → Run Task → **⚡ Kill All Flutter Processes**

### Issue: Changes Not Reflecting
**Fix**:
1. Try `R` (Hot Restart)
2. If still not working: Full restart (`Shift+F5` then `F5`)

### Issue: Emulator Too Slow
**Fix**:
```bash
# Disable animations
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0
```

### Issue: "Package Not Found"
**Fix**: Run task **🧹 Flutter Clean All**

---

## 📊 Performance Profiling

### Find Slow Frames
1. Run in profile mode: `flutter run --profile`
2. Press `p` → DevTools → **Performance** tab
3. Record 5 seconds
4. Find frames >16ms (red bars)
5. Click frame → See slow widget/function

### Memory Leak Detection
1. DevTools → **Memory** tab
2. Perform action 10 times
3. Force GC (trash icon)
4. Check if memory keeps growing
5. If yes → memory leak!

---

## 🎬 Complete Workflow Example

### Debug Order Creation Bug

**Old Way (15 min)**:
1. Stop app → Restart → Manual login → Create order → Bug occurs → Add print → Repeat

**New Way (30 sec)**:
1. Firebase emulator running (already on)
2. Change code
3. Press `r` (hot reload)
4. Bug occurs
5. Check DevTools console
6. Fix code
7. Press `r` again
✅ Done!

---

## 🔥 Firebase Emulator Workflow

### Setup (Once)
```bash
firebase init emulators
# Select: Firestore, Auth, Functions
# Accept default ports
```

### Daily Usage
```bash
# Terminal 1: Start emulators
firebase emulators:start

# Terminal 2: Run app with emulator
flutter run --dart-define=USE_FIREBASE_EMULATOR=true
```

### Reset Data
Stop emulators (Ctrl+C) → Restart → Clean state!

---

## 💡 Pro Tips

### Tip 1: Lock to Device
Never select device again:
[launch.json](.vscode/launch.json) → Add:
```json
"deviceId": "emulator-5554"
```

### Tip 2: Auto-Save for Hot Reload
Settings → **Files: Auto Save** → `afterDelay`

### Tip 3: Search Logs
```bash
# Show only errors
flutter logs | grep "Error"

# Show only specific service
flutter logs | grep "OrdersService"
```

### Tip 4: Test Specific File
```bash
# Instead of running all tests
flutter test test/providers/earnings_provider_test.dart
```

### Tip 5: Faster Builds
```bash
# Use split APKs (50% faster)
flutter build apk --split-per-abi
```

---

## 📈 Speed Comparison

| Task | Before | After | Gain |
|------|--------|-------|------|
| UI change | 60s (restart) | 2s (hot reload) | **97%** |
| Test data reset | 300s (manual) | 5s (emulator) | **98%** |
| Function test | 120s (deploy) | 10s (local) | **91%** |
| Find bug | 30m (guessing) | 2m (profiler) | **93%** |

---

## 🆘 Emergency Commands

### Nuclear Option (Fix Everything)
```bash
# Kill all Flutter processes
taskkill /F /IM flutter.exe /T
taskkill /F /IM dart.exe /T

# Clean everything
cd apps/wawapp_client && flutter clean && flutter pub get
cd apps/wawapp_driver && flutter clean && flutter pub get

# Restart VSCode
```

### Quick Health Check
```bash
flutter doctor -v
```

---

**Last Updated**: 2025-11-30
**For Full Guide**: See [docs/DEBUGGING_SPEED_GUIDE.md](DEBUGGING_SPEED_GUIDE.md)

---

# 📱 Mobile Quick Reference (Screenshot This!)

```
┌──────────────────────────────────────┐
│   WHILE DEBUGGING (Terminal)         │
├──────────────────────────────────────┤
│  r  → Hot Reload        ~1 sec       │
│  R  → Hot Restart       ~5 sec       │
│  p  → DevTools          instant      │
│  i  → Inspector         instant      │
│  q  → Quit              instant      │
└──────────────────────────────────────┘

┌──────────────────────────────────────┐
│   VSCODE SHORTCUTS                   │
├──────────────────────────────────────┤
│  F5             → Debug              │
│  Ctrl+F5        → Run (no debug)     │
│  Shift+F5       → Stop               │
│  Ctrl+Shift+P   → Tasks              │
│  F12            → Go to definition   │
└──────────────────────────────────────┘

┌──────────────────────────────────────┐
│   MUST KNOW                          │
├──────────────────────────────────────┤
│  firebase emulators:start            │
│  flutter run --dart-define=USE_FIREBASE_EMULATOR=true │
│  flutter test --watch                │
└──────────────────────────────────────┘
```

---

**Print this page and keep it visible while coding!**
