# WawApp System Map
**Generated:** 2025-12-30  
**Purpose:** Comprehensive system architecture overview for delivery audit

---

## 1. Repository Structure

```
wawapp-ai/
├── apps/
│   ├── wawapp_client/      # Flutter client app (customers)
│   ├── wawapp_driver/      # Flutter driver app
│   └── wawapp_admin/       # Flutter web admin panel
├── packages/
│   ├── auth_shared/        # Shared auth logic (phone/PIN)
│   └── core_shared/        # Shared models (Order, Profile, etc.)
├── functions/              # Firebase Cloud Functions (Node.js/TypeScript)
├── firestore.rules         # Security rules
├── firestore.indexes.json  # Composite indexes
└── firebase.json           # Firebase config
```

---

## 2. Firebase Project Configuration

**Project ID:** `wawapp-952d6`  
**Environment:** Production + Emulators

### Firebase Services
- **Firestore:** Primary database
- **Authentication:** Phone auth + Custom tokens (PIN-based)
- **Cloud Functions:** Backend logic (Node 18+)
- **Hosting:** Admin panel web hosting
- **Cloud Messaging (FCM):** Push notifications

### Emulator Ports
- Firestore: `8080`
- Auth: `9099`
- Functions: `5001`
- UI: `4000`

---

## 3. Applications

### 3.1 Client App (`wawapp_client`)
**Platform:** Flutter (iOS/Android)  
**User Role:** Customers placing delivery orders

#### Features
- **Auth:** Phone/PIN login, OTP verification
- **Home:** Order creation, saved locations
- **Map:** Pickup/dropoff selection (Google Maps)
- **Quote:** Price calculation, distance estimation
- **Track:** Real-time order tracking
- **Profile:** User settings, logout
- **Shipment Type:** Package type selection

#### Key Services
- `fcm_service.dart` - Push notifications
- `notification_service.dart` - Local notifications
- `analytics_service.dart` - Event tracking

#### Navigation
- Uses Flutter Navigator 2.0 with route guards
- Auth gate checks authentication state

---

### 3.2 Driver App (`wawapp_driver`)
**Platform:** Flutter (iOS/Android)  
**User Role:** Drivers accepting and fulfilling orders

#### Features
- **Auth:** Phone/PIN login, OTP verification, driver claims
- **Home:** Driver status toggle (online/offline)
- **Nearby:** Real-time matching orders feed
- **Active:** Current order management (accept, on-route, complete)
- **Map:** Navigation, location tracking
- **Wallet:** Balance display, transaction history (UI only)
- **Earnings:** Trip statistics
- **History:** Completed orders
- **Profile:** Driver settings, logout

#### Key Services
- `orders_service.dart` - Order CRUD, status updates
- `location_service.dart` - GPS tracking
- `location_throttling_service.dart` - Bandwidth optimization
- `tracking_service.dart` - Real-time location updates
- `driver_status_service.dart` - Online/offline state
- `driver_cleanup_service.dart` - Cleanup on logout
- `fcm_service.dart` - Push notifications

#### Critical Flows
1. **Go Online:** Updates `driver_locations` collection
2. **Accept Order:** Updates order status to `accepted`, sets `assignedDriverId`
3. **Location Updates:** Throttled writes to `driver_locations/{driverId}`
4. **Complete Order:** Triggers wallet settlement via Cloud Function

---

### 3.3 Admin Panel (`wawapp_admin`)
**Platform:** Flutter Web  
**User Role:** Platform administrators

#### Features (from README)
- Dashboard with stats
- User/driver management
- Order monitoring
- Reports (financial, performance)
- Payout management

**Hosting:** Firebase Hosting at `apps/wawapp_admin/build/web`

---

## 4. Shared Packages

### 4.1 `auth_shared`
**Exports:**
- `phone_pin_auth.dart` - Phone/PIN authentication logic
- `auth_state.dart` - Authentication state model
- `auth_notifier.dart` - State management
- `phone_utils.dart` - Phone number formatting/validation

**Used by:** Client, Driver, Admin apps

---

### 4.2 `core_shared`
**Exports:**
- `order.dart` - Unified Order model
- `order_status.dart` - Order status enum
- `client_profile.dart` - Client user model
- `driver_profile.dart` - Driver user model
- `saved_location.dart` - Saved location model
- `analytics/analytics.dart` - Analytics helpers
- `fcm/fcm.dart` - FCM helpers
- `app_error.dart` - Error handling
- `date_normalizer.dart` - Date utilities

