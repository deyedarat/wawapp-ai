# WawApp Staging Go/No-Go Checklist

**Version:** 1.0
**Last Updated:** 2025-12-22
**Target:** Staging environment deployment verification
**Estimated Time:** 45-60 minutes (full checklist)

---

## Prerequisites

Before starting this checklist:

1. **Fresh clone ready:**
   ```bash
   git clone https://github.com/your-org/wawapp-ai.git
   cd wawapp-ai
   git checkout driver-auth-stable-work  # or target branch
   ```

2. **Required tools installed:**
   - Flutter SDK (stable channel)
   - Node.js 18+ with npm
   - Firebase CLI: `npm install -g firebase-tools`
   - Android SDK with ADB (for device gates)
   - Git

3. **Secrets configured:**
   - Follow [SECRETS_MANAGEMENT.md](SECRETS_MANAGEMENT.md) for:
     - `firebase_options.dart` (all 3 apps)
     - `google-services.json` (all 3 apps)
     - `api_keys.xml` (client app only)
   - Firebase emulator auth enabled
   - One Android device connected via ADB

4. **Firebase projects:**
   - Staging project ID known
   - Test/emulator project ID known
   - `firebase login` completed

---

## A) Build & Static Gates (FAST - ~10 min)

**MUST PASS** - These are blocking gates.

### A1. Flutter Analyze (All Apps)

```bash
# Driver app
cd apps/wawapp_driver
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
```

**✅ PASS:** Exit code 0, output shows "No issues found" or "X issues found" with only info-level warnings
**❌ FAIL:** Any error-level issues present
**Fix:** Review errors, fix code issues, re-run

```bash
# Client app
cd ../wawapp_client
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
```

**✅ PASS:** Exit code 0
**❌ FAIL:** Errors present

```bash
# Admin app
cd ../wawapp_admin
flutter pub get
flutter analyze --no-fatal-infos --no-fatal-warnings
```

**✅ PASS:** Exit code 0
**❌ FAIL:** Errors present

### A2. Unit Tests (All Apps)

```bash
# Driver app
cd apps/wawapp_driver
flutter test
```

**✅ PASS:** All tests pass (00:XX +X)
**❌ FAIL:** Any test failures
**Fix:** Review failing tests, fix code, re-run

```bash
# Client app (if tests exist)
cd ../wawapp_client
flutter test || echo "⚠️ No tests yet"
```

**✅ PASS:** All tests pass or no tests
**❌ FAIL:** Test failures

```bash
# Admin app (if tests exist)
cd ../wawapp_admin
flutter test || echo "⚠️ No tests yet"
```

**✅ PASS:** All tests pass or no tests
**❌ FAIL:** Test failures

### A3. Packages Tests

```bash
# Auth shared package
cd ../../packages/auth_shared
flutter pub get
flutter analyze --no-fatal-infos
flutter test
```

**✅ PASS:** Analyze + tests pass
**❌ FAIL:** Errors or test failures

```bash
# Core shared package
cd ../core_shared
flutter pub get
flutter analyze --no-fatal-infos
flutter test || echo "⚠️ No tests yet"
```

**✅ PASS:** Analyze pass
**❌ FAIL:** Errors

**Gate A Result:** [ ] PASS (all checks green) / [ ] FAIL (blockers present)

---

## B) Emulator Gates (AUTH + RULES - ~10 min)

**MUST PASS** - Security-critical validations.

### B1. Firestore Security Rules Tests

```bash
cd firestore-rules-tests
npm ci
```

**✅ PASS:** Dependencies installed
**❌ FAIL:** npm errors
**Fix:** Delete `node_modules/`, `package-lock.json`, retry `npm install`

```bash
# Run all 57 security test cases
npm test
```

**✅ PASS:** Output shows:
```
PASS  firestore.test.js
  ✓ prevents phone enumeration attacks (XXms)
  ✓ denies cross-user data access (XXms)
  ✓ protects admin-only fields (XXms)
  ✓ restricts financial operations to Cloud Functions (XXms)
  ✓ enforces PIN integrity (atomic hash + salt updates) (XXms)
  ✓ validates order status transitions (XXms)

Test Suites: 1 passed, 1 total
Tests:       57 passed, 57 total
```

**❌ FAIL:** Any test failures
**Fix:** Review failed test output, compare with `firestore.rules`, fix rules, re-run

### B2. Firebase Auth Emulator (Integration Test Prerequisites)

```bash
# Start auth emulator (in separate terminal)
cd ../../
firebase emulators:start --only auth
```

**✅ PASS:** Output shows:
```
✔  emulators: All emulators ready! View status at http://localhost:4000
┌───────────┬────────────────┐
│ Emulator  │ Host:Port      │
├───────────┼────────────────┤
│ Auth      │ localhost:9099 │
└───────────┴────────────────┘
```

**❌ FAIL:** Port already in use or emulator doesn't start
**Fix:** Kill process on port 9099: `lsof -ti:9099 | xargs kill` (Mac/Linux) or `netstat -ano | findstr :9099` (Windows)

**Leave emulator running** for next section.

