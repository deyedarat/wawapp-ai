# OTP Flow Refinement - Precise Edits

## Changes Applied

### 1. PhonePinAuth Service (`lib/services/phone_pin_auth.dart`)
- Added `setLanguageCode('ar')` in try/catch before `verifyPhoneNumber`
- Added optional `onCodeSent` callback parameter to `ensurePhoneSession()`
- Callback invoked in `codeSent` with `verificationId`

### 2. AuthNotifier (`lib/features/auth/providers/auth_service_provider.dart`)
- Updated `sendOtp()` to pass `onCodeSent` callback
- In callback: Set state with `otpFlowActive: true`, `verificationId`, `isLoading: false`, `error: null`
- Added `debugPrint` confirming both flags: `'OTP codeSent: otpFlowActive=true, verificationId=$verificationId'`

### 3. Login Screen (`lib/features/auth/phone_pin_login_screen.dart`)
- Replaced listener with one-shot guard:
  ```dart
  final becameActive = previous?.otpFlowActive == false && next.otpFlowActive == true;
  final gotVerification = previous?.verificationId == null && next.verificationId != null;
  ```
- Navigate to `/otp` only when both conditions true AND `context.mounted`
- Added `debugPrint`: `'Navigating to /otp: OTP flow activated with verificationId'`

### 4. Router (`lib/core/router/app_router.dart`)
- Changed to `debugPrint` (from `dev.log`)
- Updated redirect logic:
  - Allow `/otp` whenever `otpFlowActive == true` even if `user == null`
  - Redirect to `/login` when `!loggedIn && !otpActive && location != '/login' && location != '/otp'`
- Added `debugPrint` for all redirect decisions with format: `'Router redirect: loc=$location, loggedIn=$loggedIn, otpActive=$otpActive'`
- Added specific print when redirecting to `/otp`: `'Redirecting to /otp (OTP flow active)'`

### 5. OTP Screen (`lib/features/auth/otp_screen.dart`)
- Added guard: If `verificationId == null`, post-frame redirect to `/login`
- Returns `SizedBox.shrink()` when no verificationId
- Uses `WidgetsBinding.instance.addPostFrameCallback` for safe navigation

## Verification

```bash
dart format: ✅ 7 files formatted (1 changed)
dart analyze: ✅ No issues found!
```

## Debug Output Expected

When OTP flow runs, you'll see:
1. `OTP codeSent: otpFlowActive=true, verificationId=<id>`
2. `Router redirect: loc=/login, loggedIn=false, otpActive=true`
3. `Redirecting to /otp (OTP flow active)`
4. `Navigating to /otp: OTP flow activated with verificationId`

## Files Modified
- `lib/services/phone_pin_auth.dart`
- `lib/features/auth/providers/auth_service_provider.dart`
- `lib/features/auth/phone_pin_login_screen.dart`
- `lib/core/router/app_router.dart`
- `lib/features/auth/otp_screen.dart`
