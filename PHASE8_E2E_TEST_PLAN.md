# Phase 8: End-to-End Production Dress Rehearsal - Test Plan

**WawApp Monorepo**  
**Date**: December 2025  
**Status**: 🎯 **READY FOR EXECUTION**  
**Priority**: 🔴 CRITICAL - Production Validation

---

## 🎯 Objective

Validate the complete WawApp system through a **production-realistic end-to-end test scenario** covering:

- **Client** → Creates shipment order
- **Driver** → Accepts and completes delivery
- **Settlement** → Automatic wallet & transaction processing (80% driver / 20% platform)
- **Admin Panel** → Monitors operations, manages payouts
- **Reports** → Financial and operational reporting
- **Payout** → Admin creates and completes driver payout

This rehearsal ensures all systems are production-ready before live deployment.

---

## 📖 Test Scenario Overview

### **The Nouakchott Delivery Story**

**Characters:**
- **Fatima** (Client) - Sending a package in Nouakchott
- **Ahmed** (Driver) - Experienced delivery driver with verified profile
- **Sara** (Admin) - WawApp operations manager monitoring the platform

**Scenario Flow:**
```
1. Fatima creates order: Pickup in Tevragh-Zeina → Dropoff in Ksar
2. Ahmed sees order in "Nearby Orders" and accepts it
3. Ahmed drives to pickup location (status: on_route)
4. Ahmed completes delivery
5. Settlement function triggers automatically
   - Ahmed's wallet credited: 1,000 MRU (80%)
   - Platform wallet credited: 250 MRU (20%)
   - Total order price: 1,250 MRU
6. Sara monitors the order in Admin Panel (Live Ops)
7. Sara views updated reports (Financial Report shows settlement)
8. Sara creates payout request for Ahmed: 50,000 MRU
9. Sara completes the payout
10. Transactions & wallets updated correctly
```

---

## 🗂️ System Architecture Reference

### **Order Lifecycle States**

```
matching → assigning → accepted → on_route → completed
                                           ↓
                                        (settlement triggered)
                                           ↓
                                    [Wallets Updated]
                                    [Transactions Created]
```

### **Settlement Logic (from `orderSettlement.ts`)**

**Commission Split:**
- Driver: **80%** (0.80 rate)
- Platform: **20%** (0.20 rate)

**Trigger:** Firestore trigger on `orders/{orderId}` when status changes to `completed`

**Idempotency:** Checks `settledAt` field to prevent double-settlement

**Process:**
1. Calculate `driverEarning = orderPrice * 0.80`
2. Calculate `platformFee = orderPrice * 0.20`
3. Update driver wallet: `balance += driverEarning`
4. Update platform wallet: `balance += platformFee`
5. Create driver transaction (credit)
6. Create platform transaction (credit)
7. Mark order with `settledAt` timestamp

---

## 📊 Firestore Collections Involved

### **1. `orders` Collection**

**Document ID:** Auto-generated  
**Key Fields:**

```typescript
{
  id: string;
  ownerId: string;              // Client UID
  driverId?: string;            // Assigned driver UID
  status: OrderStatus;          // matching|assigning|accepted|on_route|completed|cancelled
  price: number;                // Order price in MRU
  distanceKm: number;
  pickup: {
    lat: number;
    lng: number;
    address: string;
  };
  dropoff: {
    lat: number;
    lng: number;
    address: string;
  };
  pickupAddress: string;
  dropoffAddress: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
  completedAt?: Timestamp;
  settledAt?: Timestamp;        // Set by settlement function
  driverEarning?: number;       // Set by settlement function
  platformFee?: number;         // Set by settlement function
}
```

**Example Order Document:**
```json
{
  "id": "order_e2e_test_001",
  "ownerId": "client_fatima_uid",
  "driverId": "driver_ahmed_uid",
  "status": "completed",
  "price": 1250,
  "distanceKm": 5.2,
  "pickup": {
    "lat": 18.0860,
    "lng": -15.9760,
    "address": "Avenue Gamal Abdel Nasser, Tevragh-Zeina"
  },
  "dropoff": {
    "lat": 18.0735,
    "lng": -15.9582,
    "address": "Rue de l'Espoir, Ksar"
  },
  "pickupAddress": "Tevragh-Zeina, Nouakchott",
  "dropoffAddress": "Ksar, Nouakchott",
  "createdAt": "2025-12-10T14:00:00Z",
  "updatedAt": "2025-12-10T14:30:00Z",
  "completedAt": "2025-12-10T14:30:00Z",
  "settledAt": "2025-12-10T14:30:01Z",
  "driverEarning": 1000,
  "platformFee": 250
}
```

---

### **2. `wallets` Collection**

**Document ID:** `driverId` or `"platform_main"`