### B3. Integration Tests (Driver App)

**Prerequisites:** Auth emulator running from B2

```bash
# In new terminal
cd apps/wawapp_driver
flutter test integration_test/auth_flow_test.dart
```

**✅ PASS:** Test completes successfully:
```
00:XX +1: Auth Flow Integration Tests OTP -> PIN Creation -> Home happy path
00:XX +1: All tests passed!
```

**❌ FAIL:** Test timeout or assertion failure
**Common issues:**
- Emulator not running → start emulator
- Test OTP doesn't work → verify emulator config allows `+22212345678` with code `123456`
- Widget not found → check Keys still present in production code

```bash
# Logout flow test
flutter test integration_test/logout_flow_test.dart
```

**✅ PASS:** Both test scenarios pass
**❌ FAIL:** Logout test fails
**Fix:** Check `logoutButton` Key exists in `driver_profile_screen.dart`

**Gate B Result:** [ ] PASS (all security + auth tests green) / [ ] FAIL (critical security issue)

---

## C) Device Gates (REAL ANDROID - ~15 min)

**SHOULD PASS** - Real device smoke tests. **Failures may be acceptable with mitigation plan.**

### C1. Build Release APKs

```bash
# Driver app release build
cd apps/wawapp_driver
flutter build apk --release --dart-define=GOOGLE_MAPS_API_KEY=staging_key_here
```

**✅ PASS:** Build succeeds, APK generated at `build/app/outputs/flutter-apk/app-release.apk`
**❌ FAIL:** Build errors
**Fix:** Check `google-services.json` present, signing config valid, dependencies resolved

```bash
# Client app release build
cd ../wawapp_client
flutter build apk --release --dart-define=GOOGLE_MAPS_API_KEY=staging_key_here
```

**✅ PASS:** APK generated
**❌ FAIL:** Build errors

### C2. Install on Real Device

**Prerequisites:** Android device connected via USB, USB debugging enabled

```bash
# Check device connected
adb devices
```

**✅ PASS:** Shows device serial number
**❌ FAIL:** "no devices/emulators found"
**Fix:** Enable USB debugging in developer options, reconnect device

```bash
# Install driver app
cd apps/wawapp_driver
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

**✅ PASS:** Output: `Success`
**❌ FAIL:** `INSTALL_FAILED_*` error
**Fix:** Uninstall old version first: `adb uninstall com.wawapp.driver`

```bash
# Install client app
cd ../wawapp_client
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

**✅ PASS:** Output: `Success`
**❌ FAIL:** Install error

### C3. Driver App Smoke Test (Manual - on device)

**Test sequence:**

1. **Launch app:**
   ```bash
   adb shell am start -n com.wawapp.driver/.MainActivity
   ```
   **✅ PASS:** App launches, shows phone login screen
   **❌ FAIL:** Crash on launch → check logcat: `adb logcat | grep -i flutter`

2. **Auth flow (manual on device):**
   - Enter valid Mauritania phone number (e.g., `+22212345678`)
   - Tap "Continue"
   - **✅ PASS:** OTP screen appears
   - Enter OTP code (from Firebase console or test number)
   - Tap "Verify"
   - **✅ PASS:** Navigates to Create PIN screen (new user) or Home (existing user)

3. **Create PIN (if new user):**
   - Enter PIN: `1357`
   - Confirm PIN: `1357`
   - Tap "Save"
   - **✅ PASS:** Navigates to Home screen

4. **Go Online toggle:**
   - On Home screen, toggle "Go Online" switch
   - **✅ PASS:** Toggle works, no crash
   - **⚠️ ACCEPTABLE FAIL:** Location permission dialog appears (expected first time)

5. **Logout:**
   - Navigate to Profile tab
   - Tap "تسجيل الخروج" (logout button)
   - Confirm logout
   - **✅ PASS:** Returns to login screen
   - **❌ FAIL:** Crash or stuck → critical blocker

### C4. Client App Smoke Test (Manual - on device)

**Test sequence:**

1. **Launch app:**
   ```bash
   adb shell am start -n com.wawapp.client/.MainActivity
   ```
   **✅ PASS:** App launches
   **❌ FAIL:** Crash

2. **Basic navigation:**
   - Complete auth flow (similar to driver)
   - Navigate to map screen
   - **✅ PASS:** Map loads (may show Mauritania)
   - **⚠️ ACCEPTABLE FAIL:** Map shows blank (API key issue, non-blocking for staging)

3. **Logout:**
   - Navigate to profile
   - Logout
   - **✅ PASS:** Returns to login

**Gate C Result:** [ ] PASS (all smoke tests work) / [ ] PARTIAL (document failures + mitigation)

---

## D) Observability Gates (CRASHLYTICS + ANALYTICS - ~5 min)

**SHOULD PASS** - Validates telemetry pipelines. **Not blocking if staging-only.**

### D1. Crashlytics Non-Fatal Event Test

**On device with driver app installed:**

