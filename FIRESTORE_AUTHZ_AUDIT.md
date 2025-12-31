# Firestore Rules & Authorization Audit Report
**Generated:** 2025-12-30  
**Scope:** Firestore security rules + Cloud Functions authorization  
**Severity:** P0 (Critical) / P1 (High)

---

## Executive Summary

**Total Findings:** 12 (6 P0, 6 P1)  
**Critical Risk Areas:**
1. Order matching feed exposes PII to all authenticated users (P0)
2. Driver location tracking accessible to all users - privacy violation (P0)
3. Wallet read authorization bypass via type checking (P0)
4. Admin field protection gaps allow privilege escalation (P0)
5. Order status transition lacks client-side enforcement (P0)
6. Race conditions in wallet settlement (P1)

**Recommendation:** Block production deployment until P0 findings are resolved.

---

## P0 Findings (Critical - Block Production)

### P0-1: Order Matching Feed Exposes Client PII to All Authenticated Users

**Severity:** P0 - Data Privacy Violation  
**Component:** Firestore Rules - `/orders` collection  
**Evidence:**
```
File: firestore.rules
Line 59: allow read: if isSignedIn() && (isOwner() || isDriver() || isAssignedDriver() || resource.data.status == "matching");
```

**Vulnerability:**
Any authenticated user (client OR driver) can read ALL orders with `status == "matching"`. This exposes:
- Client phone numbers (via `ownerId` → `users` lookup)
- Pickup/dropoff addresses (home/work locations)
- Travel patterns
- Order pricing

**Attack Scenario:**
1. Malicious driver creates account
2. Queries all `matching` orders
3. Harvests client addresses, builds location database
4. Stalking, targeted advertising, competitive intelligence

**Impact:**
- GDPR/privacy violation
- Client safety risk
- Competitive intelligence leak

**Fix:**
```javascript
// Line 59 - Replace with:
allow read: if isSignedIn() && (isOwner() || (isDriver() && resource.data.status == "matching" && driverIsNearby()));

// Add helper function:
function driverIsNearby() {
  // Only show matching orders within driver's service radius
  // Requires driver_locations/{uid} to exist with recent timestamp
  let driverLoc = get(/databases/$(database)/documents/driver_locations/$(request.auth.uid));
  return driverLoc != null && driverLoc.data.timestamp > request.time - duration.value(5, 'm');
}
```

**Verification:**
- Test: Client user should NOT be able to query `orders` where `status == "matching"`
- Test: Driver without active location should NOT see matching orders

---

### P0-2: Driver Location Privacy Leak - All Authenticated Users Can Track Drivers

**Severity:** P0 - Privacy Violation, Safety Risk  
**Component:** Firestore Rules - `/driver_locations` collection  
**Evidence:**
```
File: firestore.rules
Line 71: allow read: if isSignedIn();
```

**Vulnerability:**
ANY authenticated user (including clients) can:
- Query all active driver locations in real-time
- Track individual driver movements
- Build driver home/work location database
- Monitor driver activity patterns

**Attack Scenario:**
1. Malicious client creates account
2. Continuously queries `driver_locations` collection
3. Tracks specific driver's movements
4. Identifies driver's home address
5. Stalking, harassment, robbery

**Impact:**
- Driver safety risk (physical harm)
- Privacy violation
- Legal liability

**Fix:**
```javascript
// Line 71 - Replace with:
allow read: if isSignedIn() && (
  request.auth.uid == driverId ||  // Driver can read own location
  hasActiveOrderWithDriver(driverId)  // Client can read assigned driver's location
);

// Add helper function:
function hasActiveOrderWithDriver(driverId) {
  // Check if requesting user has an active order assigned to this driver
  return exists(/databases/$(database)/documents/orders/$(request.auth.uid + '_active')) &&
         get(/databases/$(database)/documents/orders/$(request.auth.uid + '_active')).data.assignedDriverId == driverId;
}
```

**Alternative (Simpler):**
```javascript
// Only allow drivers to read their own location
// Clients get driver location via Cloud Function that validates order assignment
allow read: if isSignedIn() && request.auth.uid == driverId;
allow write: if isSignedIn() && request.auth.uid == driverId;
```

**Verification:**
- Test: Client user should NOT be able to list all driver locations
- Test: Client should only see assigned driver's location via secure API

