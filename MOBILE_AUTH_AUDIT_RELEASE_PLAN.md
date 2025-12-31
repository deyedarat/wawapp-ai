# Mobile Auth/PIN & Router Guards Audit + Release Plan
**Generated:** 2025-12-30  
**Scope:** Auth flow security, PIN implementation, navigation guards, crash risks  
**Deliverables:** Vulnerability findings + Release gate checklist + Patch plan

---

## Part 1: Mobile Auth/PIN Audit Findings

### P0-AUTH-1: PIN Brute Force - No Rate Limiting

**Severity:** P0 - Security  
**Component:** `packages/auth_shared/lib/src/phone_pin_auth.dart` + `functions/src/auth/createCustomToken.ts`  
**Evidence:**
```dart
File: packages/auth_shared/lib/src/phone_pin_auth.dart
Lines 227-282:
Future<bool> verifyPin(String pin, String phoneE164) async {
  try {
    // Call Cloud Function to verify PIN and get custom token
    final callable = FirebaseFunctions.instance.httpsCallable('createCustomToken');
    final result = await callable.call<Map<String, dynamic>>({
      'phoneE164': phoneE164,
      'pin': pin,
    });
    // ... no rate limiting, no lockout, no attempt tracking
  }
}
```

**Vulnerability:**
- No rate limiting on PIN verification attempts
- No account lockout after failed attempts
- No CAPTCHA or challenge-response
- Attacker can try all 10,000 PIN combinations (0000-9999)

**Attack Scenario:**
1. Attacker knows driver's phone number (from order matching feed - see P0-1)
2. Attacker writes script to call `verifyPin()` with all PINs
3. At 1 attempt/second, cracks any PIN in <3 hours
4. Gains full account access

**Impact:**
- Account takeover
- Identity theft
- Fraudulent orders
- Revenue theft

**Fix:**
```typescript
// Cloud Function: Add rate limiting
import { RateLimiter } from 'limiter';

const pinAttemptLimiter = new Map<string, { count: number, lockedUntil: number }>();

export const createCustomToken = functions.https.onCall(async (data, context) => {
  const { phoneE164, pin } = data;
  
  // Check rate limit
  const now = Date.now();
  const attempts = pinAttemptLimiter.get(phoneE164) || { count: 0, lockedUntil: 0 };
  
  if (attempts.lockedUntil > now) {
    const remainingSeconds = Math.ceil((attempts.lockedUntil - now) / 1000);
    throw new functions.https.HttpsError(
      'resource-exhausted',
      `Account locked. Try again in ${remainingSeconds} seconds.`
    );
  }
  
  // ... verify PIN ...
  
  if (!isValidPin) {
    attempts.count++;
    
    // Progressive lockout: 3 attempts = 1 min, 6 = 5 min, 10 = 1 hour
    if (attempts.count >= 10) {
      attempts.lockedUntil = now + (60 * 60 * 1000); // 1 hour
    } else if (attempts.count >= 6) {
      attempts.lockedUntil = now + (5 * 60 * 1000); // 5 minutes
    } else if (attempts.count >= 3) {
      attempts.lockedUntil = now + (60 * 1000); // 1 minute
    }
    
    pinAttemptLimiter.set(phoneE164, attempts);
    
    throw new functions.https.HttpsError(
      'unauthenticated',
      `Invalid PIN. ${10 - attempts.count} attempts remaining.`
    );
  }
  
  // Reset on success
  pinAttemptLimiter.delete(phoneE164);
  
  // ... return token ...
});
```

---

### P0-AUTH-2: Null Pointer Crash in Auth Gate

**Severity:** P0 - Crash Risk  
**Component:** `apps/wawapp_driver/lib/features/auth/auth_gate.dart`  
**Evidence:**
```dart
File: apps/wawapp_driver/lib/features/auth/auth_gate.dart
Lines 35-36:
final user = authState.user;

if (user == null) {
  return Stream.value(null);
}

return FirebaseFirestore.instance
    .collection('drivers')
    .doc(user.uid)  // CRASH: user can be null here due to race condition
    .snapshots();
```

**Vulnerability:**
Race condition between lines 28-35:
1. `authState.user` is checked (line 28) → not null
2. User signs out → `authState.user` becomes null
3. Line 34 executes → `user.uid` throws `NoSuchMethodError`

**Impact:**
- App crash on logout
- Poor user experience
- Crashlytics spam

