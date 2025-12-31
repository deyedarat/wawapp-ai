# Cloud Functions Backend Audit Report
**Generated:** 2025-12-30  
**Scope:** Idempotency, retries, wallet/settlement consistency, Admin SDK misuse  
**Format:** Vulnerability backlog with evidence

---

## Executive Summary

**Total Findings:** 18 vulnerabilities  
**Severity Breakdown:**
- **P0 (Critical):** 4 findings
- **P1 (High):** 8 findings  
- **P2 (Medium):** 6 findings

**Critical Risk Areas:**
1. Wallet settlement race condition (double-credit risk)
2. Missing idempotency in acceptance confirmation
3. Non-atomic updates outside transactions
4. Batch operations without rollback capability
5. Admin SDK FieldValue.delete() misuse

---

## P0 Findings (Critical)

### P0-1: Wallet Settlement Race Condition - Double Credit Vulnerability

**Severity:** P0 - Financial Integrity  
**Component:** `functions/src/finance/orderSettlement.ts`  
**Evidence:**
```typescript
File: functions/src/finance/orderSettlement.ts
Lines 21-34:
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
```

**Vulnerability:**
Idempotency check (`afterData.settledAt`) happens OUTSIDE the transaction (lines 31-34). Race condition window:
1. Request A reads order, sees `settledAt: null` → proceeds
2. Request B reads order, sees `settledAt: null` → proceeds (before A commits)
3. Both requests enter transaction and credit wallet
4. Driver receives double payment

**Attack Vector:**
- Rapid status updates trigger multiple function invocations
- Firestore retry logic can cause duplicate invocations
- Network issues cause client retries

**Impact:**
- Financial loss (double payment to driver)
- Platform wallet balance corruption
- Ledger integrity violation

**Fix:**
```typescript
// Move idempotency check INSIDE transaction
async function settleOrder(orderId: string, orderData: any): Promise<void> {
  const db = admin.firestore();
  
  await db.runTransaction(async (transaction) => {
    // FIRST: Check idempotency inside transaction
    const orderRef = db.collection('orders').doc(orderId);
    const orderSnap = await transaction.get(orderRef);
    
    if (orderSnap.data()?.settledAt) {
      console.log(`Order ${orderId}: Already settled (idempotent)`);
      return;  // Exit safely
    }
    
    // THEN: Proceed with settlement
    // ... rest of logic
  });
}
```

**Verification:**
- Load test: Trigger function 10x simultaneously for same order
- Assert: Only one wallet credit occurs
- Check: Transaction logs show 9 idempotent exits

---

### P0-2: Acceptance Confirmation Missing Idempotency - Duplicate Notifications

**Severity:** P0 - Data Integrity  
**Component:** `functions/src/notifyUnassignedOrders.ts`  
**Evidence:**
```typescript
File: functions/src/notifyUnassignedOrders.ts
Lines 507-515:
// Send confirmation notification
const result = await sendAcceptanceConfirmation(assignedDriverId, orderId, orderData);

if (result.success) {
  // Mark as sent (idempotency)
  await db.collection('orders').doc(orderId).update({
    acceptConfirmSentAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}
```

**Vulnerability:**
Notification send (line 508) and idempotency marker update (lines 512-515) are NOT atomic. Race condition:
1. Request A sends notification → succeeds
2. Request B sends notification → succeeds (before A updates `acceptConfirmSentAt`)
3. Request A updates `acceptConfirmSentAt`
4. Request B updates `acceptConfirmSentAt` (overwrites)
5. Driver receives 2+ notifications

**Attack Vector:**
- Scheduled function runs overlap (1-minute interval)
- Firestore query returns same order to multiple invocations
- Function retry on transient errors

**Impact:**
- Spam notifications to drivers
- FCM quota exhaustion
- Poor user experience

**Fix:**
```typescript
// Use transaction for atomic check-and-send
await db.runTransaction(async (transaction) => {
  const orderRef = db.collection('orders').doc(orderId);
  const orderSnap = await transaction.get(orderRef);
  const orderData = orderSnap.data()!;
  
  // Idempotency check INSIDE transaction
  if (orderData.acceptConfirmSentAt) {
    console.log('[NotifyAcceptConfirm] Already sent (idempotent)');
    return;
  }
  
  // Send notification
  const result = await sendAcceptanceConfirmation(assignedDriverId, orderId, orderData);
  
  if (result.success) {
    // Mark as sent atomically
    transaction.update(orderRef, {
      acceptConfirmSentAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
});
```

---

### P0-3: Top-up Approval Balance Corruption - Concurrent Approvals