---

### P0-3: Wallet Read Authorization Bypass via Type Manipulation

**Severity:** P0 - Financial Data Exposure  
**Component:** Firestore Rules - `/wallets` collection  
**Evidence:**
```
File: firestore.rules
Lines 181-183:
allow read: if isSignedIn() && 
               request.auth.uid == walletId &&
               resource.data.type == 'driver';
```

**Vulnerability:**
The rule checks `resource.data.type == 'driver'` AFTER checking `request.auth.uid == walletId`. This means:
- If a malicious user creates a wallet document with their own UID and `type: 'driver'`, they can read it
- Platform wallet (`PLATFORM_WALLET`) can be read if attacker guesses the ID

**Attack Scenario:**
1. Attacker discovers platform wallet ID is `PLATFORM_WALLET` (hardcoded in code)
2. Attacker cannot directly read it (UID mismatch)
3. BUT: If platform wallet has `type: 'platform'`, the rule fails correctly
4. HOWEVER: If attacker can create a wallet with `walletId == attacker_uid` and `type: 'driver'`, they can read their fake wallet

**Actual Risk:**
- Platform wallet is protected by UID mismatch
- BUT: Rule should explicitly deny platform wallet reads by non-admins

**Fix:**
```javascript
// Lines 181-183 - Replace with:
allow read: if isSignedIn() && 
               request.auth.uid == walletId &&
               resource.data.type == 'driver' &&
               walletId != 'PLATFORM_WALLET';  // Explicit platform wallet protection
```

**Better Fix (Defense in Depth):**
```javascript
// Lines 176-186 - Replace entire section:
match /wallets/{walletId} {
  // Admins can read all wallets
  allow read: if isAdmin();
  
  // Drivers can ONLY read their own wallet (must match UID AND type)
  allow read: if isSignedIn() && 
                 request.auth.uid == walletId &&
                 resource.data.ownerId == request.auth.uid &&
                 resource.data.type == 'driver';
  
  // Platform wallet: admins only
  allow read: if walletId == 'PLATFORM_WALLET' && isAdmin();
  
  // Only Cloud Functions can write (no direct client writes)
  allow write: if false;
}
```

---

### P0-4: Admin Field Protection Gaps Allow Privilege Escalation

**Severity:** P0 - Privilege Escalation  
**Component:** Firestore Rules - `/users`, `/drivers`, `/clients` collections  
**Evidence:**
```
File: firestore.rules

Lines 94-95 (users):
&& (!('totalTrips' in resource.data) || request.resource.data.totalTrips == resource.data.totalTrips)
&& (!('averageRating' in resource.data) || request.resource.data.averageRating == resource.data.averageRating);

Lines 143-146 (drivers):
&& (!('isVerified' in resource.data) || request.resource.data.isVerified == resource.data.isVerified)
&& (!('rating' in resource.data) || request.resource.data.rating == resource.data.rating)
&& (!('totalTrips' in resource.data) || request.resource.data.totalTrips == resource.data.totalTrips)
&& (!('ratedOrders' in resource.data) || request.resource.data.ratedOrders == resource.data.ratedOrders);

Lines 162-164 (clients):
&& (!('isVerified' in resource.data) || request.resource.data.isVerified == resource.data.isVerified)
&& (!('totalTrips' in resource.data) || request.resource.data.totalTrips == resource.data.totalTrips)
&& (!('averageRating' in resource.data) || request.resource.data.averageRating == resource.data.averageRating);
```

**Vulnerability:**
Admin fields are ONLY protected if they already exist in the document. A user can:
1. Create a new document WITHOUT admin fields (passes validation)
2. Later, add admin fields in an update (e.g., `isVerified: true`, `totalTrips: 1000`)
3. Rules only check "if field exists, don't change it" - but if it doesn't exist, user can add it!