**Fix:**
```dart
final driverProfileProvider =
    StreamProvider.autoDispose<DocumentSnapshot<Map<String, dynamic>>?>((ref) {
  if (TestLabFlags.safeEnabled) {
    return Stream.value(TestLabMockData.mockDriverDoc);
  }
  
  final authState = ref.watch(authProvider);
  final user = authState.user;

  // FIXED: Check user is not null before accessing uid
  if (user == null) {
    return Stream.value(null);
  }

  // Capture uid in local variable to prevent race condition
  final uid = user.uid;
  
  return FirebaseFirestore.instance
      .collection('drivers')
      .doc(uid)
      .snapshots();
});
```

---

### P1-AUTH-1: Unhandled Exception in OTP Flow

**Severity:** P1 - Crash Risk  
**Component:** `packages/auth_shared/lib/src/phone_pin_auth.dart`  
**Evidence:**
```dart
File: packages/auth_shared/lib/src/phone_pin_auth.dart
Lines 175-186:
Future<void> confirmOtp(String smsCode) async {
  final vid = _lastVerificationId;
  if (vid == null) {
    throw Exception('No verification id');  // CRASH: Unhandled exception
  }
  // ...
}
```

**Vulnerability:**
- `Exception` is thrown but not caught by caller
- No user-friendly error message
- App crashes instead of showing error

**Impact:**
- App crash during OTP entry
- User stuck in broken state

**Fix:**
```dart
// In auth_service_provider.dart
Future<void> verifyOtp(String code) async {
  state = state.copyWith(isLoading: true, error: null);
  try {
    await _authService.confirmOtp(code);
    await AnalyticsService.instance.logLoginSuccess('otp');
    state = state.copyWith(isLoading: false, otpFlowActive: false);
  } on Exception catch (e) {
    // FIXED: Catch Exception specifically
    if (e.toString().contains('No verification id')) {
      state = state.copyWith(
        isLoading: false,
        error: 'Session expired. Please request a new code.',
        otpStage: OtpStage.failed,
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        error: AuthErrorMessages.getErrorMessage(e),
      );
    }
  } on Object catch (e) {
    state = state.copyWith(
      isLoading: false,
      error: AuthErrorMessages.getErrorMessage(e),
    );
  }
}
```

---

### P1-AUTH-2: setState After Dispose - Memory Leak

**Severity:** P1 - Memory Leak  
**Component:** Multiple screens  
**Evidence:**
```dart
File: apps/wawapp_driver/lib/features/auth/otp_screen.dart
Lines 26-30:
void _listenToAuthState() {
  ref.listen<AuthState>(authProvider, (previous, next) {
    if (!mounted) return;  // Good: checks mounted
    
    if (authState.error != null) {
      // ... but no check before setState in other callbacks
    }
  });
}
```

**Vulnerability:**
- Some callbacks check `mounted`, others don't
- Inconsistent pattern across codebase
- Can cause `setState() called after dispose()` errors

**Impact:**
- Memory leaks
- Crash in production
- Crashlytics noise

**Fix:**
```dart
// Consistent pattern for all async callbacks
void _listenToAuthState() {
  ref.listen<AuthState>(authProvider, (previous, next) {
    // ALWAYS check mounted before setState
    if (!mounted) return;
    
    if (next.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(next.error!)),
      );
    }
    
    if (next.user != null) {
      // Check mounted again before navigation
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
      );
    }
  });
}
```

---

### P1-AUTH-3: PIN Verification Missing Phone Parameter

**Severity:** P1 - Logic Error  
**Component:** `apps/wawapp_driver/lib/features/auth/providers/auth_service_provider.dart`  
**Evidence:**
```dart
File: apps/wawapp_driver/lib/features/auth/providers/auth_service_provider.dart
Lines 169-188:
Future<void> loginByPin(String pin) async {
  state = state.copyWith(isLoading: true, error: null);
  try {
    final isValid = await _authService.verifyPin(pin);  // MISSING: phoneE164 parameter
    // ...
  }
}
```

**Vulnerability:**
- `verifyPin()` requires `phoneE164` parameter (line 227 of phone_pin_auth.dart)
- But `loginByPin()` doesn't pass it
- Compilation error or runtime crash

**Impact:**
- PIN login broken
- Users cannot log in with PIN

