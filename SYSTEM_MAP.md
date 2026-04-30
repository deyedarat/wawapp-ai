# WawApp Driver System Map

## Architecture Overview
The WawApp Driver application is a Flutter monorepo utilizing a multi-package architecture. It relies heavily on Firebase (Firestore, Functions, Auth, Messaging) for backend infrastructure. The system is split into:
- **`apps/wawapp_driver`**: Main application logic, UI, and services.
- **`packages/core_shared`**: Shared data models and utilities (with client app).
- **`packages/auth_shared`**: Shared authentication logic.
- **`functions/src`**: Firebase Cloud Functions backend.

## Major Subsystems & Responsibilities

### 1. Authentication & Navigation (GoRouter + Riverpod)
**Responsibility**: Manages driver session state, login flow (Phone OTP + PIN), and route protection.
- **`apps/wawapp_driver/lib/core/router/app_router.dart`**:
  - `_redirect` (Line 221): Checks `AuthState` and `DriverProfile`. Controls flow to `/login`, `/otp`, `/create-pin`, `/pin-gate`, `/blocked`, and `/`.
  - **Note**: Explicitly bypasses PIN checks for notification routes (`/full-screen-notification`, `/trip-start-reminder`, `/active-order`).
- **`packages/auth_shared/lib/src/phone_pin_auth.dart`**: Core authentication implementation.
- **`apps/wawapp_driver/lib/services/driver_status_service.dart`**:
  - `setOnline` (Line 14) / `setOffline` (Line 47): Writes `isOnline` status to `drivers/{driverId}` document.

### 2. Location Tracking (`TrackingService`)
**Responsibility**: Acquires GPS coordinates and syncs them to Firestore for matching engine.
- **`apps/wawapp_driver/lib/services/tracking_service.dart`**:
  - `startTracking` (Line 40): Subscribes to driver's online status stream.
  - `_startLocationUpdates` (Line 99): Initiates GPS stream.
  - `_writeLocationToFirestore` (Line 271): Writes to `driver_locations/{uid}`. Enforces throttling and a 3-minute max stale keep-alive timer.

### 3. Order & Dispatch Management (`OrdersService`)
**Responsibility**: Fetches orders, manages state transitions, and handles accept/reject workflows.
- **`apps/wawapp_driver/lib/services/orders_service.dart`**:
  - `getNearbyOrders` (Line 34): Calls `getNearbyOrders` Cloud Function.
  - `acceptOrder` (Line 101) & `acceptOfferV2` (Line 306): Initiates acceptance via Cloud Functions (`acceptOrder`, `acceptOrderV2`).
  - `transition` (Line 148): Local transaction to update order status.
  - `watchMyOffers` (Line 410): Listens to `dispatch_offers` collection for v2 dispatch.

### 4. FCM & Notification Routing
**Responsibility**: Lifecycle of FCM tokens, receiving push notifications, and routing to appropriate screens.
- **`apps/wawapp_driver/lib/services/fcm_token_manager.dart`**:
  - `_onTokenRefresh` (Line 64): Listens for FCM token updates.
  - `_syncTokenToFirestore` (Line 150): Writes `fcmToken` and `lastSeen` to `drivers/{uid}`.
- **`apps/wawapp_driver/lib/services/fcm_service.dart`**:
  - `handleNotificationTap` (Line 29): Routes `new_order`, `trip_start_reminder`, etc.
  - `_verifyOrderStillMatching` (Line 149): Guard to prevent routing to unassigned order if already taken.

### 5. Backend Cloud Functions
**Responsibility**: Secure execution of dispatch matching, status verification, and push notifications.
- **`functions/src/dispatch/notifyNewOrder.ts`** & **`functions/src/notifyNewOrder.v2.ts`**: Dispatches FCM payloads to drivers.
- **`functions/src/dispatch/acceptOrder.ts`** & **`functions/src/acceptOrder.v2.ts`**: Processes driver acceptance, enforcing concurrency checks.
- **`functions/src/dispatch/getNearbyOrders.ts`**: Queries spatial data.
- **`functions/src/dispatch/notifyUnassignedOrders.ts`**: Scheduled reminder system.

## Cross-Layer Dependency Chains
1. **FCM Token -> Dispatch Payload**: The Cloud Functions `notifyNewOrder` depend entirely on `fcm_token_manager.dart` successfully syncing tokens to the `drivers/{uid}` document.
2. **Online Status -> Tracking Service**: `TrackingService` internally subscribes to `DriverStatusService.watchOnlineStatus` (Line 54). If the status write fails or stream drops, GPS tracking is silently disabled.
3. **App Router -> Notification Service**: `app_router.dart` bypasses normal `pin-gate` auth walls to allow `FCMService` deep links.
