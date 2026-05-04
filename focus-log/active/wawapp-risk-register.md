# WawApp Driver - Risk Register & Fix Priority
Generated: 2026-05-01

## Fixed Today - 2026-05-01
1. ✅ PERMISSION_DENIED on order read - fixed by reading from dispatch_offers instead of orders
2. ✅ offer status mismatch 'pending' vs 'sent' - fixed in isOrderStillMatching
3. ✅ releaseDriverState not called after trip completion - fixed in notifyOrderEvents.ts
4. ✅ driver_dispatch_state not cleaned on completion - fixed race condition with assignedDriverId fallback
5. ✅ MIN_DRIVER_ACCURACY_METERS raised from 100 to 800
6. ✅ LOCATION_FRESHNESS_MINUTES raised from 5 to 30
7. ✅ EXPIRATION_TIMEOUT_MS raised from 8 to 60 minutes
8. ✅ Rejected offer reappearing in nearby screen - fixed by filtering watchMyOffers via native SharedPreferences

## Critical Priority
1. notification_service.dart:671 - Driver stuck on trip screen if client cancels while offline. Fix: auto-navigate when active orders stream is empty.
2. connectivity_service.dart:100 - isOnline stays true on disconnect, dispatch sends offers to unreachable driver. ⚠️ Fix: set isOnline false on disconnect, restore on reconnect.

## High Priority
~~3. orders_service.dart:122 - native trip flag set after API call, crash between leaves driver accepting offers while on trip. Fix: sync flag from active orders stream on startup.~~ → FIXED
~~4. orders_service.dart:176 - native trip flag cleared only on transaction success, network failure blocks driver permanently. Fix: tie flag to active orders stream.~~ → FIXED
~~5. MyFirebaseMessagingService.kt:337 - 5s Firestore check fails-open, shows notifications for already-assigned offers. ⚠️ Fix: fail-closed on timeout.~~ → FIXED

## Medium Priority
~~6. orders_service.dart:126 - 5s acceptance lock allows duplicate accepts on slow network. Fix: clear lock in finally block tied to API call completion.~~ → DEFERRED
~~7. MyFirebaseMessagingService.kt:411 - rejectOffer has no retry, dispatch waits until timeout if driver rejects offline. Fix: local retry queue.~~ → DEFERRED
~~8. MyFirebaseMessagingService.kt:48 - FCM dedup TTL 10min allows delayed ghost notifications. Fix: increase TTL to 1 hour.~~ → FIXED

## Current Active Issue
- active_order_screen.dart - Driver stays on trip screen when client cancels while offline. Root cause confirmed: activeOrdersProvider stream returns empty list but no navigation triggered. Fix pending: add ref.listen on activeOrdersProvider to auto-navigate to /nearby when list is empty.

## Current Session Status
- Android-MCP installed at C:\Users\hp\AppData\Local\Programs\Python\Python313\Scripts\android-mcp.exe
- Amazon Q can execute ADB commands directly via terminal tool
- Screenshots saved to C:\Users\hp\Desktop\aws_screenshots\
- Driver device: R83Y20PC4EN (wawapp_driver open, driver online)
- Client device: RZ8R716T96J (screen locked, needs unlock)
- wawapp_test.py script creation pending

## Technical Debt (Low Priority)
9. notification_service.dart:213,219,229 - FCM streams (onMessage, onForegroundMessage, onMessageOpenedApp) subscriptions not captured or cancelled. Safe due to singleton lifecycle but lacks proper teardown. Fix: capture all three subscriptions and cancel in dispose().
10. fcm_token_manager.dart:42,52 - onTokenRefresh and authStateChanges streams not captured. Safe as permanent singleton. Fix: add teardown mechanism.

## Fixed in This Session
- auth_gate.dart:53 - Duplicate onNewIntent listener on login/logout cycle. Fixed: capture + cancel before re-listen + dispose().
- notification_service.dart:~263 - accept_order handled in both notification_service and auth_gate causing duplicate API calls. Fixed: removed from notification_service.
- NotificationHelper.kt - Foreground tap opened FullScreenNotificationActivity over Flutter screen. Fixed: isForeground() check routes to MainActivity instead.
- NotificationHelper.kt - Channel ID updated to new_orders_v11 to force fresh channel creation on all devices.
- orders_service.dart - (item 3) syncActiveTripFlagOnStartup() added, called from notification_system_initializer.dart on startup.
- orders_service.dart - (item 4) setActiveTripFlag(false) moved to finally block in transition() and cancelOrder().
- MyFirebaseMessagingService.kt - (item 8) FCM dedup TTL increased from 10min to 60min, added sentTime check to drop messages older than 60min silently.
- active_order_screen.dart - Driver stays on trip screen when client cancels while offline. Root cause confirmed: activeOrdersProvider stream returns empty list but no navigation triggered. Fix pending: add ref.listen on activeOrdersProvider to auto-navigate to /nearby when list is empty.

## Call-Style Notification Fixes (This Session)
- FIX 1: NotificationHelper.kt — Sound extended to 8 plays over 56s (was 3 plays/8s). Uses existing consumePendingRepeat + SharedPreferences + AlarmManager pattern scaled to 7 repeat slots at 8s intervals. Covers full 60s notification TTL.
- FIX 2: FullScreenNotificationActivity.kt — Firestore snapshot listener added on orders/{orderId}. Auto-dismisses (cancelNotification + finish) on terminal statuses: cancelled, cancelledByClient, cancelledByDriver, expired, accepted, completed. Listener re-attached on onNewIntent, removed on onDestroy. Mirrors Flutter FullScreenNotificationScreen behavior.
- FIX 3: AndroidManifest.xml — Default FCM notification channel corrected from new_orders_v10 to new_orders_v11. Prevents silent notifications when Android auto-displays from FCM notification block before native service runs.
- Build: debug APK built successfully. Devices disconnected — install pending reconnection.

## Deferred (Low Risk)
- orders_service.dart:126 - (item 6) acceptance lock UI-level only. Concurrent programmatic calls possible but rare. Deferred.
- MyFirebaseMessagingService.kt:411 - (item 7) rejectOffer fire-and-forget. Causes dispatch delay not crash. Deferred.