**Severity:** P0 - Financial Integrity  
**Component:** `functions/src/approveTopupRequest.ts`  
**Evidence:**
```typescript
File: functions/src/approveTopupRequest.ts
Lines 73-90:
if (!walletDoc.exists) {
  // Create new driver wallet
  transaction.set(walletRef, {
    id: driverId,
    type: 'driver',
    ownerId: driverId,
    balance: 0,
    totalCredited: 0,
    // ...
  });
} else {
  currentBalance = walletDoc.data()!.balance || 0;
}

// Update wallet balance
transaction.update(walletRef, {
  balance: admin.firestore.FieldValue.increment(amount),
  totalCredited: admin.firestore.FieldValue.increment(amount),
  // ...
});
```

**Vulnerability:**
If wallet doesn't exist, function creates it with `balance: 0` (line 80), then immediately updates with `increment(amount)` (line 94). Race condition:
1. Request A: Wallet doesn't exist → creates with balance: 0
2. Request B: Wallet doesn't exist → creates with balance: 0 (before A commits)
3. Request A: Updates balance → increment(100) → balance: 100
4. Request B: Updates balance → increment(100) → balance: 100 (overwrites A's update)
5. Driver receives only 100 MRU instead of 200 MRU

**Attack Vector:**
- Admin approves multiple top-up requests simultaneously
- First-time driver with no wallet
- Concurrent admin actions

**Impact:**
- Driver financial loss (missing credits)
- Wallet balance corruption
- Ledger inconsistency

**Fix:**
```typescript
// Use merge: true for atomic create-or-update
if (!walletDoc.exists) {
  // Create wallet with initial balance in ONE operation
  transaction.set(walletRef, {
    id: driverId,
    type: 'driver',
    ownerId: driverId,
    balance: amount,  // Set initial balance directly
    totalCredited: amount,
    totalDebited: 0,
    pendingPayout: 0,
    currency: FINANCE_CONFIG.DEFAULT_CURRENCY,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
} else {
  currentBalance = walletDoc.data()!.balance || 0;
  
  // Update existing wallet
  transaction.update(walletRef, {
    balance: admin.firestore.FieldValue.increment(amount),
    totalCredited: admin.firestore.FieldValue.increment(amount),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}
```

---

### P0-4: Driver Rating Aggregation Array Growth - DoS Risk

**Severity:** P0 - Availability  
**Component:** `functions/src/aggregateDriverRating.ts`  
**Evidence:**
```typescript
File: functions/src/aggregateDriverRating.ts
Lines 73-81:
// Check if this order was already counted (idempotency)
const ratedOrders = driverData.ratedOrders || [];
if (ratedOrders.includes(orderId)) {
  console.log('[AggregateRating] Already processed (idempotent)');
  return;
}

// ...

transaction.update(driverRef, {
  rating: Math.round(newRating * 10) / 10,
  totalTrips: newTotalTrips,
  ratedOrders: admin.firestore.FieldValue.arrayUnion(orderId),
  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
});
```

**Vulnerability:**
`ratedOrders` array grows unbounded (line 94). Firestore document size limit is 1MB. A driver with 10,000+ trips will exceed this limit, causing:
1. Document write failures
2. Rating updates stop working
3. Driver profile becomes read-only

**Attack Vector:**
- Long-term active drivers (1+ year)
- High-volume drivers (100+ trips/day)
- Normal platform growth

**Impact:**
- Driver profile corruption
- Rating system failure
- Platform-wide outage for active drivers

**Fix:**
```typescript
// Option 1: Use separate collection for rated orders
const ratedOrderRef = db.collection('driver_rated_orders').doc(`${driverId}_${orderId}`);
const ratedOrderDoc = await transaction.get(ratedOrderRef);

if (ratedOrderDoc.exists) {
  console.log('[AggregateRating] Already processed (idempotent)');
  return;
}

// Create rated order marker
transaction.set(ratedOrderRef, {
  driverId,
  orderId,
  rating,
  processedAt: admin.firestore.FieldValue.serverTimestamp(),
});

// Update driver rating WITHOUT array
transaction.update(driverRef, {
  rating: Math.round(newRating * 10) / 10,
  totalTrips: newTotalTrips,
  lastRatedOrderId: orderId,  // Track last processed order
  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
});

// Option 2: Use rolling window (keep last 100 orders only)
const ratedOrders = driverData.ratedOrders || [];
if (ratedOrders.length >= 100) {
  ratedOrders.shift();  // Remove oldest
}
ratedOrders.push(orderId);

transaction.update(driverRef, {
  rating: Math.round(newRating * 10) / 10,
  totalTrips: newTotalTrips,
  ratedOrders: ratedOrders,  // Replace entire array
  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
});
```

---

## P1 Findings (High)

### P1-1: Batch Operations Without Rollback - Partial Failure Risk

**Severity:** P1 - Data Consistency  
**Component:** `functions/src/expireStaleOrders.ts`  
**Evidence:**
```typescript
File: functions/src/expireStaleOrders.ts
Lines 64-107:
const batch = db.batch();
let expiredCount = 0;

staleOrdersSnapshot.forEach((doc) => {
  const orderData = doc.data();
  
  if (orderData.status === 'matching' && orderData.assignedDriverId === null) {
    batch.update(doc.ref, {
      status: 'expired',
      expiredAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    expiredCount++;
  }
});

// Commit batch update
if (expiredCount > 0) {
  await batch.commit();
}
```

**Vulnerability:**
Batch commit (line 107) is all-or-nothing. If ANY order update fails (e.g., document deleted, permission denied), ENTIRE batch fails. No partial success, no retry logic.

**Attack Vector:**
- Order deleted between query and batch commit
- Firestore quota limits hit mid-batch
- Network interruption during commit

**Impact:**
- Stale orders remain unprocessed
- Function appears successful but no work done
- Silent failures (no error thrown)

**Fix:**
```typescript
// Process in smaller batches with retry
const BATCH_SIZE = 100;
const batches: admin.firestore.WriteBatch[] = [];
let currentBatch = db.batch();
let batchCount = 0;

staleOrdersSnapshot.forEach((doc) => {
  const orderData = doc.data();
  
  if (orderData.status === 'matching' && orderData.assignedDriverId === null) {
    currentBatch.update(doc.ref, {
      status: 'expired',
      expiredAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    batchCount++;
    
    // Split into smaller batches
    if (batchCount >= BATCH_SIZE) {
      batches.push(currentBatch);
      currentBatch = db.batch();
      batchCount = 0;
    }
  }
});

// Add remaining batch
if (batchCount > 0) {
  batches.push(currentBatch);
}

// Commit batches with error handling
const results = await Promise.allSettled(
  batches.map((batch, index) => 
    batch.commit().catch(err => {
      console.error(`[ExpireOrders] Batch ${index} failed:`, err);
      throw err;
    })
  )
);

// Log results
const succeeded = results.filter(r => r.status === 'fulfilled').length;
const failed = results.filter(r => r.status === 'rejected').length;

console.log('[ExpireOrders] Batch results', {
  total_batches: batches.length,
  succeeded,
  failed,
});

if (failed > 0) {
  throw new Error(`${failed} batches failed to commit`);
}
```

---

### P1-2: Non-Atomic Order Updates - Race Condition Risk

**Severity:** P1 - Data Consistency  
**Component:** `functions/src/trackOrderAcceptance.ts`  
**Evidence:**
```typescript
File: functions/src/trackOrderAcceptance.ts
Lines 59-62:
await change.after.ref.update({
  acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
});
```

**Vulnerability:**
Update happens OUTSIDE transaction. If order status changes between trigger and update, `acceptedAt` timestamp is set on wrong status.

**Attack Scenario:**
1. Driver accepts order → status: `accepted`
2. `trackOrderAcceptance` triggers
3. Driver immediately starts trip → status: `onRoute`
4. `trackOrderAcceptance` updates order → sets `acceptedAt` on `onRoute` order
5. Timestamp is incorrect, breaks business logic

**Impact:**
- Incorrect timestamps
- Business logic errors (e.g., "5-minute confirmation" triggers at wrong time)
- Analytics corruption

**Fix:**
```typescript
// Use transaction to ensure status hasn't changed
await admin.firestore().runTransaction(async (transaction) => {
  const orderSnap = await transaction.get(change.after.ref);
  const currentData = orderSnap.data();
  
  // Only update if still in 'accepted' status
  if (currentData?.status === 'accepted') {
    transaction.update(change.after.ref, {
      acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } else {
    console.log('[TrackAcceptance] Status changed, skipping update', {
      order_id: change.after.id,
      current_status: currentData?.status,
    });
  }
});
```

---

### P1-3: Notification Count Increment Race Condition

**Severity:** P1 - Business Logic  
**Component:** `functions/src/notifyUnassignedOrders.ts`  
**Evidence:**
```typescript
File: functions/src/notifyUnassignedOrders.ts
Lines 200-211:
await admin.firestore().runTransaction(async (transaction) => {
  const doc = await transaction.get(docRef);
  const currentCount = doc.exists ? (doc.data()?.count || 0) : 0;
  
  transaction.set(docRef, {
    driverId,
    orderId,
    count: currentCount + 1,
    lastNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
});
```

**Vulnerability:**
Transaction reads `currentCount` (line 202), then sets `count: currentCount + 1` (line 207). This is correct, BUT:
- `merge: true` can cause issues if document structure changes
- Should use `FieldValue.increment(1)` for atomic increment

**Impact:**
- Notification count drift
- Drivers hit limit prematurely or never hit limit
- Spam notifications

**Fix:**
```typescript
await admin.firestore().runTransaction(async (transaction) => {
  const doc = await transaction.get(docRef);
  
  if (doc.exists) {
    // Document exists: use atomic increment
    transaction.update(docRef, {
      count: admin.firestore.FieldValue.increment(1),
      lastNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } else {
    // Document doesn't exist: create with count: 1
    transaction.set(docRef, {
      driverId,
      orderId,
      count: 1,
      lastNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
});
```

---

### P1-4: FCM Token Deletion Without Transaction - Data Loss Risk

**Severity:** P1 - Data Integrity  
**Component:** Multiple files  
**Evidence:**
```typescript
File: functions/src/notifyUnassignedOrders.ts
Lines 310-317:
// Remove invalid token (non-blocking)
admin
  .firestore()
  .collection('drivers')
  .doc(driver.driverId)
  .update({ fcmToken: admin.firestore.FieldValue.delete() })
  .catch((err) =>
    console.error('[NotifyUnassignedOrders] Failed to remove invalid token:', err)
  );
```

**Vulnerability:**
FCM token deletion happens without checking if driver is still online or has active orders. Race condition:
1. Driver A gets invalid token error → function deletes token
2. Driver A refreshes token → updates `fcmToken` field
3. Function's delete operation executes → removes new valid token
4. Driver A can no longer receive notifications

**Impact:**
- Driver loses notifications
- Missed order opportunities
- Revenue loss for driver

**Fix:**
```typescript
// Use transaction to check timestamp before deletion
try {
  await admin.firestore().runTransaction(async (transaction) => {
    const driverRef = admin.firestore().collection('drivers').doc(driver.driverId);
    const driverSnap = await transaction.get(driverRef);
    
    if (!driverSnap.exists) {
      return;
    }
    
    const driverData = driverSnap.data()!;
    const currentToken = driverData.fcmToken;
    
    // Only delete if token hasn't changed
    if (currentToken === driver.fcmToken) {
      transaction.update(driverRef, {
        fcmToken: admin.firestore.FieldValue.delete(),
        fcmTokenInvalidatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      console.log('[NotifyUnassignedOrders] Invalid FCM token removed', {
        driver_id: driver.driverId,
      });
    } else {
      console.log('[NotifyUnassignedOrders] Token already updated, skipping deletion', {
        driver_id: driver.driverId,
      });
    }
  });
} catch (err) {
  console.error('[NotifyUnassignedOrders] Failed to remove invalid token:', err);
}
```

---

### P1-5: Admin SDK FieldValue.delete() Misuse - Partial Update Risk

**Severity:** P1 - Data Integrity  
**Component:** `functions/src/admin/adminDriverActions.ts`  
**Evidence:**
```typescript
File: functions/src/admin/adminDriverActions.ts
Lines 132-138:
await driverRef.update({
  isBlocked: false,
  unblockedAt: admin.firestore.FieldValue.serverTimestamp(),
  unblockedBy: context.auth.uid,
  blockReason: admin.firestore.FieldValue.delete(),
  blockedAt: admin.firestore.FieldValue.delete(),
  blockedBy: admin.firestore.FieldValue.delete(),
  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
});
```

**Vulnerability:**
Multiple `FieldValue.delete()` operations in single update. If ANY field doesn't exist, update still succeeds but leaves partial state. Example:
- Driver was never blocked → `blockReason`, `blockedAt`, `blockedBy` don't exist
- Admin "unblocks" driver → sets `isBlocked: false`, `unblockedAt`, `unblockedBy`
- Driver appears as "unblocked" but was never blocked
- Audit trail is confusing

**Impact:**
- Inconsistent data state
- Audit trail corruption
- Business logic errors

**Fix:**
```typescript
// Check current state before unblocking
const driverDoc = await driverRef.get();
const driverData = driverDoc.data()!;

if (!driverData.isBlocked) {
  throw new functions.https.HttpsError(
    'failed-precondition',
    'Driver is not currently blocked'
  );
}

// Only delete fields that exist
const updateData: any = {
  isBlocked: false,
  unblockedAt: admin.firestore.FieldValue.serverTimestamp(),
  unblockedBy: context.auth.uid,
  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
};

// Conditionally delete fields
if ('blockReason' in driverData) {
  updateData.blockReason = admin.firestore.FieldValue.delete();
}
if ('blockedAt' in driverData) {
  updateData.blockedAt = admin.firestore.FieldValue.delete();
}
if ('blockedBy' in driverData) {
  updateData.blockedBy = admin.firestore.FieldValue.delete();
}

await driverRef.update(updateData);
```

---

### P1-6: Scheduled Function Overlap - Duplicate Processing

**Severity:** P1 - Cost, Performance  
**Component:** `functions/src/notifyUnassignedOrders.ts`  
**Evidence:**
```typescript
File: functions/src/notifyUnassignedOrders.ts
Lines 607-616:
export const notifyUnassignedOrders = functions
  .region('us-central1')
  .runWith({
    timeoutSeconds: 300, // 5 minutes max execution time
    memory: '512MB',
  })
  .pubsub
  .schedule('every 1 minutes')
  .timeZone('Africa/Nouakchott')
  .onRun(async (context) => {
```

**Vulnerability:**
Function runs every 1 minute with 5-minute timeout. If function takes >1 minute, multiple instances run concurrently:
- Instance 1 starts at 00:00, runs until 00:02
- Instance 2 starts at 00:01, runs until 00:03
- Both instances query same orders, send duplicate notifications

**Impact:**
- Duplicate notifications
- Wasted compute resources
- FCM quota exhaustion
- Increased costs

**Fix:**
```typescript
// Option 1: Use Cloud Tasks for exactly-once execution
// Option 2: Add distributed lock

import { Firestore } from '@google-cloud/firestore';

async function acquireLock(lockName: string, ttlSeconds: number): Promise<boolean> {
  const db = admin.firestore();
  const lockRef = db.collection('function_locks').doc(lockName);
  
  try {
    await db.runTransaction(async (transaction) => {
      const lockDoc = await transaction.get(lockRef);
      const now = admin.firestore.Timestamp.now();
      
      if (lockDoc.exists) {
        const lockData = lockDoc.data()!;
        const expiresAt = lockData.expiresAt as admin.firestore.Timestamp;
        
        // Check if lock is still valid
        if (expiresAt.seconds > now.seconds) {
          throw new Error('Lock already held');
        }
      }
      
      // Acquire lock
      transaction.set(lockRef, {
        acquiredAt: now,
        expiresAt: new admin.firestore.Timestamp(now.seconds + ttlSeconds, 0),
        instanceId: process.env.FUNCTION_INSTANCE_ID || 'unknown',
      });
    });
    
    return true;
  } catch (error) {
    console.log('[Lock] Failed to acquire lock', { lock_name: lockName });
    return false;
  }
}

async function releaseLock(lockName: string): Promise<void> {
  const db = admin.firestore();
  await db.collection('function_locks').doc(lockName).delete();
}

// In function:
export const notifyUnassignedOrders = functions
  .pubsub
  .schedule('every 1 minutes')
  .onRun(async (context) => {
    const lockAcquired = await acquireLock('notify_unassigned_orders', 60);
    
    if (!lockAcquired) {
      console.log('[NotifyUnassignedOrders] Another instance is running, skipping');
      return { skipped: true };
    }
    
    try {
      // ... existing logic
    } finally {
      await releaseLock('notify_unassigned_orders');
    }
  });
```

---

### P1-7: Missing Retry Logic for Transient Errors

**Severity:** P1 - Reliability  
**Component:** `functions/src/finance/orderSettlement.ts`  
**Evidence:**
```typescript
File: functions/src/finance/orderSettlement.ts
Lines 47-54:
try {
  await settleOrder(orderId, afterData);
  console.log(`Order ${orderId}: Successfully settled`);
  return null;
} catch (error: any) {
  console.error(`Order ${orderId}: Settlement failed:`, error);
  throw error; // Throw to trigger retry
}
```

**Vulnerability:**
Function throws error to trigger retry (line 53), but:
- No exponential backoff
- No max retry limit
- No distinction between transient vs permanent errors
- Retries can cause duplicate processing if idempotency fails

**Impact:**
- Infinite retry loops
- Cost explosion
- Delayed error detection

**Fix:**
```typescript
// Add retry logic with exponential backoff
import { Firestore } from '@google-cloud/firestore';

const TRANSIENT_ERROR_CODES = [
  'unavailable',
  'deadline-exceeded',
  'resource-exhausted',
  'aborted',
];

async function isTransientError(error: any): Promise<boolean> {
  return TRANSIENT_ERROR_CODES.includes(error.code);
}

try {
  await settleOrder(orderId, afterData);
  console.log(`Order ${orderId}: Successfully settled`);
  return null;
} catch (error: any) {
  console.error(`Order ${orderId}: Settlement failed:`, error);
  
  // Check if error is transient
  if (await isTransientError(error)) {
    console.warn(`Order ${orderId}: Transient error, will retry`, {
      error_code: error.code,
    });
    throw error;  // Allow Cloud Functions to retry
  } else {
    // Permanent error: mark order for manual review
    console.error(`Order ${orderId}: Permanent error, marking for review`, {
      error_code: error.code,
      error_message: error.message,
    });
    
    await change.after.ref.update({
      settlementError: {
        code: error.code,
        message: error.message,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      },
      settlementStatus: 'failed',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // Don't throw - prevent infinite retries
    return null;
  }
}
```

---

### P1-8: Wallet Balance Negative Check Missing

**Severity:** P1 - Financial Integrity  
**Component:** `functions/src/finance/adminPayouts.ts`  
**Evidence:**
```typescript
File: functions/src/finance/adminPayouts.ts
Lines 298-306:
transaction.update(walletRef, {
  balance: admin.firestore.FieldValue.increment(-amount),
  totalDebited: admin.firestore.FieldValue.increment(amount),
  pendingPayout: admin.firestore.FieldValue.increment(-amount),
  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
});

transaction.update(payoutRef, {
  status: 'completed',
  // ...
});
```

**Vulnerability:**
No check if wallet balance is sufficient before debiting. `FieldValue.increment(-amount)` can make balance negative.

**Attack Scenario:**
1. Driver has balance: 100 MRU
2. Admin approves payout: 150 MRU
3. Wallet balance becomes: -50 MRU
4. Driver owes platform money

**Impact:**
- Negative wallet balances
- Financial loss
- Accounting errors

**Fix:**
```typescript
// Check balance before debiting
const walletSnap = await transaction.get(walletRef);
const walletData = walletSnap.data()!;
const currentBalance = walletData.balance || 0;

if (currentBalance < amount) {
  throw new functions.https.HttpsError(
    'failed-precondition',
    `Insufficient wallet balance. Current: ${currentBalance}, Required: ${amount}`
  );
}

// Proceed with debit
transaction.update(walletRef, {
  balance: admin.firestore.FieldValue.increment(-amount),
  totalDebited: admin.firestore.FieldValue.increment(amount),
  pendingPayout: admin.firestore.FieldValue.increment(-amount),
  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
});
```

---

## P2 Findings (Medium)

### P2-1: Missing Input Validation - Amount Limits

**Severity:** P2 - Business Logic  
**Component:** `functions/src/approveTopupRequest.ts`  
**Evidence:**
```typescript
File: functions/src/approveTopupRequest.ts
Lines 65-66:
const { driverId, amount } = requestData;

// No validation of amount
```

**Vulnerability:**
No validation that `amount` is:
- Positive number
- Within reasonable limits (e.g., max 1,000,000 MRU)
- Not NaN or Infinity

**Impact:**
- Admin can approve negative top-ups (steal from driver)
- Admin can approve huge amounts (financial loss)
- NaN/Infinity causes wallet corruption

**Fix:**
```typescript
const { driverId, amount } = requestData;

// Validate amount
if (typeof amount !== 'number' || !Number.isFinite(amount)) {
  throw new functions.https.HttpsError(
    'invalid-argument',
    'Amount must be a finite number'
  );
}

if (amount <= 0) {
  throw new functions.https.HttpsError(
    'invalid-argument',
    'Amount must be positive'
  );
}

const MAX_TOPUP_AMOUNT = 1000000; // 1M MRU
if (amount > MAX_TOPUP_AMOUNT) {
  throw new functions.https.HttpsError(
    'invalid-argument',
    `Amount exceeds maximum allowed (${MAX_TOPUP_AMOUNT} MRU)`
  );
}
```

---

### P2-2: Stale Location Cleanup Without Notification

**Severity:** P2 - User Experience  
**Component:** `functions/src/cleanStaleDriverLocations.ts`  
**Evidence:**
```typescript
File: functions/src/cleanStaleDriverLocations.ts
Lines 62-67:
staleLocations.docs.forEach((doc) => {
  batch.delete(doc.ref);
  deletedDriverIds.push(doc.id);
});

await batch.commit();
```

**Vulnerability:**
Function deletes driver locations without:
- Notifying driver they went offline
- Updating driver's `isOnline` status
- Checking if driver has active orders

**Impact:**
- Driver appears online in app but location is deleted
- Order matching fails
- Driver confusion

**Fix:**
```typescript
// Update driver status before deleting location
for (const doc of staleLocations.docs) {
  const driverId = doc.id;
  
  // Check if driver has active orders
  const activeOrders = await admin.firestore()
    .collection('orders')
    .where('assignedDriverId', '==', driverId)
    .where('status', 'in', ['accepted', 'onRoute'])
    .limit(1)
    .get();
  
  if (!activeOrders.empty) {
    console.warn('[CleanStaleDriverLocations] Driver has active orders, skipping', {
      driver_id: driverId,
    });
    continue;
  }
  
  // Update driver status to offline
  await admin.firestore()
    .collection('drivers')
    .doc(driverId)
    .update({
      isOnline: false,
      lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  
  // Delete location
  batch.delete(doc.ref);
  deletedDriverIds.push(driverId);
}

await batch.commit();
```

---

### P2-3: Missing Transaction Logging

**Severity:** P2 - Auditability  
**Component:** `functions/src/processTripStartFee.ts`  
**Evidence:**
```typescript
File: functions/src/processTripStartFee.ts
Lines 199-215:
transaction.set(ledgerRef, {
  id: ledgerDocId,
  walletId: assignedDriverId,
  type: 'debit',
  source: 'trip_start_fee',
  amount: tripStartFee,
  currency: 'MRU',
  orderId: orderId,
  balanceBefore: currentBalance,
  balanceAfter: currentBalance - tripStartFee,
  note: `Trip start fee for order #${orderId}`,
  metadata: {
    orderPrice,
    feeRate: 0.1,
  },
  createdAt: admin.firestore.FieldValue.serverTimestamp(),
});
```

**Vulnerability:**
Transaction record missing:
- Admin/system actor who triggered it
- IP address (for audit)
- Reversal flag (if fee is refunded)

**Impact:**
- Incomplete audit trail
- Difficult forensics
- Compliance issues

**Fix:**
```typescript
transaction.set(ledgerRef, {
  id: ledgerDocId,
  walletId: assignedDriverId,
  type: 'debit',
  source: 'trip_start_fee',
  amount: tripStartFee,
  currency: 'MRU',
  orderId: orderId,
  balanceBefore: currentBalance,
  balanceAfter: currentBalance - tripStartFee,
  note: `Trip start fee for order #${orderId}`,
  metadata: {
    orderPrice,
    feeRate: 0.1,
    triggeredBy: 'system',  // Add actor
    functionName: 'processTripStartFee',
    reversible: false,  // Cannot be refunded
  },
  createdAt: admin.firestore.FieldValue.serverTimestamp(),
  
  // Audit fields
  auditLog: {
    actor: 'system',
    action: 'debit_trip_start_fee',
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  },
});
```

---

### P2-4: Notification Limit Not Enforced Server-Side

**Severity:** P2 - Spam Prevention  
**Component:** `functions/src/notifyUnassignedOrders.ts`  
**Evidence:**
```typescript
File: functions/src/notifyUnassignedOrders.ts
Lines 233-240:
// Check notification limit
const hasReachedLimit = await hasReachedNotificationLimit(driver.driverId, orderId);
if (hasReachedLimit) {
  return {
    success: false,
    error: 'notification_limit_reached',
  };
}
```

**Vulnerability:**
Notification limit check (line 234) happens BEFORE sending notification (line 285), but increment happens AFTER (line 288). Race condition:
1. Request A checks limit → 9/10 → proceeds
2. Request B checks limit → 9/10 → proceeds
3. Request A sends notification, increments → 10/10
4. Request B sends notification, increments → 11/10
5. Driver receives 11 notifications (limit exceeded)

**Impact:**
- Spam notifications
- FCM quota waste
- Poor UX

**Fix:**
```typescript
// Use transaction for atomic check-and-increment
const canSend = await admin.firestore().runTransaction(async (transaction) => {
  const docRef = admin.firestore()
    .collection('driver_order_notifications')
    .doc(`${driver.driverId}_${orderId}`);
  
  const doc = await transaction.get(docRef);
  const currentCount = doc.exists ? (doc.data()?.count || 0) : 0;
  
  if (currentCount >= MAX_NOTIFICATIONS_PER_DRIVER_ORDER) {
    return false;  // Limit reached
  }
  
  // Increment count atomically
  if (doc.exists) {
    transaction.update(docRef, {
      count: admin.firestore.FieldValue.increment(1),
      lastNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } else {
    transaction.set(docRef, {
      driverId: driver.driverId,
      orderId,
      count: 1,
      lastNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  
  return true;  // Can send
});

if (!canSend) {
  return { success: false, error: 'notification_limit_reached' };
}

// Send notification
const response = await admin.messaging().send(message);
```

---

### P2-5: Order Expiration Without Client Notification

**Severity:** P2 - User Experience  
**Component:** `functions/src/expireStaleOrders.ts`  
**Evidence:**
```typescript
File: functions/src/expireStaleOrders.ts
Lines 81-85:
batch.update(doc.ref, {
  status: 'expired',
  expiredAt: admin.firestore.FieldValue.serverTimestamp(),
  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
});
```

**Vulnerability:**
Order is expired but client is not notified. Client app may still show order as "matching".

**Impact:**
- Client confusion
- Poor UX
- Support tickets

**Fix:**
```typescript
// After batch commit, send notifications
if (expiredCount > 0) {
  await batch.commit();
  
  // Send notifications to clients
  const notificationPromises = staleOrdersSnapshot.docs
    .filter(doc => doc.data().status === 'matching')
    .map(async (doc) => {
      const orderData = doc.data();
      const ownerId = orderData.ownerId;
      
      // Get client FCM token
      const clientDoc = await db.collection('users').doc(ownerId).get();
      const fcmToken = clientDoc.data()?.fcmToken;
      
      if (fcmToken) {
        await admin.messaging().send({
          token: fcmToken,
          notification: {
            title: 'انتهت صلاحية الطلب',
            body: 'لم يتم العثور على سائق متاح. يرجى المحاولة مرة أخرى.',
          },
          data: {
            notificationType: 'order_expired',
            orderId: doc.id,
          },
        });
      }
    });
  
  await Promise.allSettled(notificationPromises);
}
```

---

### P2-6: Missing Monitoring/Alerting for Critical Failures

**Severity:** P2 - Operations  
**Component:** All functions  
**Evidence:**
```typescript
// No structured error reporting to external monitoring
console.error('[ExpireOrders] Error expiring stale orders:', error);
```

**Vulnerability:**
Errors are only logged to Cloud Logging. No:
- Slack/PagerDuty alerts for critical failures
- Metrics tracking (success rate, latency)
- Dead letter queue for failed operations

**Impact:**
- Silent failures go unnoticed
- No operational visibility
- Delayed incident response

**Fix:**
```typescript
// Add error reporting to external service
import { ErrorReporting } from '@google-cloud/error-reporting';

const errors = new ErrorReporting();

try {
  // ... function logic
} catch (error: any) {
  console.error('[ExpireOrders] Error expiring stale orders:', error);
  
  // Report to Error Reporting
  errors.report(error, {
    user: 'system',
    service: 'expireStaleOrders',
    version: process.env.FUNCTION_VERSION || 'unknown',
  });
  
  // Send alert to Slack/PagerDuty
  await sendAlert({
    severity: 'critical',
    title: 'Order Expiration Failed',
    message: error.message,
    context: {
      function: 'expireStaleOrders',
      error_code: error.code,
    },
  });
  
  throw error;
}
```

---

## Summary Table

| ID | Severity | Component | Issue | Impact | Fix Complexity |
|----|----------|-----------|-------|--------|----------------|
| P0-1 | P0 | orderSettlement | Race condition - double credit | Financial loss | Medium |
| P0-2 | P0 | notifyUnassignedOrders | Missing idempotency - duplicate notifications | Spam, quota | Medium |
| P0-3 | P0 | approveTopupRequest | Concurrent wallet creation | Balance corruption | Low |
| P0-4 | P0 | aggregateDriverRating | Unbounded array growth | DoS, document limit | High |
| P1-1 | P1 | expireStaleOrders | Batch without rollback | Partial failures | Medium |
| P1-2 | P1 | trackOrderAcceptance | Non-atomic update | Incorrect timestamps | Low |
| P1-3 | P1 | notifyUnassignedOrders | Count increment race | Notification drift | Low |
| P1-4 | P1 | Multiple | FCM token deletion race | Lost notifications | Medium |
| P1-5 | P1 | adminDriverActions | FieldValue.delete() misuse | Partial state | Low |
| P1-6 | P1 | notifyUnassignedOrders | Function overlap | Duplicate work, cost | High |
| P1-7 | P1 | orderSettlement | Missing retry logic | Infinite loops | Medium |
| P1-8 | P1 | adminPayouts | No balance check | Negative balance | Low |
| P2-1 | P2 | approveTopupRequest | Missing input validation | Invalid amounts | Low |
| P2-2 | P2 | cleanStaleDriverLocations | No driver notification | UX confusion | Low |
| P2-3 | P2 | processTripStartFee | Incomplete audit log | Compliance | Low |
| P2-4 | P2 | notifyUnassignedOrders | Limit not enforced | Spam | Medium |
| P2-5 | P2 | expireStaleOrders | No client notification | UX confusion | Low |
| P2-6 | P2 | All | Missing monitoring | Silent failures | Medium |

---

## Recommended Fix Priority

1. **P0-1** (Settlement race) - IMMEDIATE, blocks production
2. **P0-3** (Wallet creation) - IMMEDIATE, financial risk
3. **P0-4** (Array growth) - HIGH, will cause outages
4. **P0-2** (Notification idempotency) - HIGH, user impact
5. **P1-8** (Balance check) - HIGH, financial risk
6. **P1-1** (Batch rollback) - MEDIUM, reliability
7. **P1-6** (Function overlap) - MEDIUM, cost impact
8. **P1-7** (Retry logic) - MEDIUM, reliability
9. **P1-2, P1-3, P1-4, P1-5** - LOW, data consistency
10. **P2-*** - LOW, quality of life improvements

---

## Testing Recommendations

### Load Testing
- Simulate 100 concurrent order completions → verify single settlement
- Simulate 50 concurrent top-up approvals → verify balance accuracy
- Run scheduled functions with 30-second overlap → verify no duplicates

### Chaos Testing
- Kill function mid-transaction → verify rollback
- Inject Firestore errors → verify retry logic
- Delete documents during batch operations → verify error handling

### Monitoring
- Track wallet balance drift (sum of transactions vs wallet.balance)
- Alert on negative balances
- Track notification send rate vs limit
- Monitor function execution time vs schedule interval

---

## End of Audit Report
