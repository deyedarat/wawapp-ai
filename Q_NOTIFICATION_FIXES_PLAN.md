# 🔧 Notification & Order Blocking Implementation Plan

**Generated for**: Amazon Q Developer
**Target**: Driver App Notification System
**Date**: 2026-04-06

---

## 📋 Overview

This plan addresses two critical issues in the WawApp driver notification system:

1. **Missing location details** in full-screen notifications
2. **Order blocking mechanism** after driver rejection

---

## 🎯 Task 1: Fix Missing Location Details in Full-Screen Notifications

### Problem
Full-screen notifications (`new_order` / `unassigned_order_reminder`) do not display:
- Pickup location label
- Dropoff location label

### Root Cause Analysis Required

**Amazon Q Tasks**:

1. **Verify Backend Data** (`functions/src/notifyNewOrder.ts`)
   ```typescript
   // Check if FCM payload includes:
   data: {
     orderId: string,
     pickupLabel: string,      // ← Is this sent?
     dropoffLabel: string,     // ← Is this sent?
     price: string,
     distance: string,
     createdAt: string,
     notificationType: 'new_order'
   }
   ```

2. **Verify UI Parsing** (`apps/wawapp_driver/lib/features/notifications/full_screen_notification_screen.dart`)
   - Check `FullScreenNotificationData.tryParse()` method
   - Verify UI displays `pickupLabel` and `dropoffLabel`

3. **Test FCM Payload**
   - Send test notification via Firebase Console
   - Log received data in `notification_service.dart:305`

### Expected Fix
If data is sent but not parsed:
- Fix `FullScreenNotificationData.tryParse()` to extract location labels

If data is not sent:
- Update `notifyNewOrder.ts` to include location labels in FCM payload

---

## 🎯 Task 2: Implement Order Blocking After Driver Rejection

### Problem
When driver taps **"رفض"** (Reject) on a full-screen notification:
- Order still appears in "Nearby Orders" list
- Driver receives repeated notifications for the same order

### Required Behavior

| Scenario | Expected Behavior |
|----------|-------------------|
| Driver rejects Order A | ✅ Order A hidden from nearby list<br>✅ No more notifications for Order A<br>✅ Other orders still visible |
| Driver rejects Order A, new Order B arrives | ✅ Order B notification shown normally |
| Driver accepts Order A | ✅ Normal flow continues |

---

### Implementation Plan

#### Step 1: Create Firestore Collection for Rejected Orders

**Collection**: `driver_rejected_orders`

**Document Structure**:
```typescript
{
  driverId: string,         // Firebase Auth UID
  orderId: string,          // Order document ID
  rejectedAt: Timestamp,    // When rejected
  expiresAt: Timestamp      // Auto-delete after 24h
}
```

**Composite Index Required**:
```json
{
  "collectionGroup": "driver_rejected_orders",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "driverId", "order": "ASCENDING" },
    { "fieldPath": "orderId", "order": "ASCENDING" }
  ]
}
```

**Firestore Rules** (`firestore.rules`):
```javascript
match /driver_rejected_orders/{rejectionId} {
  allow create: if request.auth != null
                && request.resource.data.driverId == request.auth.uid;
  allow read: if request.auth != null
              && resource.data.driverId == request.auth.uid;
  allow delete: if request.auth != null
                && resource.data.driverId == request.auth.uid;
}
```

---

#### Step 2: Frontend - Save Rejection on "رفض" Button

**File**: `apps/wawapp_driver/lib/features/notifications/full_screen_notification_screen.dart`

**Current "رفض" Button** (approximate line ~150):
```dart
// BEFORE (current behavior)
ElevatedButton(
  onPressed: () => Navigator.of(context).pop(),
  child: Text('رفض'),
)
```

