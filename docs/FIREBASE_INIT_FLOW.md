# Firebase Initialization Flow

## Overview

Firebase is initialized exactly once per isolate using a centralized helper to prevent duplicate app errors.

## Main App Initialization

**Location:** `apps/wawapp_client/lib/main.dart` and `apps/wawapp_driver/lib/main.dart`

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with duplicate protection
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  
  // Initialize Crashlytics
  await CrashlyticsObserver.initialize();
  
  runApp(MyApp());
}
```

## Centralized Helper

**Location:** `packages/core_shared/lib/src/observability/firebase_bootstrap.dart`

Provides two methods:

### 1. Main App Initialization
```dart
await FirebaseBootstrap.initialize(DefaultFirebaseOptions.currentPlatform);
```
- Initializes Firebase + Crashlytics
- Safe to call multiple times
- Used in main app entry points

### 2. Background Isolate Initialization
```dart
await FirebaseBootstrap.initializeBackground(DefaultFirebaseOptions.currentPlatform);
```
- Only initializes Firebase (no Crashlytics)
- For FCM background handlers
- Lightweight for background tasks

## Background Handlers (FCM)

If you need to handle FCM messages in background:

**File:** `lib/firebase_messaging_background_handler.dart`

```dart
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase for this background isolate
  await FirebaseBootstrap.initializeBackground(
    DefaultFirebaseOptions.currentPlatform
  );
  
  // Handle message
}
```

## Key Rules

1. **Never call Firebase.initializeApp() directly** - always check `Firebase.apps.isEmpty` first
2. **Main app:** Use full initialization with Crashlytics
3. **Background isolates:** Use lightweight initialization
4. **Hot restart:** The check prevents duplicate initialization errors

## Troubleshooting

### Error: [core/duplicate-app]
**Cause:** Firebase.initializeApp() called twice in same isolate

**Fix:** Ensure all initialization goes through the protected pattern:
```dart
if (Firebase.apps.isEmpty) {
  await Firebase.initializeApp(...);
}
```

### Background Handler Not Working
**Cause:** Firebase not initialized in background isolate

**Fix:** Call `FirebaseBootstrap.initializeBackground()` at start of handler
