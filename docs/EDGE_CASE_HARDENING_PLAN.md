# WawApp Dispatch — Edge Case Hardening Plan
## Systematic Reliability Engineering Analysis

**Date**: 2026-05-13
**Author**: Reliability Engineering Review
**Scope**: 6 critical edge cases identified from production architecture analysis

---

## Edge Case 1: Acceptance Succeeds Server-Side But Response Never Reaches Driver

### Root Cause
`acceptOrderV2` Cloud Function completes the Firestore transaction (order → accepted, offer → accepted, driver_dispatch_state → busy) but the HTTPS response is lost due to network timeout, TCP reset, or app backgrounding during the await.

### Failure Sequence
```
T0: Driver taps Accept → acceptOfferV2() called
T1: Cloud Function transaction commits successfully
T2: Network drops / app backgrounded / timeout
T3: Flutter catches timeout exception → AcceptanceLockManager.clearLock()
T4: Driver sees error snackbar "حدث خطأ، حاول مرة أخرى"
T5: _actionTaken = false, _isLoading = false → UI shows Accept/Reject again
T6: Driver taps Accept again → "offer_accepted" error (already accepted by them)
T7: _safeDismiss() fires → driver lands on /nearby
T8: Driver has NO visibility that they own an active order
T9: Client waits indefinitely. Trip start reminder fires after 3 min.
```

### Architectural Weakness
- No client-side reconciliation on app foreground/resume
- `syncActiveTripFlagOnStartup` only runs on cold start, not on resume
- The `getDriverActiveOrders` stream exists but is not consulted after acceptance failure
- `_safeDismiss()` navigates to `/nearby` instead of checking for active orders

### Proposed Fix

**Invariant Protected**: "A driver who owns an accepted order MUST be routed to the active-order screen within 10 seconds of app resume."

**Changes Required**:

1. **Flutter — Add foreground reconciliation** (`orders_service.dart`):
```dart
/// Called on AppLifecycleState.resumed and after any acceptance error.
/// Checks Firestore for orders assigned to this driver.
/// If found, navigates to /active-order and sets native trip flag.
static Future<bool> reconcileActiveOrder(BuildContext context) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return false;
  final snap = await FirebaseFirestore.instance
      .collection('orders')
      .where('assignedDriverId', isEqualTo: uid)
      .where('status', whereIn: ['accepted', 'onRoute'])
      .limit(1)
      .get(const GetOptions(source: Source.server));
  if (snap.docs.isNotEmpty) {
    final orderId = snap.docs.first.id;
    await NotificationMethodChannel.setActiveTripFlag(true, orderId: orderId, source: 'reconciliation');
    await AcceptanceLockManager.clearLock();
    if (context.mounted) context.go('/active-order');
    return true;
  }
  return false;
}
```

2. **Flutter — Hook into AppLifecycleState** (in main app widget):
```dart
// On resume: check if we own an order we don't know about
if (state == AppLifecycleState.resumed) {
  OrdersService.reconcileActiveOrder(context);
}
```

3. **Flutter — After acceptance error in `_accept()`**:
```dart
// Before showing "حدث خطأ", check if we actually own the order
final reconciled = await OrdersService.reconcileActiveOrder(context);
if (reconciled) return; // Success! Server accepted, response was lost.
```

4. **Structured log** (Cloud Function side — already exists via `handleOfferAcceptance` logs)

### Recovery Behavior
- **After app restart**: `syncActiveTripFlagOnStartup` queries Firestore → finds active order → sets flag
- **After resume**: new `reconcileActiveOrder` fires → detects ownership → navigates
- **Under partial network**: Uses `Source.server` — if unreachable, returns false (no action). Next resume retries.

### Idempotency Guarantee
- `reconcileActiveOrder` is a pure read + navigate. Safe to call N times.
- If order was cancelled between acceptance and reconciliation, query returns empty → no action.

### QA Verification Strategy
```
Scenario: acceptance_response_lost
1. Create order, wait for offer
2. Intercept network (airplane mode) AFTER accept tap but BEFORE response
3. Wait 3s, restore network
4. Verify: driver lands on /active-order within 10s of network restore
5. Verify: order status = accepted in Firestore
6. Verify: native trip flag = true
```

### Rollback Risk
- **Low**: Pure additive change. If reconciliation fails, existing behavior (error snackbar) remains.
- No state mutations on failure path.

---

## Edge Case 2: Infinite Dispatch Waves When No Drivers Exist