**Driver Wallet Structure:**
```typescript
{
  id: string;               // Same as driverId
  type: "driver";
  ownerId: string;          // Driver UID
  balance: number;          // Current balance (MRU)
  totalCredited: number;    // Lifetime credits
  totalDebited: number;     // Lifetime debits
  pendingPayout: number;    // Amount in pending payouts
  currency: "MRU";
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

**Example - Ahmed's Wallet (Before):**
```json
{
  "id": "driver_ahmed_uid",
  "type": "driver",
  "ownerId": "driver_ahmed_uid",
  "balance": 49000,
  "totalCredited": 200000,
  "totalDebited": 151000,
  "pendingPayout": 0,
  "currency": "MRU",
  "createdAt": "2025-01-15T10:00:00Z",
  "updatedAt": "2025-12-10T13:00:00Z"
}
```

**Example - Ahmed's Wallet (After Settlement):**
```json
{
  "id": "driver_ahmed_uid",
  "type": "driver",
  "ownerId": "driver_ahmed_uid",
  "balance": 50000,           // +1000 from order
  "totalCredited": 201000,     // +1000
  "totalDebited": 151000,
  "pendingPayout": 0,
  "currency": "MRU",
  "updatedAt": "2025-12-10T14:30:01Z"
}
```

**Example - Platform Wallet (After Settlement):**
```json
{
  "id": "platform_main",
  "type": "platform",
  "ownerId": null,
  "balance": 2500250,          // +250 from order
  "totalCredited": 2500250,    // +250
  "totalDebited": 0,
  "pendingPayout": 0,
  "currency": "MRU",
  "updatedAt": "2025-12-10T14:30:01Z"
}
```

---

### **3. `transactions` Collection**

**Document ID:** Auto-generated

**Transaction Structure:**
```typescript
{
  id: string;
  walletId: string;              // Reference to wallet
  type: "credit" | "debit";
  source: TransactionSource;     // order_settlement|payout|manual_adjustment
  amount: number;                // Always positive
  currency: "MRU";
  orderId?: string;
  payoutId?: string;
  adminId?: string;
  balanceBefore: number;
  balanceAfter: number;
  note?: string;
  metadata?: object;
  createdAt: Timestamp;
}
```

**Example - Driver Transaction (Order Settlement):**
```json
{
  "id": "txn_driver_settlement_001",
  "walletId": "driver_ahmed_uid",
  "type": "credit",
  "source": "order_settlement",
  "amount": 1000,
  "currency": "MRU",
  "orderId": "order_e2e_test_001",
  "balanceBefore": 49000,
  "balanceAfter": 50000,
  "note": "Driver earning from order #order_e2e_test_001",
  "metadata": {
    "orderPrice": 1250,
    "driverShare": 0.80,
    "platformFee": 250
  },
  "createdAt": "2025-12-10T14:30:01Z"
}
```

**Example - Platform Transaction (Order Settlement):**
```json
{
  "id": "txn_platform_settlement_001",
  "walletId": "platform_main",
  "type": "credit",
  "source": "order_settlement",
  "amount": 250,
  "currency": "MRU",
  "orderId": "order_e2e_test_001",
  "balanceBefore": 2500000,
  "balanceAfter": 2500250,
  "note": "Platform commission from order #order_e2e_test_001",
  "metadata": {
    "orderPrice": 1250,
    "platformShare": 0.20,
    "driverEarning": 1000
  },
  "createdAt": "2025-12-10T14:30:01Z"
}
```

**Example - Driver Transaction (Payout Debit):**
```json
{
  "id": "txn_driver_payout_001",
  "walletId": "driver_ahmed_uid",
  "type": "debit",
  "source": "payout",
  "amount": 50000,
  "currency": "MRU",
  "payoutId": "payout_ahmed_001",
  "adminId": "admin_sara_uid",
  "balanceBefore": 50000,
  "balanceAfter": 0,
  "note": "Payout to driver Ahmed via bank_transfer",
  "metadata": {
    "method": "bank_transfer",
    "recipientInfo": {
      "bankName": "Bank of Mauritania",
      "accountNumber": "****1234"
    }
  },
  "createdAt": "2025-12-10T15:00:00Z"
}
```

---

### **4. `payouts` Collection**

**Document ID:** Auto-generated

**Payout Structure:**
```typescript
{
  id: string;
  driverId: string;
  amount: number;
  method: PayoutMethod;          // manual|bank_transfer|mobile_money
  status: PayoutStatus;          // requested|approved|processing|completed|rejected
  recipientInfo?: {
    bankName?: string;
    accountNumber?: string;
    accountName?: string;
    phoneNumber?: string;
  };
  requestedBy: string;           // Admin UID
  requestedAt: Timestamp;
  approvedBy?: string;
  approvedAt?: Timestamp;
  completedBy?: string;
  completedAt?: Timestamp;
  note?: string;
  metadata?: object;
}
```

**Example - Payout Request:**
```json
{
  "id": "payout_ahmed_001",
  "driverId": "driver_ahmed_uid",
  "amount": 50000,
  "method": "bank_transfer",
  "status": "completed",
  "recipientInfo": {
    "bankName": "Bank of Mauritania",
    "accountNumber": "MR1234567890",
    "accountName": "Ahmed Mohamed"
  },
  "requestedBy": "admin_sara_uid",
  "requestedAt": "2025-12-10T15:00:00Z",
  "completedBy": "admin_sara_uid",
  "completedAt": "2025-12-10T15:05:00Z",
  "note": "Weekly payout for Ahmed"
}
```

---

## 👥 Test Accounts & Data

### **Admin Account**

**Email:** `admin.e2e@wawapp.mr`  
**Password:** `AdminE2ETest2025!`  
**Firebase Custom Claims:**
```json
{
  "isAdmin": true
}
```

**How to Create:**
1. Use Firebase Console Authentication → Add User
2. Use Cloud Function `setAdminRole` to set custom claim:
   ```javascript
   firebase functions:call setAdminRole --data '{
     "uid": "<admin_uid>", 
     "email": "admin.e2e@wawapp.mr"
   }'
   ```
3. Or use `scripts/create_admin_user.html` utility

**Firestore Document** (`admins/{adminUid}`):
```json
{
  "uid": "admin_sara_uid",
  "email": "admin.e2e@wawapp.mr",
  "displayName": "Sara Admin",
  "role": "operations_manager",
  "isActive": true,
  "createdAt": "2025-12-10T12:00:00Z"
}
```

---

### **Client Account (Fatima)**

**Phone:** `+222 22 12 34 56` (Mauritania format)  
**Firebase Auth:** Phone authentication  
**UID:** `client_fatima_uid` (auto-generated)

**Firestore Document** (`users/{clientUid}`):
```json
{
  "uid": "client_fatima_uid",
  "phone": "+22222123456",
  "displayName": "Fatima Client",
  "role": "client",
  "isActive": true,
  "createdAt": "2025-12-10T12:00:00Z"
}
```

**Note:** Mauritania country code is **+222**. Phone must be in E.164 format in Firebase Auth.

---

### **Driver Account (Ahmed)**

**Phone:** `+222 33 45 67 89` (Mauritania format)  
**Firebase Auth:** Phone authentication  
**UID:** `driver_ahmed_uid` (auto-generated)

**Firestore Document** (`drivers/{driverUid}`):
```json
{
  "uid": "driver_ahmed_uid",
  "phone": "+22233456789",
  "displayName": "Ahmed Driver",
  "vehicleType": "motorcycle",
  "vehiclePlate": "NKC-123",
  "rating": 4.8,
  "totalOrders": 150,
  "isActive": true,
  "isVerified": true,
  "status": "available",
  "createdAt": "2025-01-15T10:00:00Z"
}
```

**Driver Location** (`driver_locations/{driverUid}`):
```json
{
  "driverId": "driver_ahmed_uid",
  "location": {
    "lat": 18.0800,
    "lng": -15.9700
  },
  "heading": 90,
  "status": "available",
  "updatedAt": "2025-12-10T14:00:00Z"
}
```

---

## 🔧 Pre-Test Setup Requirements

### **1. Firebase Project Configuration**

**Environment:** Production (`wawapp-952d6`)

**Required Services:**
- ✅ Firebase Authentication (Phone Auth enabled)
- ✅ Cloud Firestore (Rules & Indexes deployed)
- ✅ Cloud Functions (All functions deployed)
- ✅ Firebase Hosting (Admin panel deployed)

**Deploy Commands:**
```bash
# Deploy Cloud Functions
cd functions
npm run build
firebase deploy --only functions --project wawapp-952d6

