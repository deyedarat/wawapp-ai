# WawApp System Map

Generated from code inspection. Every path and symbol referenced below was directly read.

---

## 1. Repository Layout

```
root/
├── apps/
│   ├── wawapp_client/          # Flutter client app (order placement)
│   ├── wawapp_driver/          # Flutter driver app (order acceptance + fulfillment)
│   └── wawapp_admin/           # Flutter web admin panel
├── packages/
│   ├── auth_shared/            # Shared auth: PhonePinAuth, AuthState, OtpStage, PinStatus
│   └── core_shared/            # Shared models: Order, DriverProfile, OrderStatus, BaseFCMService
├── functions/                  # Firebase Cloud Functions v1 (Node 20, TypeScript)
│   └── src/
│       ├── auth/               # sendOtp, verifyOtp, createCustomToken, checkPhoneExists, rateLimiting
│       ├── dispatch/           # engine, intake, selectors, notifications, state, counters, types
│       ├── finance/            # orderSettlement, walletOperations, config, adminPayouts
│       ├── admin/              # setAdminRole, adminDriverActions, adminClientActions, adminOrderActions
│       ├── reports/            # getDriverPerformanceReport, getFinancialReport, getReportsOverview
│       └── (root-level .ts)    # acceptOrder, expireStaleOrders, notifyOrderEvents, etc.
├── firestore.rules             # Security rules (single file, ~350 lines)
├── firestore.indexes.json      # Composite indexes
├── firebase.json               # Functions, Firestore, Hosting config
├── .firebaserc                 # Project: wawapp-952d6
├── .github/workflows/          # CI: fast-checks, client_ci, driver_safe_build, firestore-rules-test
├── codemagic.yaml              # Codemagic CI/CD: debug APK, release APK, iOS builds
├── firestore-rules-tests/      # Jest-based Firestore rules test suite
└── hosting/                    # APK distribution via Firebase Hosting
```

---

## 2. Application Layers

### 2.1 Client App (`apps/wawapp_client/`)

**Entry**: `lib/main.dart`
- Firebase init → App Check (PlayIntegrity) → Crashlytics → Sentry → Location bootstrap → `ProviderScope(child: MyApp())`

**Router**: `lib/core/router/app_router.dart`
- GoRouter with `_GoRouterRefreshStream` listening to `authProvider.notifier.stream`
- Redirect logic: CAPTCHA guard → OTP flow → public routes → auth check → PIN gate → PIN create → authenticated
- Debounced (600ms) with critical OTP states bypassing debounce

**Auth flow**: Uses `auth_shared` package's `PhonePinAuth(userCollection: 'users')`
- `AuthNotifier` in `lib/features/auth/providers/auth_service_provider.dart` (overrides shared package version)
- State machine: `PinStatus.unknown → loading → hasPin|noPin|error`

**Key services**:
- `lib/services/fcm_service.dart` — extends `BaseFCMService`, collection='users'
- `lib/services/notification_service.dart` — client-side notification handling
- `lib/core/firebase_boot.dart` — safe Firebase initialization

**Android native**: `android/app/src/main/kotlin/com/wawapp/client/`
- `MainActivity.kt` only (no custom FCM service — uses Flutter plugin default)
- Deep link schemes: `wawapp://`, `https://wawappclient.page.link`
- No full-screen intent, no custom notification channels

### 2.2 Driver App (`apps/wawapp_driver/`)

**Entry**: `lib/main.dart`
- Firebase init (3-attempt retry) → Crashlytics → Firestore offline persistence → Connectivity → FCM token manager → Battery optimization check → No-op background handler → `ProviderScope(child: MyApp())`

**Router**: `lib/core/router/app_router.dart`
- GoRouter with `_RouterRefreshNotifier` driven by `ref.listen` on `authProvider` + `driverProfileStreamProvider`
- Redirect logic: OTP → not authenticated → PIN gate (unknown/loading/error) → no PIN → blocked check → authenticated
- Notification routes (`/full-screen-notification`, `/trip-start-reminder`, `/active-order`) bypass PIN gate

**Auth flow**: Uses `auth_shared` package's `PhonePinAuth(userCollection: 'drivers')`
- `AuthNotifier` in `lib/features/auth/providers/auth_service_provider.dart` (overrides shared package version)
- Same PinStatus state machine as client

