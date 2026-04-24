# WawApp Risk Register

Generated from code inspection. Every claim references inspected file paths and symbols.

---

## Risk Severity Scale

| Level | Definition |
|-------|-----------|
| **CRITICAL** | Data loss, financial error, or complete feature failure in production |
| **HIGH** | Significant user-facing impact or security exposure |
| **MEDIUM** | Degraded experience, operational burden, or latent bug |
| **LOW** | Code quality, maintainability, or minor UX issue |

---

## R-001: Six Firestore onUpdate Triggers Race on `orders/{orderId}`

- **Severity**: HIGH
- **Category**: Cross-layer race condition
- **Files**:
  - `functions/src/notifyOrderEvents.ts` — onUpdate
  - `functions/src/handleDriverCancellation.ts` — onUpdate
  - `functions/src/finance/orderSettlement.ts` — onUpdate
  - `functions/src/processTripStartFee.ts` — onUpdate
  - `functions/src/enforceOrderExclusivity.ts` — onUpdate
  - `functions/src/trackOrderAcceptance.ts` — onUpdate
- **Evidence**: All six functions trigger on `orders/{orderId}` onUpdate. A single status change (e.g., `accepted→onRoute`) fires all six simultaneously. Each function has its own guard conditions, but:
  - `processTripStartFee` may revert status to `accepted` on insufficient balance, which triggers all six again
  - `handleDriverCancellation` sets status to `matching`, which triggers all six again
  - Each re-trigger creates a cascade of additional invocations
- **Impact**: Excessive Cloud Function invocations, potential Firestore contention (ABORTED transactions), increased costs. The `processTripStartFee` revert loop has a guard (`feeRevertCount >= 3` → cancel), but each revert still fires 6 triggers.
- **Single point of failure**: If any trigger throws an unhandled error, Cloud Functions retries it, potentially causing infinite loops.

---

## R-002: `OrderStatus.cancelledByDriver.toFirestore()` Returns `'cancelled'`, Not `'cancelledByDriver'`

- **Severity**: HIGH
- **Category**: Data model inconsistency (Flutter ↔ Cloud Functions)
- **Files**:
  - `packages/core_shared/lib/src/order_status.dart` line 91: `case OrderStatus.cancelledByDriver: return 'cancelled';`
  - `functions/src/handleDriverCancellation.ts` line 36: `if (after.status !== 'cancelled' && after.status !== 'cancelledByDriver') return null;`
  - `firestore.rules` line 16: `(currentStatus == "onRoute" && newStatus in ["completed", "cancelled", "cancelledByDriver"])`
- **Evidence**: When the driver app cancels an order, `OrderStatus.cancelledByDriver.createTransitionUpdate()` writes `status: 'cancelled'` to Firestore (not `'cancelledByDriver'`). The `handleDriverCancellation` Cloud Function checks for both values. But `notifyOrderEvents.getNotificationConfig` only has entries for `cancelledByClient` — there is NO config for `'cancelled'` as a toStatus. The Firestore rules allow both `'cancelled'` and `'cancelledByDriver'` but they are treated as different values.
- **Impact**: When a driver cancels from `onRoute`, the client receives NO notification because `notifyOrderEvents` has no matching config for `onRoute→cancelled`. The `handleDriverCancellation` function does send its own FCM to the client, but only for transitions from `accepted` (not `onRoute`, since `before.status === 'matching'` guard would not apply — actually this guard checks `before.status`, not `after.status`, so it would fire).
- **Deeper issue**: The dual representation (`'cancelled'` vs `'cancelledByDriver'`) creates ambiguity across the entire system. Cloud Functions, Firestore rules, and Flutter code each handle it differently.

---

## R-003: Hardcoded Sentry DSN in Client Source Code

