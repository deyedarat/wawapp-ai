# Navigation & State Conflicts - Comprehensive Fix Plan

## Executive Summary
This plan addresses three critical conflict points causing app freezes and permission errors during authentication flows.

---

## Conflict Point 1: Dual Navigation Control (GoRouter vs AuthGate)

### Current Problem
Two systems are competing for navigation control simultaneously:

**Client App:**
- `AppRouter` (L143-179): Uses `redirect()` to programmatically navigate to `/login` or `/otp`
- `AuthGate` (L8-42): Returns `PhonePinLoginScreen()` widget directly when `user == null`
- **Result**: When auth state changes, router tries to change URL while AuthGate tries to swap widgets internally, causing flicker and broken back button

**Driver App:**
- `AppRouter` (L21-94): NO redirect logic - relies entirely on AuthGate
- `AuthGate` (L45-195): Returns different widgets (PhonePinLoginScreen, OtpScreen, CreatePinScreen, DriverHomeScreen) based on complex state checks
- **Result**: AuthGate handles ALL navigation decisions internally via widget swapping

### Root Cause Analysis

#### Client App Issue:
```dart
// app_router.dart L143-179
String? _redirect(GoRouterState s, AuthState st) {
  final loggedIn = st.user != null;
  final canOtp = (st.otpFlowActive == true) || ...;

  if (!loggedIn && canOtp && s.matchedLocation != '/otp') {
    return '/otp';  // Router tries to navigate
  }
}

// auth_gate.dart L27-29
if (authState.user == null) {
  return const PhonePinLoginScreen();  // AuthGate swaps widget
}
```

**Conflict**: Both systems react to `authState.user == null`, creating race condition.

#### Driver App Issue:
```dart
// auth_gate.dart L96-98
if (authState.otpStage == OtpStage.codeSent) {
  return const OtpScreen();  // Widget swap
}

// But AppRouter has NO redirect logic to handle this
// AuthGate becomes a "mega-widget" with too much responsibility
```

### Proposed Solution: Unified Navigation Strategy

**Strategy A: Router-First (Recommended for Client App)**
- AuthGate becomes PASSIVE - only shows loading or blocks content
- All navigation decisions move to GoRouter redirect logic
- Benefits: Clean URL state, proper back button, declarative routing

**Strategy B: AuthGate-First (Current Driver App Pattern)**
- Remove AuthGate wrapper entirely
- Use GoRouter redirect for ALL auth flows
- Benefits: Consistent with Flutter best practices, easier to debug

**Recommended: Hybrid Approach**
1. **Client App**: Convert to Router-First
   - Remove widget returns from AuthGate
   - Move all logic to `_redirect()`
   - AuthGate only shows CircularProgressIndicator or wraps child

2. **Driver App**: Keep AuthGate-First but simplify
   - Add `redirect()` to router for OTP flow edge cases
   - Reduce AuthGate complexity by extracting PIN check to separate provider

---

## Conflict Point 2: Firestore Stream Permission Errors

### Current Problem

**Client App (client_profile_providers.dart L15-46):**
```dart
final clientProfileStreamProvider = StreamProvider.autoDispose<ClientProfile?>((ref) {
  final authState = ref.watch(authProvider);

  // Line 20-22: Transition check exists but incomplete
  final isTransitioning = authState.otpFlowActive ||
                         authState.isPinResetFlow ||
                         authState.otpStage == OtpStage.sending;

  if (authState.user == null || isTransitioning) {
    return Stream.value(null);  // Good: stops stream during transitions
  }

  return repository.watchProfile(authState.user!.uid);
});
```

**Driver App (auth_gate.dart L18-43):**
```dart
final driverProfileProvider = StreamProvider.autoDispose<DocumentSnapshot<...>?>((ref) {
  final authState = ref.watch(authProvider);

  // Line 30-32: Has isPinResetFlow check
  if (authState.isPinResetFlow) {
    return Stream.value(null);
  }

  if (user == null) {
    return Stream.value(null);
  }

  return FirebaseFirestore.instance.collection('drivers').doc(uid).snapshots();
});
```

### Race Condition Timeline
```
T0: User clicks "Change Phone"
T1: sendOtp() sets otpFlowActive=true, otpStage=sending
T2: Stream provider still active (hasn't seen state change yet)
T3: Stream tries to read Firestore with current user.uid
T4: Auth state changes, user becomes null
T5: Firestore security rules reject request (user not authenticated)
T6: Error appears: "permission-denied"
T7: Stream provider finally sees state change and stops
```

**Gap**: 100-300ms window between T1→T7 where stream is still active but auth is transitioning.