**Key services**:
- `lib/services/notification_service.dart` — 6-layer dedup pipeline, central `handleIncomingOffer()` gate
- `lib/services/fcm_service.dart` — extends `BaseFCMService`, collection='drivers' (tap handlers disabled — legacy)
- `lib/services/orders_service.dart` — `getNearbyOrders` (Cloud Function), `acceptOrder` (v1), `acceptOfferV2`, `rejectOffer`, `transition`, `cancelOrder`
- `lib/services/notification_method_channel.dart` — Flutter↔Kotlin bridge for native notifications
- `lib/services/fcm_token_manager.dart` — token refresh management
- `lib/services/location_service.dart` — GPS tracking
- `lib/services/acceptance_lock_manager.dart` — prevents double-acceptance race

**Android native**: `android/app/src/main/kotlin/com/wawapp/driver/`

| File | Responsibility |
|------|---------------|
| `MyFirebaseMessagingService.kt` | Priority-10 FCM handler. Routes: foreground→FcmForegroundBridge, background→NotificationHelper (full-screen intent). Validates order status via Firestore before showing. |
| `FcmForegroundBridge.kt` | EventChannel bridge: Kotlin→Flutter for foreground FCM messages |
| `FullScreenNotificationActivity.kt` | Native call-style UI for new order notifications (background/killed) |
| `TripReminderActivity.kt` | Native amber-theme UI for trip start reminders (background/killed) |
| `NotificationHelper.kt` | Creates v9 notification channels (bypassDnd, USAGE_ALARM), builds CallStyle notifications |
| `SoundRepeatReceiver.kt` | AlarmManager-based sound repetition (Doze-safe) |
| `NotificationDismissReceiver.kt` | Cancels sound repeats on notification swipe-dismiss |
| `OrderActionReceiver.kt` | Handles accept/decline from CallStyle notification buttons |
| `MainActivity.kt` | Flutter engine host, registers EventChannels + MethodChannels |

**Manifest permissions**: INTERNET, FINE_LOCATION, COARSE_LOCATION, FOREGROUND_SERVICE, FOREGROUND_SERVICE_LOCATION, POST_NOTIFICATIONS, USE_FULL_SCREEN_INTENT, WAKE_LOCK, SCHEDULE_EXACT_ALARM, USE_EXACT_ALARM, REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, ACCESS_NOTIFICATION_POLICY

**Deep link schemes**: `wawappdriver://`, `https://wawappdriver.page.link`

### 2.3 Shared Packages

**`packages/auth_shared/`**
- `PhonePinAuth` — singleton, parameterized by `userCollection` ('users' or 'drivers')
  - `ensurePhoneSession()` → calls `sendOtp` Cloud Function
  - `confirmOtp()` → calls `verifyOtp` Cloud Function → `signInWithCustomToken`
  - `verifyPin()` → calls `createCustomToken` Cloud Function → `signInWithCustomToken`
  - `setPin()` → writes `pinHash`+`pinSalt` to Firestore
  - `hasPinHash()` → reads from Firestore (server-first, cache fallback)
- `AuthState` — immutable state: user, pinStatus, otpStage, otpFlowActive, isPinResetFlow, etc.
- `AuthNotifier` (base) — sets `hasPin` (bool), NOT `pinStatus` (enum). Both apps override this.

**`packages/core_shared/`**
- `Order` — unified model with `fromFirestore`, `fromFirestoreWithId`, `toMap`, `copyWith`
- `OrderStatus` — enum with `fromFirestore` (handles legacy values), `toFirestore`, `canTransitionTo`, `createTransitionUpdate`
- `DriverProfile` — model with `isCompleteForOrders` validation
- `BaseFCMService` — abstract: token management, permission requests, Firestore persistence
- `CrashlyticsObserver`, `WawLog`, `DebugConfig` — observability

---

## 3. Cloud Functions

### 3.1 Firestore Triggers (onUpdate/onCreate)

| Function | Trigger | Collection | Condition |
|----------|---------|------------|-----------|
| `notifyNewOrderV2` | `onCreate` | `orders/{orderId}` | `status === 'matching'` → enqueues into dispatch engine |
| `notifyOrderEvents` | `onUpdate` | `orders/{orderId}` | Status changed → sends FCM to client/driver |
| `handleDriverCancellation` | `onUpdate` | `orders/{orderId}` | Status → `cancelled`/`cancelledByDriver` → returns to matching |
| `onOrderCompleted` | `onUpdate` | `orders/{orderId}` | Status → `completed` → settles finances |
| `processTripStartFee` | `onUpdate` | `orders/{orderId}` | `accepted` → `onRoute` → deducts 10% from driver wallet |
| `enforceOrderExclusivity` | `onUpdate` | `orders/{orderId}` | Exclusivity guards |
| `trackOrderAcceptance` | `onUpdate` | `orders/{orderId}` | Tracks acceptance timestamp |
| `aggregateDriverRating` | `onUpdate` | `orders/{orderId}` | Rating submitted → updates driver aggregate |