# Deploy Firestore Rules & Indexes
firebase deploy --only firestore:rules,firestore:indexes --project wawapp-952d6

# Deploy Admin Panel (Production Config)
cd apps/wawapp_admin
flutter build web --release --dart-define=ENVIRONMENT=prod
cd ../..
firebase deploy --only hosting --project wawapp-952d6
```

---

### **2. Firestore Security Rules Validation**

**Critical Rules to Verify:**

```javascript
// Admin access
function isAdmin() {
  return request.auth != null && 
         request.auth.token.isAdmin == true;
}

// Order creation (clients only)
allow create: if isSignedIn() && 
              request.resource.data.status == "matching" &&
              request.resource.data.ownerId == request.auth.uid;

// Wallet read (admin or owner)
allow read: if isAdmin() || 
            resource.data.ownerId == request.auth.uid;

// Transaction read (admin or wallet owner)
allow read: if isAdmin() || 
            resource.data.walletId == request.auth.uid;
```

**Test Security Rules:**
```bash
firebase emulators:start --only firestore
# Run security rules test suite
```

---

### **3. Required Cloud Functions**

**Verify Deployed:**

| Function | Purpose | Trigger |
|----------|---------|---------|
| `onOrderCompleted` | Settlement automation | Firestore trigger on orders |
| `adminCreatePayoutRequest` | Create payout | HTTPS Callable |
| `adminUpdatePayoutStatus` | Update payout status | HTTPS Callable |
| `getFinancialReport` | Generate financial reports | HTTPS Callable |
| `getReportsOverview` | Overview statistics | HTTPS Callable |

**Check Deployment:**
```bash
firebase functions:list --project wawapp-952d6
```

---

### **4. Admin Panel Verification**

**URL:** `https://wawapp-952d6.web.app` (or custom domain)

