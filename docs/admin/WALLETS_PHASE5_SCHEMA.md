# WawApp Wallet & Payout System - Phase 5 Schema

## Overview

Phase 5 introduces a comprehensive **Wallet & Payout System** that makes money flows first-class citizens in WawApp. This system provides:

- **Explicit wallet balances** for drivers and platform
- **Double-entry ledger** via transactions collection
- **Admin-managed payouts** with full audit trail
- **Idempotent order settlement** to prevent double-charging
- **Foundation for external payment integration** (Wise, Stripe, etc.)

**Key Principles:**
- ✅ **Auditability**: Every financial movement is recorded
- ✅ **Idempotency**: Safe retry of operations
- ✅ **Consistency**: 80% driver / 20% platform commission model
- ✅ **Security**: Admin-only payout operations with custom claims
- ✅ **Traceability**: Link transactions to orders and admin actions

---

## Firestore Collections

### 1. `wallets` Collection

Stores current balance and metadata for each financial entity (drivers and platform).

**Document Structure:**

```typescript
{
  id: string;              // Document ID (driverId or "platform_main")
  type: "driver" | "platform";
  ownerId: string | null;  // driverId for drivers, null for platform
  balance: number;         // Current available balance in MRU
  totalCredited: number;   // Lifetime credits (for reporting)
  totalDebited: number;    // Lifetime debits (for reporting)
  pendingPayout: number;   // Amount currently pending in payouts
  currency: "MRU";
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

**Examples:**

**Driver Wallet:**
```json
{
  "id": "driver123",
  "type": "driver",
  "ownerId": "driver123",
  "balance": 125000,
  "totalCredited": 500000,
  "totalDebited": 375000,
  "pendingPayout": 50000,
  "currency": "MRU",
  "createdAt": "2024-01-15T10:00:00Z",
  "updatedAt": "2024-12-09T15:30:00Z"
}
```

**Platform Wallet:**
```json
{
  "id": "platform_main",
  "type": "platform",
  "ownerId": null,
  "balance": 2500000,
  "totalCredited": 2500000,
  "totalDebited": 0,
  "pendingPayout": 0,
  "currency": "MRU",
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-12-09T15:30:00Z"
}
```

**Indexes Required:**
```
Collection: wallets
- type ASC, balance DESC
- ownerId ASC
```

**Business Rules:**
- Driver wallets created automatically on first order completion
- Platform wallet ID is always `"platform_main"`
- Balance can never be negative (enforced by validation)
- `pendingPayout` tracks sum of non-completed payout requests
- All amounts in **MRU** (Mauritanian Ouguiya)

---

### 2. `transactions` Collection

Immutable ledger of all financial movements. Provides complete audit trail.

**Document Structure:**

```typescript
{
  id: string;                    // Auto-generated transaction ID
  walletId: string;              // Reference to wallet document
  type: "credit" | "debit";
  source: TransactionSource;     // See enum below
  amount: number;                // Always positive (> 0)
  currency: "MRU";
  orderId?: string;              // Link to order (for settlements)
  payoutId?: string;             // Link to payout (for payout debits)
  adminId?: string;              // Admin who initiated (for manual/payouts)
  balanceBefore: number;         // Wallet balance before transaction
  balanceAfter: number;          // Wallet balance after transaction
  note?: string;                 // Optional description
  metadata?: Record<string, any>; // Extensible metadata
  createdAt: Timestamp;
}
```

**Transaction Sources (Enum):**
```typescript
type TransactionSource =
  | "order_settlement"      // Automatic: order completed
  | "payout"                // Admin: payout to driver
  | "manual_adjustment"     // Admin: balance correction
  | "refund"                // Future: order refund
  | "bonus"                 // Future: promotional credit
  | "penalty";              // Future: fine/penalty