**Critical Model:** `Order` class with dual constructors:
- `fromFirestore(Map)` - Client app compatibility
- `fromFirestoreWithId(String, Map)` - Driver app compatibility

---

## 5. Firestore Collections

### 5.1 `users`
**Purpose:** Client user profiles  
**Key Fields:**
- `phone` (E.164 format)
- `pinHash`, `pinSalt` (SHA-256 hashed PIN)
- `totalTrips`, `averageRating` (admin-managed)
- Subcollection: `savedLocations`

**Security:**
- Read/write: Owner only
- No list queries (prevents phone enumeration)
- PIN fields must be updated together

---

### 5.2 `drivers`
**Purpose:** Driver profiles  
**Key Fields:**
- `phone`, `pinHash`, `pinSalt`
- `isVerified`, `rating`, `totalTrips`, `ratedOrders` (admin-managed)
- `fcmToken` (for notifications)

**Security:**
- Read/write: Owner only
- Admin has full access
- No list queries (use `driver_locations` for active drivers)

---

### 5.3 `clients`
**Purpose:** Client metadata (separate from `users`)  
**Key Fields:**
- `isVerified`, `totalTrips`, `averageRating` (admin-managed)

**Security:**
- Read/write: Owner only
- Admin has full access

---

### 5.4 `orders`
**Purpose:** Delivery orders  
**Key Fields:**
- `ownerId` (client UID)
- `status` (matching, accepted, onRoute, completed, cancelled*)
- `assignedDriverId`, `driverId`
- `pickup`, `dropoff` (lat/lng/label)
- `pickupAddress`, `dropoffAddress`
- `price`, `distanceKm`
- `createdAt`, `updatedAt`, `completedAt`
- `driverRating`, `ratedAt`
- `settledAt`, `driverEarning`, `platformFee` (finance)
- `walletGuard` (Phase D: balance enforcement)

**Status Transitions (Firestore Rules):**
- `matching` → `accepted`, `cancelled*`
- `accepted` → `onRoute`, `cancelled*`
- `onRoute` → `completed`, `cancelled*`

**Security:**
- Create: Owner only, must be `matching` status
- Read: Owner, assigned driver, or `matching` status (for driver feed)
- Update: Strict status transition validation, role-based

**Indexes:** 9 composite indexes (see `firestore.indexes.json`)

---

### 5.5 `driver_locations`
**Purpose:** Real-time driver GPS positions  
**Key Fields:**
- Document ID = `driverId`
- `lat`, `lng`, `timestamp`

**Security:**
- Read: Any authenticated user (for matching)
- Write: Owner driver only

**Cleanup:** `cleanStaleDriverLocations` function (scheduled)

---

### 5.6 `wallets`
**Purpose:** Driver wallet balances (Phase 5)  
**Key Fields:**
- Document ID = `driverId` or `PLATFORM_WALLET`
- `type` (driver, platform)
- `ownerId`
- `balance`, `totalCredited`, `totalDebited`, `pendingPayout`
- `currency` (MRU)

**Security:**
- Read: Owner driver, admins
- Write: Cloud Functions only (no client writes)

---

### 5.7 `transactions`
**Purpose:** Wallet transaction ledger (Phase 5)  
**Key Fields:**
- `walletId`
- `type` (credit, debit)
- `source` (order_settlement, trip_start_fee, payout, topup)
- `amount`, `currency`
- `orderId` (if applicable)
- `balanceBefore`, `balanceAfter`
- `note`, `metadata`

**Security:**
- Read: Wallet owner, admins
- Write: Cloud Functions only

---

### 5.8 `payouts`
**Purpose:** Driver payout requests (Phase 5)  
**Key Fields:**
- `driverId`
- `amount`, `currency`
- `status` (pending, approved, rejected, completed)
- `requestedAt`, `processedAt`

**Security:**
- Read: Driver owner, admins
- Write: Cloud Functions only

---

### 5.9 `topup_requests`
**Purpose:** Driver wallet top-up requests (Phase D)  
**Key Fields:**
- `driverId`
- `amount`
- `status` (pending, approved, rejected)

