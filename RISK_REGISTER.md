# WawApp Driver Risk Register

## High-Risk Paths & Vulnerabilities

### 1. Navigation Guard Bypass for Push Notifications
**Risk Description**: Unverified users might gain access to sensitive active-order or notification screens if they are logged in via Phone OTP but have not completed the required PIN entry.
**Affected Files**: 
- `apps/wawapp_driver/lib/core/router/app_router.dart` (Lines 274-282, 301-309)
**Failure Scenario**: An attacker who obtains OTP access could potentially intercept active order data or interact with notifications before passing the `pin-gate`. While this ensures notifications are not dropped, it technically breaches the secondary authentication barrier.

### 2. Silent Tracking Failure Chain
**Risk Description**: The GPS `TrackingService` is tightly coupled to a Firestore stream of the `isOnline` status.
**Affected Files**: 
- `apps/wawapp_driver/lib/services/tracking_service.dart` (Line 54-71)
- `apps/wawapp_driver/lib/services/driver_status_service.dart` (Line 90-123)
**Failure Scenario**: If `DriverStatusService.watchOnlineStatus` drops due to a transient Firestore connection error or permission denial, the stream might silently close or fail to emit. Tracking will immediately stop via `_stopLocationUpdates()`. The driver's app will falsely appear "Online" in the UI (if UI state is optimistic), but they will not receive any dispatch matching.

### 3. FCM Token Desynchronization
**Risk Description**: The dispatch Cloud Functions rely absolutely on the `fcmToken` stored in the `drivers/{uid}` document to send order offers.
**Affected Files**:
- `apps/wawapp_driver/lib/services/fcm_token_manager.dart` (Line 150-182)
- `functions/src/notifyNewOrder.ts` / `notifyNewOrder.v2.ts`
**Failure Scenario**: If a driver logs in on a poor connection and `_syncTokenToFirestore` fails, the backend retains the old token (or no token). `FcmTokenManager` does not have a robust local retry queue for this specific write. The driver will be "Online" and tracking, but orders will fail to reach their device.

### 4. Timestamp Deserialization Fragility
**Risk Description**: Custom parsing of dynamic Timestamp structures from Cloud Functions is brittle.
**Affected Files**:
- `apps/wawapp_driver/lib/services/orders_service.dart` (Lines 72-82)
**Failure Scenario**: If the backend Cloud Function updates its Firebase Admin SDK or serialization approach (e.g., stops emitting `_seconds`/`_nanoseconds` or ISO strings), the list mapping will throw an exception. The catch block returns an empty list `[]` (Line 97), meaning the entire "Nearby Orders" screen will fail silently.

### 5. Delayed Acceptance Lock Release
**Risk Description**: The `AcceptanceLockManager` sets an optimistic 5-second lock on an order during acceptance to prevent duplicate local processing.
**Affected Files**:
- `apps/wawapp_driver/lib/services/orders_service.dart` (Lines 126-128, 342-344)
**Failure Scenario**: If the `acceptOrder` Cloud Function call hangs or takes slightly more than 5 seconds but eventually succeeds, the lock clears prematurely, potentially allowing a duplicate tap. Conversely, if there are non-Firebase exceptions that somehow bypass the catch blocks, the lock might persist indefinitely, permanently blocking the driver from accepting that order.