```

**Examples:**

**Order Settlement (Driver Credit):**
```json
{
  "id": "txn_001",
  "walletId": "driver123",
  "type": "credit",
  "source": "order_settlement",
  "amount": 1000,
  "currency": "MRU",
  "orderId": "order456",
  "balanceBefore": 124000,
  "balanceAfter": 125000,
  "note": "80% of order #order456",
  "metadata": {
    "orderPrice": 1250,
    "driverShare": 0.8
  },
  "createdAt": "2024-12-09T15:30:00Z"
}
```

**Order Settlement (Platform Credit):**
```json
{
  "id": "txn_002",
  "walletId": "platform_main",
  "type": "credit",
  "source": "order_settlement",
  "amount": 250,
  "currency": "MRU",
  "orderId": "order456",
  "balanceBefore": 2499750,
  "balanceAfter": 2500000,
  "note": "20% commission from order #order456",
  "metadata": {
    "orderPrice": 1250,
    "platformShare": 0.2
  },
  "createdAt": "2024-12-09T15:30:00Z"
}
```

**Payout Debit:**
```json
{
  "id": "txn_003",
  "walletId": "driver123",
  "type": "debit",
  "source": "payout",
  "amount": 50000,
  "currency": "MRU",
  "payoutId": "payout789",
  "adminId": "admin001",
  "balanceBefore": 125000,
  "balanceAfter": 75000,
  "note": "Payout via bank transfer",
  "createdAt": "2024-12-09T16:00:00Z"
}
```

**Indexes Required:**
```
Collection: transactions
- walletId ASC, createdAt DESC
- orderId ASC
- payoutId ASC
- source ASC, createdAt DESC
- createdAt DESC
```

**Business Rules:**
- Transactions are **immutable** (never updated or deleted)
- Amount must always be positive
- `balanceBefore` and `balanceAfter` provide audit snapshot
- Each transaction must atomically update the linked wallet
- Timestamps use server-side `FieldValue.serverTimestamp()`

---

### 3. `payouts` Collection

Records admin-triggered payout requests to drivers.

**Document Structure:**

```typescript
{
  id: string;                          // Auto-generated payout ID
  driverId: string;
  walletId: string;                    // Always matches driverId
  amount: number;                      // Payout amount in MRU
  currency: "MRU";
  method: PayoutMethod;                // See enum below
  status: PayoutStatus;                // See enum below
  requestedByAdminId: string;          // Admin who created request
  processedByAdminId?: string;         // Admin who completed/rejected
  transactionId?: string;              // Link to debit transaction
  recipientInfo?: {                    // Payment recipient details
    bankName?: string;
    accountNumber?: string;
    accountName?: string;
    phoneNumber?: string;
    email?: string;
  };
  note?: string;                       // Admin notes
  rejectionReason?: string;            // If status = rejected
  createdAt: Timestamp;
  updatedAt: Timestamp;
  completedAt?: Timestamp;             // When status → completed
}
```

**Payout Methods (Enum):**
```typescript
type PayoutMethod =
  | "manual"           // Manual cash/check
  | "bank_transfer"    // Mauritanian bank transfer
  | "wise"             // Wise.com integration (future)
  | "stripe"           // Stripe Connect (future)
  | "mobile_money";    // Mobile money transfer (future)
```

**Payout Status (Enum):**
```typescript
type PayoutStatus =
  | "requested"   // Initial state
  | "approved"    // Admin approved, ready to process
  | "processing"  // Payment in progress
  | "completed"   // Successfully paid out
  | "rejected";   // Request denied
```

**Status Flow:**
```
requested → approved → processing → completed
    ↓
 rejected