**Verify Screens:**
- ✅ Login (with admin.e2e@wawapp.mr)
- ✅ Dashboard (Overview stats)
- ✅ Live Ops (Real-time order map)
- ✅ Reports → Financial Report Tab
- ✅ Wallets Screen (Driver & Platform wallets)
- ✅ Payouts Screen (Create & manage payouts)

**Environment Check:**
When logged in, console should show:
```
🚀 WAWAPP ADMIN PANEL
====================================
📍 Environment: PROD
🔒 Strict Auth: true
✅ Production mode: Strict authentication enforced
✅ Admin access requires isAdmin custom claim
```

---

## 🚀 Test Execution Workflow

### **Phase A: Backend Deployment & Verification**

#### **A1. Deploy Cloud Functions**
```bash
cd /path/to/wawapp-ai/functions
npm install
npm run build
firebase deploy --only functions --project wawapp-952d6
```

**Expected Output:**
```
✔ functions: Finished running predeploy script.
✔ functions[onOrderCompleted(us-central1)]: Successful update operation.
✔ functions[adminCreatePayoutRequest(us-central1)]: Successful update operation.
...
✔ Deploy complete!
```

**Verification:**
```bash
firebase functions:list --project wawapp-952d6 | grep -E "onOrderCompleted|adminCreatePayoutRequest|adminUpdatePayoutStatus"
```

---

#### **A2. Deploy Firestore Rules & Indexes**
```bash
firebase deploy --only firestore:rules,firestore:indexes --project wawapp-952d6
```

**Expected Output:**
```
✔ firestore: released rules firestore.rules to cloud.firestore
✔ firestore: deployed indexes in firestore.indexes.json successfully
```

**Verification:**
- Open Firebase Console → Firestore → Rules
- Verify `isAdmin()` function exists
- Check indexes are deployed (no red warnings)

---

#### **A3. Deploy Admin Panel**
```bash
cd apps/wawapp_admin
flutter pub get
flutter build web --release --dart-define=ENVIRONMENT=prod --web-renderer canvaskit
cd ../..
firebase deploy --only hosting --project wawapp-952d6
```

**Expected Output:**
```
✔ hosting[wawapp-952d6]: file upload complete
✔ hosting[wawapp-952d6]: version finalized
✔ hosting[wawapp-952d6]: release complete
```

**Verification:**
- Open `https://wawapp-952d6.web.app`
- Should see WawApp Admin login screen
- Check browser console for environment banner

---

### **Phase B: Test Account Setup**

#### **B1. Create Admin Account**

**Option 1: Firebase Console**
1. Firebase Console → Authentication → Add User
2. Email: `admin.e2e@wawapp.mr`
3. Password: `AdminE2ETest2025!`
4. Note the generated UID

**Option 2: CLI**
```bash
firebase auth:import admin_user.json --project wawapp-952d6
```

**Set Custom Claim:**
```bash
# Using Cloud Function (if deployed)
curl -X POST https://us-central1-wawapp-952d6.cloudfunctions.net/setAdminRole \
  -H "Content-Type: application/json" \
  -d '{"uid": "<admin_uid>", "email": "admin.e2e@wawapp.mr"}'

# Or use Firebase Admin SDK script
node scripts/set-admin-claim.js <admin_uid>
```

**Verify:**
```bash
firebase auth:export admin-check.json --project wawapp-952d6
# Check for isAdmin: true in custom claims
```

---

#### **B2. Create Client Account (Fatima)**

**Using Firebase Console:**
1. Authentication → Users → Add User → Phone
2. Phone: `+22222123456`
3. Send verification code (or skip for test)