- **Severity**: HIGH
- **Category**: Security / credential exposure
- **File**: `apps/wawapp_client/lib/main.dart` line 30
- **Evidence**: `options.dsn = 'https://7af9dad2913b46aed9be1fc7e0c40780@o4511234675834880.ingest.us.sentry.io/4511234687303680'`
- **Impact**: Violates project guardrails (`wawapp-guardrails.md`: "Never commit or include API keys"). Enables Sentry event flooding by anyone with the DSN. The DSN is in a committed file, visible in git history.

---

## R-004: `notifyOrderEvents` Has Unreachable Dead Code for Driver Expiry Notification

- **Severity**: MEDIUM
- **Category**: Missing feature / dead code
- **File**: `functions/src/notifyOrderEvents.ts` lines 62-67 and 86-91
- **Evidence**: Two identical `if (fromStatus === 'matching' && toStatus === 'expired')` blocks. The first returns `type: 'order_expired'` (client notification). The second returns `type: 'order_expired_driver'` (driver notification) but is unreachable because JavaScript returns on the first match.
- **Impact**: Drivers who received dispatch offers for an order are never notified when that order expires. Their `dispatch_offers` docs with `status: 'sent'` for the active wave are never cleaned up (see R-005). This is likely intentional (no assigned driver to notify), but the dead code suggests the intent was to notify drivers.

---

## R-005: Orphaned `dispatch_offers` When Order Expires

- **Severity**: MEDIUM
- **Category**: Data hygiene / potential stale state
- **Files**:
  - `functions/src/dispatch/engine.ts` — `processExpiredWavesForOrder` lines 296-303
  - `functions/src/expireStaleOrders.ts` — sets status to 'expired'
- **Evidence**: When `expireStaleOrders` sets an order to `expired`, the next `processExpiredWavesForOrder` call hits the guard `orderDoc.data()?.status !== 'matching'` and calls `dequeueOrder(orderId)` — which only deletes the `dispatch_queue` doc. It does NOT expire the `dispatch_offers` docs from the current active wave. Those offers remain with `status: 'sent'` in Firestore indefinitely.
- **Impact**: Data accumulation in `dispatch_offers`. Driver app's `watchMyOffers` stream filters by `status: 'sent'` — these orphaned offers would appear in the driver's offer list until their `expiresAt` passes (client-side filter in `DispatchOffer.isValid`). If the client-side filter has a bug, drivers could see stale offers.

---

## R-006: `auth_shared` AuthNotifier vs App-Level AuthNotifier Confusion

- **Severity**: MEDIUM
- **Category**: Architecture / maintainability
- **Files**:
  - `packages/auth_shared/lib/src/auth_notifier.dart` — sets `hasPin` (bool), never sets `pinStatus`
  - `packages/auth_shared/lib/src/auth_state.dart` — defines both `hasPin` and `pinStatus`
  - `apps/wawapp_driver/lib/features/auth/providers/auth_service_provider.dart` — overrides with own AuthNotifier that sets `pinStatus`, never `hasPin`
- **Evidence**: Two AuthNotifier classes with the same name exist. The shared package version manages `hasPin` (bool). Both apps override it with their own version that manages `pinStatus` (enum). The `hasPin` field in AuthState is dead code in both apps. The router only reads `pinStatus`.
- **Impact**: If a developer reads `hasPin` thinking it's authoritative, they'll get stale data. The shared package's AuthNotifier is effectively unused — it's imported but immediately overridden.

---

## R-007: Client App Router Debounce (600ms) May Delay Critical Navigation

- **Severity**: MEDIUM
- **Category**: UX / timing
- **File**: `apps/wawapp_client/lib/core/router/app_router.dart` — `_GoRouterRefreshStream` constructor
- **Evidence**: Non-critical auth state changes are debounced by 600ms before triggering router redirect. Critical OTP states (`codeSent`, `failed`) bypass the debounce. But `PinStatus` changes (e.g., `unknown→hasPin` after PIN check completes) go through the 600ms debounce.
- **Impact**: After PIN verification succeeds, there's a 600ms delay before the router redirects from `/pin-gate` to `/`. User sees a brief loading state. Not a bug, but noticeable on slow devices.