### Root Cause
`getWaveConfig()` returns `REPEAT_WAVE` for wave 4+ with no upper bound. `processExpiredWavesForOrder` triggers `processNextWave` unconditionally after each wave expires. If `findEligibleDrivers` returns 0 drivers, the wave still "completes" (sends 0 offers) and schedules the next expiration.

### Failure Sequence
```
T0: Order created in area with 0 online drivers
T1-T3: Waves 1-3 fire, find 0 drivers, expire after 45s each (135s total)
T4+: Wave 4, 5, 6... repeat every 60s indefinitely
T∞: dispatch_queue entry lives forever, Cloud Tasks fire every 60s
    Order stays in 'matching' forever (no expireStaleOrders for this path)
    Client sees "searching for driver" indefinitely
```

### Architectural Weakness
- No maximum wave count or maximum dispatch lifetime
- `wave_no_eligible_drivers` metric is emitted but not acted upon
- `expireStaleOrders` Cloud Function exists but may not cover dispatch_queue orders
- No client-side timeout or "no drivers available" feedback

### Proposed Fix

**Invariant Protected**: "No order may remain in dispatch_queue longer than MAX_DISPATCH_LIFETIME_MS without either being accepted or expired."

**Changes Required**:

1. **Engine — Add max wave limit and lifetime check** (`engine.ts`):
```typescript
const MAX_WAVE_COUNT = 10; // ~10 minutes total dispatch time
const MAX_DISPATCH_LIFETIME_MS = 10 * 60 * 1000; // 10 minutes absolute

// In processExpiredWavesForOrder, before processNextWave:
const lifetimeMs = now.toMillis() - queueData.createdAt.toMillis();
if (lifetimeMs > MAX_DISPATCH_LIFETIME_MS || queueData.currentWave >= MAX_WAVE_COUNT) {
  console.warn(JSON.stringify({
    tag: 'DispatchEngine',
    stage: 'dispatch_exhausted',
    orderId,
    currentWave: queueData.currentWave,
    lifetimeMs,
    result: 'expiring_order',
  }));
  emitMetric('dispatch_lifetime_exhausted', { orderId });
  
  // Expire the order
  await db.collection('orders').doc(orderId).update({
    status: 'expired',
    expiredAt: admin.firestore.FieldValue.serverTimestamp(),
    expiryReason: 'no_drivers_available',
  });
  await dequeueOrder(orderId);
  // Notify client
  // ... send FCM to client with type 'no_drivers_available'
  return;
}
```

2. **Add consecutive-empty-wave counter** (in `dispatch_queue` schema):
```typescript
// New field: consecutiveEmptyWaves (incremented when 0 drivers found)
// If >= 3 consecutive empty waves, expire immediately (no point waiting)
```

3. **Client notification**: Send FCM `type: 'order_expired_no_drivers'` to client with Arabic message.

### Recovery Behavior
- **Idempotent**: `processExpiredWavesForOrder` already checks `order.status !== 'matching'` — if order was expired by this fix, subsequent triggers are no-ops.
- **Under partial network**: Cloud Tasks retry on 5xx. If Firestore write fails, next scheduler run retries.

### QA Verification Strategy
```
Scenario: dispatch_exhausted_no_drivers
1. Set driver offline (or use coordinates with 0 nearby drivers)
2. Create order
3. Wait 10 minutes (or mock time)
4. Verify: order status = 'expired', expiryReason = 'no_drivers_available'
5. Verify: dispatch_queue entry deleted
6. Verify: client received expiry notification
```

### Rollback Risk
- **Low**: Only adds a ceiling. Existing orders that DO find drivers are unaffected.
- If MAX_WAVE_COUNT is too low, increase it. No data corruption possible.

---

## Edge Case 3: AcceptanceLock Remaining Stuck After Process Death

### Root Cause
`AcceptanceLockManager.setAcceptanceLock()` writes timestamp to SharedPreferences. Lock is cleared by `Future.delayed(5s)` on success or `clearLock()` on failure. If the process dies during the 5s window (OOM kill, force stop, crash), the lock persists in SharedPreferences indefinitely.

### Failure Sequence
```
T0: Driver taps Accept → setAcceptanceLock(orderId) writes to SharedPrefs
T1: acceptOfferV2 call starts
T2: Process killed (OOM, user force-stop, Android kills background)
T3: App restarts (cold start)
T4: syncActiveTripFlagOnStartup runs → sets trip flag correctly
T5: New offer arrives via FCM → NotificationService.handleIncomingOffer
T6: AcceptanceLockManager.isWithinAcceptanceWindow() → reads SharedPrefs
T7: lastAcceptanceMs is from T0 (could be hours ago)
T8: elapsedMs > 5000 → returns false → LOCK IS NOT STUCK (self-healing!)
```