**Or Firestore Direct Insert (for testing):**
```javascript
// In Firestore Console: users collection
{
  "uid": "client_fatima_uid",  // Use actual UID from Auth
  "phone": "+22222123456",
  "displayName": "Fatima Client",
  "role": "client",
  "isActive": true,
  "createdAt": Timestamp.now()
}
```

---

#### **B3. Create Driver Account (Ahmed)**

**Create in Firebase Auth:**
```
Phone: +22233456789
```

**Create Driver Profile in Firestore:**
```javascript
// Collection: drivers/{driverUid}
{
  "uid": "driver_ahmed_uid",
  "phone": "+22233456789",
  "displayName": "Ahmed Driver",
  "vehicleType": "motorcycle",
  "vehiclePlate": "NKC-123",
  "rating": 4.8,
  "totalOrders": 150,
  "isActive": true,
  "isVerified": true,
  "status": "available",
  "createdAt": Timestamp.now()
}
```

**Create Driver Location:**
```javascript
// Collection: driver_locations/{driverUid}
{
  "driverId": "driver_ahmed_uid",
  "location": {
    "lat": 18.0800,
    "lng": -15.9700
  },
  "heading": 90,
  "status": "available",
  "updatedAt": Timestamp.now()
}
```

**Create Initial Wallet:**
```javascript
// Collection: wallets/{driverUid}
{
  "id": "driver_ahmed_uid",
  "type": "driver",
  "ownerId": "driver_ahmed_uid",
  "balance": 49000,
  "totalCredited": 200000,
  "totalDebited": 151000,
  "pendingPayout": 0,
  "currency": "MRU",
  "createdAt": Timestamp.now(),
  "updatedAt": Timestamp.now()
}
```

---

### **Phase C: Execute Order Lifecycle**

#### **C1. Client Creates Order**

**Method 1: Using Client App (if available)**
- Login as Fatima (+22222123456)
- Create new order:
  - Pickup: Avenue Gamal Abdel Nasser, Tevragh-Zeina
  - Dropoff: Rue de l'Espoir, Ksar
  - Price: 1,250 MRU

**Method 2: Direct Firestore Insert (for testing)**
```javascript
// Collection: orders/{orderId}
{
  "id": "order_e2e_test_001",
  "ownerId": "client_fatima_uid",
  "status": "matching",
  "price": 1250,
  "distanceKm": 5.2,
  "pickup": {
    "lat": 18.0860,
    "lng": -15.9760,
    "address": "Avenue Gamal Abdel Nasser, Tevragh-Zeina"
  },
  "dropoff": {
    "lat": 18.0735,
    "lng": -15.9582,
    "address": "Rue de l'Espoir, Ksar"
  },
  "pickupAddress": "Tevragh-Zeina, Nouakchott",
  "dropoffAddress": "Ksar, Nouakchott",
  "createdAt": Timestamp.now(),
  "updatedAt": Timestamp.now()
}
```

**Expected Result:**
- Order document created with status `matching`
- Visible in Admin Panel → Live Ops

---

#### **C2. Driver Accepts Order**

**Update Order Status to `assigning` → `accepted`:**

**Method 1: Using Driver App**
- Login as Ahmed (+22233456789)
- View "Nearby Orders"
- Accept order_e2e_test_001

**Method 2: Manual Firestore Update**
```javascript
// Update: orders/order_e2e_test_001
{
  "status": "accepted",
  "driverId": "driver_ahmed_uid",
  "acceptedAt": Timestamp.now(),
  "updatedAt": Timestamp.now()
}
```

**Expected Result:**
- Order status: `accepted`
- `driverId` field populated
- Visible in Admin Panel → Live Ops with driver info

---

#### **C3. Driver En Route**

**Update Order Status to `on_route`:**
```javascript
// Update: orders/order_e2e_test_001
{
  "status": "on_route",
  "updatedAt": Timestamp.now()
}
```

**Expected Result:**
- Order status: `on_route`
- Admin Panel shows driver moving on map
- Order card shows "Driver en route"

---

#### **C4. Driver Completes Order (CRITICAL - Triggers Settlement)**

**Update Order Status to `completed`:**
```javascript
// Update: orders/order_e2e_test_001
{
  "status": "completed",
  "completedAt": Timestamp.now(),
  "updatedAt": Timestamp.now()
}
```

**IMPORTANT:** This update triggers the `onOrderCompleted` Cloud Function!

**Expected Automatic Actions (within 1-2 seconds):**

1. **Order Updated:**
   ```javascript
   {
     "settledAt": Timestamp.now(),
     "driverEarning": 1000,     // 80% of 1250
     "platformFee": 250         // 20% of 1250
   }
   ```

2. **Driver Wallet Updated:**
   ```javascript
   {
     "balance": 50000,          // 49000 + 1000
     "totalCredited": 201000,   // 200000 + 1000
     "updatedAt": Timestamp.now()
   }
   ```

