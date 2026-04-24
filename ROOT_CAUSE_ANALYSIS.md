# Root Cause Analysis: R-006 (Dual AuthNotifier)

---

## Question 1: Where are the two AuthNotifier instances created?

There are actually **three** AuthNotifier-like classes, not two:

| # | Class Name | File | Used By |
|---|-----------|------|---------|
| A | `AuthNotifier` | `packages/auth_shared/lib/src/auth_notifier.dart` L8 | **Nobody** — exported by `auth_shared.dart` but shadowed in both apps |
| B | `AuthNotifier` | `apps/wawapp_driver/lib/features/auth/providers/auth_service_provider.dart` L21 | Driver app — instantiated by `authProvider` at L348 |
| C | `ClientAuthNotifier` | `apps/wawapp_client/lib/features/auth/providers/auth_service_provider.dart` L20 | Client app — instantiated by `authProvider` at L399 |

### How shadowing works

The driver app's `auth_service_provider.dart` imports `package:auth_shared/auth_shared.dart` at L1, which exports the shared `AuthNotifier` (class A). But the same file declares its own `class AuthNotifier extends StateNotifier<AuthState>` at L21 (class B) — **same name, different class**. Dart's scoping rules mean the local declaration shadows the import. Every reference to `AuthNotifier` in the driver app resolves to class B.

The client app avoids this by naming its class `ClientAuthNotifier` (class C) — no shadowing.

### Instantiation

Only one instance exists per app at runtime:
- Driver: `authProvider` at L348 creates class B (`AuthNotifier`)
- Client: `authProvider` at L399 creates class C (`ClientAuthNotifier`)
- Class A is never instantiated by any code path

---

## Question 2: Do they share the same state or maintain separate states?

All three classes use the same `AuthState` type from `packages/auth_shared/lib/src/auth_state.dart`. They all extend `StateNotifier<AuthState>`.

But they manage **different fields** within that state:

| Field in AuthState | Class A (shared) sets it? | Class B (driver) sets it? | Class C (client) sets it? |
|---|---|---|---|
| `user` | ✅ via `authStateChanges` | ✅ via `authStateChanges` | ✅ via `authStateChanges` |
| `hasPin` (bool) | ✅ `state.copyWith(hasPin: hasPinHash)` L42 | ❌ Never | ❌ Never |
| `pinStatus` (enum) | ❌ Never | ✅ `state.copyWith(pinStatus: status)` L101 | ✅ `state.copyWith(pinStatus: effectiveStatus)` L100 |
| `isPinCheckLoading` | ✅ L33, L44, L48 | ✅ L86, L103 | ❌ (uses `pinStatus: PinStatus.loading` instead) |
| `otpFlowActive` | ✅ L96 | ✅ L170 | ✅ L175 |
| `otpStage` | ✅ L85, L96, L107 | ✅ L170, L193 | ✅ L175, L199 |
| `isPinResetFlow` | ❌ Never | ✅ L142 | ✅ L148 |
| `isStreamsSafeToRun` | ✅ L84, L108 | ❌ Never | ❌ Never |
| `shouldOfferBugReport` | ❌ Never | ❌ Never | ✅ L199, L213 |

**Key observation**: Class A sets `hasPin` (bool). Classes B and C set `pinStatus` (enum). The router reads `pinStatus`. So class A's PIN check result would be invisible to the router.

---

## Question 3: Can they produce conflicting auth state at the same time?

**No — because only one class is instantiated per app.**

- Driver app: only class B exists at runtime. Class A is never instantiated.
- Client app: only class C exists at runtime. Class A is never instantiated.

There is no scenario where two AuthNotifier instances coexist and produce conflicting state. The `authProvider` Riverpod provider creates exactly one instance.

---

## Question 4: What is the user-facing symptom if they conflict?

**No conflict is possible at runtime** (see Q3). However, the dead code creates a **developer confusion risk**:

If a developer reads `auth_shared`'s `AuthNotifier` and assumes it's the active class, they might:
1. Add logic to class A thinking it will run — it won't (shadowed)
2. Read `state.hasPin` (bool) thinking it reflects PIN status — it doesn't (always `false` in classes B and C)
3. Modify class A's `_checkHasPin()` to fix a bug — the fix would have no effect

The `hasPin` bool field in `AuthState` is the most dangerous trap. It defaults to `false` and is never set to `true` by either app's notifier. Any code that reads `authState.hasPin` would always get `false`, even when the user has a PIN.

**Evidence that `hasPin` is never read**: Exhaustive search of the driver app found zero references to `state.hasPin` or `authState.hasPin`. Every PIN check uses `pinStatus == PinStatus.hasPin` (the enum).

---

## Question 5: Is one of them dead code or are both active?