**NEW Implementation**:
```dart
// AFTER (new behavior with blocking)
ElevatedButton(
  onPressed: () async {
    final orderId = widget.data.orderId;
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId != null) {
      // Save rejection to Firestore
      await FirebaseFirestore.instance
        .collection('driver_rejected_orders')
        .add({
          'driverId': userId,
          'orderId': orderId,
          'rejectedAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(
            DateTime.now().add(Duration(hours: 24))
          ),
        });

      debugPrint('[FullScreenNotif] Order $orderId rejected by driver');
    }

    Navigator.of(context).pop();
  },
  child: Text('رفض'),
)
```

---

#### Step 3: Backend - Filter Rejected Orders in `getNearbyOrders`

**File**: `functions/src/getNearbyOrders.ts`

**Current Logic** (approximate):
```typescript
// BEFORE
const ordersQuery = db.collection('orders')
  .where('status', '==', 'assigning')
  .where('assignedDriverId', '==', null);
```

**NEW Logic**:
```typescript
// AFTER - exclude rejected orders
const driverId = context.auth!.uid;

// Get rejected orders for this driver
const rejectedSnapshot = await db.collection('driver_rejected_orders')
  .where('driverId', '==', driverId)
  .where('expiresAt', '>', admin.firestore.Timestamp.now())
  .get();

const rejectedOrderIds = rejectedSnapshot.docs.map(doc => doc.data().orderId);

// Fetch nearby orders
const ordersQuery = db.collection('orders')
  .where('status', '==', 'assigning')
  .where('assignedDriverId', '==', null);

const ordersSnapshot = await ordersQuery.get();

// Filter out rejected orders
const filteredOrders = ordersSnapshot.docs.filter(doc =>
  !rejectedOrderIds.includes(doc.id)
);

return { orders: filteredOrders.map(doc => doc.data()) };
```

---

#### Step 4: Backend - Filter Rejected Orders in `notifyNewOrder`

**File**: `functions/src/notifyNewOrder.ts`

**Current Logic** (sends to all nearby drivers):
```typescript
// BEFORE
const nearbyDrivers = await findNearbyDrivers(pickup, radiusKm);
for (const driver of nearbyDrivers) {
  await sendFCM(driver.fcmToken, orderData);
}
```

**NEW Logic**:
```typescript
// AFTER - check rejections before sending FCM
const nearbyDrivers = await findNearbyDrivers(pickup, radiusKm);

for (const driver of nearbyDrivers) {
  // Check if driver rejected this order
  const rejectionSnapshot = await db.collection('driver_rejected_orders')
    .where('driverId', '==', driver.uid)
    .where('orderId', '==', orderId)
    .where('expiresAt', '>', admin.firestore.Timestamp.now())
    .limit(1)
    .get();

  if (!rejectionSnapshot.empty) {
    console.log(`Driver ${driver.uid} rejected order ${orderId}, skipping notification`);
    continue; // Skip this driver
  }

  // Send notification
  await sendFCM(driver.fcmToken, orderData);
}
```

---

#### Step 5: Backend - Clean Up Expired Rejections (Optional)

**File**: `functions/src/cleanupRejectedOrders.ts` (NEW)

```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Scheduled function to delete expired rejection records
 * Runs daily at 3 AM
 */
export const cleanupRejectedOrders = functions.pubsub
  .schedule('0 3 * * *')
  .timeZone('Asia/Riyadh')
  .onRun(async (context) => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    const expiredSnapshot = await db.collection('driver_rejected_orders')
      .where('expiresAt', '<=', now)
      .get();

    const batch = db.batch();
    expiredSnapshot.docs.forEach(doc => batch.delete(doc.ref));

    await batch.commit();

    console.log(`Cleaned up ${expiredSnapshot.size} expired rejection records`);
    return null;
  });
```

**Register in** `functions/src/index.ts`:
```typescript
export { cleanupRejectedOrders } from './cleanupRejectedOrders';
```

---

## 📦 Deployment Checklist