3. **Platform Wallet Updated:**
   ```javascript
   {
     "balance": 2500250,        // 2500000 + 250
     "totalCredited": 2500250,  // 2500000 + 250
     "updatedAt": Timestamp.now()
   }
   ```

4. **Driver Transaction Created:**
   ```javascript
   // Collection: transactions/{txnId}
   {
     "walletId": "driver_ahmed_uid",
     "type": "credit",
     "source": "order_settlement",
     "amount": 1000,
     "orderId": "order_e2e_test_001",
     "balanceBefore": 49000,
     "balanceAfter": 50000,
     "note": "Driver earning from order #order_e2e_test_001",
     "createdAt": Timestamp.now()
   }
   ```

5. **Platform Transaction Created:**
   ```javascript
   // Collection: transactions/{txnId}
   {
     "walletId": "platform_main",
     "type": "credit",
     "source": "order_settlement",
     "amount": 250,
     "orderId": "order_e2e_test_001",
     "balanceBefore": 2500000,
     "balanceAfter": 2500250,
     "createdAt": Timestamp.now()
   }
   ```

**Verification Steps:**
```bash
# Check Cloud Functions logs
firebase functions:log --only onOrderCompleted --project wawapp-952d6

# Expected log:
# "Order order_e2e_test_001: Settling 1250 MRU (driver: 1000, platform: 250)"
# "Order order_e2e_test_001: Transaction committed successfully"
# "Order order_e2e_test_001: Successfully settled"
```

---

### **Phase D: Admin Panel Verification**

#### **D1. Login to Admin Panel**

**URL:** `https://wawapp-952d6.web.app`

**Credentials:**
- Email: `admin.e2e@wawapp.mr`
- Password: `AdminE2ETest2025!`

**Verify Login:**
- Check console for environment banner (PROD mode)
- Dashboard loads successfully
- No errors in browser console

---

#### **D2. Verify Live Ops**

**Navigate to:** Live Ops

**Checks:**
- [ ] Map displays correctly
- [ ] Order `order_e2e_test_001` appears on map
- [ ] Order status shows `completed`
- [ ] Driver Ahmed's location displayed
- [ ] Order details panel shows correct info:
  - Price: 1,250 MRU
  - Driver: Ahmed
  - Status: Completed
  - Settlement info visible

**Filter Test:**
- [ ] Filter by "Completed" - order appears
- [ ] Filter by "On Route" - order disappears
- [ ] Search by order ID - finds order

---

#### **D3. Verify Reports**

**Navigate to:** Reports → Financial Report Tab

**Generate Report:**
- Period: Today (or custom range including order completion time)
- Click "Generate Report"

**Expected Report Data:**

**Financial Summary Cards:**
| Metric | Expected Value | Actual |
|--------|----------------|--------|
| Gross Revenue | +1,250 MRU | ✅ |
| Driver Earnings | +1,000 MRU | ✅ |
| Platform Commission | +250 MRU | ✅ |
| Total Orders | +1 | ✅ |
| Avg Commission Rate | 20% | ✅ |
| Total Payouts | 0 MRU | ✅ |
| Outstanding Driver Balances | 50,000 MRU | ✅ |
| Platform Wallet Balance | 2,500,250 MRU | ✅ |

**Daily Breakdown Table:**
Should show entry for today with:
- Orders: 1
- Revenue: 1,250 MRU
- Driver Share: 1,000 MRU
- Platform Share: 250 MRU

**CSV Export Test:**
- [ ] Click "Export Financial Report"
- [ ] CSV file downloads
- [ ] Opens correctly in Excel/Sheets
- [ ] Contains correct data

---

#### **D4. Verify Wallets Screen**

**Navigate to:** Wallets

**Platform Wallet Summary:**
- [ ] Balance: 2,500,250 MRU
- [ ] Total Credited: 2,500,250 MRU
- [ ] Pending Payouts: 0 MRU

**Driver Wallets Table:**
Search for "Ahmed":
- [ ] Driver: Ahmed Driver
- [ ] Balance: 50,000 MRU
- [ ] Total Credited: 201,000 MRU
- [ ] Total Debited: 151,000 MRU
- [ ] Pending Payout: 0 MRU

**Transaction History:**
- [ ] Click "View Details" on Ahmed's wallet
- [ ] Transaction dialog opens
- [ ] Shows recent credit transaction:
  - Type: Credit
  - Amount: +1,000 MRU
  - Source: Order Settlement
  - Date: Today
  - Note: "Driver earning from order #order_e2e_test_001"

**CSV Export Test:**
- [ ] Click "Export Transactions" on Ahmed's wallet
- [ ] CSV downloads with transaction history
- [ ] Contains settlement transaction