**Wait** — re-reading the code: `_lockWindowSeconds = 5`. The lock is timestamp-based with a 5-second TTL. After 5 seconds, `isWithinAcceptanceWindow()` returns false regardless of whether `clearLock()` was called.

### Revised Root Cause
The lock is **NOT permanently stuck** — it self-expires after 5 seconds based on timestamp comparison. The real risk is:
- If the system clock jumps backward (rare on Android)
- If SharedPreferences becomes corrupted

**Actual vulnerability**: The `_keyLastAcceptance` timestamp remains in SharedPreferences forever (never cleaned up), but functionally it's harmless after 5s.

### Architectural Weakness (Revised)
The real issue is the **in-memory `_actionTaken` flag** in `FullScreenNotificationScreen`, not the SharedPreferences lock. If the app is killed while `_actionTaken = true` and the acceptance failed, the next time the fullscreen is shown for the same offer, `_actionTaken` starts as `false` (fresh widget) — so this is also self-healing.

**Conclusion**: This edge case is already mitigated by the timestamp-based TTL design. No code change needed.

### Recommendation
Add a cleanup step in `syncActiveTripFlagOnStartup` to explicitly clear stale lock entries:
```dart
// In syncActiveTripFlagOnStartup, after the main logic:
final prefs = await SharedPreferences.getInstance();
final lastLock = prefs.getInt('last_acceptance_timestamp') ?? 0;
if (lastLock > 0 && DateTime.now().millisecondsSinceEpoch - lastLock > 30000) {
  await AcceptanceLockManager.clearLock(); // Defensive cleanup
}
```

### Rollback Risk: None (defensive cleanup only)

---

## Edge Case 4: Wallet Fee Deduction Race During Cancellation

### Root Cause
`processTripStartFee` triggers on `orders/{orderId}.onUpdate` when status changes `accepted → onRoute`. If the client cancels the order in the same moment (setting status to `cancelledByClient`), two concurrent Cloud Function invocations race:

1. Driver's `transition(orderId, onRoute)` → status = onRoute
2. Client's cancel → status = cancelledByClient

Firestore's last-write-wins means one of these will be the final state. But `processTripStartFee` may have already read the snapshot showing `onRoute` and committed the fee deduction.

### Failure Sequence
```
T0: Order status = 'accepted'
T1: Driver taps "Start Trip" → client writes status = 'onRoute'
T2: Client taps "Cancel" → client writes status = 'cancelledByClient'
T3: Firestore resolves: final status depends on write ordering
    Case A: onRoute wins → processTripStartFee fires → fee deducted → then cancel arrives → fee NOT refunded
    Case B: cancelledByClient wins → processTripStartFee sees accepted→cancelledByClient (not onRoute) → skips
```

### Architectural Weakness
- Firestore rules allow client cancel from `accepted` status (correct behavior)
- But there's no coordination between the driver's transition and the client's cancel
- `processTripStartFee` uses `beforeStatus === 'accepted' && afterStatus === 'onRoute'` — if cancel wins, it never fires (Case B is safe)
- Case A is the problem: fee deducted, then order cancelled, no refund

### Proposed Fix

**Invariant Protected**: "Trip start fee is only permanently deducted if the order reaches a non-cancelled terminal state (completed). If cancelled within CANCEL_GRACE_PERIOD after fee deduction, refund."

**Changes Required**:

1. **Add cancel-after-fee-deduction handler** (new Cloud Function or extend existing):
```typescript
// In a new onUpdate trigger or extend processTripStartFee:
// If order transitions FROM onRoute TO cancelledByClient/cancelledByDriver:
// Check if trip_start_fee ledger entry exists AND startedAt is < 60s ago
// If yes: refund the fee

const CANCEL_GRACE_PERIOD_MS = 60_000; // 60 seconds

// When order becomes cancelled:
if (afterStatus.startsWith('cancelled') && beforeStatus === 'onRoute') {
  const startedAt = afterData.startedAt?.toMillis() ?? 0;
  const elapsed = Date.now() - startedAt;
  
  if (elapsed < CANCEL_GRACE_PERIOD_MS) {
    // Refund trip start fee
    const feeDoc = await db.collection('transactions')
      .where('orderId', '==', orderId)
      .where('type', '==', 'trip_start_fee')
      .limit(1).get();
    
    if (!feeDoc.empty) {
      const feeAmount = Math.abs(feeDoc.docs[0].data().amount);
      await atomicWalletUpdate(db, driverId, feeAmount, {
        orderId, type: 'refund',
        description: `Refund: trip cancelled within grace period`,
      });
    }
  }
}
```