```

**Examples:**

**New Payout Request:**
```json
{
  "id": "payout789",
  "driverId": "driver123",
  "walletId": "driver123",
  "amount": 50000,
  "currency": "MRU",
  "method": "bank_transfer",
  "status": "requested",
  "requestedByAdminId": "admin001",
  "recipientInfo": {
    "bankName": "BNM",
    "accountNumber": "123456789",
    "accountName": "Mohammed Ould Ahmed"
  },
  "note": "Weekly payout",
  "createdAt": "2024-12-09T16:00:00Z",
  "updatedAt": "2024-12-09T16:00:00Z"
}
```

**Completed Payout:**
```json
{
  "id": "payout789",
  "driverId": "driver123",
  "walletId": "driver123",
  "amount": 50000,
  "currency": "MRU",
  "method": "bank_transfer",
  "status": "completed",
  "requestedByAdminId": "admin001",
  "processedByAdminId": "admin002",
  "transactionId": "txn_003",
  "recipientInfo": {
    "bankName": "BNM",
    "accountNumber": "123456789",
    "accountName": "Mohammed Ould Ahmed"
  },
  "note": "Weekly payout",
  "createdAt": "2024-12-09T16:00:00Z",
  "updatedAt": "2024-12-09T17:30:00Z",
  "completedAt": "2024-12-09T17:30:00Z"
}
```

**Indexes Required:**
```
Collection: payouts
- driverId ASC, createdAt DESC
- status ASC, createdAt DESC
- requestedByAdminId ASC, createdAt DESC
- createdAt DESC
```

**Business Rules:**
- Only admins with `isAdmin: true` can create/update payouts
- Amount must be ≤ available wallet balance (balance - pendingPayout)
- When status → `approved`: increment wallet.pendingPayout
- When status → `completed`: create debit transaction, decrement pendingPayout
- When status → `rejected`: decrement wallet.pendingPayout (if was approved)
- All status changes logged to `admin_actions` collection

---

## Financial Flows

### Flow 1: Order Settlement (Order Completed → Wallets)

**Trigger:** Order status changes to `completed`

**Process:**
1. **Validation:**
   - Check order not already settled (use `order.settledAt` field)
   - Verify order has valid price and driverId

2. **Calculate Amounts:**
   ```typescript
   const COMMISSION_RATE = 0.20;
   const orderPrice = order.price;
   const platformFee = Math.round(orderPrice * COMMISSION_RATE);
   const driverEarning = orderPrice - platformFee;
   ```

3. **Atomic Transaction:**
   ```typescript
   await db.runTransaction(async (transaction) => {
     // 1. Get driver wallet (create if not exists)
     const driverWalletRef = db.collection('wallets').doc(order.driverId);
     const driverWallet = await transaction.get(driverWalletRef);
     
     if (!driverWallet.exists) {
       transaction.set(driverWalletRef, {
         id: order.driverId,
         type: 'driver',
         ownerId: order.driverId,
         balance: 0,
         totalCredited: 0,
         totalDebited: 0,
         pendingPayout: 0,
         currency: 'MRU',
         createdAt: FieldValue.serverTimestamp(),
         updatedAt: FieldValue.serverTimestamp(),
       });
     }
     
     // 2. Get platform wallet
     const platformWalletRef = db.collection('wallets').doc('platform_main');
     const platformWallet = await transaction.get(platformWalletRef);
     
     const driverBalance = driverWallet.data()?.balance || 0;
     const platformBalance = platformWallet.data()?.balance || 0;
     
     // 3. Update driver wallet
     transaction.update(driverWalletRef, {
       balance: driverBalance + driverEarning,
       totalCredited: FieldValue.increment(driverEarning),
       updatedAt: FieldValue.serverTimestamp(),
     });
     
     // 4. Update platform wallet
     transaction.update(platformWalletRef, {
       balance: platformBalance + platformFee,
       totalCredited: FieldValue.increment(platformFee),
       updatedAt: FieldValue.serverTimestamp(),
     });
     
     // 5. Create driver transaction
     transaction.set(db.collection('transactions').doc(), {
       walletId: order.driverId,
       type: 'credit',
       source: 'order_settlement',
       amount: driverEarning,
       currency: 'MRU',
       orderId: order.id,
       balanceBefore: driverBalance,
       balanceAfter: driverBalance + driverEarning,
       note: `80% of order #${order.id}`,
       metadata: { orderPrice, driverShare: 0.8 },
       createdAt: FieldValue.serverTimestamp(),
     });
     
     // 6. Create platform transaction
     transaction.set(db.collection('transactions').doc(), {
       walletId: 'platform_main',
       type: 'credit',
       source: 'order_settlement',
       amount: platformFee,
       currency: 'MRU',
       orderId: order.id,
       balanceBefore: platformBalance,
       balanceAfter: platformBalance + platformFee,
       note: `20% commission from order #${order.id}`,
       metadata: { orderPrice, platformShare: 0.2 },
       createdAt: FieldValue.serverTimestamp(),
     });
     
     // 7. Mark order as settled
     transaction.update(db.collection('orders').doc(order.id), {
       settledAt: FieldValue.serverTimestamp(),
     });
   });
   ```

4. **Idempotency:**
   - Check `order.settledAt` field before processing
   - If already set, skip settlement (return success)
   - This prevents double-settlement on function retries

**Result:**
- Driver wallet credited with 80% of order price
- Platform wallet credited with 20% of order price
- Two transaction records created
- Order marked as settled

---

### Flow 2: Admin Payout Request

**Trigger:** Admin creates payout via admin panel or API

**Process:**

1. **Cloud Function: `adminCreatePayoutRequest`**

   **Input:**
   ```typescript
   {
     driverId: string;
     amount: number;
     method: PayoutMethod;
     recipientInfo?: RecipientInfo;
     note?: string;
   }
   ```

   **Validation:**
   - Caller has `isAdmin: true` custom claim
   - Driver wallet exists
   - Amount > 0 and amount ≤ (wallet.balance - wallet.pendingPayout)

   **Execution:**
   ```typescript
   await db.runTransaction(async (transaction) => {
     // 1. Get driver wallet
     const walletRef = db.collection('wallets').doc(driverId);
     const wallet = await transaction.get(walletRef);
     
     const availableBalance = wallet.data().balance - wallet.data().pendingPayout;
     if (amount > availableBalance) {
       throw new Error('Insufficient balance');
     }
     
     // 2. Create payout record
     const payoutRef = db.collection('payouts').doc();
     transaction.set(payoutRef, {
       id: payoutRef.id,
       driverId,
       walletId: driverId,
       amount,
       currency: 'MRU',
       method,
       status: 'requested',
       requestedByAdminId: context.auth.uid,
       recipientInfo,
       note,
       createdAt: FieldValue.serverTimestamp(),
       updatedAt: FieldValue.serverTimestamp(),
     });
     
     // 3. Increment pendingPayout
     transaction.update(walletRef, {
       pendingPayout: FieldValue.increment(amount),
       updatedAt: FieldValue.serverTimestamp(),
     });
     
     // 4. Log admin action
     transaction.set(db.collection('admin_actions').doc(), {
       action: 'createPayoutRequest',
       performedBy: context.auth.uid,
       driverId,
       payoutId: payoutRef.id,
       amount,
       performedAt: FieldValue.serverTimestamp(),
     });
   });
   ```

**Result:**
- Payout record created with status `requested`
- Wallet `pendingPayout` incremented (reserves the amount)
- Admin action logged

---

### Flow 3: Payout Completion

**Trigger:** Admin marks payout as completed (after external transfer)

**Process:**

1. **Cloud Function: `adminUpdatePayoutStatus`**

   **Input:**
   ```typescript
   {
     payoutId: string;
     newStatus: PayoutStatus;
     note?: string;
   }
   ```

   **Validation:**
   - Caller has `isAdmin: true` custom claim
   - Payout exists and not already in final state

   **Execution (status → `completed`):**
   ```typescript
   await db.runTransaction(async (transaction) => {
     // 1. Get payout
     const payoutRef = db.collection('payouts').doc(payoutId);
     const payout = await transaction.get(payoutRef);
     
     if (payout.data().status === 'completed') {
       return; // Already completed, idempotent
     }
     
     // 2. Get wallet
     const walletRef = db.collection('wallets').doc(payout.data().driverId);
     const wallet = await transaction.get(walletRef);
     const currentBalance = wallet.data().balance;
     
     // 3. Create debit transaction
     const txnRef = db.collection('transactions').doc();
     transaction.set(txnRef, {
       walletId: payout.data().driverId,
       type: 'debit',
       source: 'payout',
       amount: payout.data().amount,
       currency: 'MRU',
       payoutId,
       adminId: context.auth.uid,
       balanceBefore: currentBalance,
       balanceAfter: currentBalance - payout.data().amount,
       note: `Payout via ${payout.data().method}`,
       createdAt: FieldValue.serverTimestamp(),
     });
     
     // 4. Update wallet
     transaction.update(walletRef, {
       balance: FieldValue.increment(-payout.data().amount),
       totalDebited: FieldValue.increment(payout.data().amount),
       pendingPayout: FieldValue.increment(-payout.data().amount),
       updatedAt: FieldValue.serverTimestamp(),
     });
     
     // 5. Update payout
     transaction.update(payoutRef, {
       status: 'completed',
       processedByAdminId: context.auth.uid,
       transactionId: txnRef.id,
       completedAt: FieldValue.serverTimestamp(),
       updatedAt: FieldValue.serverTimestamp(),
     });
     
     // 6. Log admin action
     transaction.set(db.collection('admin_actions').doc(), {
       action: 'completePayoutRequest',
       performedBy: context.auth.uid,
       driverId: payout.data().driverId,
       payoutId,
       amount: payout.data().amount,
       performedAt: FieldValue.serverTimestamp(),
     });
   });
   ```

   **Execution (status → `rejected`):**
   ```typescript
   await db.runTransaction(async (transaction) => {
     // 1. Get payout
     const payoutRef = db.collection('payouts').doc(payoutId);
     const payout = await transaction.get(payoutRef);
     
     // 2. Update wallet (release pending amount)
     const walletRef = db.collection('wallets').doc(payout.data().driverId);
     transaction.update(walletRef, {
       pendingPayout: FieldValue.increment(-payout.data().amount),
       updatedAt: FieldValue.serverTimestamp(),
     });
     
     // 3. Update payout
     transaction.update(payoutRef, {
       status: 'rejected',
       processedByAdminId: context.auth.uid,
       rejectionReason: note,
       updatedAt: FieldValue.serverTimestamp(),
     });
     
     // 4. Log admin action
     transaction.set(db.collection('admin_actions').doc(), {
       action: 'rejectPayoutRequest',
       performedBy: context.auth.uid,
       driverId: payout.data().driverId,
       payoutId,
       reason: note,
       performedAt: FieldValue.serverTimestamp(),
     });
   });
   ```

**Result:**
- For `completed`: Wallet debited, transaction created, pendingPayout decremented
- For `rejected`: pendingPayout decremented (amount released back to available)
- Payout status updated
- Admin action logged

---

## Security Rules

**Firestore Security Rules** (add to `firestore.rules`):

```javascript
// Helper: Check if user is admin
function isAdmin() {
  return request.auth != null && request.auth.token.isAdmin == true;
}