### 3.2 Scheduled Functions

| Function | Schedule | Purpose |
|----------|----------|---------|
| `expireStaleOrders` | Every 2 min | Expires matching orders older than 8 min |
| `processExpiredWaves` | Every 1 min | Fallback: processes expired dispatch waves |
| `monitorAcceptedOrders` | Every 1 min | Sends escalating trip-start reminders |
| `cleanStaleDriverLocations` | Scheduled | Cleans old driver location docs |
| `cleanupRejectedOrders` | Scheduled | Cleans expired rejection records |
| `autoForceUpdate` | Scheduled | Auto-enables force update after deadline |

### 3.3 Callable Functions (HTTPS)

| Function | Called By | Purpose |
|----------|-----------|---------|
| `sendOtp` | Client/Driver | Sends OTP via Twilio Verify |
| `verifyOtp` | Client/Driver | Verifies OTP, creates/finds user, returns customToken |
| `createCustomToken` | Client/Driver | PIN-based auth with rate limiting |
| `checkPhoneExists` | Client/Driver | Phone existence check |
| `acceptOrder` | Driver (v1) | Legacy order acceptance |
| `acceptOrderV2` | Driver (v2) | Offer-based acceptance with dispatch engine |
| `rejectOffer` | Driver | Explicit offer rejection |
| `getNearbyOrders` | Driver | Server-side nearby order query (bypasses Firestore rules) |
| `handleDriverCancellation` | (trigger) | Returns cancelled orders to matching |
| `requestTripStartExtension` | Driver | Request extra time before trip start |
| `createTopupRequest` | Driver | Create wallet top-up request |
| `approveTopupRequest` | Admin | Approve/reject top-up |
| `updateOrderLocation` | Driver | Secure driver location tracking |
| `deleteAccount` | Client/Driver | Google Play compliance: account deletion |

### 3.4 HTTP Functions

| Function | Trigger | Purpose |
|----------|---------|---------|
| `handleWaveExpirationTask` | Cloud Tasks POST | Precise per-order wave expiration |

### 3.5 Dispatch Engine (`functions/src/dispatch/`)

**Architecture**: Hybrid sequential-wave system

```
Order Created → notifyNewOrderV2 (onCreate)
  → safeEnqueueOrder (intake.ts: normalize → validate → enqueue or quarantine)
    → enqueueOrder (engine.ts: write dispatch_queue, trigger wave 1)
      → processNextWave (transaction: atomic wave status update)
        → sendWaveOffers (find eligible drivers → create dispatch_offers → send FCM)
          → scheduleWaveExpirationTask (Cloud Tasks: precise TTL)

Wave Expires → handleWaveExpirationTask (Cloud Tasks) OR processExpiredWaves (fallback scheduler)
  → processExpiredWavesForOrder
    → expire sent offers → processNextWave (next wave)

Driver Accepts → acceptOrderV2 (callable)
  → handleOfferAcceptance (transaction: validate offer → update order → lock driver → expire other offers → dequeue)

Driver Rejects → rejectOffer (callable)
  → handleOfferRejection (transaction: update offer → clear driver state)
```

**Wave config** (types.ts):
- Wave 1: 1 driver, 3km, 45s TTL
- Wave 2: 3 drivers, 8km, 45s TTL
- Wave 3: 5 drivers, 15km, 45s TTL
- Wave 4+: 5 drivers, 15km, 60s TTL (repeats until order status changes)

**Safety mechanisms**:
- Per-order circuit breaker (3 consecutive failures → `dispatch_stuck_orders`)
- Global circuit breaker (10 failures/min → 30s cooldown)
- Intake quarantine (`dispatch_intake_failures`)
- Architecture violation assertion (rejects raw order data in notification layer)
- Idempotent enqueue (checks existing dispatch_queue doc)

---

## 4. Firestore Collections

### 4.1 Core Collections

