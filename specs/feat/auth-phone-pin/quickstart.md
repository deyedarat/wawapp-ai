# Quickstart: Phone + PIN Authentication

## Prerequisites

- Flutter 3.35.5+
- Firebase project configured
- Firebase Auth enabled with Phone provider
- `google-services.json` in `android/app/`

## Setup

1. **Add dependencies** (already in pubspec.yaml):
```yaml
dependencies:
  firebase_auth: latest
  flutter_secure_storage: latest
  riverpod: latest
  go_router: latest
```

2. **Firebase Console**:
   - Enable Phone Authentication
   - Add test phone numbers (optional for dev)

3. **Run the app**:
```bash
cd apps/wawapp_client
flutter pub get
flutter run
```

## Testing Flow

### New User Registration
1. Open app → Welcome screen
2. Tap "Get Started"
3. Enter phone: `+1234567890`
4. Enter OTP code
5. Create 6-digit PIN
6. Confirm PIN → Home screen

### Returning User Login
1. Open app → Login screen
2. Enter phone: `+1234567890`
3. Enter PIN
4. → Home screen

### PIN Reset
1. Login screen → "Forgot PIN"
2. Enter phone number
3. Enter OTP code
4. Create new PIN
5. → Home screen

## Development Notes

- Test phone numbers can be configured in Firebase Console
- PIN is stored encrypted in Secure Storage
- Lockout after 3 failed attempts (5 min)
- All screens support AR/FR/EN localization