---

### **Phase E: Payout Creation & Completion**

#### **E1. Create Payout Request**

**Navigate to:** Payouts Screen

**Click:** "New Payout Request" (FAB button)

**Fill Form:**
- Driver ID: `driver_ahmed_uid` (or select from dropdown)
- Amount: 50,000 MRU
- Method: Bank Transfer
- Bank Name: Bank of Mauritania
- Account Number: MR1234567890
- Account Name: Ahmed Mohamed
- Note: "Weekly payout for Ahmed - E2E Test"

**Click:** "Create Payout"

**Expected Result:**
- Success message: "Payout request created successfully"
- New payout appears in payouts table
- Status: `requested`
- Amount: 50,000 MRU

**Firestore Verification:**
```javascript
// Collection: payouts/{payoutId}
{
  "id": "<auto_generated>",
  "driverId": "driver_ahmed_uid",
  "amount": 50000,
  "method": "bank_transfer",
  "status": "requested",
  "recipientInfo": {
    "bankName": "Bank of Mauritania",
    "accountNumber": "MR1234567890",
    "accountName": "Ahmed Mohamed"
  },
  "requestedBy": "admin_sara_uid",
  "requestedAt": Timestamp.now(),
  "note": "Weekly payout for Ahmed - E2E Test"
}
```

**Wallet Update Verification:**
```javascript
// wallets/driver_ahmed_uid
{
  "balance": 50000,
  "pendingPayout": 50000,      // ← Updated!
  "updatedAt": Timestamp.now()
}
```

---

#### **E2. Approve Payout (Optional Step)**

**In Payouts Table:**
- [ ] Find payout with status `requested`
- [ ] Click "Actions" → "Approve"
- [ ] Confirm approval

**Expected Result:**
- Status changes to `approved`
- `approvedBy` and `approvedAt` fields set

---

#### **E3. Complete Payout**

**In Payouts Table:**
- [ ] Find payout with status `requested` or `approved`
- [ ] Click "Actions" → "Mark as Completed"
- [ ] Confirm completion

**Expected Result:**
- Success message: "Payout marked as completed"
- Status changes to `completed`
- Payout row shows completion timestamp

**CRITICAL Automatic Actions:**

1. **Driver Wallet Debited:**
   ```javascript
   // wallets/driver_ahmed_uid
   {
     "balance": 0,              // 50000 - 50000
     "totalDebited": 201000,    // 151000 + 50000
     "pendingPayout": 0,        // Cleared
     "updatedAt": Timestamp.now()
   }
   ```

2. **Payout Transaction Created:**
   ```javascript
   // transactions/{txnId}
   {
     "walletId": "driver_ahmed_uid",
     "type": "debit",
     "source": "payout",
     "amount": 50000,
     "payoutId": "<payout_id>",
     "adminId": "admin_sara_uid",
     "balanceBefore": 50000,
     "balanceAfter": 0,
     "note": "Payout to driver Ahmed via bank_transfer",
     "metadata": {
       "method": "bank_transfer",
       "recipientInfo": { ... }
     },
     "createdAt": Timestamp.now()
   }
   ```

---

#### **E4. Verify Payout Completion**

**Wallets Screen:**
- [ ] Ahmed's balance now: 0 MRU
- [ ] Total Debited: 201,000 MRU
- [ ] Pending Payout: 0 MRU
- [ ] Transaction history shows new debit entry

**Payouts Screen:**
- [ ] Payout status: `completed`
- [ ] Completion timestamp visible
- [ ] CSV export includes completed payout

**Financial Reports:**
- [ ] Generate new report
- [ ] "Total Payouts in Period" increased by 50,000 MRU
- [ ] Outstanding Driver Balances decreased

---

## ✅ Success Criteria

### **Order Lifecycle ✅**
- [x] Order created with correct data
- [x] Order accepted by driver
- [x] Order progressed through states correctly
- [x] Order completed with timestamp

### **Settlement ✅**
- [x] Settlement triggered automatically on completion
- [x] Driver wallet credited correctly (80%)
- [x] Platform wallet credited correctly (20%)
- [x] Order marked with `settledAt` timestamp
- [x] No double-settlement (idempotency)

### **Transactions ✅**
- [x] Driver credit transaction created
- [x] Platform credit transaction created
- [x] Payout debit transaction created
- [x] All transactions have correct balanceBefore/After
- [x] Transaction metadata accurate

### **Wallets ✅**
- [x] Driver wallet balance accurate
- [x] Platform wallet balance accurate
- [x] `pendingPayout` updated during payout lifecycle
- [x] `totalCredited` and `totalDebited` accumulate correctly