| Collection | Owner | Purpose | Key Fields |
|------------|-------|---------|------------|
| `orders` | Client creates, Driver/Functions update | Order lifecycle | status, ownerId, assignedDriverId, pickup, dropoff, price, createdAt |
| `users` | Client | Client profiles + auth | phone, pinHash, pinSalt, fcmToken, name |
| `drivers` | Driver | Driver profiles + auth | phone, pinHash, pinSalt, fcmToken, name, vehicleType, vehiclePlate, city, isVerified, isOnline, isBlocked |
| `clients` | Client | Client profiles (alternate) | phone, name |
| `driver_locations` | Driver | Real-time GPS | latitude/lat, longitude/lng, updatedAt, accuracy |
| `wallets` | Functions | Driver + platform wallets | balance, totalDebited, totalCredited |
| `transactions` | Functions | Financial ledger | walletId, type, amount, orderId, balanceBefore, balanceAfter |

### 4.2 Dispatch Collections

| Collection | Writer | Purpose |
|------------|--------|---------|
| `dispatch_queue` | Functions | Active orders awaiting dispatch (single source of truth) |
| `dispatch_offers` | Functions | Per-driver offers with status lifecycle (sent→accepted/rejected/expired/cancelled) |
| `driver_dispatch_state` | Functions | Per-driver lock state (activeOfferId, activeOrderId, acceptanceLock) |
| `dispatch_metrics` | Functions | Per-order dispatch analytics |
| `dispatch_intake_failures` | Functions | Quarantined orders that failed validation |
| `dispatch_stuck_orders` | Functions | Orders that hit circuit breaker threshold |
| `driver_rejected_orders` | Driver (client SDK) | Driver rejection records (24h TTL) |

### 4.3 Notification/Logging Collections

| Collection | Writer | Purpose |
|------------|--------|---------|
| `notification_log` | Functions | Idempotency log for `notifyOrderEvents` |
| `notification_logs/{driverId}/events` | Driver (client SDK) | Client-side notification event tracking |
| `driver_notifications` | Functions | Per-driver notification records |
| `driver_notification_health` | Driver (client SDK) | Health monitoring reports |
| `bug_reports` | Unauthenticated (client SDK) | OTP error reports (pre-login) |

### 4.4 Admin/Config Collections

| Collection | Writer | Purpose |
|------------|--------|---------|
| `admins` | Admin | Admin profiles |
| `app_config` | Admin | Bank app configs, force update settings |
| `topup_requests` | Driver creates, Admin approves | Wallet top-up requests |
| `payouts` | Functions | Driver payout records |
| `pin_rate_limits` | Functions only | Brute-force protection (locked from client SDK) |

---

## 5. Notification Generation & Handling Paths

### 5.1 New Order → Driver (Full-Screen)

```
Client creates order (Firestore write)
  → notifyNewOrderV2 (onCreate trigger)
    → safeEnqueueOrder → enqueueOrder → processNextWave → sendWaveOffers
      → sendOfferNotification (dispatch/notifications.ts)
        → admin.messaging().send() — DATA-ONLY payload (no notification block)
          → Android: MyFirebaseMessagingService.onMessageReceived()
            → Foreground: FcmForegroundBridge → Flutter NotificationService.handleIncomingOffer()
              → 6-layer dedup → _showFullScreenNotification → ctx.go('/full-screen-notification')
            → Background/Killed: NotificationHelper.showFullScreenNotification()
              → FullScreenNotificationActivity (native call-style UI)
```

### 5.2 Order Status Change → Client

```
Driver accepts/starts/completes order (Firestore update)
  → notifyOrderEvents (onUpdate trigger)
    → getNotificationConfig(before, after)
      → sendNotification(ownerId, orderId, config, 'users')
        → idempotency check (notification_log)
        → admin.messaging().send() — data + APNS notification block
          → Client app: standard Flutter FCM handling
```

### 5.3 Trip Start Reminder → Driver

```
monitorAcceptedOrders (every 1 min scheduler)
  → queries orders where status='accepted'
  → for each: check elapsed time since acceptedAt
    → if >= 3 min and not recently reminded:
      → sendToDriver() — data-only FCM with notificationType='trip_start_reminder'
        → Same MyFirebaseMessagingService path as new orders
          → Background: TripReminderActivity (native amber UI)
          → Foreground: Flutter NotificationService → /trip-start-reminder route
```

### 5.4 Order Expiry → Client

