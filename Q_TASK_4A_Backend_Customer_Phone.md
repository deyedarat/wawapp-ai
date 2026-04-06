# Q TASK 4A: Backend - Add Customer Phone to Order

**Part:** A of 3
**Time:** 20 minutes

---

## Objective
When driver accepts order, fetch customer's phone number from `users` collection and add it to the order document.

---

## File to Modify

### `functions/src/acceptOrder.ts`

---

## Implementation

### Step 1: Locate the Transaction Block

Find the main transaction in `acceptOrder.ts` (around line 80-150).

Look for this code:
```typescript
await db.runTransaction(async (transaction) => {
  const orderDoc = await transaction.get(orderRef);
  // ...
  transaction.update(orderRef, {
    status: 'accepted',
    assignedDriverId: driverId,
    driverId: driverId,
    acceptedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
});
```

---

### Step 2: Add Customer Phone Fetch

**Inside the transaction**, after getting the order document, add this code:

```typescript
// Fetch customer phone number
const ownerId = orderData.ownerId as string;
let customerPhone: string | null = null;

if (ownerId) {
  try {
    const userDoc = await transaction.get(db.collection('users').doc(ownerId));
    if (userDoc.exists) {
      const userData = userDoc.data();
      customerPhone = userData?.phoneNumber as string | null;
    }
  } catch (phoneErr) {
    // Log error but don't fail the acceptance
    console.warn('[AcceptOrder] Failed to fetch customer phone', {
      order_id: orderId,
      owner_id: ownerId,
      error: phoneErr,
    });
  }
}
```

---

### Step 3: Update Order with Phone

Modify the `transaction.update()` call to include `customerPhone`:

```typescript
transaction.update(orderRef, {
  status: 'accepted',
  assignedDriverId: driverId,
  driverId: driverId,
  acceptedAt: FieldValue.serverTimestamp(),
  customerPhone: customerPhone,  // ADD THIS LINE
  updatedAt: FieldValue.serverTimestamp(),
});
```

---

### Step 4: Add Logging

After the transaction succeeds, add a log:

```typescript
console.log('[AcceptOrder] Order accepted with customer phone', {
  order_id: orderId,
  driver_id: driverId,
  has_phone: customerPhone !== null,
});
```

---

## Complete Code Example

Here's how the modified transaction should look:

```typescript
await db.runTransaction(async (transaction) => {
  const orderDoc = await transaction.get(orderRef);

  if (!orderDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'Order not found');
  }

  const orderData = orderDoc.data()!;

  // Validate order status
  if (orderData.status !== 'matching') {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `Order is not available (status: ${orderData.status})`
    );
  }

  // Check if already assigned
  if (orderData.assignedDriverId) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Order already assigned to another driver'
    );
  }

  // Fetch customer phone number
  const ownerId = orderData.ownerId as string;
  let customerPhone: string | null = null;

  if (ownerId) {
    try {
      const userDoc = await transaction.get(db.collection('users').doc(ownerId));
      if (userDoc.exists) {
        const userData = userDoc.data();
        customerPhone = userData?.phoneNumber as string | null;
      }
    } catch (phoneErr) {
      console.warn('[AcceptOrder] Failed to fetch customer phone', {
        order_id: orderId,
        owner_id: ownerId,
        error: phoneErr,
      });
    }
  }

  // Update order
  transaction.update(orderRef, {
    status: 'accepted',
    assignedDriverId: driverId,
    driverId: driverId,
    acceptedAt: FieldValue.serverTimestamp(),
    customerPhone: customerPhone,
    updatedAt: FieldValue.serverTimestamp(),
  });
});

console.log('[AcceptOrder] Order accepted with customer phone', {
  order_id: orderId,
  driver_id: driverId,
  has_phone: customerPhone !== null,
});
```

---

## Testing

After modification:

### 1. Build
```bash
cd functions
npm run build
```

Expected: **No errors**

### 2. Test Locally (Optional)
```bash
firebase emulators:start --only functions
```

### 3. Deploy
```bash
firebase deploy --only functions:acceptOrder
```

### 4. Manual Test
- Accept an order from driver app
- Check Firestore: `orders/{orderId}` should have `customerPhone` field
- If customer has phone in users collection → field populated
- If customer has no phone → field is `null` (OK)

---

## Safety

✅ **Good practices used:**
- Phone fetch is inside transaction (atomic)
- Error in phone fetch doesn't fail acceptance (try-catch)
- Logs success/failure clearly
- Nullable field (backward compatible)

---

## Report Back to Claude

✅ Modified: `functions/src/acceptOrder.ts`
✅ Added: Customer phone fetch from `users` collection
✅ Added: `customerPhone` field to order update
✅ Build: `npm run build` successful
✅ Deploy: `firebase deploy --only functions:acceptOrder` successful
✅ Test: Order document has `customerPhone` field after acceptance

---

**Next:** Proceed to Part B - Update Order Model