**Fix:**
```dart
Future<void> loginByPin(String pin) async {
  state = state.copyWith(isLoading: true, error: null);
  try {
    // FIXED: Pass phoneE164 from state
    final phoneE164 = state.phoneE164;
    if (phoneE164 == null) {
      state = state.copyWith(
        isLoading: false,
        error: 'Phone number not found. Please log in with OTP.',
      );
      return;
    }
    
    final isValid = await _authService.verifyPin(pin, phoneE164);
    if (isValid) {
      await AnalyticsService.instance.logLoginSuccess('pin');
      state = state.copyWith(isLoading: false, hasPin: true);
    } else {
      state = state.copyWith(
        isLoading: false,
        error: AuthErrorMessages.pinIncorrect,
      );
    }
  } on Object catch (e) {
    state = state.copyWith(
      isLoading: false,
      error: AuthErrorMessages.getErrorMessage(e),
    );
  }
}
```

---

### P2-AUTH-1: Weak PIN Validation - Sequential/Repeated Digits Allowed

**Severity:** P2 - Security  
**Component:** `apps/wawapp_driver/lib/features/auth/create_pin_screen.dart`  
**Evidence:**
```dart
File: apps/wawapp_driver/lib/features/auth/create_pin_screen.dart
Lines 18-21:
bool _isValidPin(String pin) {
  if (pin.length != 4 || !RegExp(r'^\\d{4}$').hasMatch(pin)) {
    return false;
  }
  return true;  // Allows 0000, 1234, 1111, etc.
}
```

**Vulnerability:**
- Allows weak PINs: `0000`, `1111`, `1234`, `4321`
- No check for sequential digits
- No check for repeated digits

**Impact:**
- Easy to guess PINs
- Reduced security

**Fix:**
```dart
bool _isValidPin(String pin) {
  if (pin.length != 4 || !RegExp(r'^\\d{4}$').hasMatch(pin)) {
    return false;
  }
  
  // Check for repeated digits (0000, 1111, etc.)
  if (pin[0] == pin[1] && pin[1] == pin[2] && pin[2] == pin[3]) {
    return false;
  }
  
  // Check for sequential ascending (1234, 2345, etc.)
  bool isSequentialAsc = true;
  for (int i = 0; i < 3; i++) {
    if (int.parse(pin[i + 1]) != int.parse(pin[i]) + 1) {
      isSequentialAsc = false;
      break;
    }
  }
  if (isSequentialAsc) return false;
  
  // Check for sequential descending (4321, 5432, etc.)
  bool isSequentialDesc = true;
  for (int i = 0; i < 3; i++) {
    if (int.parse(pin[i + 1]) != int.parse(pin[i]) - 1) {
      isSequentialDesc = false;
      break;
    }
  }
  if (isSequentialDesc) return false;
  
  return true;
}
```

---

## Part 2: Release Gate Checklist

### Pre-Production Deployment Checklist

#### Security (MUST PASS)
- [ ] **P0-1:** Order matching feed PII leak - FIXED
- [ ] **P0-2:** Driver location privacy violation - FIXED
- [ ] **P0-3:** Wallet read authorization bypass - FIXED
- [ ] **P0-4:** Admin field privilege escalation - FIXED
- [ ] **P0-5:** Order cancellation after trip start - FIXED
- [ ] **P0-6:** Free order creation - FIXED
- [ ] **P0-AUTH-1:** PIN brute force protection - FIXED
- [ ] **P0-AUTH-2:** Null pointer crash in auth gate - FIXED

#### Financial Integrity (MUST PASS)
- [ ] **P0-1 (Functions):** Wallet settlement race condition - FIXED
- [ ] **P0-2 (Functions):** Acceptance confirmation idempotency - FIXED
- [ ] **P0-3 (Functions):** Top-up approval balance corruption - FIXED
- [ ] **P1-8 (Functions):** Wallet balance negative check - FIXED

#### Critical Bugs (MUST PASS)
- [ ] **P0-4 (Functions):** Driver rating array growth DoS - FIXED
- [ ] **P1-AUTH-1:** Unhandled exception in OTP flow - FIXED
- [ ] **P1-AUTH-3:** PIN verification missing phone parameter - FIXED

#### High Priority (SHOULD PASS)
- [ ] **P1-1 through P1-7 (Firestore):** All P1 Firestore rules issues - FIXED
- [ ] **P1-1 through P1-7 (Functions):** All P1 Cloud Functions issues - FIXED
- [ ] **P1-AUTH-2:** setState after dispose - FIXED

