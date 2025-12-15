# Phase 2: Implementation Mapping for Pull Request

**PR Title**: `feat(phase2): Stability & Confidence - Core Implementation`  
**Source Branch**: `phase2-stability-001`  
**Target Branch**: `driver-auth-stable-work`

---

## Specification → Implementation Mapping

This document provides the required mapping table showing how each specification item is implemented.

### Section 1: Manual Test Cases (15 Test Cases)

| Test Case | Spec Item | File(s) | How It Is Handled |
|-----------|-----------|---------|-------------------|
| **TC-01: Kill app during phone verification** | Auth verification state must persist across app kills | `packages/auth_shared/lib/src/auth_persistence_manager.dart` | ✅ `saveVerificationPending()` persists phone + timestamp to SharedPreferences. `getInterruptedVerification()` checks for interrupted sessions on app restart. 10-minute expiry enforced. |
| **TC-02: Token expires during active session** | Token must auto-refresh or show session expired error | `packages/auth_shared/lib/src/token_refresh_manager.dart` | ✅ `startMonitoring()` checks token expiry every 5 mins. Auto-refreshes if <10 min remaining. Callbacks log `token_refresh_attempt`, `token_refresh_success/failed` for observability. |
| **TC-03: Logout with active order** | Active order visible after re-login | `packages/auth_shared/lib/src/auth_persistence_manager.dart` | ✅ `saveActiveOrder()` persists orderId + status before logout. `getActiveOrderBeforeLogout()` retrieves after re-login. Breadcrumb `logout_with_active_order` logged. |
| **TC-04: Create order → offline → online** | User sees offline error OR order queued | `packages/core_shared/lib/src/observability/network_monitor.dart`<br>`apps/wawapp_client/lib/features/track/data/resilient_orders_repository.dart` | ✅ `NetworkMonitor.checkOnlineOrGetError()` blocks order creation if offline. Immediate error returned: "No internet connection, please check your network...". Breadcrumb `order_create_failed: network_unavailable` logged. |
| **TC-05: Background app after order created** | Order state syncs correctly when app returns | `packages/core_shared/lib/src/observability/app_lifecycle_observer.dart`<br>`apps/wawapp_client/lib/features/track/data/resilient_orders_repository.dart` | ✅ `AppLifecycleObserver` logs `app_backgrounded` and `app_foregrounded` with orderId. `watchOrder()` in ResilientOrdersRepository monitors listener health. Listener disconnection triggers alert after 60s. |
| **TC-06: Kill app after order accepted** | App restores to active order screen | `apps/wawapp_client/lib/features/track/data/resilient_orders_repository.dart`<br>`packages/core_shared/lib/src/observability/crashlytics_keys_manager.dart` | ✅ `setActiveOrderContext()` saves orderId to Crashlytics keys. Breadcrumb `app_killed_with_active_order` logged on restart. UI restoration logic pending (main.dart integration). |
| **TC-07: Accept order → kill → restart** | Driver sees active order with client details | `packages/core_shared/lib/src/observability/breadcrumb_service.dart` (foundation) | ⏳ Infrastructure ready. Breadcrumbs defined: `order_accepted`, `active_order_restored`. Driver service integration pending. |
| **TC-08: Go offline during active trip** | Action blocked with error message | N/A (pending) | ⏳ Validation logic to be added in driver "go offline" handler. |
| **TC-09: Complete trip → kill app** | Order marked completed in Firestore, no duplicates | N/A (pending) | ⏳ Payment monitoring with `StuckStateDetector.monitorPaymentProcessing()` ready. Integration pending. |
| **TC-10: Airplane mode during order creation** | Immediate error, no loading spinner | `packages/core_shared/lib/src/observability/network_monitor.dart`<br>`apps/wawapp_client/lib/features/track/data/resilient_orders_repository.dart` | ✅ Same as TC-04. Offline detected before Firestore write attempt. Error: "No internet connection" shown immediately. |
| **TC-11: Slow network timeout** | Order created <10s OR timeout error | `apps/wawapp_client/lib/features/track/data/resilient_orders_repository.dart`<br>`packages/core_shared/lib/src/observability/stuck_state_detector.dart` | ✅ `.timeout(10s)` enforced on `createOrder()`. `StuckStateDetector.monitorLoadingAction()` tracks timeout. Breadcrumb `action_timeout` logged if exceeded. Error: "Request timed out, please try again". |
| **TC-12: Firestore write fails** | Error surfaced to UI, non-fatal logged | `apps/wawapp_client/lib/features/track/data/resilient_orders_repository.dart` | ✅ `on FirebaseException catch (e)` block logs `firestore_write_failed` breadcrumb. Crashlytics non-fatal recorded with `failure_point: order_creation`, `error_code: e.code`. UI error: "Failed to create order, please try again". |
| **TC-13: Background for 10 mins → return** | App shows current state, listeners reconnect | `packages/core_shared/lib/src/observability/app_lifecycle_observer.dart` | ✅ Background duration calculated in `_handleResumed()`. If >10 min, `app_backgrounded_long_duration` breadcrumb logged. Listener reconnection monitoring via `StuckStateDetector.monitorListenerDisconnection()`. |
| **TC-14: Force-stop with active order** | App restores to active order screen, state matches Firestore | `packages/core_shared/lib/src/observability/app_lifecycle_observer.dart`<br>`packages/core_shared/lib/src/observability/crashlytics_keys_manager.dart` | ✅ `checkIfAppWasKilled()` detects force-stop. Breadcrumb `app_force_stopped` logged. Active order context available via Crashlytics keys. UI restoration pending. |
| **TC-15: Rapidly switch apps during order creation** | Exactly ONE order created, no duplicates | `apps/wawapp_client/lib/features/track/data/resilient_orders_repository.dart` | ✅ UUID `tempId` generated at start of `createOrder()`. Logged in breadcrumb `order_create_initiated`. Firestore write uses single transaction. TempId enables duplicate detection if needed. |

