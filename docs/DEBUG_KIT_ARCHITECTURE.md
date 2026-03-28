# Debug & Observability Kit - Architecture

## 📐 System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     WawApp Monorepo                         │
└─────────────────────────────────────────────────────────────┘
                              │
                ┌─────────────┴─────────────┐
                │                           │
        ┌───────▼────────┐          ┌──────▼────────┐
        │  Client App    │          │  Driver App   │
        │  (wawapp_client)│          │ (wawapp_driver)│
        └───────┬────────┘          └──────┬────────┘
                │                           │
                │    ┌──────────────────┐   │
                └────►  core_shared    ◄───┘
                     │   (package)     │
                     └────────┬────────┘
                              │
                    ┌─────────▼─────────┐
                    │  Observability    │
                    │     Layer         │
                    └───────────────────┘
```

---

## 🏗️ Component Breakdown

### 1. Core Shared Package

**Location:** `packages/core_shared/lib/src/observability/`

```
observability/
├── debug_config.dart          # Centralized flags
├── waw_log.dart               # Unified logger
├── crashlytics_observer.dart  # Error handling
└── provider_observer.dart     # State tracking
```

**Responsibilities:**
- Provide shared observability utilities
- Manage debug configuration
- Handle error reporting
- Track state changes

**Dependencies:**
- `firebase_crashlytics: ^4.1.3`
- `flutter_riverpod: ^2.4.9`

---

### 2. Client App Integration

**Location:** `apps/wawapp_client/`

```
wawapp_client/
├── lib/
│   ├── main.dart                    # Observability bootstrap
│   └── debug/
│       └── debug_menu_screen.dart   # Debug UI
├── android/
│   ├── build.gradle.kts             # Crashlytics classpath
│   └── app/
│       └── build.gradle.kts         # Crashlytics plugin
└── pubspec.yaml                     # Dependencies
```

**Integration Points:**
1. **main.dart:**
   - Initialize Crashlytics
   - Add ProviderObserver
   - Enable performance overlay

2. **Debug Menu:**
   - Test crash button
   - Log testing
   - Config display

---

### 3. Driver App Integration

**Location:** `apps/wawapp_driver/`

```
wawapp_driver/
├── lib/
│   ├── main.dart                    # Observability bootstrap
│   └── debug/
│       └── debug_menu_screen.dart   # Debug UI
├── android/
│   ├── build.gradle.kts             # Crashlytics buildscript
│   └── app/
│       └── build.gradle.kts         # Crashlytics plugin
└── pubspec.yaml                     # Dependencies
```

**Same integration as client app**

---

## 🔄 Data Flow

### Logging Flow

```
Application Code
      │
      ├─► WawLog.d() ──► Console (DEBUG only)
      │
      ├─► WawLog.w() ──► Console (DEBUG only)
      │
      └─► WawLog.e() ──┬─► Console (always)
                       │
                       └─► Crashlytics (if enabled)
                           └─► Firebase Console
```

### Error Handling Flow

```
Flutter Error
      │
      ├─► FlutterError.onError
      │   └─► CrashlyticsObserver
      │       └─► FirebaseCrashlytics.recordFlutterFatalError()
      │
      └─► PlatformDispatcher.onError
          └─► CrashlyticsObserver
              └─► FirebaseCrashlytics.recordError(fatal: true)
```

### State Tracking Flow

```
Riverpod Provider Update
      │
      └─► ProviderObserver.didUpdateProvider()
          │
          ├─► WawLog.d() ──► Console
          │
          └─► Check for rapid updates (rebuild loop detection)
```

---

## 🎛️ Configuration System

### DebugConfig Hierarchy

```
DebugConfig (compile-time constants)
      │
      ├─► enablePerformanceOverlay
      │   └─► MaterialApp.showPerformanceOverlay
      │
      ├─► enableProviderObserver
      │   └─► ProviderScope.observers
      │
      ├─► enableVerboseLogging
      │   └─► WawLog verbosity level
      │
      └─► enableNonFatalCrashlytics
          └─► WawLog.e() → Crashlytics
```

### Build Mode Adaptation

```
kDebugMode = true (Debug Build)
      │
      ├─► Performance Overlay: ON
      ├─► ProviderObserver: ON
      ├─► Verbose Logging: ON
      └─► Crashlytics: ON

kDebugMode = false (Profile/Release Build)
      │
      ├─► Performance Overlay: OFF
      ├─► ProviderObserver: OFF
      ├─► Verbose Logging: OFF
      └─► Crashlytics: ON (errors only)
```

---

## 🔌 Integration Points

### 1. Application Bootstrap

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Initialize Crashlytics
  await CrashlyticsObserver.initialize();
  
  // Run app with observers
  runApp(
    ProviderScope(
      observers: DebugConfig.enableProviderObserver 
        ? [WawProviderObserver()] 
        : [],
      child: MyApp(),
    ),
  );
}
```

### 2. MaterialApp Configuration

```dart
MaterialApp.router(
  showPerformanceOverlay: DebugConfig.enablePerformanceOverlay,
  // ... other config
)
```

### 3. Error Handling

```dart
try {
  await riskyOperation();
} catch (e, stack) {
  WawLog.e('Feature', 'Operation failed', e, stack);
  // Automatically sent to Crashlytics if enabled
}
```

---

## 📊 Monitoring Layers