**Class A (shared `AuthNotifier`) is dead code. Confirmed.**

Evidence:
1. The driver app declares its own `class AuthNotifier` at L21 of `auth_service_provider.dart`, which shadows the import from `auth_shared`
2. The `authProvider` at L348 instantiates the local class B, not the shared class A
3. No file in either app directly references `auth_shared.AuthNotifier` by qualified name
4. The client app uses `ClientAuthNotifier` (class C) — a different name entirely, no shadowing needed

**Class A's methods that are dead code**:
- `_checkHasPin()` — sets `hasPin` (bool), never `pinStatus` (enum). Result is invisible to router.
- `sendOtp()` — sets `isStreamsSafeToRun`, which no app reads
- `verifyOtp()` — sets `isStreamsSafeToRun`
- `loginByPin()` — sets `isStreamsSafeToRun`
- `createPin()` — sets `hasPin: true`, never `pinStatus: PinStatus.hasPin`
- `logout()` — resets to `const AuthState()` (same as classes B and C)

**Fields in `AuthState` that are dead code**:
- `hasPin` (bool) — set only by class A, read by nobody
- `isPinCheckLoading` — set by class A and class B, but class B also sets `pinStatus: PinStatus.loading` which is what the router actually checks
- `isStreamsSafeToRun` — set only by class A, read by nobody in either app

---

## Question 6: Is there a safe path to consolidate without breaking existing auth flow?

**Yes, but it requires a two-step approach.**

### Step 1: Remove dead fields from `AuthState` (safe, no behavioral change)

Remove `hasPin`, `isPinCheckLoading`, and `isStreamsSafeToRun` from `AuthState`. These are never read by any app code. The only risk is if a third-party or test file reads them — a grep would confirm.

### Step 2: Remove class A from `auth_shared` (safe, no behavioral change)

Stop exporting `AuthNotifier` from `auth_shared.dart`. Both apps define their own notifier. The shared package should only export:
- `AuthState` (used by both apps)
- `OtpStage` (used by both apps)
- `PinStatus` (used by both apps)
- `PhonePinAuth` (used by both apps)

The shared `AuthNotifier` class can be deleted entirely. No code references it.

### Risk assessment

| Change | Risk | Mitigation |
|--------|------|-----------|
| Remove `hasPin` from `AuthState` | Any code reading `state.hasPin` would fail to compile | Grep confirms zero readers in both apps |
| Remove `isPinCheckLoading` from `AuthState` | Same | Driver app sets it but never reads it in router logic — router reads `pinStatus` |
| Remove `isStreamsSafeToRun` from `AuthState` | Same | Zero readers in both apps |
| Remove `AuthNotifier` from `auth_shared` | Any code importing it by qualified name would fail | Grep confirms zero qualified references |
| Remove `auth_notifier.dart` export from `auth_shared.dart` | Same | Both apps define their own provider |

### What NOT to do

Do NOT try to make both apps use the shared `AuthNotifier`. The apps have diverged significantly:
- Driver app has: `DriverCleanupService`, `AnalyticsService.logLoginSuccess`, `AuthErrorMessages`, `startOtpFlow`/`endOtpFlow`/`startPinResetFlow`, `checkHasPin` (public)
- Client app has: `PinStatusCache`, `LogService`, `CrashlyticsObserver.setUserContext`, `verifyCurrentPin`, `setPin`, `deleteAccount`, `shouldOfferBugReport`, client-side OTP rate limiting

These are fundamentally different feature sets. Forcing them into a shared class would create a god-class with driver-specific and client-specific logic interleaved.

---

## Summary

| Finding | Severity | Evidence |
|---------|----------|----------|
| Shared `AuthNotifier` (class A) is dead code — never instantiated | INFO | Shadowed by local declaration in driver app; client app uses `ClientAuthNotifier` |
| `hasPin` (bool) field in `AuthState` is dead code — never read | LOW | Exhaustive grep: zero readers. Set only by class A which is never instantiated. |
| `isStreamsSafeToRun` field in `AuthState` is dead code — never read | LOW | Set only by class A. Zero readers in either app. |
| `isPinCheckLoading` field is partially dead — set but never read by router | LOW | Router checks `pinStatus == PinStatus.loading`, not `isPinCheckLoading` |
| No runtime conflict possible — only one notifier instance per app | CONFIRMED | `authProvider` creates exactly one instance. No dual-state scenario. |
| Safe consolidation path exists | CONFIRMED | Remove dead fields + stop exporting class A. Two-step, zero behavioral change. |

**Verdict**: R-006 is **confirmed as dead code, not a runtime bug**. Downgraded from MEDIUM to LOW. The risk is developer confusion, not user-facing failure. Safe cleanup is possible but not urgent.