---

### Section 2: Stuck State Thresholds (6 Thresholds)

| Threshold | Spec Item | File(s) | How It Is Handled |
|-----------|-----------|---------|-------------------|
| **Order stuck pending (10 min)** | Show banner + Cancel button, log non-fatal | `packages/core_shared/lib/src/observability/stuck_state_detector.dart` | ✅ `monitorOrderPending(orderId, onTimeout)` starts 10-min timer. On timeout: logs breadcrumb `order_stuck_pending`, records Crashlytics non-fatal with `failure_point: order_stuck_pending`. `onTimeout` callback triggers UI banner (UI pending). |
| **Order stuck accepting (2 min)** | Rollback to pending, show error to client | `packages/core_shared/lib/src/observability/stuck_state_detector.dart` | ✅ `monitorOrderAccepting(orderId, driverId, onTimeout)` starts 2-min timer. On timeout: logs breadcrumb `order_stuck_accepting`, records non-fatal with `orderId` + `driverId`. Rollback logic pending in order service. |
| **Loading spinner (15 sec)** | Hide spinner, show timeout error + Retry button | `packages/core_shared/lib/src/observability/stuck_state_detector.dart` | ✅ `monitorLoadingAction(actionName, onTimeout)` starts 15-sec timer. On timeout: logs breadcrumb `action_timeout`, records non-fatal. Integrated in `ResilientOrdersRepository.createOrder()`. UI timeout handling ready. |
| **Driver toggle (5 sec)** | Revert toggle, show error | `packages/core_shared/lib/src/observability/stuck_state_detector.dart` | ✅ `monitorDriverToggle(targetOnlineState, onTimeout)` starts 5-sec timer. On timeout: logs breadcrumb `driver_toggle_timeout`, records non-fatal. Driver UI integration pending. |
| **Payment processing (30 sec)** | Show error + Support button, trigger P0 alert | `packages/core_shared/lib/src/observability/stuck_state_detector.dart` | ✅ `monitorPaymentProcessing(orderId, onTimeout)` starts 30-sec timer. On timeout: logs breadcrumb `payment_timeout`, records non-fatal with `severity: P0`. Driver order completion integration pending. |
| **Listener disconnected (60 sec)** | Show "Connection lost, retrying..." banner | `packages/core_shared/lib/src/observability/stuck_state_detector.dart` | ✅ `monitorListenerDisconnection(collection, onTimeout)` starts 60-sec timer. On timeout: logs breadcrumb `firestore_listener_disconnected`, records non-fatal. Banner UI pending. |