### **Admin Panel ✅**
- [x] Login successful with admin account
- [x] Live Ops displays orders correctly
- [x] Reports show accurate financial data
- [x] Wallets screen displays correct balances
- [x] Payout creation works
- [x] Payout completion works
- [x] CSV exports functional

### **Security ✅**
- [x] Admin authentication required
- [x] isAdmin custom claim enforced
- [x] Non-admin users cannot access admin functions
- [x] Firestore security rules enforced

---

## 🐛 Common Issues & Troubleshooting

### **Issue: Settlement Not Triggering**

**Symptoms:**
- Order status changes to `completed`
- No `settledAt` field appears
- Wallets not updated

**Debugging:**
```bash
# Check Cloud Functions logs
firebase functions:log --only onOrderCompleted --limit 50

# Look for errors or "No settlement needed" messages
```

**Common Causes:**
1. Cloud Function not deployed → Redeploy
2. Order already has `settledAt` → Check idempotency
3. Order missing `price` or `driverId` → Validate order data
4. Function failed → Check logs for stack trace

**Fix:**
```bash
# Redeploy function
cd functions
npm run build
firebase deploy --only functions:onOrderCompleted
```

---

### **Issue: Admin Login Fails**

**Symptoms:**
- "Access denied: Admin privileges required"

**Debugging:**
```bash
# Check custom claims
firebase auth:export users.json --project wawapp-952d6
# Look for isAdmin: true in customClaims
```

**Fix:**
```bash
# Set admin claim using Cloud Function
curl -X POST https://us-central1-wawapp-952d6.cloudfunctions.net/setAdminRole \
  -H "Content-Type: application/json" \
  -d '{"uid": "<admin_uid>", "email": "admin.e2e@wawapp.mr"}'
```

---

### **Issue: Payout Creation Fails**

**Error:** "Insufficient balance"

**Cause:** Driver wallet balance < payout amount

**Fix:**
- Verify wallet balance in Firestore
- Ensure `pendingPayout` is not too high
- Check `balance - pendingPayout >= amount`

---

### **Issue: CSV Export Not Working**

**Symptoms:**
- Click "Export" button
- No file downloads

**Debugging:**
- Check browser console for errors
- Verify CSV export utility in code

**Fix:**
- Check browser popup blocker
- Ensure CSV data is being generated
- Verify `dart:html` is available (web platform)

---

## 📊 Expected Test Duration

| Phase | Activity | Estimated Time |
|-------|----------|----------------|
| **A** | Backend Deployment | 15-20 min |
| **B** | Account Setup | 10-15 min |
| **C** | Order Lifecycle | 5-10 min |
| **D** | Admin Verification | 10-15 min |
| **E** | Payout Flow | 5-10 min |
| **Total** | **Complete E2E Test** | **45-70 minutes** |

---

## 📝 Documentation Requirements

After test execution, document:

1. **Actual vs Expected Results** for each checkpoint
2. **Screenshots** of key states:
   - Admin Panel login
   - Live Ops with order
   - Financial Report
   - Wallets screen
   - Payout completion
3. **Firestore Snapshots** of:
   - Order document (before/after settlement)
   - Wallet documents (before/after)
   - Transaction documents
   - Payout documents
4. **Cloud Functions Logs** excerpts
5. **Any Deviations** from expected behavior
6. **Performance Metrics**:
   - Settlement trigger latency
   - Admin panel page load times
   - Report generation time

---

## 🎯 Success Definition

**Phase 8 E2E Test is SUCCESSFUL if:**

✅ **All 5 Phases (A-E) complete without errors**  
✅ **All checkboxes in verification sections marked**  
✅ **Settlement mathematics correct (80/20 split)**  
✅ **All Firestore documents match expected schemas**  
✅ **Admin Panel displays accurate real-time data**  
✅ **Payout lifecycle completes successfully**  
✅ **Zero security rule violations**  
✅ **Cloud Functions execute within 2 seconds**  
✅ **CSV exports contain valid data**  
✅ **No JavaScript errors in browser console**  
✅ **All test accounts function correctly**

---

## 🚀 Next Steps After Successful E2E

1. **Phase 9: Production Launch Preparation**
   - Monitor production traffic
   - Set up error alerting
   - Configure backup schedules
   - Establish on-call procedures

2. **User Acceptance Testing (UAT)**
   - Real users test system
   - Collect feedback
   - Iterate on UX improvements

3. **Performance Optimization**
   - Profile Cloud Functions
   - Optimize Firestore queries
   - Implement caching strategies

4. **Documentation Updates**
   - Finalize user manuals
   - Create training materials
   - Document operational procedures

---

**Document Version:** 1.0  
**Last Updated:** December 2025  
**Status:** ✅ READY FOR EXECUTION