### Proposed Solution: Stream Lifecycle Guards

**Phase 1: Immediate Protection (Client App)**
```dart
final clientProfileStreamProvider = StreamProvider.autoDispose<ClientProfile?>((ref) {
  final authState = ref.watch(authProvider);

  // EXPANDED transition detection
  final isTransitioning =
    authState.otpFlowActive ||
    authState.isPinResetFlow ||
    authState.otpStage == OtpStage.sending ||
    authState.otpStage == OtpStage.codeSent ||
    authState.otpStage == OtpStage.verifying ||
    authState.isLoading;  // ADD: General loading state

  if (authState.user == null || isTransitioning) {
    return Stream.value(null);
  }

  // ADD: Defensive UID capture
  final uid = authState.user!.uid;

  // ADD: Stream with error handling
  return repository.watchProfile(uid).handleError((error) {
    if (kDebugMode) {
      print('[ClientProfile] Stream error during transition: $error');
    }
    return null;  // Gracefully return null instead of throwing
  });
});
```

**Phase 2: Coordinated Shutdown (Both Apps)**

Add new flag to `AuthState`:
```dart
class AuthState {
  // ... existing fields
  final bool isStreamsSafeToRun;  // NEW

  const AuthState({
    // ... existing params
    this.isStreamsSafeToRun = true,  // Default: safe
  });
}
```

Update `AuthNotifier.sendOtp()`:
```dart
Future<void> sendOtp(String phone) async {
  // BEFORE starting OTP flow
  state = state.copyWith(
    isStreamsSafeToRun: false,  // Signal streams to stop FIRST
    isLoading: true,
    error: null,
    otpStage: OtpStage.sending,
  );

  // Give streams 100ms to cleanly shut down
  await Future.delayed(const Duration(milliseconds: 100));

  // NOW proceed with OTP
  await _authService.ensurePhoneSession(phone);

  state = state.copyWith(
    isLoading: false,
    phoneE164: phone,
    otpStage: OtpStage.codeSent,
    otpFlowActive: true,
  );
}
```

Update stream providers:
```dart
final clientProfileStreamProvider = StreamProvider.autoDispose<ClientProfile?>((ref) {
  final authState = ref.watch(authProvider);

  // SIMPLE check - trust the flag
  if (!authState.isStreamsSafeToRun || authState.user == null) {
    return Stream.value(null);
  }

  return repository.watchProfile(authState.user!.uid);
});
```

---

## Conflict Point 3: Loading State Deadlock

### Current Problem

**Client App (auth_gate.dart L21-24):**
```dart
if ((authState.user == null && authState.isLoading) || authState.isPinCheckLoading) {
  return const Scaffold(body: Center(child: CircularProgressIndicator()));
}
```

**Deadlock Scenario:**
```
1. User is logged in: user != null
2. User starts profile update: isLoading = true
3. Auth check: (null && true) = false, isPinCheckLoading = false
4. Condition FAILS → passes through to child
5. Child expects complete data but update is still loading
6. Result: Partial data shown or error thrown
```

**Driver App (auth_gate.dart L87-92):**
```dart
if (authState.isLoading || authState.isPinCheckLoading) {
  return const Scaffold(body: Center(child: CircularProgressIndicator()));
}
```

**Better**, but still has edge case:
- Doesn't distinguish between "initial load" vs "profile update in background"
- Shows full-screen spinner even for minor updates

### Root Cause
`isLoading` flag is overloaded:
- Initial auth check
- OTP flow
- PIN verification
- Profile updates
- Sign out process

**No way to distinguish** which operation is loading.

### Proposed Solution: Granular Loading States

**Option A: Separate Loading Flags (Simple)**
```dart
class AuthState {
  final bool isInitializing;      // First-time auth check
  final bool isAuthenticating;    // Login/OTP flow
  final bool isPinCheckLoading;   // Existing
  final bool isPinResetFlow;      // Existing

  // Computed helper
  bool get shouldShowLoadingScreen => isInitializing || isAuthenticating;
  bool get shouldBlockInteraction => isPinCheckLoading || isPinResetFlow;
}
```

Update AuthGate:
```dart
// Client
if (authState.shouldShowLoadingScreen) {
  return const Scaffold(body: Center(child: CircularProgressIndicator()));
}

if (authState.user == null) {
  return const PhonePinLoginScreen();
}

// Only show loading if we're checking for first-time PIN setup
if (authState.isPinCheckLoading && !authState.hasPin) {
  return const Scaffold(body: Center(child: CircularProgressIndicator()));
}

if (!authState.hasPin) {
  return const CreatePinScreen();
}

return child;
```

