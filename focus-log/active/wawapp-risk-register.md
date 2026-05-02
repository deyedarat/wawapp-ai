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
3. orders_service.dart:122 - native trip flag set after API call, crash between leaves driver accepting offers while on trip. Fix: sync flag from active orders stream on startup.
4. orders_service.dart:176 - native trip flag cleared only on transaction success, network failure blocks driver permanently. Fix: tie flag to active orders stream.
5. MyFirebaseMessagingService.kt:337 - 5s Firestore check fails-open, shows notifications for already-assigned offers. ⚠️ Fix: fail-closed on timeout.

## Medium Priority
6. orders_service.dart:126 - 5s acceptance lock allows duplicate accepts on slow network. Fix: clear lock in finally block tied to API call completion.
7. MyFirebaseMessagingService.kt:411 - rejectOffer has no retry, dispatch waits until timeout if driver rejects offline. Fix: local retry queue.
8. MyFirebaseMessagingService.kt:48 - FCM dedup TTL 10min allows delayed ghost notifications. Fix: increase TTL to 1 hour.

## Current Active Issue
- No active critical issues. See risk register for remaining items.

## Technical Debt (Low Priority)
9. notification_service.dart:213,219,229 - FCM streams (onMessage, onForegroundMessage, onMessageOpenedApp) subscriptions not captured or cancelled. Safe due to singleton lifecycle but lacks proper teardown. Fix: capture all three subscriptions and cancel in dispose().
10. fcm_token_manager.dart:42,52 - onTokenRefresh and authStateChanges streams not captured. Safe as permanent singleton. Fix: add teardown mechanism.

## Fixed in This Session
- auth_gate.dart:53 - Duplicate onNewIntent listener on login/logout cycle. Fixed: capture + cancel before re-listen + dispose().
- notification_service.dart:~263 - accept_order handled in both notification_service and auth_gate causing duplicate API calls. Fixed: removed from notification_service.
- NotificationHelper.kt - Foreground tap opened FullScreenNotificationActivity over Flutter screen. Fixed: isForeground() check routes to MainActivity instead.
- NotificationHelper.kt - Channel ID updated to new_orders_v11 to force fresh channel creation on all devices.
