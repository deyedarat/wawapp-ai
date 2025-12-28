# Driver App Integration Tests

This directory contains integration tests for critical auth flows in the WawApp Driver application.

## Tests Included

### 1. `auth_flow_test.dart` - Authentication Happy Path
Tests the complete new driver registration flow:
1. Enter phone number
2. Send OTP
3. Verify OTP code
4. Create PIN
5. Land on Home screen

### 2. `logout_flow_test.dart` - Logout Flow
Tests logout functionality:
1. Logout from profile screen
2. Verify return to login screen
3. Verify cannot access home without re-authentication
4. Test logout cancellation

## Running Tests

### Prerequisites

1. **Firebase Auth Emulator** (recommended for local testing):
   ```bash
   firebase emulators:start --only auth
   ```

2. **Or use Firebase Test Lab** for cloud testing

### Run All Integration Tests

```bash
cd apps/wawapp_driver
flutter test integration_test/
```

### Run Specific Test

```bash
# Auth flow only
flutter test integration_test/auth_flow_test.dart

# Logout flow only
flutter test integration_test/logout_flow_test.dart
```

### Run on Physical Device

```bash
# Connect device via USB, then:
flutter test integration_test/ --device-id=<DEVICE_ID>

# Or run on all connected devices:
flutter test integration_test/
```

### Run with Verbose Output

```bash
flutter test integration_test/ --verbose
```

## Test Configuration

### Firebase Auth Test Configuration

For local testing with Firebase Auth emulator:

1. Set up emulator in `firebase.json`:
   ```json
   {
     "emulators": {
       "auth": {
         "port": 9099
       }
     }
   }
   ```

2. Use test phone numbers that work with emulator:
   - Format: `+22212345678`
   - OTP: `123456`

### CI/CD Integration

For GitHub Actions or other CI systems:

```yaml
- name: Run Integration Tests
  run: |
    cd apps/wawapp_driver
    flutter test integration_test/
```

## Test Keys Reference

The following Keys are used for test selectors:

### Phone/PIN Login Screen
- `phoneField` - Phone number input
- `continueButton` - Continue/Send OTP button

### OTP Screen
- `otpField` - OTP code input
- `verifyButton` - Verify OTP button

### Create PIN Screen
- `pinField` - PIN input
- `confirmPinField` - Confirm PIN input
- `savePinButton` - Save PIN button

### Profile Screen
- `logoutButton` - Logout button

## Troubleshooting

### Test Fails at OTP Step
- Ensure Firebase Auth emulator is running
- Check that test phone number format is correct (`+222XXXXXXXX`)
- Verify OTP code matches emulator configuration

### Test Fails at PIN Creation
- Ensure PIN meets validation rules:
  - Exactly 4 digits
  - No repeated digits (e.g., `1111`)
  - No sequential digits (e.g., `1234`, `4321`)

### Cannot Find Widget
- Check that Keys are still present in production code
- Ensure `pumpAndSettle()` timeout is sufficient
- Verify navigation timing with longer delays if needed

## Maintenance

When updating auth screens:
1. Ensure test Keys remain on widgets
2. Update tests if flow changes
3. Run tests locally before committing
4. Update this README if new tests added