**Option B: Loading Context Enum (Advanced)**
```dart
enum AuthLoadingContext {
  none,
  initializing,
  sendingOtp,
  verifyingOtp,
  checkingPin,
  resettingPin,
  signingOut,
}

class AuthState {
  final AuthLoadingContext loadingContext;

  bool get isLoading => loadingContext != AuthLoadingContext.none;
  bool get shouldShowFullscreenLoader =>
    loadingContext == AuthLoadingContext.initializing ||
    loadingContext == AuthLoadingContext.checkingPin;
}
```

---

## Implementation Plan

### Phase 1: Quick Wins (Low Risk, High Impact)
**Priority: URGENT**

1. **Add `isStreamsSafeToRun` flag to AuthState**
   - Files: `packages/auth_shared/lib/src/auth_state.dart`
   - Risk: LOW - new flag, existing logic unchanged
   - Impact: HIGH - prevents race conditions

2. **Update stream providers with safety check**
   - Files:
     - `apps/wawapp_client/lib/features/profile/providers/client_profile_providers.dart`
     - `apps/wawapp_driver/lib/features/profile/providers/driver_profile_providers.dart`
     - `apps/wawapp_driver/lib/features/auth/auth_gate.dart` (driverProfileProvider)
   - Risk: LOW - early return is safe
   - Impact: HIGH - fixes permission errors

3. **Add 100ms delay in sendOtp() before auth operations**
   - Files: `packages/auth_shared/lib/src/auth_notifier.dart`
   - Risk: MEDIUM - adds latency but prevents errors
   - Impact: HIGH - allows streams to cleanly shut down

### Phase 2: Client App Navigation Fix
**Priority: HIGH**

1. **Remove widget returns from Client AuthGate**
   - File: `apps/wawapp_client/lib/features/auth/auth_gate.dart`
   - Change: Only return loading screen or child
   - Risk: MEDIUM - changes navigation flow

2. **Expand Client Router redirect logic**
   - File: `apps/wawapp_client/lib/core/router/app_router.dart`
   - Add routes for all auth states
   - Risk: MEDIUM - complex redirect logic

3. **Test Client App auth flows**
   - New user registration
   - Existing user login
   - PIN reset flow
   - Profile edit during active session

### Phase 3: Driver App Simplification
**Priority: MEDIUM**

1. **Add minimal redirect logic to Driver Router**
   - File: `apps/wawapp_driver/lib/core/router/app_router.dart`
   - Only handle OTP edge cases
   - Risk: LOW - defensive addition

2. **Simplify Driver AuthGate**
   - File: `apps/wawapp_driver/lib/features/auth/auth_gate.dart`
   - Extract PIN check to separate provider
   - Reduce nested conditions
   - Risk: MEDIUM - refactoring existing logic

### Phase 4: Loading State Refinement
**Priority: LOW (Can wait for Phase 1-3 to stabilize)**

1. **Implement Option A: Separate Loading Flags**
   - Files:
     - `packages/auth_shared/lib/src/auth_state.dart`
     - `packages/auth_shared/lib/src/auth_notifier.dart`
   - Risk: MEDIUM - changes state structure

2. **Update AuthGate implementations**
   - Both apps
   - Use granular flags
   - Risk: LOW - clearer logic

---

## Testing Strategy

### Unit Tests (TODO: Create)
```dart
// Test stream safety flag
test('stream providers stop when isStreamsSafeToRun = false', () {
  // Setup authProvider with isStreamsSafeToRun = false
  // Verify stream returns null immediately
});

// Test navigation transitions
test('router redirects to /otp when otpStage = codeSent', () {
  // Setup authState with otpStage = codeSent
  // Verify _redirect() returns '/otp'
});

// Test loading states
test('AuthGate shows loading only during initialization', () {
  // Setup authState with isInitializing = true
  // Verify CircularProgressIndicator shown

  // Change to isAuthenticating = true, user != null
  // Verify child shown (no loading screen)
});
```

### Integration Tests
1. **Client App:**
   - Register new user → verify no permission errors
   - Change phone number → verify smooth OTP flow
   - Edit profile while logged in → verify no flicker

2. **Driver App:**
   - Register new driver → verify PIN creation
   - Reset PIN → verify no Firestore errors
   - View profile during active order → verify stable UI