// Wallets collection
match /wallets/{walletId} {
  // Admins can read all wallets
  allow read: if isAdmin();
  
  // Drivers can read their own wallet
  allow read: if request.auth != null && 
                 request.auth.uid == walletId &&
                 resource.data.type == 'driver';
  
  // Only Cloud Functions can write (no direct client writes)
  allow write: if false;
}

// Transactions collection
match /transactions/{transactionId} {
  // Admins can read all transactions
  allow read: if isAdmin();
  
  // Drivers can read their own transactions
  allow read: if request.auth != null && 
                 request.auth.uid == resource.data.walletId;
  
  // Only Cloud Functions can write
  allow write: if false;
}

// Payouts collection
match /payouts/{payoutId} {
  // Admins can read all payouts
  allow read: if isAdmin();
  
  // Drivers can read their own payouts
  allow read: if request.auth != null && 
                 request.auth.uid == resource.data.driverId;
  
  // Only Cloud Functions can write
  allow write: if false;
}
```

**Key Points:**
- All write operations MUST go through Cloud Functions (admin-authenticated)
- Drivers can view their own wallets, transactions, and payouts (read-only)
- Admins can view everything
- No direct client writes to prevent tampering

---

## Configuration

**Environment Variables / Constants:**

```typescript
// functions/src/config/finance.ts
export const FINANCE_CONFIG = {
  // Commission rates
  PLATFORM_COMMISSION_RATE: 0.20,  // 20%
  DRIVER_COMMISSION_RATE: 0.80,    // 80%
  
  // Currency
  DEFAULT_CURRENCY: 'MRU',
  
  // Platform wallet
  PLATFORM_WALLET_ID: 'platform_main',
  
  // Limits
  MIN_PAYOUT_AMOUNT: 10000,        // 10,000 MRU minimum payout
  MAX_PAYOUT_AMOUNT: 1000000,      // 1,000,000 MRU maximum single payout
  
  // Audit
  ENABLE_AUDIT_LOGGING: true,
};
```

---

## Future Extensions

**Phase 6+ Enhancements:**

1. **External Payment Integration:**
   - Wise API for international transfers
   - Stripe Connect for automated payouts
   - Mobile money APIs (Mauritel Mobile Money, etc.)

2. **Advanced Features:**
   - Scheduled payouts (weekly, bi-weekly, monthly)
   - Automatic payout thresholds (auto-payout when balance > X)
   - Multi-currency support
   - Currency conversion
   - Refund handling (credit back to client)
   - Bonus/penalty system

3. **Reporting:**
   - Financial forecasting
   - Driver earnings trends
   - Platform revenue analytics
   - Tax reporting exports

4. **Compliance:**
   - KYC/AML checks for drivers
   - Tax withholding
   - Regulatory reporting (Mauritanian financial authorities)

---

## Testing Scenarios

### Scenario 1: First Order Settlement
**Given:** New driver, no wallet  
**When:** First order completed  
**Then:**
- Driver wallet created with balance = driverEarning
- Platform wallet credited with platformFee
- Two transactions recorded
- Order marked as settled

### Scenario 2: Retry Idempotency
**Given:** Order already settled  
**When:** Settlement function runs again (retry)  
**Then:**
- No wallet updates
- No new transactions
- Function returns success (idempotent)

### Scenario 3: Payout Request
**Given:** Driver has balance 100,000 MRU, no pending  
**When:** Admin requests 50,000 MRU payout  
**Then:**
- Payout created with status `requested`
- Wallet pendingPayout = 50,000
- Available balance = 50,000 (100,000 - 50,000)

### Scenario 4: Payout Completion
**Given:** Payout in `requested` status  
**When:** Admin marks as `completed`  
**Then:**
- Wallet balance reduced by payout amount
- Wallet pendingPayout reduced by payout amount
- Debit transaction created
- Payout status = `completed`

### Scenario 5: Payout Rejection
**Given:** Payout in `requested` status  
**When:** Admin marks as `rejected`  
**Then:**
- Wallet pendingPayout reduced (amount released)
- Wallet balance unchanged
- No transaction created
- Payout status = `rejected`

---

## Migration Plan

**For Existing Orders (Before Phase 5):**

1. **Option A: Backfill Settlement**
   - Run a one-time Cloud Function to settle all historical completed orders
   - Create wallets and transactions for past orders
   - Use `settledAt` field to track which orders were backfilled

2. **Option B: Fresh Start**
   - Only settle orders completed after Phase 5 deployment
   - Historical orders remain in Phase 4 reporting only
   - Simpler but loses historical wallet data

**Recommended:** Option A with careful validation and dry-run testing.

---

## Glossary

- **Wallet**: Financial account holding balance for a driver or the platform
- **Transaction**: Immutable ledger entry recording a financial movement
- **Payout**: Admin-initiated transfer from driver wallet to external account
- **Settlement**: Process of crediting wallets when order is completed
- **Pending Payout**: Amount reserved for approved but not completed payouts
- **Available Balance**: `balance - pendingPayout` (amount driver can withdraw)
- **Idempotency**: Ability to safely retry operations without duplication
- **Audit Trail**: Complete history of all financial operations

---

## Summary

Phase 5 establishes a **robust, auditable, and safe** financial system for WawApp:

✅ **Explicit Balances**: Clear wallet balances for drivers and platform  
✅ **Complete Ledger**: Every transaction recorded with full context  
✅ **Admin Control**: Secure payout management with approval workflow  
✅ **Idempotent Operations**: Safe retry of all financial operations  
✅ **Audit Trail**: Full traceability of all money movements  
✅ **Future-Ready**: Foundation for external payment integration  

This system transforms WawApp from a simple order tracker into a comprehensive financial management platform, ready for real-world production use and future scaling.
