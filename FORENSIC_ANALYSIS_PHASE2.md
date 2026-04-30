# Forensic Analysis: WawApp Driver Monorepo

## RISK A (R-002): cancelledByDriver writes 'cancelled'

### 1. Trigger Flow
Driver cancellation is triggered in the app via `OrdersService.cancelOrder(orderId, reason)` (`apps/wawapp_driver/lib/services/orders_service.dart`, Line 184). This function runs a local Firestore transaction to verify the order is in a state where the driver can cancel, and then updates the document with the output of `createTransitionUpdate()`.

### 2. Value Written to Firestore
In `packages/core_shared/lib/src/order_status.dart` (Line 99-100), `OrderStatus.cancelledByDriver.toFirestore()` strictly returns the string `'cancelledByDriver'`.

### 3. Notification Configuration (`notifyOrderEvents.ts`)
In `functions/src/notifyOrderEvents.ts` (Lines 31-104), the `getNotificationConfig` function evaluates `fromStatus` and `toStatus`. There is **no configuration** that matches a transition TO `cancelledByDriver`. If a driver cancels, `notifyOrderEvents.ts` returns `null` and silently exits.

### 4. Guard Condition in `handleDriverCancellation.ts`
In `functions/src/handleDriverCancellation.ts` (Lines 30-35), the guards are:
```typescript
if (before.status === after.status) return null;
if (after.status === 'cancelledBySystem') return null;
if (after.status !== 'cancelled' && after.status !== 'cancelledByDriver') return null;
if (before.status === 'matching') return null;
```
**Does it fire for `onRoute` → `cancelledByDriver`?** 
Yes. The condition `after.status === 'cancelledByDriver'` matches, and `before.status` was `'onRoute'` (which is not `'matching'`). Therefore, the function proceeds. 

### 5. Client Impact
When a driver cancels from `onRoute`, `handleDriverCancellation.ts` takes over (since `notifyOrderEvents.ts` ignores it). 
1. It sends an FCM notification directly to the client: `"ألغى السائق الطلب... جارِ البحث عن سائق آخر..."` (Line 88).
2. It completely resets the order back to `'matching'` (Line 50).
**Result:** The client receives a push notification, but catastrophically, the Firestore document drops back to `matching`. The client UI abruptly snaps from live GPS tracking back to the "Searching for Driver" radar screen, even though the physical trip was already underway.

---

## RISK B (R-011): FCM token written from two places

### 1. Initialization Order
In `apps/wawapp_driver/lib/main.dart`:
1. Line 99: `await FcmTokenManager().initialize();` runs synchronously before the Flutter UI mounts.
2. Line 222: Inside `_MyAppState.initState()` via `addPostFrameCallback`, `await NotificationService().initialize();` runs. `NotificationService` extends `BaseFCMService`.

### 2. Overlapping Writes
**Yes, both write to the exact same field.**
- `FcmTokenManager._syncTokenToFirestore` (`apps/wawapp_driver/lib/services/fcm_token_manager.dart`, Line 161) updates `drivers/{uid}` with `fcmToken`.
- `BaseFCMService.saveTokenToFirestore` (`packages/core_shared/lib/src/fcm/base_fcm_service.dart`, Line 212) explicitly calls `_firestore.collection('drivers').doc(user.uid).update({'fcmToken': token})`.

### 3. Race Condition Risk
Because both initialize on app startup in rapid succession, both call `FirebaseMessaging.instance.getToken()` and then hit Firestore. Depending on offline persistence queuing and network latency, the second write will overwrite the first. If the token rotates precisely during app initialization, one service might write a stale token, which the other immediately overwrites.

### 4. Applied Fixes vs Reality
In `fcm_token_manager.dart` (Line 52), a listener was added to `FirebaseAuth.instance.authStateChanges()` to re-sync the token upon login, fixing token drops during auth transitions. However, `BaseFCMService.saveTokenToFirestore()` was never decommissioned. It is highly active and still fundamentally duplicating the exact same work `FcmTokenManager` is designated to handle.