**Security:**
- Create: Driver owner, must be `pending` status
- Update: Admins only (via Cloud Functions)

---

### 5.10 `admins`
**Purpose:** Admin user metadata  
**Security:**
- Read: Admins only
- Write: Cloud Functions only (no client writes)

---

## 6. Cloud Functions

**Runtime:** Node.js 18+  
**Location:** `functions/src/`

### 6.1 Authentication
- **`createCustomToken`** - Generate custom token after PIN verification
- **`manualSetDriverClaims`** - Set driver custom claims (isDriver: true)

### 6.2 Order Lifecycle
- **`notifyNewOrder`** - Notify drivers when order created (matching status)
- **`notifyUnassignedOrders`** - Repeated notifications for unassigned orders (Phase A)
- **`trackOrderAcceptance`** - Track acceptance timestamp (Phase B)
- **`notifyOrderEvents`** - Notify on status changes
- **`expireStaleOrders`** - Auto-cancel old matching orders (scheduled)

### 6.3 Finance/Wallet (Phase 5)
- **`onOrderCompleted`** - Settle completed orders into wallets (80/20 split)
  - Triggers on order status → `completed`
  - Credits driver wallet (80%), platform wallet (20%)
  - Creates transaction records
  - Idempotent (checks `settledAt` field)
- **`processTripStartFee`** - Deduct trip start fee from driver wallet (Phase C)
- **`enforceWalletBalance`** - Enforce positive balance for order acceptance (Phase D)
  - Triggers on order status → `accepted`
  - Reverts to `matching` if balance ≤ 0
  - Fail-closed on errors
  - Loop guard via `walletGuard` field
- **`createTopupRequest`** - Create driver top-up request (Phase D)
- **`approveTopupRequest`, `rejectTopupRequest`** - Admin top-up approval (Phase D)
- **`adminCreatePayoutRequest`, `adminUpdatePayoutStatus`** - Admin payout management

### 6.4 Guards/Enforcement
- **`enforceOrderExclusivity`** - Prevent drivers from accepting multiple orders (Phase C)
- **`aggregateDriverRating`** - Update driver rating on order completion
- **`cleanStaleDriverLocations`** - Remove old driver locations (scheduled)

### 6.5 Admin Actions
- **`setAdminRole`, `removeAdminRole`** - Manage admin custom claims
- **`getAdminStats`** - Dashboard statistics
- **`adminCancelOrder`, `adminReassignOrder`** - Order management
- **`adminBlockDriver`, `adminUnblockDriver`, `adminVerifyDriver`** - Driver management
- **`adminSetClientVerification`, `adminBlockClient`, `adminUnblockClient`** - Client management

### 6.6 Reports
- **`getReportsOverview`** - Overview statistics
- **`getFinancialReport`** - Financial analytics
- **`getDriverPerformanceReport`** - Driver performance metrics

---

## 7. Critical Flows

### 7.1 Authentication Flow (Phone + PIN)

#### New User Registration
1. **Client:** Enter phone number
2. **Client → Firebase Auth:** Send OTP via `verifyPhoneNumber()`
3. **User:** Receive SMS, enter OTP
4. **Client → Firebase Auth:** Verify OTP, sign in with `PhoneAuthCredential`
5. **Client:** Create PIN (4 digits)
6. **Client → Firestore:** Write `users/{uid}` with `pinHash`, `pinSalt`
7. **Client:** Navigate to home

#### Returning User (PIN Login)
1. **Client:** Enter phone number + PIN
2. **Client → Cloud Function:** Call `createCustomToken(phoneE164, pin)`
3. **Function:** Query `users` by phone, verify PIN hash
4. **Function → Client:** Return custom token
5. **Client → Firebase Auth:** Sign in with custom token
6. **Client:** Navigate to home

**Security Concerns:**
- PIN brute force (no rate limiting visible)
- Phone enumeration (mitigated by Firestore rules, but function still queries)
- Session binding (no device/session tracking)

---

### 7.2 Order Lifecycle

#### 1. Order Creation (Client)
```
Client App
  ↓ Select pickup/dropoff
  ↓ Calculate price
  ↓ Create order (status: matching)
  ↓
Firestore: orders/{orderId}
  ↓ Trigger: notifyNewOrder
  ↓
Cloud Function
  ↓ Query active drivers
  ↓ Send FCM notifications
  ↓
Driver Apps (nearby feed)
```