2. **Firestore rules**: Already prevent client cancel after `onRoute` (P0-5 fix). But driver can still cancel from `onRoute`. The grace period handles this.

3. **Idempotency**: Refund uses a unique ledger doc ID (`${orderId}_start_fee_refund`) to prevent double-refund.

### Recovery Behavior
- **Idempotent**: Checks for existing refund doc before writing
- **Under partial network**: Cloud Function retries on failure. Refund is atomic (transaction).
- **After restart**: No client-side component — purely server-side

### QA Verification Strategy
```
Scenario: fee_refund_on_immediate_cancel
1. Create order, accept, start trip (onRoute)
2. Within 30s: driver cancels
3. Verify: refund transaction exists in ledger
4. Verify: driver wallet balance restored
5. Verify: no double-refund on retry
```

### Rollback Risk
- **Medium**: Introduces refund logic. If buggy, could over-refund.
- Mitigation: Idempotency key prevents double-refund. Grace period is configurable.

---

## Edge Case 5: Orphaned dispatch_queue States

### Root Cause
Multiple paths can leave an order in `dispatch_queue` after it's no longer actionable:
1. `handleOfferAcceptance` succeeds but `dequeueOrder` fails (network error after transaction)
2. Client cancels order but no one removes it from dispatch_queue
3. `expireStaleOrders` expires the order but doesn't touch dispatch_queue

### Failure Sequence
```
T0: Order accepted via handleOfferAcceptance (transaction commits)
T1: dequeueOrder(orderId) throws (Firestore transient error)
T2: Order is 'accepted' in orders collection
T3: dispatch_queue still has the entry
T4: processExpiredWaves fires → reads order status → sees 'accepted' → dequeues (SELF-HEALING)
```

### Architectural Weakness
The self-healing exists (`processExpiredWavesForOrder` checks order status and dequeues non-matching orders) but relies on the fallback scheduler running. If Cloud Tasks are the primary mechanism and the fallback scheduler is disabled, orphans persist until the next scheduler run.

### Proposed Fix

**Invariant Protected**: "dispatch_queue entries for non-matching orders are cleaned up within 2 minutes."

**Changes Required**:

1. **Already handled**: `processExpiredWavesForOrder` line:
```typescript
if (!orderDoc.exists || orderDoc.data()?.status !== 'matching') {
  await dequeueOrder(orderId);
  return;
}
```

2. **Add explicit cleanup in acceptance path** (belt-and-suspenders):
```typescript
// In handleOfferAcceptance, after the transaction succeeds:
// Wrap dequeueOrder in retry
await withRetry(() => dequeueOrder(offer.orderId), { 
  label: 'post_accept_dequeue', 
  orderId: offer.orderId,
  maxAttempts: 3 
});
```

3. **Add Firestore onUpdate trigger for orders** that dequeues on terminal status:
```typescript
// orders/{orderId} onUpdate: if status changed to terminal, dequeue
const TERMINAL = ['accepted', 'completed', 'cancelledByClient', 'cancelledByDriver', 'expired'];
if (TERMINAL.includes(afterStatus) && !TERMINAL.includes(beforeStatus)) {
  await dequeueOrder(orderId).catch(() => {}); // best-effort
}
```

### Recovery Behavior
- **Primary**: `dequeueOrder` with retry in acceptance path
- **Secondary**: Order status trigger dequeues on any terminal transition
- **Tertiary**: Fallback scheduler (every 60s) catches any remaining orphans

### Rollback Risk: **None** — all paths are additive and idempotent.

---

## Edge Case 6: Expired Snoozed Offers Resurfacing

### Root Cause
When driver taps "لاحقاً" (Snooze), the app:
1. Clears dedup state for this offer (`clearSnoozedOffer`)
2. Schedules Android AlarmManager to re-show after 5 minutes
3. After 5 min: alarm fires → native code builds notification → shows fullscreen

But the offer's `expiresAt` is typically 45-60 seconds from creation. After 5 minutes, the offer is long expired on the backend.

