# Smoke Testing Guide

This document outlines the strategy and execution of smoke tests for the WAWAPP ecosystem (Client & Driver).

## 🚀 Running the Tests

We provide a unified PowerShell script to run all smoke tests on a connected device.

```powershell
.\run_smoke_tests.ps1
```

**What this script does:**
1.  **Auto-detects** your connected Android/iOS device.
2.  **Runs** the Client Auth Smoke Test (`apps/wawapp_client/integration_test/smoke_auth_flow_test.dart`).
3.  **Runs** the Driver Auth Smoke Test (`apps/wawapp_driver/integration_test/smoke_auth_flow_test.dart`).
4.  **Generates Logs** in the `logs/` directory for historical tracking.

## 🧪 Test Philosophy & Rules

### 1. No `pumpAndSettle` in Auth Flows
**Policy:** Do **NOT** use `tester.pumpAndSettle()` when waiting for screen transitions in integration tests.

**Reason:** Screens like `PinGateScreen` or `LoginScreen` often contain infinite animations (loaders, spinners). `pumpAndSettle` waits for *all* animations to complete, causing the test to **hang indefinitely** until the watchdog kills it.

**Solution:** Use the `pumpUntilFound` extension or explicit polling:
```dart
// ✅ DO THIS
await tester.pumpUntilFound(find.byKey(const ValueKey('screen_home')));

// ❌ NOT THIS
await tester.pumpAndSettle(); 
expect(find.byKey(...), findsOneWidget);
```

### 2. Explicit State Management
Tests drive the `FakeAuthNotifier` explicitly. Do not rely on "side-effects" of screens (like `initState` checks) to drive navigation.
- We simulate state changes using `pushState` / `setTestState`.
- We override methods like `checkHasPin()` in fakes to be no-ops.

### 3. Screen Identification
All critical screens MUST have a `ValueKey` on their root `Scaffold` for stable querying:
- `ValueKey('screen_login')`
- `ValueKey('screen_otp')`
- `ValueKey('screen_pin_gate')`
- `ValueKey('screen_create_pin')`
- `ValueKey('screen_home')`

## 🛠 Adding a New Step

1.  **Add Key:** Add `ValueKey('screen_new_name')` to the new screen's Scaffold.
2.  **Update Test:** In `smoke_auth_flow_test.dart`:
    ```dart
    await settle(tester);
    
    await pushState(tester, fakeNotifier, AuthState(...), label: 'STEP X -> NewScreen');
    
    step('X: Checking New Screen');
    await tester.pumpUntilFound(find.byKey(const ValueKey('screen_new_name')));
    expect(find.byKey(const ValueKey('screen_new_name')), findsOneWidget);
    ```

## 📂 Logs
Artifacts are saved to `logs/` with the format:
- `smoke_client_YYYYMMDD_HHMM.txt`
- `smoke_driver_YYYYMMDD_HHMM.txt`