**Attack Scenario (Driver):**
1. Driver creates account → `drivers/{uid}` document created without `isVerified`
2. Driver updates profile, adds `isVerified: true` in the same update
3. Rule checks `!('isVerified' in resource.data)` → TRUE (field doesn't exist yet)
4. Update succeeds, driver is now verified without admin approval

**Attack Scenario (Client):**
1. Client creates account → `users/{uid}` without `totalTrips`
2. Client updates profile, adds `totalTrips: 1000`, `averageRating: 5.0`
3. Client appears as experienced user with perfect rating

**Impact:**
- Privilege escalation
- Fake verification status
- Manipulated ratings/statistics
- Trust system bypass

**Fix:**
```javascript
// Lines 87-95 (users) - Replace with:
allow update: if isSignedIn()
              && request.auth.uid == uid
              // Prevent partial PIN edits
              && !(request.resource.data.diff(resource.data).affectedKeys()
                   .hasAny(['pinHash','pinSalt'])
                   && !request.resource.data.keys().hasAll(['pinHash','pinSalt']))
              // STRICT: Prevent adding OR modifying admin fields
              && !request.resource.data.diff(resource.data).affectedKeys()
                   .hasAny(['totalTrips', 'averageRating', 'isVerified', 'isAdmin']);

// Lines 140-146 (drivers) - Replace with:
allow update: if isSignedIn()
              && request.auth.uid == driverId
              // STRICT: Prevent adding OR modifying admin fields
              && !request.resource.data.diff(resource.data).affectedKeys()
                   .hasAny(['isVerified', 'rating', 'totalTrips', 'ratedOrders', 'isBlocked']);

// Lines 160-164 (clients) - Replace with:
allow update: if isSignedIn() 
              && request.auth.uid == clientId
              // STRICT: Prevent adding OR modifying admin fields
              && !request.resource.data.diff(resource.data).affectedKeys()
                   .hasAny(['isVerified', 'totalTrips', 'averageRating', 'isBlocked']);
```

**Verification:**
- Test: User creates document without `isVerified`, then tries to add it → DENY
- Test: User tries to modify existing `totalTrips` → DENY
- Test: Admin via Cloud Function can modify admin fields → ALLOW

---

### P0-5: Order Status Transition Validation Missing Client-Side Enforcement

**Severity:** P0 - Business Logic Bypass  
**Component:** Firestore Rules - `/orders` update validation  
**Evidence:**
```
File: firestore.rules
Lines 61-67:
allow update: if isSignedIn()
  && request.resource.data.price == resource.data.price
  && request.resource.data.ownerId == resource.data.ownerId
  && ((validStatusTransition() && ((request.resource.data.status == "accepted" && request.resource.data.assignedDriverId == request.auth.uid) ||
      (request.resource.data.status == "cancelledByClient" && isOwner()) ||
      (request.resource.data.status in ["onRoute", "completed", "cancelled", "cancelledByDriver"] && isAssignedDriver()))) ||
      (isRatingUpdate() && isOwner()));
```

**Vulnerability:**
The rule allows clients to cancel orders with `cancelledByClient` status, but:
1. No validation that order is in a cancellable state
2. Client can cancel `completed` orders (after driver finished)
3. Client can cancel `onRoute` orders (after driver started trip and paid fee)
4. No refund logic for trip start fee

**Attack Scenario:**
1. Client places order → `matching`
2. Driver accepts → `accepted`
3. Driver starts trip → `onRoute` (10% fee deducted from driver wallet)
4. Client cancels order → `cancelledByClient` (allowed by rules)
5. Driver loses trip start fee, no compensation

**Impact:**
- Driver financial loss
- Business logic bypass
- Refund fraud

**Fix:**
```javascript
// Lines 61-67 - Replace with:
allow update: if isSignedIn()
  && request.resource.data.price == resource.data.price
  && request.resource.data.ownerId == resource.data.ownerId
  && ((validStatusTransition() && (
      (request.resource.data.status == "accepted" && request.resource.data.assignedDriverId == request.auth.uid) ||
      (request.resource.data.status == "cancelledByClient" && isOwner() && resource.data.status in ["matching", "accepted"]) ||  // ONLY allow cancel before onRoute
      (request.resource.data.status in ["onRoute", "completed", "cancelled", "cancelledByDriver"] && isAssignedDriver())
    )) ||
    (isRatingUpdate() && isOwner()));
```

**Additional Fix (validStatusTransition):**
```javascript
// Lines 12-18 - Update to prevent client cancel after onRoute:
function validStatusTransition() {
  let currentStatus = resource.data.status;
  let newStatus = request.resource.data.status;
  return (currentStatus == "matching" && newStatus in ["accepted", "cancelled", "cancelledByClient", "cancelledByDriver"]) ||
         (currentStatus == "accepted" && newStatus in ["onRoute", "cancelled", "cancelledByClient", "cancelledByDriver"]) ||
         (currentStatus == "onRoute" && newStatus in ["completed", "cancelled", "cancelledByDriver"]);  // Removed cancelledByClient
}
```

---

### P0-6: Order Price Manipulation via Free Orders

**Severity:** P0 - Financial Loss  
**Component:** Firestore Rules - `/orders` create validation  
**Evidence:**
```
File: firestore.rules
Lines 35-36:
&& request.resource.data.price is int
&& request.resource.data.price >= 0
```

**Vulnerability:**
Rules allow `price: 0` for order creation. This enables:
1. Client creates order with `price: 0`
2. Driver accepts (no validation)
3. Driver completes trip
4. Settlement function credits driver 80% of 0 = 0 MRU
5. Free ride for client, no earnings for driver

**Attack Scenario:**
1. Malicious client modifies app code to set `price: 0`
2. Creates order with valid pickup/dropoff
3. Driver sees order, accepts (assuming legitimate)
4. Driver completes trip, earns 0 MRU
5. Client gets free delivery

**Impact:**
- Driver financial loss
- Platform revenue loss
- Business model bypass

**Fix:**
```javascript
// Lines 35-36 - Replace with:
&& request.resource.data.price is int
&& request.resource.data.price > 0  // MUST be positive, no free orders
&& request.resource.data.price <= 100000  // Add max price sanity check (100k MRU)
```

**Additional Server-Side Validation:**
Add to Cloud Function `notifyNewOrder`:
```typescript
// Validate price is reasonable based on distance
const expectedPrice = calculatePrice(orderData.distanceKm);
if (orderData.price < expectedPrice * 0.5 || orderData.price > expectedPrice * 2) {
  console.error('Price manipulation detected', { orderId, price: orderData.price, expected: expectedPrice });
  await orderRef.update({ status: 'cancelled', cancellationReason: 'Invalid price' });
  return;
}
```

---

## P1 Findings (High - Fix Before Production)

### P1-1: Race Condition in Wallet Settlement - Double Credit Risk

**Severity:** P1 - Financial Integrity  
**Component:** Cloud Functions - `onOrderCompleted`  
**Evidence:**
```
File: functions/src/finance/orderSettlement.ts
Lines 14-55:
export const onOrderCompleted = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    // ...
    // Only process when status changes TO completed
    const wasCompleted = beforeData.status === 'completed';
    const isCompleted = afterData.status === 'completed';

    if (!isCompleted || wasCompleted) {
      return null;
    }

    // Check if already settled (idempotency)
    if (afterData.settledAt) {
      console.log(`Order ${orderId}: Already settled`);
      return null;
    }
    // ...
  });
```

**Vulnerability:**
Idempotency check happens OUTSIDE the transaction. Race condition:
1. Request A: Checks `settledAt` → null, proceeds
2. Request B: Checks `settledAt` → null, proceeds (before A commits)
3. Request A: Runs transaction, credits wallet, sets `settledAt`
4. Request B: Runs transaction, credits wallet AGAIN, overwrites `settledAt`
5. Driver wallet credited twice for same order

**Attack Scenario:**
1. Attacker completes order
2. Rapidly updates order status to trigger multiple function invocations
3. Race condition causes double credit
4. Attacker withdraws excess funds

**Impact:**
- Financial loss (double payment)
- Wallet balance corruption
- Ledger integrity violation

**Fix:**
```typescript
// Lines 47-54 - Move idempotency check INSIDE transaction:
try {
  await settleOrder(orderId, afterData);
  // ...
}

// Lines 60-193 - Update settleOrder function:
async function settleOrder(orderId: string, orderData: any): Promise<void> {
  const db = admin.firestore();
  
  await db.runTransaction(async (transaction) => {
    // 1. FIRST: Check idempotency INSIDE transaction
    const orderRef = db.collection('orders').doc(orderId);
    const orderSnap = await transaction.get(orderRef);
    
    if (orderSnap.data()?.settledAt) {
      console.log(`Order ${orderId}: Already settled (idempotent)`);
      return;  // Exit transaction safely
    }
    
    // 2. THEN: Proceed with settlement
    const orderPrice = orderData.price;
    const driverId = orderData.driverId;
    // ... rest of settlement logic
  });
}
```

**Verification:**
- Test: Trigger function twice simultaneously → Only one settlement
- Test: Check transaction logs for duplicate credits

---

### P1-2: Missing Authorization in Admin Order Reassignment

**Severity:** P1 - Business Logic Bypass  
**Component:** Cloud Functions - `adminReassignOrder`  
**Evidence:**
```
File: functions/src/admin/adminOrderActions.ts
Lines 104-196:
export const adminReassignOrder = functions.https.onCall(async (data, context) => {
  // ... admin auth check ...
  
  const { orderId, newDriverId } = data;
  
  // Check if driver exists and is available
  const driverDoc = await db.collection('drivers').doc(newDriverId).get();
  // ...
  
  // Update order
  const orderRef = db.collection('orders').doc(orderId);
  const orderDoc = await orderRef.get();
  // ...
  
  await orderRef.update({
    driverId: newDriverId,
    assignedDriverId: newDriverId,
    reassignedAt: admin.firestore.FieldValue.serverTimestamp(),
    reassignedBy: context.auth.uid,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
});
```

**Vulnerability:**
Function does NOT check:
1. Order status (can reassign `completed` orders)
2. Driver wallet balance (new driver might have insufficient funds)
3. Previous driver refund (if trip start fee was deducted)
4. Order settlement status (can reassign settled orders)

**Attack Scenario:**
1. Admin reassigns `onRoute` order to new driver
2. Original driver already paid trip start fee (10%)
3. New driver has insufficient balance
4. Order stuck in limbo, original driver loses fee

**Impact:**
- Driver financial loss
- Order fulfillment failure
- Wallet inconsistency

**Fix:**
```typescript
// Lines 151-170 - Add validation before update:
const orderData = orderDoc.data()!;
const currentStatus = orderData.status;

// Validate order can be reassigned
if (!['matching', 'accepted'].includes(currentStatus)) {
  throw new functions.https.HttpsError(
    'failed-precondition',
    `Cannot reassign order with status: ${currentStatus}`
  );
}

// Check if trip start fee was deducted
if (orderData.startedAt) {
  throw new functions.https.HttpsError(
    'failed-precondition',
    'Cannot reassign order after trip started (fee already deducted)'
  );
}

// Check new driver wallet balance
const newDriverWallet = await db.collection('wallets').doc(newDriverId).get();
if (newDriverWallet.exists && newDriverWallet.data()!.balance <= 0) {
  throw new functions.https.HttpsError(
    'failed-precondition',
    'New driver has insufficient wallet balance'
  );
}

await orderRef.update({
  driverId: newDriverId,
  assignedDriverId: newDriverId,
  reassignedAt: admin.firestore.FieldValue.serverTimestamp(),
  reassignedBy: context.auth.uid,
  previousDriverId: previousDriverId,  // Track for audit
  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
});
```

---

### P1-3: Order Exclusivity Guard Ineffective - No Reversion Logic

**Severity:** P1 - Business Logic Bypass  
**Component:** Cloud Functions - `enforceOrderExclusivity`  
**Evidence:**
```
File: functions/src/enforceOrderExclusivity.ts
Lines 46-62:
// Check for driver change after assignment (potential security issue)
if (previousDriverId && previousDriverId !== currentDriverId) {
  console.warn('[OrderExclusivity] Driver change detected', {
    order_id: orderId,
    previous_driver: previousDriverId,
    current_driver: currentDriverId,
    status: currentStatus,
  });

  // Allow admin reassignments but log for audit
  console.log('[Analytics] driver_reassignment', {
    order_id: orderId,
    previous_driver: previousDriverId,
    current_driver: currentDriverId,
    status: currentStatus,
  });
}
```

**Vulnerability:**
Function DETECTS driver changes but does NOT prevent them. It only logs a warning. This means:
1. Malicious driver can modify `assignedDriverId` via client SDK
2. Function logs the change but allows it
3. Order is reassigned without authorization

**Attack Scenario:**
1. Driver A accepts order → `assignedDriverId: A`
2. Driver B modifies order via client SDK → `assignedDriverId: B`
3. Firestore rules allow update (if status transition is valid)
4. `enforceOrderExclusivity` logs warning but doesn't revert
5. Driver B steals order from Driver A

**Impact:**
- Order theft
- Driver earnings loss
- Trust system breakdown

**Fix:**
```typescript
// Lines 46-62 - Replace with reversion logic:
// Check for unauthorized driver change
if (previousDriverId && previousDriverId !== currentDriverId) {
  console.error('[OrderExclusivity] UNAUTHORIZED driver change detected', {
    order_id: orderId,
    previous_driver: previousDriverId,
    current_driver: currentDriverId,
    status: currentStatus,
  });

  // Check if this is an admin reassignment
  const adminActions = await admin.firestore()
    .collection('admin_actions')
    .where('action', '==', 'reassignOrder')
    .where('orderId', '==', orderId)
    .orderBy('performedAt', 'desc')
    .limit(1)
    .get();

  const isAdminReassignment = !adminActions.empty &&
    adminActions.docs[0].data().newDriverId === currentDriverId;

  if (!isAdminReassignment) {
    // REVERT unauthorized change
    await change.after.ref.update({
      assignedDriverId: previousDriverId,
      driverId: previousDriverId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      securityAlert: {
        type: 'unauthorized_driver_change',
        detectedAt: admin.firestore.FieldValue.serverTimestamp(),
        attemptedBy: currentDriverId,
      },
    });

    console.error('[OrderExclusivity] Reverted unauthorized driver change', {
      order_id: orderId,
      reverted_to: previousDriverId,
    });
  } else {
    console.log('[OrderExclusivity] Admin reassignment allowed', {
      order_id: orderId,
      new_driver: currentDriverId,
    });
  }
}
```

---

### P1-4: Trip Start Fee Reversion Creates Infinite Loop Risk

**Severity:** P1 - Denial of Service  
**Component:** Cloud Functions - `processTripStartFee`  
**Evidence:**
```
File: functions/src/processTripStartFee.ts
Lines 177-181:
// Revert order status to accepted
transaction.update(change.after.ref, {
  status: 'accepted',
  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
});
```

**Vulnerability:**
Function reverts order status from `onRoute` → `accepted` if insufficient balance. This triggers:
1. Driver app sees order back in `accepted` state
2. Driver taps "Start Trip" again
3. Order status → `onRoute` again
4. Function triggers again, checks balance (still insufficient)
5. Reverts to `accepted` again
6. INFINITE LOOP

**Attack Scenario:**
1. Driver accepts order with 0 balance
2. Driver tries to start trip
3. Function reverts to `accepted`
4. Driver app auto-retries (or driver manually retries)
5. Function triggers again, infinite loop
6. Firestore write quota exhausted, function costs spike

**Impact:**
- Denial of service
- Cost explosion
- Poor user experience

**Fix:**
```typescript
// Lines 169-189 - Add loop guard:
// Check if sufficient balance
if (currentBalance < tripStartFee) {
  console.warn('[TripStartFee] Insufficient balance, reverting order status', {
    order_id: orderId,
    driver_id: assignedDriverId,
    current_balance: currentBalance,
    required_fee: tripStartFee,
  });

  // Check for loop guard
  const revertCount = afterData.feeRevertCount || 0;
  if (revertCount >= 3) {
    // Too many reverts, cancel order instead
    transaction.update(change.after.ref, {
      status: 'cancelled',
      cancellationReason: 'Insufficient driver wallet balance after multiple attempts',
      cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    console.error('[TripStartFee] Order cancelled due to repeated insufficient balance', {
      order_id: orderId,
      driver_id: assignedDriverId,
      revert_count: revertCount,
    });
  } else {
    // Revert order status to accepted with loop guard
    transaction.update(change.after.ref, {
      status: 'accepted',
      feeRevertCount: admin.firestore.FieldValue.increment(1),
      lastFeeRevertAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  // Send notification to driver (outside transaction)
  setImmediate(() => {
    sendInsufficientBalanceNotification(assignedDriverId, orderId, tripStartFee);
  });

  return;
}
```

---

### P1-5: Wallet Balance Enforcement Fail-Closed Creates DoS

**Severity:** P1 - Availability  
**Component:** Cloud Functions - `enforceWalletBalance`  
**Evidence:**
```
File: functions/src/enforceWalletBalance.ts
Lines 197-224:
} catch (error) {
  console.error('[WalletBalanceGuard] Error checking wallet balance', {
    order_id: orderId,
    driver_id: assignedDriverId,
    error: error,
  });

  // Fix #1: Change to Fail-Closed - revert order on wallet check error
  console.warn('[WalletBalanceGuard] Reverting order due to wallet check error (fail-closed)', {
    order_id: orderId,
    driver_id: assignedDriverId,
  });

  // Revert order to matching status with walletGuard
  await change.after.ref.update({
    status: 'matching',
    assignedDriverId: null,
    driverId: null,
    walletGuard: {
      blockedAt: admin.firestore.FieldValue.serverTimestamp(),
      reason: 'CHECK_FAILED',
      driverId: assignedDriverId,
    },
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
```

**Vulnerability:**
Fail-closed policy is correct for security, BUT:
1. Firestore outage → All order acceptances fail
2. Wallet collection read error → All drivers blocked
3. Transient network error → Legitimate drivers cannot work
4. No retry mechanism

**Attack Scenario:**
1. Attacker triggers Firestore rate limits (DoS attack)
2. Wallet reads start failing
3. ALL drivers cannot accept orders (fail-closed)
4. Platform becomes unusable

**Impact:**
- Platform-wide outage
- Revenue loss
- Driver/client frustration

**Fix:**
```typescript
// Lines 197-224 - Add retry logic and circuit breaker:
} catch (error) {
  console.error('[WalletBalanceGuard] Error checking wallet balance', {
    order_id: orderId,
    driver_id: assignedDriverId,
    error: error,
  });

  // Check error type
  const isTransientError = error.code === 'unavailable' || 
                           error.code === 'deadline-exceeded';

  if (isTransientError) {
    // Transient error: Allow acceptance but flag for manual review
    console.warn('[WalletBalanceGuard] Transient error, allowing acceptance with flag', {
      order_id: orderId,
      driver_id: assignedDriverId,
    });

    await change.after.ref.update({
      walletCheckFailed: true,
      walletCheckError: error.message,
      walletCheckFailedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Alert ops team
    console.error('[ALERT] Wallet check failed, manual review required', {
      order_id: orderId,
      driver_id: assignedDriverId,
      error: error,
    });

    return null;  // Allow order to proceed
  }

  // Non-transient error: Fail-closed
  console.warn('[WalletBalanceGuard] Reverting order due to wallet check error (fail-closed)', {
    order_id: orderId,
    driver_id: assignedDriverId,
  });

  await change.after.ref.update({
    status: 'matching',
    assignedDriverId: null,
    driverId: null,
    walletGuard: {
      blockedAt: admin.firestore.FieldValue.serverTimestamp(),
      reason: 'CHECK_FAILED',
      driverId: assignedDriverId,
      error: error.message,
    },
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await sendWalletNotification(assignedDriverId, orderId, 'CHECK_FAILED');
}
```

---

### P1-6: Admin Actions Missing Audit Trail for Sensitive Operations

**Severity:** P1 - Compliance, Forensics  
**Component:** Cloud Functions - Admin actions  
**Evidence:**
```
File: functions/src/admin/adminClientActions.ts
Lines 60-65:
// Log the action
await db.collection('admin_actions').add({
  action: isVerified ? 'verifyClient' : 'unverifyClient',
  clientId,
  performedBy: context.auth.uid,
  performedAt: admin.firestore.FieldValue.serverTimestamp(),
});
```

**Vulnerability:**
Admin action logs are incomplete. Missing:
1. IP address of admin
2. User agent (web vs mobile)
3. Before/after state (what changed)
4. Reason/justification (required for compliance)
5. No immutability guarantee (logs can be deleted)

**Attack Scenario:**
1. Malicious admin blocks competitor's drivers
2. Admin action logged but with minimal info
3. Admin deletes log entries (no write protection)
4. Forensic investigation impossible

**Impact:**
- Compliance violation (GDPR, audit requirements)
- Insider threat undetectable
- Legal liability

**Fix:**
```typescript
// Create dedicated audit log collection with stricter rules
// Lines 60-65 - Replace with comprehensive logging:

// Enhanced audit log
const auditLog = {
  action: isVerified ? 'verifyClient' : 'unverifyClient',
  targetType: 'client',
  targetId: clientId,
  performedBy: context.auth.uid,
  performedByEmail: (await admin.auth().getUser(context.auth.uid)).email,
  performedAt: admin.firestore.FieldValue.serverTimestamp(),
  
  // Context
  ipAddress: context.rawRequest?.ip || 'unknown',
  userAgent: context.rawRequest?.headers['user-agent'] || 'unknown',
  
  // State changes
  beforeState: {
    isVerified: clientDoc.data()!.isVerified || false,
  },
  afterState: {
    isVerified: isVerified,
  },
  
  // Justification (should be required parameter)
  reason: data.reason || 'No reason provided',
  
  // Immutability marker
  immutable: true,
};

await db.collection('audit_logs').add(auditLog);

// Also log to external system (e.g., Cloud Logging) for immutability
console.log('[AUDIT]', JSON.stringify(auditLog));
```

**Firestore Rules for Audit Logs:**
```javascript
// Add to firestore.rules:
match /audit_logs/{logId} {
  // Only Cloud Functions can write
  allow write: if false;
  
  // Only admins can read
  allow read: if isAdmin();
  
  // Prevent deletion (immutability)
  allow delete: if false;
}
```

---

## Summary Table

| ID | Severity | Component | Issue | Impact | Fix Complexity |
|----|----------|-----------|-------|--------|----------------|
| P0-1 | P0 | Firestore Rules | Order matching feed exposes PII | Privacy violation, stalking risk | Medium |
| P0-2 | P0 | Firestore Rules | Driver location tracking leak | Safety risk, privacy violation | Medium |
| P0-3 | P0 | Firestore Rules | Wallet read authorization bypass | Financial data exposure | Low |
| P0-4 | P0 | Firestore Rules | Admin field protection gaps | Privilege escalation | Low |
| P0-5 | P0 | Firestore Rules | Order cancellation after trip start | Driver financial loss | Low |
| P0-6 | P0 | Firestore Rules | Free order creation allowed | Revenue loss, driver loss | Low |
| P1-1 | P1 | Cloud Functions | Wallet settlement race condition | Double payment risk | Medium |
| P1-2 | P1 | Cloud Functions | Admin reassignment missing validation | Business logic bypass | Medium |
| P1-3 | P1 | Cloud Functions | Order exclusivity guard ineffective | Order theft | High |
| P1-4 | P1 | Cloud Functions | Trip start fee infinite loop | DoS, cost explosion | Low |
| P1-5 | P1 | Cloud Functions | Wallet enforcement fail-closed DoS | Platform outage | Medium |
| P1-6 | P1 | Cloud Functions | Incomplete audit trail | Compliance violation | Low |

---

## Recommended Patch Order

1. **P0-6** (Free orders) - Immediate fix, 1 line change
2. **P0-4** (Admin field protection) - Critical privilege escalation, 3 rule changes
3. **P0-1** (Order matching PII) - Privacy violation, medium complexity
4. **P0-2** (Driver location leak) - Safety risk, medium complexity
5. **P0-5** (Order cancellation) - Business logic, 2 line change
6. **P0-3** (Wallet read bypass) - Defense in depth, low complexity
7. **P1-1** (Settlement race condition) - Financial integrity, medium complexity
8. **P1-4** (Trip start fee loop) - DoS prevention, low complexity
9. **P1-3** (Order exclusivity) - High complexity, requires admin action tracking
10. **P1-2** (Admin reassignment) - Business logic, medium complexity
11. **P1-5** (Wallet enforcement DoS) - Availability, medium complexity
12. **P1-6** (Audit trail) - Compliance, low complexity

---

## Testing Checklist

### Firestore Rules Testing
- [ ] Deploy updated rules to emulator
- [ ] Test P0-1: Client cannot read matching orders
- [ ] Test P0-2: Client cannot list driver locations
- [ ] Test P0-4: User cannot add `isVerified: true` to profile
- [ ] Test P0-5: Client cannot cancel `onRoute` order
- [ ] Test P0-6: Order creation with `price: 0` is rejected

### Cloud Functions Testing
- [ ] Test P1-1: Concurrent order completions only settle once
- [ ] Test P1-3: Unauthorized driver change is reverted
- [ ] Test P1-4: Trip start fee reversion after 3 attempts cancels order
- [ ] Load test wallet enforcement under Firestore outage

---

## End of Audit Report