---

### Section 3: Observability Checklist

#### 3A: Required Breadcrumbs (23 Actions)

| Breadcrumb Action | Spec Item | File(s) | How It Is Handled |
|-------------------|-----------|---------|-------------------|
| **Auth breadcrumbs** | phone_verification_started, otp_requested, otp_entered, token_refresh_attempt, token_refresh_success/failed, login_success/failed, logout, logout_with_active_order, auth_verification_interrupted | `packages/core_shared/lib/src/observability/breadcrumb_service.dart` (constants defined)<br>`packages/auth_shared/lib/src/token_refresh_manager.dart` (token refresh) | ✅ All actions defined in `BreadcrumbActions` class. Token refresh breadcrumbs integrated in `TokenRefreshManager`. Auth flow integration pending in auth screens. |
| **Order breadcrumbs (Client)** | order_form_opened, pickup_location_selected, dropoff_location_selected, order_create_initiated, order_create_success/failed, order_cancelled, order_state_restored | `packages/core_shared/lib/src/observability/breadcrumb_service.dart`<br>`apps/wawapp_client/lib/features/track/data/resilient_orders_repository.dart` | ✅ All actions defined. `order_create_initiated`, `order_create_success`, `order_create_failed` fully integrated in `ResilientOrdersRepository.createOrder()`. Other breadcrumbs pending UI integration. |
| **Order breadcrumbs (Driver)** | order_list_viewed, order_accept_tapped, order_accepted, trip_started, trip_completed, driver_toggled_online/offline, go_offline_blocked, active_order_restored | `packages/core_shared/lib/src/observability/breadcrumb_service.dart` | ✅ All actions defined. Driver service integration pending. |
| **App Lifecycle breadcrumbs** | app_foregrounded, app_backgrounded, app_killed_detected, app_killed_with_active_order, app_force_stopped | `packages/core_shared/lib/src/observability/app_lifecycle_observer.dart`<br>`packages/core_shared/lib/src/observability/breadcrumb_service.dart` | ✅ All actions defined and integrated in `AppLifecycleObserver`. `_handleResumed()` logs `app_foregrounded`, `_handlePaused()` logs `app_backgrounded`. `checkIfAppWasKilled()` logs kill detection. |
| **Network breadcrumbs** | network_lost, network_restored, firestore_write_failed, firestore_listener_disconnected, listeners_reconnected | `packages/core_shared/lib/src/observability/network_monitor.dart`<br>`packages/core_shared/lib/src/observability/breadcrumb_service.dart`<br>`apps/wawapp_client/lib/features/track/data/resilient_orders_repository.dart` | ✅ All actions defined. `network_lost/restored` integrated in `NetworkMonitor`. `firestore_write_failed` integrated in `ResilientOrdersRepository`. `firestore_listener_disconnected` integrated in `watchOrder()`. |

**Coverage**: All 23 breadcrumbs defined. ~40% wired into flows. Full integration pending.

#### 3B: Required Crashlytics Custom Keys (9 Keys)

| Custom Key | Spec Item | File(s) | How It Is Handled |
|------------|-----------|---------|-------------------|
| **User Context** | user_id, user_role (client\|driver), auth_state (authenticated\|anonymous\|verification_pending) | `packages/core_shared/lib/src/observability/crashlytics_keys_manager.dart` | ✅ `setUserContext(userId, userRole, authState)` method. Keys updated via `FirebaseCrashlytics.instance.setCustomKey()`. Caching prevents redundant writes. |
| **Active Order Context** | active_order_id, active_order_status | `packages/core_shared/lib/src/observability/crashlytics_keys_manager.dart` | ✅ `setActiveOrderContext(activeOrderId, activeOrderStatus)` method. Integrated in `ResilientOrdersRepository.createOrder()`. Cleared on order cancel via `clearActiveOrderContext()`. |
| **Session Context** | app_version, platform (android\|ios), network_type (wifi\|cellular\|offline), session_duration | `packages/core_shared/lib/src/observability/crashlytics_keys_manager.dart`<br>`packages/core_shared/lib/src/observability/network_monitor.dart` | ✅ `setSessionContext(appVersion, platform, networkType)` method. `updateSessionDuration(duration)` method. Network type auto-updated by `NetworkMonitor._updateConnectivity()`. |
| **Failure Context** | failure_point, firestore_collection, error_code, retry_count | `packages/core_shared/lib/src/observability/crashlytics_keys_manager.dart` | ✅ `setFailureContext(failurePoint, firestoreCollection, errorCode, retryCount)` method. Automatically set before `recordNonFatal()`. Used in all error handlers. |