```
expireStaleOrders (every 2 min scheduler)
  → queries orders where status='matching', assignedDriverId=null, createdAt < 8min ago
  → batch update: status='expired'
    → notifyOrderEvents (onUpdate trigger)
      → getNotificationConfig('matching', 'expired') → type='order_expired'
        → sendNotification(ownerId) → FCM to client
```

---

## 6. Auth Flow (Both Apps)

```
Phone Entry → sendOtp Cloud Function → Twilio Verify SMS
  → OTP Screen → verifyOtp Cloud Function → Twilio check → find/create user → customToken
    → signInWithCustomToken → Firebase Auth state change
      → AuthNotifier._checkHasPin() → reads pinHash from Firestore
        → PinStatus.hasPin → Router redirects to home
        → PinStatus.noPin → Router redirects to /create-pin
          → setPin() → writes pinHash+pinSalt to Firestore → PinStatus.hasPin

Returning User → Phone Entry → loginByPin
  → createCustomToken Cloud Function → rate limit check → PIN hash verification → customToken
    → signInWithCustomToken → same flow as above
```

---

## 7. CI/CD & Deployment

### 7.1 GitHub Actions

| Workflow | Trigger | What it does |
|----------|---------|-------------|
| `fast-checks.yml` | Push/PR on `apps/wawapp_driver/**`, `packages/**` | Flutter analyze + test (driver) |
| `wawapp_client_ci.yml` | Push/PR on `apps/wawapp_client/**` | Flutter analyze (client) |
| `wawapp_driver_safe_build.yml` | Push/PR on main/develop | Gradle assembleDebug (Android only, no Flutter) |
| `firestore-rules-test.yml` | Push/PR on `firestore.rules`, `firestore-rules-tests/**` | Syntax validation + 57 Jest security tests |

### 7.2 Codemagic

| Workflow | Trigger | Output |
|----------|---------|--------|
| `android_debug` | Push to main | Debug APK (client) |
| `android_release` | Tag `v*` | Release APK (client) |
| `ios_debug` | Push to develop | iOS debug build (client) |
| `ios_release` | Tag `ios-v*` | IPA → TestFlight (client) |
| `test_workflow` | Pull request | Flutter test + integration test (client) |

### 7.3 Firebase Deployment

- **Project**: `wawapp-952d6`
- **Functions**: `firebase deploy --only functions` (from `functions/` dir)
- **Firestore rules**: `firebase deploy --only firestore:rules` (from root `firestore.rules`)
- **Hosting targets**: `admin` → `wawapp-952d6`, `downloads` → `wawapp-downloads` (APK distribution)

---

## 8. Cross-Layer Dependency Chains

### Chain A: Order Creation → Driver Notification
```
Client Flutter → Firestore write (orders collection)
  → Cloud Functions (notifyNewOrderV2 onCreate)
    → Dispatch Engine (intake → engine → selectors → notifications)
      → FCM (admin.messaging().send)
        → Android Native (MyFirebaseMessagingService.kt)
          → Kotlin NotificationHelper / FcmForegroundBridge
            → Flutter NotificationService / FullScreenNotificationActivity
```
**Layers crossed**: Flutter → Firestore → Cloud Functions → FCM → Android Native → Flutter

### Chain B: Driver Acceptance → Client Notification
```
Driver Flutter → Cloud Function (acceptOrderV2 callable)
  → Dispatch Engine (handleOfferAcceptance transaction)
    → Firestore update (orders.status = 'accepted')
      → Cloud Functions (notifyOrderEvents onUpdate)
        → FCM → Client Flutter
```
**Layers crossed**: Flutter → Cloud Functions → Firestore → Cloud Functions → FCM → Flutter

### Chain C: Trip Start → Fee Deduction
```
Driver Flutter → Firestore transaction (status: accepted → onRoute)
  → Cloud Functions (processTripStartFee onUpdate)
    → Firestore transaction (wallet deduction + ledger write)
      → If insufficient: revert status to 'accepted' + FCM notification
```
**Layers crossed**: Flutter → Firestore → Cloud Functions → Firestore → (optional) FCM → Flutter

### Chain D: Auth (PIN Login)
```
Driver/Client Flutter → Cloud Function (createCustomToken callable)
  → Firestore read (users/drivers collection: phone lookup + PIN hash)
    → Firebase Auth (createCustomToken)
      → Flutter (signInWithCustomToken)
        → Firebase Auth state change → AuthNotifier → Router redirect
```
**Layers crossed**: Flutter → Cloud Functions → Firestore → Firebase Auth → Flutter
