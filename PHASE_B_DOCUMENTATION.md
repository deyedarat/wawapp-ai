# Phase B: Driver Acceptance Confirmation

## Overview
Phase B sends exactly one confirmation notification to drivers 5 minutes after they accept an order.

## New Fields Added to Orders Collection

### acceptedAt (timestamp)
- **When set**: Automatically when order status becomes 'accepted' AND assignedDriverId != null
- **Set by**: `trackOrderAcceptance` Cloud Function (onUpdate trigger)
- **Purpose**: Track when order was first accepted for 5-minute delay calculation

### acceptConfirmSentAt (timestamp, nullable)
- **When set**: After successfully sending acceptance confirmation notification
- **Set by**: `notifyUnassignedOrders` scheduled function (Phase B logic)
- **Purpose**: Idempotency - ensures only one confirmation is sent per order

## Implementation Details

### 1. Acceptance Tracking (`trackOrderAcceptance.ts`)
- **Trigger**: Firestore onUpdate for orders/{orderId}
- **Logic**: When status becomes 'accepted' AND assignedDriverId is set
- **Action**: Sets `acceptedAt` timestamp and ensures `acceptConfirmSentAt` is null

### 2. Confirmation Notifications (Extended `notifyUnassignedOrders.ts`)
- **Schedule**: Every 1 minute (shared with Phase A)
- **Query**: Orders where status='accepted', acceptedAt <= 5 minutes ago, acceptConfirmSentAt=null
- **Action**: Send notification and set `acceptConfirmSentAt` timestamp

## Notification Details

### Message Content
- **Title**: "تأكيد قبول الطلب" (Order Acceptance Confirmation)
- **Body**: "تم قبول طلبك بنجاح. [pickup] → [dropoff]"
- **Channel**: "acceptance_confirmations"
- **Type**: "acceptance_confirmation"

### Delivery Rules
- Send only if at send time:
  - status == 'accepted'
  - assignedDriverId unchanged from acceptance
  - acceptConfirmSentAt is null
  - now - acceptedAt >= 5 minutes

## Android Notification Channel

Add to driver app:

```kotlin
val channel = NotificationChannel(
    "acceptance_confirmations",
    "Order Acceptance Confirmations",
    NotificationManager.IMPORTANCE_HIGH
).apply {
    description = "Confirmations for accepted orders"
    enableVibration(true)
    setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION), null)
}
```

## Firestore Rules Addition

No additional rules needed - uses existing orders collection with new fields.

## Monitoring

### Logs to Monitor
- `[TrackAcceptance]` - Acceptance timestamp tracking
- `[NotifyAcceptConfirm]` - Confirmation notification processing

### Key Metrics
- Orders with acceptedAt set vs total accepted orders
- Confirmation notifications sent vs eligible orders
- Time accuracy: confirmations sent ~5 minutes after acceptance