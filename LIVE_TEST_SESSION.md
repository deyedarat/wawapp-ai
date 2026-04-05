# WawApp reCAPTCHA Fix - Live Test Session

## 📋 Summary of Investigation

### Root Cause Identified
After comprehensive testing and Firebase Console diagnostics via Manus browser agent, we identified:

**Error Code**: 17201 - "reCAPTCHA token is missing"

**Root Cause**: **73% of App Check tokens are invalid** ❌

This means the Flutter app is generating App Check tokens, but Firebase rejects them as invalid, causing reCAPTCHA to fail.

---

## ✅ What We've Done So Far

### 1. Navigation & State Management Fixes (Completed)
We implemented **5 critical fixes** to the navigation system:

#### Fix #1: Force stay on /login during reCAPTCHA
- **File**: `apps/wawapp_client/lib/core/router/app_router.dart:187-197`
- **Fix**: Added logic to detect `OtpStage.sending` and force redirect to `/login` to prevent race conditions

#### Fix #2: Reset otpStage to `failed` on error
- **File**: `packages/auth_shared/lib/src/auth_notifier.dart:97-105`
- **Fix**: Added `otpStage: OtpStage.failed` in catch block to properly reset state

#### Fix #3: Move 800ms delay to AuthNotifier (State Layer)
- **File**: `packages/auth_shared/lib/src/auth_notifier.dart:79-91`
- **Fix**: Moved delay from UI layer to state management so GoRouter can react to it

#### Fix #4: Skip debounce for critical OTP states
- **File**: `apps/wawapp_client/lib/core/router/app_router.dart:290-303`
- **Fix**: Made `codeSent` and `failed` states bypass the 600ms debounce for immediate navigation

#### Fix #5: Store currentState in RefreshStream
- **File**: `apps/wawapp_client/lib/core/router/app_router.dart:33-41, 289, 317-318`
- **Fix**: Eliminated closure race condition by storing and reading latest state from `_GoRouterRefreshStream.currentState`

**Result**: Navigation logic is now correct ✅ (confirmed in logs: Router properly reads `OtpStage.failed` and stays on `/login`)

---

### 2. Firebase Console Diagnostic (Completed)

Used Manus browser agent to audit Firebase Console.

**Key Findings:**
- ✅ Phone Authentication: Enabled
- ✅ App Check: Registered with Play Integrity
- ✅ SHA-256 from Google Play: Present in Firebase
- ✅ All required APIs: Enabled
- ✅ Firestore Security Rules: Correct
- ❌ **73% App Check tokens invalid** ← ROOT CAUSE
- ⚠️ App Check in "Monitoring" mode (not enforced)
- ⚠️ Web app not registered in App Check

---

### 3. Updated firebase_app_check Dependency (Just Completed)

- **Before**: `firebase_app_check: ^0.3.2+1` (very old)
- **After**: `firebase_app_check: ^0.3.2+10` (latest compatible version)
- **File**: `apps/wawapp_client/pubspec.yaml:30`
- **Status**: ✅ Dependency updated, `flutter pub get` completed

---

## 🔧 Next Steps to Fix Error 17201

### Step 1: Download Fresh google-services.json ⏳

**Why**: The current `google-services.json` file may be outdated and missing App Check configuration.

**Action Required**: Use Manus browser agent with this prompt:
📄 **MANUS_DOWNLOAD_GOOGLE_SERVICES.md**

Manus will:
1. Navigate to Firebase Console
2. Download the latest `google-services.json` for `com.wawapp.client`
3. Provide the file contents

Once received, I will:
- Replace the old file in `apps/wawapp_client/android/app/google-services.json`
- Rebuild the APK
- Test on device

---

### Step 2: Rebuild and Test

After updating `google-services.json`:

```bash
cd apps/wawapp_client
flutter clean
flutter pub get
flutter build apk --release
adb -s <DEVICE_ID> install -r build/app/outputs/flutter-apk/app-release.apk
```

Then test:
1. Open app
2. Enter phone number
3. Click "Create Account"
4. Complete reCAPTCHA
5. **Expected**: Navigate to OTP screen (NO "about:blank")

---

### Step 3: Monitor App Check Metrics

After deploying the fix, wait 10-15 minutes, then ask Manus to check:
```
Firebase Console → App Check → APIs → Authentication → Metrics
```

**Success criteria**:
- Verified requests > 90% ✅
- Invalid requests < 10%

---

## 📊 Current Status

| Task | Status |
|------|--------|
| Navigation fixes | ✅ Completed (5 fixes) |
| Firebase diagnostic | ✅ Completed (via Manus) |
| Update firebase_app_check | ✅ Completed (0.3.2+10) |
| SHA-256 verification | ✅ Confirmed present |
| Download google-services.json | ⏳ **NEXT STEP** |
| Rebuild & test | ⏳ Pending |
| Monitor metrics | ⏳ Pending |

---

## 📁 Files Modified

### Client App:
1. `apps/wawapp_client/lib/core/router/app_router.dart` - 5 navigation fixes
2. `apps/wawapp_client/lib/features/home/home_screen.dart` - UI overflow fix
3. `apps/wawapp_client/pubspec.yaml` - Updated firebase_app_check

### Shared Package:
4. `packages/auth_shared/lib/src/auth_notifier.dart` - State management fixes

### Documentation:
5. `FIXES_REPORT.md` - Comprehensive QA report
6. `DEVICE_TEST_REPORT.md` - Device testing results
7. `MANUAL_TEST_CHECKLIST.md` - Arabic testing guide
8. `MANUS_FIREBASE_DIAGNOSTIC_PROMPT.md` - Manus diagnostic prompt
9. `MANUS_DOWNLOAD_GOOGLE_SERVICES.md` - Manus download prompt
10. `LIVE_TEST_SESSION.md` - This file

---

## 🎯 Success Criteria

The fix will be successful when:

1. ✅ App Check metrics show > 90% verified requests
2. ✅ Error 17201 no longer appears in logs
3. ✅ No "about:blank" screen during reCAPTCHA
4. ✅ Successful reCAPTCHA navigates to OTP screen
5. ✅ Failed reCAPTCHA returns to login screen with error message

---

## 🚀 Ready to Continue

**NEXT ACTION**:
Use Manus browser agent with **MANUS_DOWNLOAD_GOOGLE_SERVICES.md** to download the latest `google-services.json` file.

Once you provide the file contents, I will:
1. Replace the old file
2. Run `flutter clean && flutter pub get`
3. Rebuild the APK
4. Install on device
5. Test the OTP flow
6. Verify App Check metrics

---

**Last Updated**: 2026-03-10
**Testing Device**: R83Y20PC4EN (Samsung Galaxy)
**APK Version**: 1.0.0+27 (with navigation fixes + updated firebase_app_check)
