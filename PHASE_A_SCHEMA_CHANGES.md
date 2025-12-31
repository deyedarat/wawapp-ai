# Phase A: Driver Notification Schema Changes

## New Firestore Collection: `driver_order_notifications`

This collection tracks notification counts per driver-order pair to enforce the 10-notification limit.

### Document Structure

**Document ID**: `{driverId}_{orderId}`

**Fields**:
- `driverId` (string): Driver's UID
- `orderId` (string): Order document ID
- `count` (number): Number of notifications sent to this driver for this order
- `lastNotifiedAt` (timestamp): When the last notification was sent
- `updatedAt` (timestamp): Last update timestamp

### Example Document
```json
{
  "driverId": "driver_abc123",
  "orderId": "order_xyz789",
  "count": 3,
  "lastNotifiedAt": "2025-12-28T10:30:00Z",
  "updatedAt": "2025-12-28T10:30:00Z"
}
```

## Firestore Rules Addition

Add this rule to `firestore.rules` for the new collection:

```javascript
// Driver order notification tracking (Cloud Functions only)
match /driver_order_notifications/{docId} {
  allow read, write: if false; // Cloud Functions only
}
```

## TTL Policy (Optional)

Consider adding a TTL policy to auto-delete old notification tracking documents after 7 days to prevent collection growth:

```javascript
// In Firestore console, create TTL policy:
// Collection: driver_order_notifications
// Field: updatedAt
// TTL: 7 days
```

## Android Notification Channel

The driver app needs to register this new notification channel:

```kotlin
// In MainActivity.kt or NotificationHelper.kt
val channel = NotificationChannel(
    "unassigned_orders",
    "Unassigned Order Reminders",
    NotificationManager.IMPORTANCE_HIGH
).apply {
    description = "Repeated notifications for available orders"
    enableVibration(true)
    setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION), null)
}
```

## Cloud Scheduler Job

The function runs automatically via Cloud Scheduler. No manual setup required - Firebase handles this based on the `schedule('every 1 minutes')` configuration.

## Monitoring

Monitor the function in Firebase Console:
- **Function name**: `notifyUnassignedOrders`
- **Trigger**: Cloud Scheduler (every 1 minute)
- **Logs**: Check for `[NotifyUnassignedOrders]` prefixed messages
- **Metrics**: Execution count, duration, errors

## Cost Considerations

- **Function executions**: 1,440 per day (every minute)
- **Firestore reads**: ~100-500 per execution (depending on unassigned orders)
- **FCM messages**: Variable based on unassigned orders and nearby drivers
- **Firestore writes**: 1 per notification sent (for tracking)