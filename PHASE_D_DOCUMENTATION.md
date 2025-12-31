# Phase D: Manual Driver Top-up Flow

## Overview
Phase D implements manual driver top-up requests with admin approval only, using existing wallets and transactions collections.

## Data Model

### topup_requests Collection
- **Document ID**: Auto-generated
- **Fields**:
  - `id` (string): Document ID
  - `driverId` (string): Driver's UID
  - `amount` (number): Top-up amount in MRU
  - `status` (string): 'pending' | 'approved' | 'rejected'
  - `requestedAt` (timestamp): When request was created
  - `processedAt` (timestamp, nullable): When admin processed request
  - `adminId` (string, nullable): Admin who processed request
  - `notes` (string, nullable): Admin notes

## Implementation Details

### 1. Create Top-up Request (`createTopupRequest.ts`)
- **Type**: Callable Cloud Function
- **Auth**: Required, must be driver
- **Validation**: 
  - Amount between 1,000 and 100,000 MRU
  - Driver profile must exist
- **Action**: Creates pending top-up request

### 2. Approve Top-up Request (`approveTopupRequest.ts`)
- **Type**: Callable Cloud Function
- **Auth**: Admin-only (uses existing admin auth pattern)
- **Idempotent**: If already processed, returns success without changes
- **Atomic Transaction**:
  1. Check request status (must be pending)
  2. Get or create driver wallet
  3. Credit wallet balance and totalCredited
  4. Create transaction record with ID `topup_${requestId}`
  5. Update request status to approved

### 3. Reject Top-up Request (`rejectTopupRequest.ts`)
- **Type**: Callable Cloud Function
- **Auth**: Admin-only
- **Action**: Set status to rejected with admin notes

### 4. Wallet Balance Enforcement (`enforceWalletBalance.ts`)
- **Type**: Firestore onUpdate trigger
- **Logic**: When order status becomes 'accepted'
- **Check**: Assigned driver wallet balance > 0
- **Action**: If insufficient or check fails, revert to 'matching' and notify driver
- **Fail-Closed**: On wallet check errors, revert order (no fail-open)
- **Loop Guard**: Uses `walletGuard` field to prevent repeated reverts
  - `walletGuard.reason`: 'INSUFFICIENT_BALANCE' | 'CHECK_FAILED'
  - `walletGuard.blockedAt`: Timestamp when blocked
  - `walletGuard.driverId`: Driver who was blocked

## Transaction Schema

Uses existing `transactions` collection with:
- **Document ID**: `topup_${requestId}` (for idempotency)
- **Fields**: Standard transaction schema
  - `id`, `walletId`, `type: 'credit'`, `source: 'topup'`
  - `amount`, `currency`, `balanceBefore`, `balanceAfter`
  - `note`, `metadata` (includes requestId, adminId, notes)
  - `createdAt`

## Wallet Integration

Uses existing `wallets` collection:
- **Balance Update**: `admin.firestore.FieldValue.increment(amount)`
- **Total Tracking**: Updates `totalCredited` field
- **Consistency**: Follows same pattern as order settlements

## Enforcement Rules

### Backend Enforcement
- **Trigger**: Order status change to 'accepted'
- **Check**: `wallet.balance > 0` for assigned driver
- **Action**: If insufficient, revert order to 'matching' status
- **Notification**: Send FCM to driver about insufficient balance

### Client-Side Integration
- Driver apps should check wallet balance before showing order actions
- Display wallet balance and top-up request status
- Provide UI to create top-up requests

## Firestore Rules

```javascript
// Top-up requests collection
match /topup_requests/{requestId} {
  // Admins can read all requests
  allow read: if isAdmin();
  
  // Drivers can read their own requests
  allow read: if isSignedIn() && 
                 request.auth.uid == resource.data.driverId;
  
  // Drivers can create their own requests
  allow create: if isSignedIn() && 
                   request.auth.uid == request.resource.data.driverId &&
                   request.resource.data.status == 'pending' &&
                   request.resource.data.amount is number &&
                   request.resource.data.amount > 0;
  
  // Only admins can approve/reject (via Cloud Functions)
  allow update: if false;
  allow delete: if false;
}
```

## API Usage

### Driver Creates Request
```javascript
const result = await firebase.functions().httpsCallable('createTopupRequest')({
  amount: 50000 // 50,000 MRU
});
```

### Admin Approves Request
```javascript
const result = await firebase.functions().httpsCallable('approveTopupRequest')({
  requestId: 'request_123',
  notes: 'Approved after verification'
});
```

### Admin Rejects Request
```javascript
const result = await firebase.functions().httpsCallable('rejectTopupRequest')({
  requestId: 'request_123',
  notes: 'Insufficient documentation'
});
```

## Validation Limits

- **Minimum Amount**: 1,000 MRU
- **Maximum Amount**: 100,000 MRU
- **Status Values**: 'pending', 'approved', 'rejected'
- **No Auto-approval**: All requests require manual admin action

## Monitoring

### Logs to Monitor
- `[CreateTopup]` - Top-up request creation
- `[ApproveTopup]` - Admin approval processing
- `[RejectTopup]` - Admin rejection processing
- `[WalletBalance]` - Balance enforcement on order acceptance

### Analytics Events
- `topup_request_created` - Driver creates request
- `topup_approved` - Admin approves request
- `topup_rejected` - Admin rejects request
- `order_rejected_insufficient_balance` - Order blocked due to balance

## Security Features

- **Admin-Only Approval**: Only users with `isAdmin: true` token can approve
- **Driver Ownership**: Drivers can only create/read their own requests
- **Idempotent Processing**: Safe to retry approval operations
- **Balance Enforcement**: Backend prevents order acceptance without balance