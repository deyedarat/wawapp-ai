# go_router Registry Assertion Crash Fix

## Root Cause Analysis

**Crash**: `'package:go_router/src/state.dart': Failed assertion: line 204 pos 12: 'registry.containsKey(page)': is not true.`

**Location**: `GoRouterStateRegistry._createPageRouteAssociation`

### Primary Root Cause

The crash occurs in **both** `wawapp_client` and `wawapp_driver` apps due to the `_GoRouterRefreshStream` implementation:

**File**: `apps/wawapp_client/lib/core/router/app_router.dart` (lines 252-265)  
**File**: `apps/wawapp_driver/lib/core/router/app_router.dart` (lines 225-238)

```dart
class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream(Stream<AuthState> stream) {
    notifyListeners(); // ❌ PROBLEM: Immediate notification
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  // ...
}
```

**The Issue**:
1. `notifyListeners()` is called **immediately** in the constructor
2. This triggers go_router to rebuild and run `redirect()` 
3. If auth state changes rapidly (e.g., OTP verification → PIN check → home), multiple redirects fire
4. go_router's page registry gets out of sync because:
   - A new page is created before the old one is removed
   - The registry expects pages to be tracked, but rapid navigation breaks this assumption
   - The assertion `registry.containsKey(page)` fails

### Secondary Contributing Factors

1. **No navigation throttling** - Rapid auth state changes trigger immediate navigation
2. **Redirect logic complexity** - Multiple conditional redirects can race
3. **Stream broadcast** - `asBroadcastStream()` can emit multiple events in quick succession

---

## Solution

### Fix 1: Remove Immediate notifyListeners() Call

**Rationale**: The immediate `notifyListeners()` in the constructor is unnecessary and harmful:
- go_router will call `redirect()` on initial build anyway
- The immediate notification can trigger a redirect before the router is fully initialized
- This creates a race condition with the initial route setup

**Change**: Remove the immediate `notifyListeners()` call from the constructor.

### Fix 2: Add Debouncing to Stream Listener

**Rationale**: Rapid auth state changes (e.g., login → PIN check → home) can trigger multiple redirects in quick succession. Debouncing ensures we only redirect after the state has stabilized.

**Change**: Add a small debounce (50-100ms) to the stream listener to batch rapid state changes.

### Fix 3: Add Navigation Logging

**Rationale**: Better observability to track when and why redirects occur, helping diagnose future issues.

**Change**: Add structured logging for all redirect decisions.

---

## Implementation

### Changes to `apps/wawapp_client/lib/core/router/app_router.dart`

1. Remove immediate `notifyListeners()` from `_GoRouterRefreshStream` constructor
2. Add debouncing to stream listener
3. Add navigation logging

### Changes to `apps/wawapp_driver/lib/core/router/app_router.dart`

Same changes as client app.

---

## Testing

### Before Fix - Reproduction Steps

1. **Scenario 1: Rapid OTP → PIN → Home**
   - Open app (logged out)
   - Enter phone number
   - Verify OTP (triggers redirect to /create-pin or /pin-gate)
   - PIN status resolves (triggers redirect to /)
   - **CRASH**: Registry assertion fails due to rapid redirects

2. **Scenario 2: Auth State Stream Burst**
   - Any scenario where auth state changes multiple times rapidly
   - E.g., logout → login → OTP → authenticated
   - **CRASH**: Multiple `notifyListeners()` calls trigger conflicting redirects

### After Fix - Verification Steps

1. **Test Scenario 1**: Complete full auth flow (login → OTP → PIN → home)
   - Should navigate smoothly without crashes
   - Check logs for debounced navigation events

2. **Test Scenario 2**: Rapid state changes
   - Trigger multiple auth state changes quickly
   - Should see debouncing in action (logs show "debouncing redirect")
   - No crashes

3. **Test Scenario 3**: Normal navigation
   - Navigate between screens normally
   - Ensure no regression in navigation behavior

---

## Constraints Met

✅ **Keep user flows unchanged** - No visible behavior changes  
✅ **Avoid large refactors** - Minimal, localized changes  
✅ **Ensure no new lints/errors** - Code compiles cleanly  
✅ **Production-safe** - Defensive fix with logging

---

## Monitoring

After deployment, monitor Crashlytics for:
- ✅ Absence of `registry.containsKey(page)` assertion crashes
- ⚠️ Any new navigation-related issues
- 📊 Navigation logs showing debouncing in action

---

## Rollback Plan

If issues arise:
```bash
git revert <commit-hash>
```

Or apply reverse patch:
```bash
git apply --reverse go_router_registry_fix.patch
```