---

## RISK C (R-009): Legacy acceptOrder v1 still called

### 1. `OrdersService` Function Call
`OrdersService.acceptOrder(String orderId)` (`apps/wawapp_driver/lib/services/orders_service.dart`, Line 115) unequivocally calls the v1 Cloud Function named `'acceptOrder'`. 

### 2. Missing v2 Engine Logic in v1
`acceptOrder.v2.ts` exclusively delegates to the new Dispatch Engine (`handleOfferAcceptance()`) enforcing offer-based locking.
`acceptOrder.ts` (v1) contains legacy logic (Lines 49-94):
- It bypasses `offerId` validations entirely.
- It performs a raw Firestore transaction, checking only if `status !== 'matching'` and `assignedDriverId` is null.
- It manually fetches `customerPhone` from the `users` collection and writes it to the order document (a deprecated pattern).
- It completely ignores the `dispatch_offers` collection, meaning it bypasses the expiration logic, driver exclusivity checks, and wave matching rules established in v2.

### 3. Lingering Invocation Path
Any legacy UI component (like a fallback matching screen) calling `OrdersService.acceptOrder(orderId)` will hit v1. While v1 has a patch (Line 31) that delegates to the engine *if* an `offerId` is provided, `OrdersService.acceptOrder` does not accept or pass an `offerId` in its method signature, guaranteeing it hits the legacy bypass path.

---

## RISK D (R-001 + R-008): Trigger cascade

### 1. The 6 `onUpdate` Order Triggers
1. **`trackOrderAcceptance.ts`**: Fires when `afterStatus === 'accepted' && afterDriverId !== null` and it was not previously accepted.
2. **`processTripStartFee.ts`**: Fires when `beforeStatus === 'accepted' && afterStatus === 'onRoute' && assignedDriverId !== null`.
3. **`notifyOrderEvents.ts`**: Fires on *any* status change (`beforeStatus !== afterStatus`).
4. **`handleDriverCancellation.ts`**: Fires on status change TO `'cancelled'` or `'cancelledByDriver'` (from anything except `'matching'`).
5. **`finance/orderSettlement.ts`**: Fires when `beforeStatus !== 'completed' && afterStatus === 'completed'`.
6. **`enforceOrderExclusivity.ts`** (`onWrite`): Fires on any driver change (`previousDriverId !== currentDriverId`).

### 2. Revert Sequence (`processTripStartFee.ts`)
If an order transitions to `onRoute` but the driver has insufficient balance:
1. Trigger fires. Wallet is checked.
2. If balance < fee (Line 185), it checks `feeRevertCount`.
3. If `< 3`, it reverts the status: `transaction.update(..., { status: 'accepted', feeRevertCount: increment(1) })` (Line 212).
4. Because the status changed back from `onRoute` to `accepted`, `notifyOrderEvents.ts` fires AGAIN. (Though `notifyOrderEvents.ts` doesn't have a config for `onRoute` → `accepted`, so it silently ignores it). 
5. If `< 3` continues failing, on the 3rd attempt, it hard-cancels the order to `cancelledBySystem` (Line 198), which triggers `notifyOrderEvents.ts` to send the client an "order cancelled by system" notification.

### 3. Lack of Distributed Locking
There is **no distributed lock** across these triggers. `processTripStartFee.ts` uses a local idempotency ledger (`transactions` collection doc), but it operates completely independently of `notifyOrderEvents.ts` and `enforceOrderExclusivity.ts`.
**Consequence:** When the driver clicks "Start Trip" (triggering `onRoute`), `notifyOrderEvents.ts` instantly fires and sends the "Driver is on the way" push notification to the client. Milliseconds later, `processTripStartFee.ts` realizes the driver has no money and reverts the order back to `accepted`. The client receives a notification that the trip started, but their app UI snaps backward to the "Waiting for driver to start" screen.