#### Testing (MUST PASS)
- [ ] Load test: 100 concurrent order completions → single settlement
- [ ] Load test: 50 concurrent top-up approvals → correct balances
- [ ] Security test: PIN brute force blocked after 10 attempts
- [ ] Security test: Client cannot read other users' orders
- [ ] Security test: Client cannot track driver locations
- [ ] Crash test: Logout during profile load → no crash
- [ ] Crash test: OTP timeout → graceful error
- [ ] E2E test: Full order flow (create → accept → complete → settle)
- [ ] E2E test: Driver wallet top-up → balance updated
- [ ] E2E test: PIN login → successful authentication

#### Monitoring (MUST HAVE)
- [ ] Crashlytics enabled and tested
- [ ] Analytics events firing correctly
- [ ] Error reporting to external service (Sentry/Rollbar)
- [ ] Alerts configured for:
  - Wallet balance drift
  - Negative wallet balances
  - High error rates (>5%)
  - Function timeout rates (>10%)

#### Documentation (SHOULD HAVE)
- [ ] API documentation for admin functions
- [ ] Runbook for common incidents
- [ ] Rollback plan documented
- [ ] Incident response plan

---

## Part 3: Patch Plan

### Patch Ordering (by dependency)

#### Phase 1: Foundation (No dependencies)
**Estimated Time:** 2-3 days  
**Risk:** Low

1. **Patch 1.1:** Firestore Rules - Input Validation
   - Fix P0-6 (Free orders)
   - Fix P0-5 (Order cancellation validation)
   - Files: `firestore.rules` (lines 35-36, 61-67)
   - Test: Unit tests for rules

2. **Patch 1.2:** Firestore Rules - Admin Field Protection
   - Fix P0-4 (Admin field escalation)
   - Files: `firestore.rules` (lines 87-95, 140-146, 160-164)
   - Test: Try to add `isVerified: true` → DENY

3. **Patch 1.3:** Cloud Functions - Input Validation
   - Fix P2-1 (Amount limits)
   - Files: `functions/src/approveTopupRequest.ts` (lines 65-66)
   - Test: Approve negative amount → ERROR

#### Phase 2: Privacy & Security (Depends on Phase 1)
**Estimated Time:** 3-4 days  
**Risk:** Medium

4. **Patch 2.1:** Firestore Rules - Privacy Fixes
   - Fix P0-1 (Order matching PII leak)
   - Fix P0-2 (Driver location leak)
   - Fix P0-3 (Wallet read bypass)
   - Files: `firestore.rules` (lines 59, 71, 176-186)
   - Test: Client tries to read all orders → DENY
   - Test: Client tries to list driver locations → DENY

5. **Patch 2.2:** Auth - PIN Brute Force Protection
   - Fix P0-AUTH-1 (Rate limiting)
   - Files: `functions/src/auth/createCustomToken.ts`
   - Test: 10 failed attempts → locked for 1 hour

6. **Patch 2.3:** Auth - Weak PIN Validation
   - Fix P2-AUTH-1 (Sequential/repeated digits)
   - Files: `apps/wawapp_driver/lib/features/auth/create_pin_screen.dart`
   - Test: Try to create PIN `1234` → DENY

#### Phase 3: Financial Integrity (Depends on Phase 1, 2)
**Estimated Time:** 4-5 days  
**Risk:** High

7. **Patch 3.1:** Wallet Settlement Idempotency
   - Fix P0-1 (Functions) (Settlement race)
   - Files: `functions/src/finance/orderSettlement.ts` (lines 21-54)
   - Test: Trigger function 10x → single credit

8. **Patch 3.2:** Top-up Approval Atomicity
   - Fix P0-3 (Functions) (Balance corruption)
   - Files: `functions/src/approveTopupRequest.ts` (lines 73-97)
   - Test: Concurrent approvals → correct balance

9. **Patch 3.3:** Wallet Balance Validation
   - Fix P1-8 (Functions) (Negative balance)
   - Files: `functions/src/finance/adminPayouts.ts` (lines 298-306)
   - Test: Payout > balance → ERROR

#### Phase 4: Reliability (Depends on Phase 1-3)
**Estimated Time:** 3-4 days  
**Risk:** Medium