---

## R-008: `processTripStartFee` Revert Creates Trigger Cascade

- **Severity**: HIGH
- **Category**: Trigger cascade / cost
- **File**: `functions/src/processTripStartFee.ts` lines 168-185
- **Evidence**: When driver has insufficient balance, the function reverts order status from `onRoute` back to `accepted`. This Firestore update triggers all 6 onUpdate functions again. The driver may retry (tap "Start Trip" again), causing another `accepted→onRoute` transition, which triggers all 6 again, and if balance is still insufficient, reverts again. The `feeRevertCount` guard stops this after 3 cycles, but each cycle fires 6×2=12 function invocations (6 for onRoute, 6 for revert to accepted).
- **Impact**: Up to 36 Cloud Function invocations for a single insufficient-balance scenario before the circuit breaker trips. Each invocation costs money and creates Firestore contention.

---

## R-009: `acceptOrder` (v1) Still Exported and Callable

- **Severity**: MEDIUM
- **Category**: Legacy code / security surface
- **File**: `functions/src/index.ts` line 14: `export { acceptOrder } from './acceptOrder';`
- **Evidence**: Both `acceptOrder` (v1) and `acceptOrderV2` are exported. The v1 version doesn't require `offerId` and may bypass dispatch engine validation. The driver app's `OrdersService.acceptOrder()` calls the v1 function directly.
- **Impact**: If a driver uses the v1 acceptance path, the dispatch engine's offer tracking, driver state management, and metrics are bypassed. The order gets accepted but `dispatch_offers` and `driver_dispatch_state` are not updated, leaving stale state.

---

## R-010: No CI Pipeline for Cloud Functions

- **Severity**: MEDIUM
- **Category**: Deployment safety
- **Files**: `.github/workflows/` — no workflow for `functions/` directory
- **Evidence**: The four GitHub Actions workflows cover: Flutter analyze (client), Flutter analyze+test (driver), Gradle build (driver Android), Firestore rules tests. None run `tsc` compilation or tests for `functions/src/`. The `functions/package.json` has a `test` script (`jest`), but no CI workflow invokes it.
- **Impact**: TypeScript compilation errors or test failures in Cloud Functions are not caught before deployment. A broken function deploy could take down order matching, notifications, or financial settlement.

---

## R-011: FCM Token Stored in Two Places with Different Update Paths

- **Severity**: MEDIUM
- **Category**: Data consistency
- **Files**:
  - `packages/core_shared/lib/src/fcm/base_fcm_service.dart` — `saveTokenToFirestore()` writes to `drivers/{uid}.fcmToken`
  - `apps/wawapp_driver/lib/services/fcm_token_manager.dart` — also manages token persistence
- **Evidence**: `BaseFCMService.saveTokenToFirestore()` is called from `FCMService.initialize()` (via `AuthGate`). `FcmTokenManager.initialize()` is called from `main.dart`. Both write `fcmToken` to the same Firestore doc but at different times and with different error handling. If one succeeds and the other fails, the token may be stale.
- **Impact**: If the token refresh from `FcmTokenManager` writes a new token but `BaseFCMService` still holds the old cached `_currentToken`, or vice versa, FCM messages may be sent to an expired token.

---

## R-012: `notification_log` Collection Grows Unbounded

- **Severity**: LOW
- **Category**: Operational / cost
- **File**: `functions/src/notifyOrderEvents.ts` line 207 — TODO comment: "Add Firestore TTL rule to auto-delete notification_log docs after 7 days"
- **Evidence**: Every notification sent by `notifyOrderEvents` creates a doc in `notification_log` for idempotency. There is no TTL policy, no cleanup function, and no Firestore TTL configured. The collection grows by ~5-10 docs per order (one per status transition per recipient).
- **Impact**: Increasing Firestore storage costs over time. At scale (1000 orders/day), this adds ~150K docs/month with no cleanup.

---

## R-013: Driver App Has Two Notification Entry Points (Legacy `FCMService` + Active `NotificationService`)

