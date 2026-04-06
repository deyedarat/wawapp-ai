# Q TASK 5: Update Notification Colors

**Priority:** MEDIUM 🟡
**Estimated Time:** 30 minutes
**Difficulty:** Easy

---

## Objective
Add color coding to notifications:
- 🔴 **Red** for negative events (rejection, cancellation, timeout)
- 🟡 **Yellow** for opportunities (new orders, reminders)
- 🔵 **Blue** for informational updates

---

## Current Problem
All notifications use default colors - no visual distinction between types.

---

## Files to Modify

### 1. `apps/wawapp_driver/lib/services/notification_service.dart`

---

## Implementation Steps

### Step 1: Create Color Helper Method

Add this method after line 109 (after `_createNotificationChannels`):

```dart
/// Determine notification color based on type
Color _getNotificationColor(String notificationType) {
  switch (notificationType) {
    // Red for negative events
    case 'order_cancelled':
    case 'order_cancelled_by_driver':
    case 'timeout_expired':
    case 'insufficient_balance':
      return const Color(0xFFE53935); // Red

    // Yellow for opportunities
    case 'new_order':
    case 'unassigned_order_reminder':
    case 'acceptance_confirmation':
      return const Color(0xFFFDD835); // Yellow

    // Blue for informational updates
    case 'trip_start_reminder':
    case 'order_update':
    default:
      return const Color(0xFF1976D2); // Blue
  }
}
```

---

### Step 2: Update Standard Notifications (Line ~190)

In `_handleForegroundMessage()`, find the `_localNotifications.show()` call (around line 191-207).

**Add these lines:**

```dart
// Get notification color based on type
final color = _getNotificationColor(notificationType);

_localNotifications.show(
  notificationId,
  notification.title,
  notification.body,
  NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      channelName,
      importance: importance,
      priority: priority,
      color: color,            // ADD THIS LINE
      colorized: true,         // ADD THIS LINE
      enableVibration: true,
      playSound: true,
      onlyAlertOnce: true,
    ),
  ),
  payload: payload,
);
```

---

### Step 3: Update Trip Reminder Notifications (Line ~226)

In `_showTripReminderNotification()`, update the `AndroidNotificationDetails`:

```dart
final color = _getNotificationColor('trip_start_reminder');

_localNotifications.show(
  orderId.hashCode,
  'هل وصلت للعميل؟',
  'لديك $remaining دقائق لبدء الرحلة — $pickupLabel',
  NotificationDetails(
    android: AndroidNotificationDetails(
      'trip_reminders',
      'تذكيرات بدء الرحلة',
      importance: Importance.max,
      priority: Priority.max,
      color: color,            // ADD THIS LINE
      colorized: true,         // ADD THIS LINE
      enableVibration: true,
      playSound: true,
      sound: _orderSound,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      onlyAlertOnce: false,
    ),
  ),
  payload: payload,
);
```

---

### Step 4: Update Full-Screen Notifications (Line ~295)

In `_showFullScreenNotification()`, update the notification:

```dart
final type = NotificationHelper.resolveType(data);
final isReminder = type == 'unassigned_order_reminder';
final channelId = isReminder ? 'unassigned_orders' : 'new_orders';
final channelName = isReminder ? 'تذكير بطلبات متاحة' : 'طلبات جديدة';
final color = _getNotificationColor(type);  // ADD THIS LINE

final payload = jsonEncode(data);
final notificationId = notificationData.orderId.hashCode;

_localNotifications.show(
  notificationId,
  'طلب جديد قريب منك',
  '${notificationData.pickupLabel} → ${notificationData.dropoffLabel}',
  NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.max,
      priority: Priority.max,
      color: color,            // ADD THIS LINE
      colorized: true,         // ADD THIS LINE
      enableVibration: true,
      playSound: true,
      sound: _orderSound,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
      onlyAlertOnce: false,
    ),
  ),
  payload: payload,
);
```

---

## Color Reference

```dart
// Red (Negative)
const Color(0xFFE53935)  // Material Red 600

// Yellow (Opportunity)
const Color(0xFFFDD835)  // Material Yellow 600

// Blue (Informational)
const Color(0xFF1976D2)  // Material Blue 700
```

---

## Testing Checklist

- [ ] Accept order → notification bar shows **yellow** icon
- [ ] Receive trip reminder → notification shows **blue** icon
- [ ] Order timeout → notification shows **red** icon
- [ ] Driver cancels order → customer receives **red** notification
- [ ] New order arrives → notification shows **yellow** icon
- [ ] Colors visible in notification shade (pull down)
- [ ] Run `flutter analyze` → 0 errors

---

## Visual Result

**Before:**
- All notifications: gray/default color

**After:**
- New order: 🟡 Yellow notification icon
- Cancellation: 🔴 Red notification icon
- Reminder: 🔵 Blue notification icon

---

## Safety Rules

✅ **DO:**
- Add color and colorized properties
- Preserve all existing notification logic
- Keep all sound/vibration settings

❌ **DON'T:**
- Change notification channels
- Modify FCM data structure
- Remove any existing properties

---

## Verification

After implementation:

```bash
cd apps/wawapp_driver
flutter analyze
```

Expected: **0 errors** (may have existing warnings unrelated to this task)

---

## Report Back to Claude

After completing this task, report:

1. ✅ File modified: `apps/wawapp_driver/lib/services/notification_service.dart`
2. ✅ Added: `_getNotificationColor()` method
3. ✅ Updated: 3 notification locations with color + colorized
4. ✅ `flutter analyze`: 0 errors
5. ✅ Manual test: Notifications show correct colors

---

**Ready to start? Copy this entire task and paste to Amazon Q!**