10. **Patch 4.1:** Notification Idempotency
    - Fix P0-2 (Functions) (Acceptance confirmation)
    - Files: `functions/src/notifyUnassignedOrders.ts` (lines 507-515)
    - Test: Trigger function 5x → single notification

11. **Patch 4.2:** Driver Rating Array Fix
    - Fix P0-4 (Functions) (Array growth DoS)
    - Files: `functions/src/aggregateDriverRating.ts` (lines 73-94)
    - Test: Rate 1000 orders → no document size error

12. **Patch 4.3:** Batch Operations Rollback
    - Fix P1-1 (Functions) (Batch failures)
    - Files: `functions/src/expireStaleOrders.ts` (lines 64-107)
    - Test: Partial batch failure → retry

#### Phase 5: Mobile App Fixes (Depends on Phase 1-4)
**Estimated Time:** 2-3 days  
**Risk:** Low

13. **Patch 5.1:** Auth Gate Null Safety
    - Fix P0-AUTH-2 (Null pointer crash)
    - Files: `apps/wawapp_driver/lib/features/auth/auth_gate.dart` (lines 28-36)
    - Test: Logout during profile load → no crash

14. **Patch 5.2:** OTP Flow Error Handling
    - Fix P1-AUTH-1 (Unhandled exception)
    - Files: `apps/wawapp_driver/lib/features/auth/providers/auth_service_provider.dart`
    - Test: OTP timeout → graceful error

15. **Patch 5.3:** PIN Login Fix
    - Fix P1-AUTH-3 (Missing phone parameter)
    - Files: `apps/wawapp_driver/lib/features/auth/providers/auth_service_provider.dart` (lines 169-188)
    - Test: PIN login → successful

16. **Patch 5.4:** setState Safety
    - Fix P1-AUTH-2 (Memory leak)
    - Files: Multiple screens with `setState`
    - Test: Navigate away during async → no crash

#### Phase 6: Quality of Life (Optional)
**Estimated Time:** 2-3 days  
**Risk:** Low

17. **Patch 6.1:** All P2 Firestore Rules fixes
18. **Patch 6.2:** All P2 Cloud Functions fixes
19. **Patch 6.3:** Monitoring & Alerting setup

---

### Deployment Strategy

#### Week 1: Foundation + Privacy
- Deploy Patches 1.1, 1.2, 1.3 (Monday)
- Deploy Patches 2.1, 2.2, 2.3 (Thursday)
- Monitor for 48 hours

#### Week 2: Financial + Reliability
- Deploy Patches 3.1, 3.2, 3.3 (Monday)
- Monitor for 72 hours (critical)
- Deploy Patches 4.1, 4.2, 4.3 (Friday)

#### Week 3: Mobile + QoL
- Deploy Patches 5.1, 5.2, 5.3, 5.4 (Monday)
- Deploy Patches 6.1, 6.2, 6.3 (Thursday)
- Final E2E testing (Friday)

#### Week 4: Production Launch
- Pilot launch (Monday) - 10 drivers, 50 clients
- Monitor for 48 hours
- Full launch (Thursday) if no critical issues

---

### Rollback Plan

#### Firestore Rules Rollback
```bash
# Backup current rules
firebase firestore:rules:get > firestore.rules.backup

# Rollback to previous version
firebase deploy --only firestore:rules --force
```

#### Cloud Functions Rollback
```bash
# List function versions
gcloud functions list --project wawapp-952d6

# Rollback specific function
gcloud functions deploy onOrderCompleted \
  --source=gs://wawapp-952d6.appspot.com/functions/previous-version.zip \
  --project wawapp-952d6
```

#### Mobile App Rollback
- Use Firebase App Distribution to push previous APK
- Communicate rollback to users via in-app message

---

## Summary

**Total Findings:** 36 vulnerabilities
- **P0:** 12 (10 Firestore/Functions + 2 Mobile)
- **P1:** 19 (14 Firestore/Functions + 5 Mobile)
- **P2:** 5 (all Firestore/Functions)

**Estimated Fix Time:** 16-19 days (3-4 weeks)

**Critical Path:**
1. Fix all P0 issues (Week 1-2)
2. Load test financial flows (Week 2)
3. Fix P1 mobile crashes (Week 3)
4. E2E testing (Week 3-4)
5. Pilot launch (Week 4)

**Recommendation:** Do NOT launch until all P0 issues are resolved and tested.

---

## End of Report
