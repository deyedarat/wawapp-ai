---
inclusion: fileMatch
fileMatchPattern: "**/notification*,**/fcm*,**/FullScreen*,**/TripReminder*,**/MyFirebaseMessaging*"
---

# Notification Architecture — Driver App

## Critical Rule: Single Source of Truth

Each notification type has ONE handler that controls the UI. Never duplicate.

### Critical Notifications (full-screen)

| Type | UI Handler | Flutter Role |
|------|-----------|--------------|
| `new_order` | Native `FullScreenNotificationActivity` | State tracking only (no navigation) |
| `wave_offer` | Native `FullScreenNotificationActivity` | State tracking only |
| `new_order_nearby` | Native `FullScreenNotificationActivity` | State tracking only |
| `unassigned_order_reminder` | Native `FullScreenNotificationActivity` | State tracking only |
| `trip_start_reminder` | Native `TripReminderActivity` | No-op (just logs) |

### Non-Critical Notifications (foreground)

| Type | Foreground Handler | Background Handler |
|------|-------------------|-------------------|
| `acceptance_confirmation` | Flutter (via FcmForegroundBridge) | Native `handleSimpleNotification()` |
| `order_update` | Flutter | Native |
| `order_cancelled` | Flutter | Native |
| `order_cancelled_by_client` | Flutter | Native |
| `trip_cancelled_by_client` | Flutter | Native |

### Key Rules

1. **Native `MyFirebaseMessagingService` MUST `return` after forwarding to Flutter in foreground** — otherwise duplicate notifications appear.
2. **Never add Flutter navigation for `trip_start_reminder`** — `TripReminderActivity` handles everything (has Firestore timer, correct labels).
3. **`FullScreenNotificationActivity` handles accept/reject natively** — sends intent to `MainActivity` which forwards to Flutter via EventChannel.
4. **Sound is played via `openRawResourceFd()`** — NOT `setDataSource(context, uri)` which fails on Samsung.
5. **Accept flow MUST mark `fcm_dedup` + `active_trip` flag** in native SharedPreferences before launching MainActivity — prevents subsequent waves from showing.

### Stash Policy

Never leave notification-related changes in git stash. Always commit and push to the branch.
