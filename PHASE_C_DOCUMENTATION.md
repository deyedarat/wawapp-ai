# Phase C: Trip Start Fee & Order Exclusivity

## Overview
Phase C implements atomic trip start fee deduction (10% of order price) when orders transition from accepted → onRoute, with server-side exclusivity enforcement.

## New Fields Added to Orders Collection

### startedAt (timestamp, nullable)
- **When set**: When order status becomes 'onRoute' and fee is successfully deducted
- **Set by**: `processTripStartFee` Cloud Function
- **Purpose**: Track when trip actually started for exclusivity and analytics

### lockedAt (timestamp, nullable)
- **When set**: When order status becomes 'onRoute' to prevent other driver access
- **Set by**: `enforceOrderExclusivity` Cloud Function
- **Purpose**: Server-side exclusivity enforcement

## Existing Collections Used

### wallets
- **Document ID**: Driver's UID
- **Fields**: `balance`, `totalCredited`, `totalDebited`, `pendingPayout`, `type`, `ownerId`, `currency`
- **Usage**: Unified wallet system for all financial operations

### transactions
- **Document ID**: `${orderId}_start_fee` for trip start fees (idempotency)
- **Fields**:
  - `id` (string): Transaction document ID
  - `walletId` (string): Driver's UID
  - `type` (string): "debit"
  - `source` (string): "trip_start_fee"
  - `amount` (number): Positive value (deduction amount)
  - `currency` (string): "MRU"
  - `orderId` (string): Order document ID
  - `balanceBefore` (number): Wallet balance before transaction
  - `balanceAfter` (number): Wallet balance after transaction
  - `note` (string): Human-readable description
  - `metadata` (object): Additional data (orderPrice, feeRate)
  - `createdAt` (timestamp): Transaction timestamp

## Implementation Details

### 1. Trip Start Fee Deduction (`processTripStartFee.ts`)
- **Trigger**: Firestore onUpdate for orders/{orderId}
- **Logic**: Detects accepted → onRoute transition with assignedDriverId != null
- **Fee Calculation**: `Math.round(orderPrice * 0.1)` (10%, rounded to nearest integer)
- **Idempotency**: Uses fixed transaction doc ID `${orderId}_start_fee`
- **Atomic Transaction**:
  1. Check if fee already deducted (idempotency)
  2. Read driver wallet balance
  3. Verify balance >= fee
  4. Deduct fee from wallet (increment totalDebited)
  5. Create transaction record
  6. Set startedAt timestamp on order

### 2. Insufficient Balance Handling
- **Action**: Revert order status to 'accepted'
- **Notification**: Send FCM to driver with required amount
- **No Fee Deduction**: No transaction record created
- **Channel**: "wallet_notifications"

### 3. Order Exclusivity (`enforceOrderExclusivity.ts`)
- **Trigger**: Firestore onWrite for orders/{orderId}
- **Logic**: Monitors driver assignments and status changes
- **Exclusivity**: Sets lockedAt timestamp for onRoute orders
- **Audit**: Logs driver reassignments for security monitoring

## Fee Calculation & Rounding Rules

Following existing finance patterns:
- **Formula**: `Math.round(orderPrice * 0.1)`
- **Examples**:
  - 100 MRU → 10 MRU fee
  - 155 MRU → 16 MRU fee (15.5 rounded up)
  - 154 MRU → 15 MRU fee (15.4 rounded down)

## No Refund Policy

If trip is cancelled after fee deduction:
- Fee is NOT refunded to driver
- Transaction record remains permanent
- Driver must complete trip to earn revenue

## Android Notification Channel

Add to driver app:

```kotlin
val channel = NotificationChannel(
    "wallet_notifications",
    "Wallet & Payment Notifications",
    NotificationManager.IMPORTANCE_HIGH
).apply {
    description = "Balance updates and payment notifications"
    enableVibration(true)
    setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION), null)
}
```

## Firestore Rules Additions

```javascript
// Existing rules already cover wallets and transactions collections
// Phase C uses existing collections, no additional rules needed

// Enhanced order update rules to enforce assigned driver transitions:
function isAssignedDriver() { return resource.data.assignedDriverId == request.auth.uid; }

allow update: if isSignedIn()
  && validStatusTransition() 
  && request.resource.data.status in ["onRoute", "completed", "cancelled", "cancelledByDriver"] 
  && isAssignedDriver(); // Only assigned driver can transition
```

## Security & Exclusivity

### Server-Side Guards
- Only assigned driver can transition order after acceptance
- onRoute orders are locked with lockedAt timestamp
- Driver reassignments are logged for audit

### Client-Side Enforcement
- Driver apps should check assignedDriverId before showing order actions
- Hide orders with assignedDriverId != current driver
- Disable actions for orders with lockedAt timestamp

## Monitoring

### Logs to Monitor
- `[TripStartFee]` - Fee deduction processing
- `[OrderExclusivity]` - Exclusivity enforcement
- `[Analytics]` - trip_start_fee_deducted, driver_reassignment

### Key Metrics
- Fee deduction success rate
- Insufficient balance incidents
- Driver wallet balance trends
- Order exclusivity violations