### Manual Test Scenarios
```
[CRITICAL] Phone Number Change Flow:
1. Login as existing user
2. Go to profile
3. Click "Change Phone"
4. Enter new number
5. Send OTP
6. OBSERVE: No "permission-denied" errors
7. OBSERVE: No UI flicker
8. Enter OTP code
9. OBSERVE: Smooth transition to login screen
10. Login with new number + PIN
11. VERIFY: All data intact

[CRITICAL] Profile Edit Flow:
1. Login as user
2. Navigate to Profile Screen
3. Start editing name/email
4. OBSERVE: No loading spinner appears
5. Save changes
6. OBSERVE: Only subtle loading indicator (not full screen)
7. VERIFY: Changes saved, UI stable

[CRITICAL] New User Registration:
1. Enter new phone number
2. Send OTP
3. OBSERVE: Redirects to /otp route
4. OBSERVE: Back button works correctly
5. Enter code
6. OBSERVE: Redirects to /create-pin
7. Create PIN
8. OBSERVE: Redirects to home
9. VERIFY: No navigation loops
```

---

## Rollback Plan

If Phase 2 or 3 causes regressions:

1. **Immediate Rollback:**
   ```bash
   git revert <commit-hash>
   git push
   ```

2. **Keep Phase 1 fixes:**
   - Stream safety flags are defensive and low-risk
   - Can keep even if navigation changes are reverted

3. **Gradual Rollout:**
   - Deploy to Test Lab first
   - Monitor Firebase Crashlytics for auth errors
   - Deploy to production only after 24h of clean logs

---

## Success Metrics

### Before Fix (Baseline)
- Permission errors during phone change: ~30% of attempts
- UI flicker on profile edit: Visible in 100% of cases
- Back button broken after OTP: 50% of cases

### After Fix (Target)
- Permission errors: 0%
- UI flicker: 0%
- Back button: Works 100% of time
- Navigation loop bugs: 0

### Monitoring
- Firebase Crashlytics: Filter for "permission-denied" errors
- Analytics: Track auth flow completion rates
- User feedback: Monitor support tickets for auth issues

---

## Files to Change

### Phase 1 (Immediate)
- [ ] `packages/auth_shared/lib/src/auth_state.dart` - Add `isStreamsSafeToRun`
- [ ] `packages/auth_shared/lib/src/auth_notifier.dart` - Update `sendOtp()` with delay
- [ ] `apps/wawapp_client/lib/features/profile/providers/client_profile_providers.dart` - Add safety check
- [ ] `apps/wawapp_driver/lib/features/profile/providers/driver_profile_providers.dart` - Add safety check
- [ ] `apps/wawapp_driver/lib/features/auth/auth_gate.dart` - Update `driverProfileProvider`

### Phase 2 (Client Navigation)
- [ ] `apps/wawapp_client/lib/features/auth/auth_gate.dart` - Simplify to passive guard
- [ ] `apps/wawapp_client/lib/core/router/app_router.dart` - Expand `_redirect()` logic

### Phase 3 (Driver Simplification)
- [ ] `apps/wawapp_driver/lib/core/router/app_router.dart` - Add minimal redirect
- [ ] `apps/wawapp_driver/lib/features/auth/auth_gate.dart` - Simplify conditions

### Phase 4 (Loading States)
- [ ] `packages/auth_shared/lib/src/auth_state.dart` - Add granular flags
- [ ] `packages/auth_shared/lib/src/auth_notifier.dart` - Use new flags
- [ ] Both AuthGate files - Update loading conditions

---

## Timeline Estimate

- **Phase 1**: 2-3 hours (implement + test)
- **Phase 2**: 4-6 hours (implement + extensive testing)
- **Phase 3**: 3-4 hours (refactoring + testing)
- **Phase 4**: 3-4 hours (state redesign + testing)

**Total**: 12-17 hours of development + testing

---

## Open Questions

1. **Should we keep AuthGate at all in Client App?**
   - Alternative: Remove entirely, use only GoRouter guards
   - Pro: Simpler architecture
   - Con: Requires rewriting all protected routes

2. **Should loading states be visual or behavioral?**
   - Visual: Show/hide loading indicator
   - Behavioral: Block/allow user interaction
   - Current: Mixed approach causing confusion

3. **Do we need a "transition lock" mechanism?**
   - Prevent multiple auth operations from running concurrently
   - Example: Can't start OTP while PIN check is running
   - Risk: Adds complexity

---

## Conclusion

The three conflict points are interconnected:

1. **Navigation conflicts** create UI flicker and confusion
2. **Stream permission errors** happen during navigation transitions
3. **Loading state deadlocks** prevent proper transition handling

**Fix order matters**: Phase 1 (streams) must come before Phase 2 (navigation), because navigation changes will trigger more state transitions that need protected streams.

**Recommended approach**: Implement Phase 1 immediately as it's low-risk and solves the most visible user-facing errors. Then evaluate whether to proceed with full navigation refactor (Phase 2-3) or live with current UX.