#### 2. Order Acceptance (Driver)
```
Driver App
  ↓ Tap "Accept" on order
  ↓ Update order (status: accepted, assignedDriverId)
  ↓
Firestore: orders/{orderId}
  ↓ Trigger: enforceWalletBalance
  ↓
Cloud Function
  ↓ Check wallets/{driverId}.balance
  ↓ If balance ≤ 0:
  │   ↓ Revert to matching
  │   ↓ Set walletGuard field
  │   ↓ Send FCM notification
  ↓ Else: Allow acceptance
  ↓ Trigger: enforceOrderExclusivity (Phase C)
  ↓
Cloud Function
  ↓ Check for other active orders
  ↓ If exists: Revert to matching
  ↓ Trigger: trackOrderAcceptance (Phase B)
  ↓
Cloud Function
  ↓ Record acceptedAt timestamp
```

#### 3. Trip Start (Driver)
```
Driver App
  ↓ Tap "Start Trip"
  ↓ Update order (status: onRoute)
  ↓
Firestore: orders/{orderId}
  ↓ Trigger: processTripStartFee (Phase C)
  ↓
Cloud Function
  ↓ Debit driver wallet (trip start fee)
  ↓ Create transaction record
```

#### 4. Trip Completion (Driver)
```
Driver App
  ↓ Tap "Complete"
  ↓ Update order (status: completed, completedAt)
  ↓
Firestore: orders/{orderId}
  ↓ Trigger: onOrderCompleted
  ↓
Cloud Function
  ↓ Calculate split (80% driver, 20% platform)
  ↓ Credit wallets/{driverId}.balance
  ↓ Credit wallets/PLATFORM_WALLET.balance
  ↓ Create transaction records
  ↓ Set order.settledAt
  ↓ Trigger: aggregateDriverRating
  ↓
Cloud Function
  ↓ Update driver.rating, driver.totalTrips
```

---

### 7.3 Wallet System (Phase 5)

#### Wallet Structure
- **Driver Wallet:** `wallets/{driverId}`
- **Platform Wallet:** `wallets/PLATFORM_WALLET`

#### Transaction Types
- **Credit:**
  - `order_settlement` - 80% of order price
  - `topup` - Admin-approved top-up
- **Debit:**
  - `trip_start_fee` - Fee deducted on trip start
  - `payout` - Driver withdrawal

#### Finance Config (`functions/src/finance/config.ts`)
```typescript
PLATFORM_COMMISSION_RATE: 0.20  // 20%
DRIVER_COMMISSION_RATE: 0.80    // 80%
DEFAULT_CURRENCY: 'MRU'
PLATFORM_WALLET_ID: 'PLATFORM_WALLET'
```

#### Atomicity
- All wallet updates use Firestore transactions
- Idempotency via `settledAt` field on orders

**Risks:**
- No double-spend protection visible
- No ledger integrity checks
- Race conditions on concurrent order completions?
- Retry logic on transaction failures?

---

### 7.4 Driver Location Tracking

```
Driver App (online)
  ↓ location_service.dart
  ↓ GPS updates (throttled)
  ↓ location_throttling_service.dart
  ↓ Write to Firestore
  ↓
Firestore: driver_locations/{driverId}
  ↓ Real-time listeners
  ↓
Client App (tracking order)
  ↓ Display driver location on map
```

**Cleanup:**
- `cleanStaleDriverLocations` (scheduled function)
- Removes locations older than threshold

---

## 8. Security Model

### 8.1 Firestore Rules Summary

#### Strengths
- Owner-based access control
- Admin bypass via custom claims (`isAdmin: true`)
- Status transition validation for orders
- No unauthenticated list queries (prevents enumeration)
- Wallet/transaction writes locked to Cloud Functions

#### Weaknesses
- **Order Matching Feed:** Any authenticated user can read `matching` orders (line 59)
  - Potential: Client users can see driver-only data
- **Driver Locations:** Any authenticated user can read (line 71)
  - Potential: Privacy leak, location tracking
- **Admin Fields:** Protected but only if they exist (lines 94-95, 143-146)
  - Potential: New documents without admin fields bypass checks