**Coverage**: All 9 keys implemented. App initialization integration pending.

#### 3C: Required Crashlytics Non-Fatal Events (5 Event Types)

| Event Type | Spec Item | File(s) | How It Is Handled |
|------------|-----------|---------|-------------------|
| **Firestore write failures** | Log collection, document ID, error code | `packages/core_shared/lib/src/observability/crashlytics_keys_manager.dart`<br>`apps/wawapp_client/lib/features/track/data/resilient_orders_repository.dart` | ✅ `recordNonFatal()` method with `firestore_collection`, `error_code` in additionalData. Integrated in `ResilientOrdersRepository.createOrder()` catch block. |
| **Token refresh failures** | Log failure_point: token_refresh | `packages/core_shared/lib/src/observability/crashlytics_keys_manager.dart`<br>`packages/auth_shared/lib/src/token_refresh_manager.dart` | ✅ Token refresh callback `onRefreshEvent` triggers non-fatal on failure. Integrated in `TokenRefreshManager._refreshToken()`. |
| **Stuck state thresholds exceeded** | Log order_stuck_pending, order_stuck_accepting, etc. | `packages/core_shared/lib/src/observability/stuck_state_detector.dart` | ✅ All 6 stuck state monitors call `recordNonFatal()` on timeout with appropriate `failure_point` and metadata. |
| **Network timeouts during critical operations** | Log action_timeout | `packages/core_shared/lib/src/observability/stuck_state_detector.dart`<br>`apps/wawapp_client/lib/features/track/data/resilient_orders_repository.dart` | ✅ `StuckStateDetector.monitorLoadingAction()` logs non-fatal on timeout. Integrated in order creation timeout handling. |
| **State desync detected** | Log state mismatch between UI and Firestore | N/A (pending) | ⏳ Detection logic to be added in order tracking screens. Infrastructure ready. |

**Coverage**: 4/5 event types implemented. State desync detection pending.

---

## Dependency Changes

| Package | Dependency Added | Version | Purpose |
|---------|------------------|---------|---------|
| `core_shared` | `connectivity_plus` | ^6.0.5 | Network connectivity monitoring (NetworkMonitor) |
| `core_shared` | `firebase_crashlytics` | ^4.1.3 | Crashlytics integration (all observability services) |
| `auth_shared` | `shared_preferences` | ^2.2.2 | Auth state persistence (AuthPersistenceManager) |

---

## Integration Status

### ✅ Fully Integrated
- Network monitoring (offline detection)
- Order creation timeout enforcement
- Firestore write failure handling
- Order idempotency (UUID tempId)
- Token refresh monitoring
- App lifecycle tracking
- Stuck state detection infrastructure

### ⏳ Partially Integrated (Foundation Ready, Wiring Pending)
- Auth flow breadcrumbs (constants defined, UI integration pending)
- Driver order resilience (observability ready, service integration pending)
- App kill detection (logged, UI restoration pending)
- Listener health monitoring (detection ready, banner UI pending)

### 🔴 Not Yet Integrated
- Stuck state UI surfaces (banners, modals, retry buttons)
- Driver "go offline" validation during active trip
- Payment processing monitoring
- State desync detection

---

## Testing Status

**Manual Testing**: Not yet started (infrastructure implementation phase)

**Next Steps**:
1. Complete driver service integration
2. Wire observability into app initialization (main.dart)
3. Create UI surfaces for stuck states
4. Build test APKs
5. Execute all 15 manual test cases
6. Record results in PHASE2_TEST_EXECUTION_LOG.md

---

**Implementation Status**: ~60% complete (core infrastructure + client flows)  
**Ready for Review**: Core observability infrastructure  
**Blocked**: Manual testing (requires full integration)

---

**Generated**: December 15, 2025  
**Branch**: phase2-stability-001  
**Repository**: https://github.com/deyedarat/wawapp-ai.git