1. **Trigger a non-fatal exception** (requires code change or dev menu):
   ```dart
   // In driver app, add to dev menu or test button:
   FirebaseCrashlytics.instance.recordError(
     Exception('Staging smoke test exception'),
     StackTrace.current,
     reason: 'Manual staging gate test',
     fatal: false,
   );
   ```

2. **Verify in Firebase Console:**
   - Go to Firebase Console → Crashlytics → driver app
   - Filter by "Non-fatals"
   - **✅ PASS:** Event appears within 5 minutes with reason "Manual staging gate test"
   - **❌ FAIL:** No event after 10 minutes
   - **Fix:** Check `firebase_crashlytics` dependency, verify `google-services.json`, re-test

### D2. Analytics Event Test

**On device:**

1. **Perform login** (from C3 smoke test)

2. **Verify in Firebase Console:**
   - Go to Firebase Console → Analytics → DebugView
   - Enable debug mode: `adb shell setprop debug.firebase.analytics.app com.wawapp.driver`
   - **✅ PASS:** See `auth_completed` event with `method: phone_pin`
   - **⚠️ ACCEPTABLE FAIL:** DebugView empty (staging data may be delayed)

**Gate D Result:** [ ] PASS (telemetry working) / [ ] DEFER (staging-only, verify in prod)

---

## E) Backend Gates (CLOUD FUNCTIONS - ~10 min)

**SHOULD PASS** - Validates serverless backend. **Can defer if functions unchanged.**

### E1. Deploy Functions to Staging (Emulator or Real Project)

**Option A: Emulator (faster, recommended for gate):**

```bash
cd functions
npm install
firebase emulators:start --only functions
```

**✅ PASS:** Functions emulator starts:
```
✔  functions: All functions ready!
┌───────────────────────────────────────────────┐
│ functions: http://localhost:5001/... │
└───────────────────────────────────────────────┘
```

**❌ FAIL:** Emulator errors
**Fix:** Check Node.js version (18+), `npm install`, review function syntax

**Option B: Deploy to staging project:**

```bash
firebase use staging  # switch to staging project
firebase deploy --only functions
```

**✅ PASS:** All functions deploy successfully
**❌ FAIL:** Deployment errors
**Fix:** Review function code, check IAM permissions, retry

### E2. Smoke Test Critical Function

**Test the most critical function** (e.g., order creation):

```bash
# Using emulator (adjust URL if deployed)
curl -X POST http://localhost:5001/wawapp-staging/us-central1/createOrder \
  -H "Content-Type: application/json" \
  -d '{
    "clientId": "test-client-123",
    "pickup": {"lat": 18.0735, "lng": -15.9582},
    "dropoff": {"lat": 18.0835, "lng": -15.9682},
    "fareEstimate": 150
  }'
```

**✅ PASS:** Response with orderId:
```json
{"success": true, "orderId": "order_..."}
```

**❌ FAIL:** Error response or timeout
**Fix:** Check function logs: `firebase functions:log` or emulator console

**Gate E Result:** [ ] PASS (functions working) / [ ] SKIP (no function changes in release)

---

## Final Go/No-Go Rubric

### MUST PASS (Blocking)
- ✅ Gate A: Build & Static Gates (all analyze + tests pass)
- ✅ Gate B: Security rules + integration tests pass

### SHOULD PASS (Strong recommendation)
- ✅ Gate C: Device smoke tests (auth, navigation, logout work)
- ✅ Gate D: Crashlytics reports events
- ✅ Gate E: Critical functions respond correctly

### MAY DEFER (With documented mitigation)
- ⚠️ Gate C partial: Map blank (verify API key before prod)
- ⚠️ Gate D: Analytics delayed (verify in prod DebugView)
- ⚠️ Gate E: Functions unchanged (skip if no backend changes)

---

## Decision Matrix

| Scenario | Decision | Action |
|----------|----------|--------|
| All MUST PASS + all SHOULD PASS | **GO** | Proceed to staging deployment |
| All MUST PASS + some SHOULD PASS failures | **CONDITIONAL GO** | Document mitigation plan, deploy with caution |
| Any MUST PASS failure | **NO-GO** | Fix blocking issues, re-run checklist |
| Multiple SHOULD PASS failures | **NO-GO** | Too risky, investigate and fix |

---

## Quick Reference: Helper Script

Run automated static gates:

```bash
./scripts/staging_gate.sh
```

See [scripts/staging_gate.sh](scripts/staging_gate.sh) for automated execution of Gates A-B.

---

## Checklist Sign-Off

**Completed by:** _______________
**Date:** _______________
**Git commit SHA:** _______________

**Gate Results:**
- [ ] A: Build & Static Gates - PASS / FAIL
- [ ] B: Emulator Gates - PASS / FAIL
- [ ] C: Device Gates - PASS / PARTIAL / FAIL
- [ ] D: Observability Gates - PASS / DEFER / FAIL
- [ ] E: Backend Gates - PASS / SKIP / FAIL

**Final Decision:** [ ] GO / [ ] CONDITIONAL GO / [ ] NO-GO

**Mitigation Plan (if CONDITIONAL GO):**
_________________________________________
_________________________________________

**Approved by:** _______________
**Role:** Release Engineer / QA Lead