- **Rating Update:** Client can rate completed orders (lines 19-26)
  - Potential: Rating manipulation if status is forged

### 8.2 Authentication Security

#### Custom Claims
- `isAdmin: true` - Admin users
- `isDriver: true` - Driver users (set via `manualSetDriverClaims`)

#### PIN Security
- SHA-256 hash with random salt (base64url, 16 bytes)
- Legacy migration: Upgrades old unsalted hashes on login
- **No brute force protection** (no rate limiting, lockout, or attempt tracking)

#### Session Management
- No session binding to device/IP
- No logout tracking (cleanup via `driver_cleanup_service.dart`)

---

## 9. Third-Party Integrations

### 9.1 Google Maps (Client App)
- **API Key:** Stored in `android/app/src/main/res/values/api_keys.xml`
- **Usage:** Pickup/dropoff selection, geocoding, distance calculation

### 9.2 Firebase Cloud Messaging (FCM)
- **Client App:** Order updates, promotions
- **Driver App:** New orders, wallet alerts, order events
- **Token Storage:** `drivers.fcmToken`, `users.fcmToken` (assumed)

### 9.3 Firebase Crashlytics
- **Mentioned in:** `CRASHLYTICS_VERIFICATION.md`
- **Usage:** Error tracking, crash reporting

---

## 10. CI/CD & Deployment

### GitHub Actions (`.github/`)
- Workflows for build, test, deploy (assumed from directory presence)

### Codemagic (`codemagic.yaml`)
- Mobile app builds (iOS/Android)

### Firebase Deployment
- **Functions:** `firebase deploy --only functions`
- **Firestore Rules:** `firebase deploy --only firestore:rules`
- **Hosting:** `firebase deploy --only hosting`

---

## 11. Documentation Artifacts

### Planning/Implementation
- `ARCHITECTURE.md` - System architecture
- `SECURITY_MODEL.md` - Security design
- `PRODUCT_SCOPE_V1.md` - Product requirements
- `PHASE*_COMPLETION_SUMMARY.md` - Phase deliverables

### Operations
- `PILOT_OPS_RUNBOOK.md` - Operations manual
- `TROUBLESHOOTING.md` - Common issues
- `SECRETS_MANAGEMENT.md` - API key management

### Testing
- `PHASE*_TEST_CHECKLIST.md` - Test plans
- `PRODUCTION_READINESS_*.md` - Readiness reports

---

## 12. Known Issues & Technical Debt

### From Documentation Review
1. **Logout Implementation:** Multiple phases (LOGOUT_*.md)
2. **FCM Fixes:** Simplified fixes applied (FCM_*.md)
3. **Navigator Issues:** Fixed (NAVIGATOR_FIX_SUMMARY.md)
4. **Nearby Orders Overflow:** Fixed (NEARBY_ORDERS_OVERFLOW_FIX.md)
5. **Authentication Guards:** Audited (guard_audit_otp_navigation.md)
6. **Firestore Query Optimization:** Applied (FIRESTORE_QUERY_OPTIMIZATION_SUMMARY.md)

---

## 13. Audit Scope Recommendations

### High Priority
1. **Firestore Rules:**
   - Order matching feed access control
   - Driver location privacy
   - Admin field protection gaps
   - Rating manipulation vectors

2. **Cloud Functions:**
   - Wallet transaction atomicity
   - Double-spend scenarios
   - Retry/idempotency for all financial functions
   - Input validation (all callable functions)
   - Authorization checks (admin functions)

3. **Authentication:**
   - PIN brute force protection
   - Phone enumeration via `createCustomToken`
   - Session binding/device tracking
   - Logout flow completeness

4. **Finance/Wallet:**
   - Ledger integrity checks
   - Race conditions on concurrent settlements
   - Payout request validation
   - Top-up approval workflow

### Medium Priority
1. **Order Lifecycle:**
   - Status transition edge cases
   - Cancellation flows (by client, driver, admin)
   - Stale order expiration logic

2. **Driver Tracking:**
   - Location update throttling effectiveness
   - Stale location cleanup reliability

3. **Notifications:**
   - FCM token management
   - Notification delivery guarantees

### Low Priority
1. **Admin Panel:**
   - Authorization for admin actions
   - Audit logging

2. **Analytics:**
   - Data privacy compliance

---

## End of System Map