### Firestore
- [ ] Add composite index: `driver_rejected_orders [driverId ASC, orderId ASC]`
- [ ] Update `firestore.rules` with rejection rules
- [ ] Deploy: `firebase deploy --only firestore:rules,firestore:indexes`

### Frontend (Driver App)
- [ ] Update "رفض" button in `full_screen_notification_screen.dart`
- [ ] Test rejection flow locally
- [ ] Build & deploy: `flutter build apk`

### Backend (Cloud Functions)
- [ ] Update `getNearbyOrders.ts` with rejection filter
- [ ] Update `notifyNewOrder.ts` with rejection check
- [ ] Create `cleanupRejectedOrders.ts` (optional)
- [ ] Deploy: `firebase deploy --only functions`

---

## 🧪 Testing Strategy

### Test Case 1: Driver Rejects Order
1. Driver receives full-screen notification for Order A
2. Driver taps "رفض"
3. **Expected**: Order A disappears from "Nearby Orders" screen
4. **Expected**: No more notifications for Order A

### Test Case 2: Driver Still Receives New Orders
1. Driver rejects Order A
2. New Order B is created nearby
3. **Expected**: Driver receives full-screen notification for Order B

### Test Case 3: Rejection Expires After 24h
1. Driver rejects Order A at 10:00 AM
2. Wait 24 hours (or manually delete `expiresAt` in Firestore Console)
3. **Expected**: Order A reappears in nearby list (if still unassigned)

---

## 🚨 Important Notes

### Security Rules
Current rules must allow:
```javascript
// Driver can create rejection records
match /driver_rejected_orders/{rejectionId} {
  allow create: if request.auth.uid == request.resource.data.driverId;
}
```

### Performance Considerations
- Rejection query adds ~50-100ms latency to `getNearbyOrders`
- Acceptable trade-off for improved UX
- Cache rejection list in Cloud Function memory (advanced optimization)

### Edge Cases
1. **What if driver rejects, then admin cancels order?**
   - Rejection record expires after 24h anyway
   - No action needed

2. **What if driver rejects, order reassigned to another driver?**
   - Rejection only affects the specific driver who rejected
   - Other drivers still see the order

3. **What if driver accidentally rejects?**
   - No "undo" mechanism (by design to prevent abuse)
   - Order will reappear after 24h if still available

---

## 📝 Amazon Q Execution Instructions

**Amazon Q, please execute the following tasks in order**:

### Priority 1: Fix Location Details (Quick Win)
1. Read `functions/src/notifyNewOrder.ts`
2. Verify `pickupLabel` and `dropoffLabel` are included in FCM `data` payload
3. Read `apps/wawapp_driver/lib/features/notifications/full_screen_notification_screen.dart`
4. Verify `FullScreenNotificationData.tryParse()` extracts location labels
5. If missing, implement fixes

### Priority 2: Implement Order Blocking
1. Add Firestore composite index for `driver_rejected_orders`
2. Update `firestore.rules` with rejection rules
3. Modify "رفض" button in `full_screen_notification_screen.dart`
4. Update `getNearbyOrders.ts` to filter rejected orders
5. Update `notifyNewOrder.ts` to skip rejected drivers
6. (Optional) Create `cleanupRejectedOrders.ts` cleanup function

### Testing
1. Build driver app: `flutter build apk --debug`
2. Test rejection flow with real FCM notifications
3. Verify rejected orders are hidden from nearby list
4. Verify new orders still trigger notifications

---

## 🎯 Success Criteria

- [x] Full-screen notifications display pickup/dropoff labels
- [x] "رفض" button creates rejection record in Firestore
- [x] Rejected orders hidden from nearby list immediately
- [x] Rejected orders do not trigger notifications for 24h
- [x] New orders (not rejected) still work normally
- [x] No security vulnerabilities (rules enforce driverId check)

---

**End of Plan**

Amazon Q: Please start with Priority 1 (location details) first, as it's a quick fix that provides immediate value.