### Failure Sequence
```
T0: Offer arrives (expiresAt = T0 + 45s)
T15: Driver taps Snooze → alarm scheduled for T0 + 315s (5 min)
T45: Offer expires on backend (status → expired)
T60: Wave 2 fires, new offer created for same order
T315: Snooze alarm fires → shows STALE offer (expired 270s ago)
T316: Driver taps Accept on stale offer → "انتهت صلاحية العرض" error
```

### Architectural Weakness
- Snooze alarm carries the original `offerId` which is now expired
- No server-side validation before showing the snoozed notification
- `isOrderStillMatching(offerId)` in `MyFirebaseMessagingService` checks offer status — but the snooze path bypasses this check (alarm → direct notification display)

### Proposed Fix

**Invariant Protected**: "A snoozed notification MUST validate offer/order freshness before displaying."

**Changes Required**:

1. **Native Kotlin — SnoozeAlarmReceiver**: Before showing notification, verify offer is still valid:
```kotlin
// In SnoozeAlarmReceiver.onReceive():
// Before calling NotificationHelper.showFullScreenNotification:
Thread {
  val isValid = isOfferStillValid(offerId)
  if (isValid) {
    // Show notification
  } else {
    Log.d(TAG, "Snoozed offer expired, dropping: offerId=$offerId")
    // Optionally: check if order is still matching and show fresh offer
  }
}.start()
```

2. **Flutter — FullScreenNotificationScreen.initState()**: Already has `_orderSubscription` that auto-dismisses on terminal status. This handles the case where the user sees the stale offer briefly before server confirms expiry.

3. **Alternative (simpler)**: Don't snooze for longer than the offer TTL. Cap snooze at `min(requestedDelay, offer.expiresAt - now)`. If offer expires before snooze fires, the alarm is a no-op.

### Recovery Behavior
- **If stale offer shown**: `_orderSubscription` in FullScreenNotificationScreen detects terminal status → `_safeDismiss()` fires within 1-2s
- **If validation added**: Stale offer never shown (cleaner UX)
- **Under partial network**: Validation fails → fail-closed (don't show) or fail-open (show, let subscription handle)

### QA Verification Strategy
```
Scenario: snooze_expired_offer
1. Create order, wait for offer on driver
2. Tap Snooze (5 min)
3. Immediately expire the offer on backend
4. Wait 5 min for alarm
5. Verify: NO fullscreen appears (if validation added)
   OR: fullscreen appears then auto-dismisses within 2s (existing behavior)
```

### Rollback Risk
- **Low**: Validation is a guard clause. If it fails, existing auto-dismiss behavior handles it.

---

## Implementation Priority

| # | Edge Case | Severity | Effort | Priority | Status |
|---|-----------|----------|--------|----------|--------|
| 1 | Acceptance response lost | 🔴 Critical | Medium | P0 | ✅ Implemented |
| 2 | Infinite dispatch waves | 🔴 Critical | Low | P0 | ✅ Implemented |
| 4 | Fee deduction race | 🟡 Medium | Medium | P1 | Planned |
| 5 | Orphaned dispatch_queue | 🟡 Medium | Low | P1 | Planned |
| 6 | Expired snoozed offers | 🟡 Medium | Low | P2 | Planned |
| 3 | AcceptanceLock stuck | 🟢 Already mitigated | None | — | N/A |

---

## Schema Changes Summary

| Collection | Field | Type | Purpose |
|---|---|---|---|
| `dispatch_queue` | `consecutiveEmptyWaves` | number | Track waves with 0 drivers |
| `dispatch_queue` | `maxWaveReached` | boolean | Flag for exhaustion |
| `orders` | `expiryReason` | string | Distinguish timeout vs no-drivers |
| `transactions` | `${orderId}_start_fee_refund` | doc | Idempotency key for refunds |

---

## Observability Additions

| Metric | Trigger | Alert Threshold |
|---|---|---|
| `dispatch_lifetime_exhausted` | Order expired due to max waves | > 5/hour |
| `acceptance_reconciled` | Driver recovered via reconciliation | Any (informational) |
| `fee_refund_grace_period` | Refund issued within grace period | > 3/day |
| `snooze_expired_dropped` | Snoozed offer dropped (stale) | Informational |
| `orphan_dequeued_by_trigger` | Order dequeued by status trigger | Informational |

---

## Non-Goals (Explicitly Out of Scope)

1. **Client-side price validation** — requires server-side price recalculation (separate feature)
2. **FCM token rotation mid-wave** — existing auto-cleanup is sufficient
3. **GPS drift during dispatch** — location freshness check (30 min) is adequate
4. **Firestore offline persistence disable** — would break offline-first UX
