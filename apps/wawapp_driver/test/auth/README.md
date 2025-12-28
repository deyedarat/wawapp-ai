# Auth Tests

This directory contains comprehensive tests for the Riverpod authentication stack.

## Test Structure

```
test/auth/
├── helpers/
│   ├── test_helpers.dart         # Helper functions for testing with Riverpod
│   ├── fake_phone_pin_auth.dart  # Fake PhonePinAuth service
│   └── mock_firebase_auth.dart   # Mock FirebaseAuth
├── auth_notifier_test.dart       # Unit tests for AuthNotifier
├── otp_screen_test.dart          # Widget tests for OTP screen
├── phone_pin_login_screen_test.dart  # Widget tests for Phone/PIN login screen
└── README.md                     # This file
```

## Test Coverage

### Unit Tests: AuthNotifier (`auth_notifier_test.dart`)

Tests the core authentication logic:

- **sendOtp()**: Valid/invalid phone numbers, error propagation
- **verifyOtp()**: Success/failure scenarios, state updates
- **createPin()**: PIN storage, salted hash validation, error handling
- **loginByPin()**: Correct/incorrect PIN, lockout simulation
- **logout()**: State clearing and cleanup
- **authStateChanges**: Firebase auth listener behavior

### Widget Tests: OTP Screen (`otp_screen_test.dart`)

Tests the OTP verification UI:

- Form field rendering and validation
- Input handling (6-digit numeric code)
- Error message display
- Button states and interactions
- Accessibility compliance

### Widget Tests: Phone/PIN Login Screen (`phone_pin_login_screen_test.dart`)

Tests the phone and PIN login UI:

- Form field rendering (phone and PIN)
- E.164 phone format validation
- PIN length validation (4 digits)
- Error display from Riverpod state
- Loading state handling
- SMS verification fallback flow
- Successful login flow

## Test Utilities

### FakePhonePinAuth

A fake implementation of `PhonePinAuth` that:
- Does NOT hit network or Firebase
- Tracks method call counts
- Allows configuring success/failure scenarios
- Validates phone number format
- Simulates PIN storage and verification

### MockFirebaseAuth

A mock implementation of `FirebaseAuth` that:
- Simulates auth state changes
- Provides controllable user sign-in/sign-out
- Supports testing auth listeners

### Test Helpers

Utility functions for:
- Pumping widgets with `ProviderScope`
- Creating `ProviderContainer` for unit tests
- `FakeUser` implementation for testing

## Running Tests

### Run all tests
```bash
# From the project root
flutter test apps/wawapp_driver/test/auth/

# From the app directory
cd apps/wawapp_driver
flutter test test/auth/
```

### Run specific test file
```bash
flutter test apps/wawapp_driver/test/auth/auth_notifier_test.dart
```

### Run with coverage
```bash
flutter test --coverage apps/wawapp_driver/test/auth/
```

### Run in watch mode (if using a test runner)
```bash
flutter test --watch apps/wawapp_driver/test/auth/
```

## Pre-commit Checks

Before committing, ensure:

1. **Format code**:
   ```bash
   dart format . --set-exit-if-changed
   ```

2. **Analyze code**:
   ```bash
   flutter analyze
   ```

3. **Run tests**:
   ```bash
   flutter test
   ```

## Writing New Tests

When adding new authentication features:

1. Add test cases to `auth_notifier_test.dart` for business logic
2. Add widget tests for any new UI components
3. Use the fake services in `helpers/` to avoid network calls
4. Override Riverpod providers using `pumpWithProviders()`
5. Test both success and failure paths
6. Verify loading states and error messages

## Example Test Pattern

```dart
testWidgets('example test', (tester) async {
  final fakeAuthService = FakePhonePinAuth();
  final mockFirebaseAuth = MockFirebaseAuth();

  await pumpWithProviders(
    tester,
    const YourWidget(),
    overrides: [
      phonePinAuthServiceProvider.overrideWithValue(fakeAuthService),
      authProvider.overrideWith((ref) {
        return AuthNotifier(fakeAuthService, mockFirebaseAuth);
      }),
    ],
  );

  // Your test assertions here
});
```

## Notes

- All tests use fakes/mocks and do NOT make real network calls
- Tests are deterministic and can run offline
- Widget tests verify UI behavior and state management
- Unit tests focus on business logic in AuthNotifier
- Tests verify the salted PIN hash implementation