### Layer 1: Console Logging

**Purpose:** Real-time debugging during development

**Tools:**
- WawLog.d/w/e
- ProviderObserver logs
- Flutter framework logs

**Output:** IDE console / adb logcat

---

### Layer 2: Performance Monitoring

**Purpose:** Identify UI jank and performance issues

**Tools:**
- Performance overlay (debug builds)
- Flutter DevTools (profile builds)

**Metrics:**
- Frame rendering time
- GPU/UI thread usage
- Memory allocation

---

### Layer 3: Crash Reporting

**Purpose:** Track production crashes and errors

**Tools:**
- Firebase Crashlytics
- WawLog.e() integration

**Data:**
- Stack traces
- Device info
- Custom logs
- User context

---

### Layer 4: State Tracking

**Purpose:** Debug state management issues

**Tools:**
- ProviderObserver
- Riverpod DevTools extension

**Insights:**
- Provider updates
- Rebuild loops
- State inconsistencies

---

## 🎯 Usage Patterns

### Pattern 1: Feature Logging

```dart
class OrderService {
  Future<void> createOrder(OrderData data) async {
    WawLog.d('OrderService', 'Creating order: ${data.id}');
    
    try {
      await _firestore.collection('orders').add(data.toJson());
      WawLog.d('OrderService', 'Order created successfully');
    } catch (e, stack) {
      WawLog.e('OrderService', 'Failed to create order', e, stack);
      rethrow;
    }
  }
}
```

### Pattern 2: State Debugging

```dart
final orderProvider = StateNotifierProvider<OrderNotifier, OrderState>((ref) {
  return OrderNotifier();
});

class OrderNotifier extends StateNotifier<OrderState> {
  OrderNotifier() : super(OrderState.initial()) {
    WawLog.d('OrderNotifier', 'Initialized');
  }
  
  void updateStatus(OrderStatus status) {
    WawLog.d('OrderNotifier', 'Status: ${state.status} → $status');
    state = state.copyWith(status: status);
  }
}
```

### Pattern 3: Error Boundaries

```dart
class ErrorBoundary extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(dataProvider).when(
      data: (data) => DataView(data),
      loading: () => LoadingView(),
      error: (error, stack) {
        WawLog.e('ErrorBoundary', 'Provider error', error, stack);
        return ErrorView(error);
      },
    );
  }
}
```

---

## 🔐 Security Considerations

### 1. PII Protection

```dart
// ❌ BAD: Logging sensitive data
WawLog.d('Auth', 'User phone: $phoneNumber');

// ✅ GOOD: Masking sensitive data
WawLog.d('Auth', 'User phone: ${phoneNumber.substring(0, 3)}***');
```

### 2. Debug-Only Features

```dart
// Debug menu only accessible in debug builds
if (!kDebugMode) {
  return Scaffold(
    body: Center(child: Text('Not available in production')),
  );
}
```

### 3. Crashlytics User IDs

```dart
// Set user ID for crash tracking (non-PII)
FirebaseCrashlytics.instance.setUserIdentifier(userId);

// Add custom keys
FirebaseCrashlytics.instance.setCustomKey('user_type', 'driver');
```

---

## 📈 Scalability

### Adding New Log Tags

```dart
// Just use WawLog with new tag
WawLog.d('NewFeature', 'Feature initialized');
```

### Adding Custom Observers

```dart
class CustomObserver extends ProviderObserver {
  @override
  void didUpdateProvider(...) {
    // Custom logic
  }
}

// Add to ProviderScope
ProviderScope(
  observers: [
    WawProviderObserver(),
    CustomObserver(),
  ],
  child: MyApp(),
)
```

### Extending WawLog

```dart
extension WawLogExtensions on WawLog {
  static void metric(String tag, String metric, num value) {
    d(tag, '📊 $metric: $value');
    // Could also send to analytics
  }
}
```

---

## 🧪 Testing Strategy

### Unit Tests

```dart
test('WawLog formats messages correctly', () {
  // Test log formatting
});

test('DebugConfig returns correct values', () {
  expect(DebugConfig.enableVerboseLogging, kDebugMode);
});
```

### Integration Tests

```dart
testWidgets('Crashlytics initializes', (tester) async {
  await Firebase.initializeApp();
  await CrashlyticsObserver.initialize();
  // Verify no errors
});
```

### Manual Tests

See: `docs/DEBUG_KIT_VERIFICATION_CHECKLIST.md`

---

## 🔄 Maintenance

### Updating Dependencies

```yaml
# pubspec.yaml
firebase_crashlytics: ^4.2.0  # Update version
```

```bash
flutter pub upgrade firebase_crashlytics
```

### Adding New Features

1. Add to `core_shared/observability/`
2. Export from `core_shared.dart`
3. Update documentation
4. Add tests

### Deprecating Features

1. Mark as deprecated in code
2. Update documentation
3. Provide migration guide
4. Remove after grace period

---

## 📚 Related Documentation

- [Main README](../DEBUG_KIT_README.md)
- [Implementation Summary](DEBUG_KIT_IMPLEMENTATION_SUMMARY.md)
- [Observability Guide](DEBUG_OBSERVABILITY_GUIDE.md)
- [Verification Checklist](DEBUG_KIT_VERIFICATION_CHECKLIST.md)

---

**Last Updated:** 2025-01-XX
