# Shared Auth Package & Adaptive Register+Login Flow

**Date:** 2025-11-12  
**Status:** IMPLEMENTED

## Summary

Created `packages/auth_shared/` with reusable auth logic and implemented adaptive register+login flow in client app.

## Changes

### 1. Shared Auth Package (`packages/auth_shared/`)

**Files Created:**
- `lib/src/phone_pin_auth.dart` - Core auth service with salted PIN hashing
- `lib/src/auth_state.dart` - AuthState model with OtpStage enum
- `lib/src/auth_notifier.dart` - StateNotifier for auth management
- `lib/auth_shared.dart` - Library exports
- `pubspec.yaml` - Package dependencies

**Key Features:**
- `phoneExists(phone)` - Check if phone registered
- `ensurePhoneSession(phone)` - Send OTP
- `confirmOtp(code)` - Verify OTP
- `setPin(pin)` - Create salted PIN hash
- `verifyPin(pin)` - Validate PIN with legacy migration
- `hasPinHash()` - Check if user has PIN
- Configurable `userCollection` (users/drivers)

### 2. Client App Updates

**New Files:**
- `apps/wawapp_client/lib/features/auth/otp_screen.dart`
- `apps/wawapp_client/lib/features/auth/create_pin_screen.dart`
- `apps/wawapp_client/lib/features/auth/providers/auth_service_provider.dart`

**Modified Files:**
- `apps/wawapp_client/lib/features/auth/phone_pin_login_screen.dart` - Adaptive flow
- `apps/wawapp_client/lib/core/router/app_router.dart` - Added /otp, /create-pin routes
- `apps/wawapp_client/pubspec.yaml` - Added auth_shared dependency

### 3. Adaptive Login Flow

**New User (Phone Not Registered):**
1. Enter phone → Check Phone button
2. System detects new user
3. "Create Account" button appears
4. Click → Send OTP → Navigate to /otp
5. Enter 6-digit code → Navigate to /create-pin
6. Create 4-digit PIN → Navigate to /

**Existing User (Phone Registered):**
1. Enter phone → Check Phone button
2. System detects existing user
3. PIN field appears
4. Enter 4-digit PIN → Login → Navigate to /

## Router Updates

```dart
GoRoute(
  path: '/otp',
  name: 'otp',
  builder: (context, state) => const OtpScreen(),
),
GoRoute(
  path: '/create-pin',
  name: 'createPin',
  builder: (context, state) => const CreatePinScreen(),
),
```

## Firestore Schema

**No changes to existing schema**

Collection: `users` (client) / `drivers` (driver)
```
{
  phone: "+222...",
  pinSalt: "base64...",
  pinHash: "sha256...",
  createdAt: Timestamp
}
```

## Driver App Compatibility

✅ Driver app unchanged - still uses local implementation
✅ Can be migrated to auth_shared in future
✅ Same PIN hashing algorithm (compatible)

## Acceptance Criteria

| Criteria | Status |
|----------|--------|
| New user → OTP → Create PIN → Login | ✅ Implemented |
| Existing user → PIN only → Login | ✅ Implemented |
| Salted PIN hashing | ✅ Preserved |
| No driver app breakage | ✅ Confirmed |
| Firestore schema unchanged | ✅ Confirmed |
| FCM preserved | ✅ No changes |

## Testing

```bash
# Get dependencies
cd packages/auth_shared && flutter pub get
cd ../../apps/wawapp_client && flutter pub get

# Run client
.\spec.ps1 build:client Debug
```

## Commits

- `7ba76da` - feat(auth): shared auth package with adaptive register+login flow
- `[next]` - feat(auth): add OTP and CreatePin routes to client router

## Next Steps

1. Test new user registration flow
2. Test existing user login flow
3. Optional: Migrate driver app to use auth_shared
