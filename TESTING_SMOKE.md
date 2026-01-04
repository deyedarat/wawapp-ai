# Auth Routing Smoke Tests

This document describes how to run the integration smoke tests for checking Authentication Routing flows in Client and Driver apps.

These tests use **fake authentication providers** (`FakeClientAuthNotifier`, `FakeAuthNotifier`) and **mocked Firebase Auth** to verify that the app navigates correctly between screens (Login, OTP, CreatePin, PinGate, Home) based on state changes, without hitting real Firebase services.

## Prerequisites

1.  Connect a physical device or start an emulator.
2.  Ensure `flutter devices` shows your device.

## Running Tests

### Option 1: Using provided scripts (Root Directory)

**Windows (PowerShell):**
```powershell
./run_smoke_tests.ps1
```

**Linux/Mac (Bash):**
```bash
./run_smoke_tests.sh
```

### Option 2: Running Manually

**Client App:**
```bash
cd apps/wawapp_client
flutter test integration_test/smoke_auth_flow_test.dart
```

**Driver App:**
```bash
cd apps/wawapp_driver
flutter test integration_test/smoke_auth_flow_test.dart
```

## What is Tested?

The tests simulate the following transitions:
1.  **Initial State**: Checks if `Key('login_screen')` is present.
2.  **Login (PinStatus.unknown)**: Sets user but unknown PIN status -> Expects `Key('pin_gate_screen')`.
3.  **No PIN**: Sets `PinStatus.noPin` -> Expects `Key('create_pin_screen')`.
4.  **OTP Flow**: Sets `otpFlowActive=true` -> Expects `Key('otp_screen')`.
5.  **Authenticated (Has PIN)**: Sets `PinStatus.hasPin` -> Expects `Key('home_screen')`.

## Troubleshooting

-   **"No device found"**: Make sure a device is connected. Pass `-d <device_id>` if needed.
-   **"Target file not found"**: Ensure you are in the correct app directory or using the absolute path.
-   **Lint Errors**: If you see lint warnings about `noSuchMethod` or `_delegate`, ensure `MockFirebaseAuth` extends `Fake` (from `flutter_test`).
