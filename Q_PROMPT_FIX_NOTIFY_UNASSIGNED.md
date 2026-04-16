# Amazon Q Prompt - Fix notifyUnassignedOrders for v2.0

## 🎯 Problem

`notifyUnassignedOrders` is a scheduled function that runs every 5 minutes to re-notify drivers about unassigned orders. With dispatch v2.0, this function will cause **duplicate notifications** because:

1. v2.0 already handles wave-based dispatch with automatic retries
2. `notifyUnassignedOrders` directly sends FCM notifications (bypassing dispatch queue)
3. This creates the same duplicate problem we just solved

## ✅ Solution

We have 2 options:

**Option A (Recommended):** Disable the function completely - v2.0 handles retries
**Option B:** Refactor it to re-enqueue orders instead of sending FCM

---

## 📝 Prompt for Amazon Q

**Context:** We deployed a new dispatch engine v2.0 that uses wave-based dispatch with automatic retries. The old `notifyUnassignedOrders` function sends duplicate FCM notifications. We need to refactor it to work with v2.0 OR disable it.

**Task:** Choose ONE of these approaches:

---

### Approach A: Disable the Function (Safest)

**File:** `functions/src/index.ts`

**Change:**
```typescript
// Line 34 - Comment out the export
// export { notifyUnassignedOrders } from './notifyUnassignedOrders';
```

**Then deploy:**
```bash
cd functions
npm run build
firebase functions:delete notifyUnassignedOrders --force
```

**Reasoning:** v2.0's `processExpiredWaves` already handles retries every minute, so `notifyUnassignedOrders` is redundant and harmful.

---

### Approach B: Refactor to Re-enqueue Orders

**File:** `functions/src/notifyUnassignedOrders.ts`

**Changes needed:**

1. **Update imports:**
```typescript
import { enqueueOrder } from './dispatch';
```

2. **Replace the FCM sending logic with re-enqueue:**

**OLD CODE (around lines 40-80):**
```typescript
// Sends FCM notifications directly
await sendFCMNotification(...);
```

**NEW CODE:**
```typescript
// Instead of sending FCM, re-enqueue the order
await enqueueOrder(
  orderId,
  orderData.pickupLat,
  orderData.pickupLng,
  orderData.price || 0,
  orderData.clientName
);

console.log('[NotifyUnassignedOrders] Order re-enqueued', { orderId });
```

3. **Update the function comment:**
```typescript
/**
 * notifyUnassignedOrders — Re-enqueue Stale Orders
 *
 * Runs every 5 minutes to find orders stuck in 'matching' status
 * and re-enqueue them in the dispatch queue.
 *
 * v2.0 Compatible: Does NOT send FCM directly, instead re-triggers dispatch.
 *
 * Scheduled: every 5 minutes
 */
```

4. **Reduce frequency** (since processExpiredWaves runs every minute):
```typescript
.schedule('every 10 minutes') // Changed from 5 to 10
```

---

## 🎯 Recommended Approach

**Use Approach A (Disable)** because:

1. ✅ v2.0 already handles all retries via `processExpiredWaves`
2. ✅ Cleaner architecture - one retry mechanism
3. ✅ No risk of race conditions
4. ✅ Easier to test and debug

**Only use Approach B if:**
- You want a "safety net" for orders that somehow miss dispatch queue
- You need longer retry windows (5-10 minutes vs 1 minute)

---

## 🔍 Verification Steps

### For Approach A:
```bash
# After deleting function
firebase functions:list | grep notifyUnassignedOrders
# Should return nothing

# Check logs to ensure it's not running
firebase functions:log --only notifyUnassignedOrders
# Should show no recent executions
```

### For Approach B:
```bash
# Deploy updated function
cd functions
npm run build
firebase deploy --only functions:notifyUnassignedOrders

# Check logs
firebase functions:log --only notifyUnassignedOrders --lines 10
# Should show "Order re-enqueued" instead of "Notification sent"
```

---

## 📊 Testing

**Create a stuck order:**
1. Manually create an order in Firestore with `status: 'matching'`
2. Set `createdAt` to 6 minutes ago
3. For Approach A: Should NOT receive any notification (correct behavior)
4. For Approach B: Should see order re-enqueued in logs

---

## ⚠️ Important Notes

1. **Don't do both approaches** - choose one only
2. **Approach A is safer** - recommended for production
3. **Approach B adds complexity** - only if you need redundancy
4. **Monitor for 24 hours** after deployment to ensure no issues

---

**Recommendation:** Start with Approach A. If you see orders getting stuck after 7 days, consider adding Approach B as a backup.

---

**Version:** 2.0.0
**Created:** 2026-04-16
**Priority:** 🔴 Critical (prevents duplicate notifications)