- **Severity**: LOW
- **Category**: Dead code / confusion
- **Files**:
  - `apps/wawapp_driver/lib/services/fcm_service.dart` — `handleNotificationTap` uses `context.push()`
  - `apps/wawapp_driver/lib/services/notification_service.dart` — `_handleNotificationTapFromFCM` uses `ctx.go()`
- **Evidence**: `FCMService` extends `BaseFCMService` which has `setupNotificationHandlers` disabled (returns immediately with a debug log). `FCMService.handleNotificationTap` exists but is never called in production — all tap routing goes through `NotificationService`. However, `FCMService.initialize(context)` is still called from `AuthGate`, which registers token management.
- **Impact**: No runtime impact (dead code). But `FCMService` uses `context.push()` while `NotificationService` uses `ctx.go()` — if someone accidentally re-enables the `BaseFCMService` handlers, it would cause navigation stack corruption.

---

## R-014: Firestore Rules Allow `cancelledByDriver` from `onRoute` but `OrderStatus.canTransitionTo` Does Not

- **Severity**: MEDIUM
- **Category**: State machine inconsistency (Flutter ↔ Firestore rules)
- **Files**:
  - `firestore.rules` line 16: `(currentStatus == "onRoute" && newStatus in ["completed", "cancelled", "cancelledByDriver"])`
  - `packages/core_shared/lib/src/order_status.dart` line 148: `OrderStatus.onRoute: [OrderStatus.completed]`
- **Evidence**: Firestore rules allow `onRoute→cancelled` and `onRoute→cancelledByDriver`. But the Flutter `OrderStatus.canTransitionTo` only allows `onRoute→completed`. The `canDriverCancel` getter returns `false` for `onRoute`. So the driver app UI won't show a cancel button during `onRoute`, but a direct Firestore write (or a modified client) could cancel.
- **Impact**: The Firestore rules are more permissive than the Flutter state machine. This is arguably correct (rules are the enforcement layer, Flutter is the UX layer), but the comment in `order_status.dart` says "Once onRoute, must complete" which contradicts the rules allowing cancellation.

---

## R-015: Cloud Tasks Service Account Hardcoded in Engine

- **Severity**: LOW
- **Category**: Configuration / portability
- **File**: `functions/src/dispatch/engine.ts` — `scheduleWaveExpirationTask` function
- **Evidence**: `const serviceAccountEmail = \`firebase-adminsdk-fbsvc@${project}.iam.gserviceaccount.com\``
- **Impact**: The service account email pattern assumes the default Firebase Admin SDK service account naming convention. If the project uses a custom service account or the naming convention changes, Cloud Tasks scheduling will fail silently (the function catches and warns but doesn't retry).

---

## R-016: No Automated Rollback Plan for Cloud Functions

- **Severity**: MEDIUM
- **Category**: Deployment safety
- **Files**: `functions/ROLLBACK_PLAN.md` (exists but is a manual document)
- **Evidence**: There is no automated rollback mechanism. `firebase deploy --only functions` deploys all functions atomically. If one function has a bug, all functions are affected. The `ROLLBACK_PLAN.md` describes manual steps.
- **Impact**: A bad deploy to Cloud Functions could break order matching, notifications, and financial settlement simultaneously. Recovery requires manual intervention.

---

## Summary: Top 5 Production Risks

| Rank | Risk ID | Title | Severity |
|------|---------|-------|----------|
| 1 | R-001 | Six onUpdate triggers race on orders collection | HIGH |
| 2 | R-002 | `cancelledByDriver` writes `'cancelled'` — inconsistent across layers | HIGH |
| 3 | R-008 | `processTripStartFee` revert creates trigger cascade (up to 36 invocations) | HIGH |
| 4 | R-009 | Legacy `acceptOrder` v1 bypasses dispatch engine | MEDIUM |
| 5 | R-010 | No CI for Cloud Functions — broken deploys not caught | MEDIUM |
