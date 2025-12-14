# Phase 8: E2E Production Dress Rehearsal - Execution Checklist

**WawApp Monorepo**  
**Test Executor:** _________________  
**Date:** _________________  
**Environment:** Production (`wawapp-952d6`)

---

## 📋 Pre-Execution Checklist

### ✅ **Repository & Code**

- [ ] Repository synced to latest `driver-auth-stable-work`
- [ ] Latest commit hash: ___________
- [ ] Working tree clean (no uncommitted changes)
- [ ] All Phase 1-7 changes deployed

### ✅ **Firebase Project**

- [ ] Firebase CLI installed (`firebase --version`)
- [ ] Logged into correct account (`firebase login`)
- [ ] Project set to production (`firebase use wawapp-952d6`)
- [ ] Billing enabled (required for Cloud Functions)

### ✅ **Build Tools**

- [ ] Node.js 20.x installed
- [ ] Flutter SDK 3.0.0+ installed (for admin panel)
- [ ] Firebase Admin SDK configured

---

## 🚀 Phase A: Backend Deployment

### **A1. Deploy Cloud Functions** ⏱️ Est: 10 min

```bash
cd functions
npm install
npm run build
firebase deploy --only functions --project wawapp-952d6
```

- [ ] Build completed without errors
- [ ] All functions deployed successfully
- [ ] Deployment log shows green checkmarks

**Verify Deployment:**
```bash
firebase functions:list --project wawapp-952d6
```

- [ ] `onOrderCompleted` listed
- [ ] `adminCreatePayoutRequest` listed
- [ ] `adminUpdatePayoutStatus` listed
- [ ] `getFinancialReport` listed
- [ ] `getReportsOverview` listed

**Log Check:**
```bash
firebase functions:log --limit 10
```

- [ ] No immediate errors in recent logs

---

### **A2. Deploy Firestore Rules & Indexes** ⏱️ Est: 3 min

```bash
firebase deploy --only firestore:rules,firestore:indexes --project wawapp-952d6
```

- [ ] Rules deployed successfully
- [ ] Indexes deployed successfully
- [ ] No warnings or errors

**Verify in Firebase Console:**
- [ ] Open Firestore → Rules
- [ ] `isAdmin()` function visible in rules
- [ ] Rules version timestamp updated

**Verify Indexes:**
- [ ] Open Firestore → Indexes
- [ ] Composite indexes for `orders` collection present
- [ ] No red "Index Required" warnings

---

### **A3. Deploy Admin Panel** ⏱️ Est: 7 min

```bash
cd apps/wawapp_admin
flutter pub get
flutter build web --release --dart-define=ENVIRONMENT=prod --web-renderer canvaskit
cd ../..
firebase deploy --only hosting --project wawapp-952d6
```

- [ ] Flutter build completed without errors
- [ ] `build/web/` directory created
- [ ] Hosting deployment successful
- [ ] Deployment URL displayed

**Verify Deployment:**
- [ ] Open `https://wawapp-952d6.web.app`
- [ ] Admin login page loads
- [ ] No 404 errors
- [ ] Assets load correctly (images, fonts)

**Browser Console Check:**
- [ ] No JavaScript errors
- [ ] Environment banner shows `PROD` mode
- [ ] No dev mode warnings

---

## 👥 Phase B: Test Account Setup

### **B1. Create Admin Account** ⏱️ Est: 5 min

**Firebase Console Method:**
1. [ ] Navigate to Authentication → Users
2. [ ] Click "Add User"
3. [ ] Enter email: `admin.e2e@wawapp.mr`
4. [ ] Enter password: `AdminE2ETest2025!`
5. [ ] Note generated UID: ___________

**Set Custom Claim:**

**Option 1 - Cloud Function:**
```bash
curl -X POST https://us-central1-wawapp-952d6.cloudfunctions.net/setAdminRole \
  -H "Content-Type: application/json" \
  -d '{"uid": "<admin_uid>", "email": "admin.e2e@wawapp.mr"}'
```

**Option 2 - Firebase Console:**
- [ ] Use `scripts/create_admin_user.html` utility
- [ ] Upload to Firebase Hosting
- [ ] Open and submit form with admin UID

**Verify:**
```bash
firebase auth:export admin-verify.json --project wawapp-952d6
# Check file for isAdmin: true
```

- [ ] Custom claim `isAdmin: true` present

---

### **B2. Create Client Account (Fatima)** ⏱️ Est: 3 min

**Firebase Console:**
1. [ ] Authentication → Add User
2. [ ] Method: Phone
3. [ ] Phone: `+22222123456`
4. [ ] Note UID: ___________

**Firestore Document:**
```javascript
// Collection: users/{clientUid}
{
  "uid": "<client_uid>",
  "phone": "+22222123456",
  "displayName": "Fatima Client",
  "role": "client",
  "isActive": true,
  "createdAt": <Timestamp.now()>
}
```

- [ ] Document created in `users` collection
- [ ] UID matches Firebase Auth

---

### **B3. Create Driver Account (Ahmed)** ⏱️ Est: 7 min

**Firebase Auth:**
1. [ ] Authentication → Add User → Phone
2. [ ] Phone: `+22233456789`
3. [ ] Note UID: ___________

**Firestore Documents:**

**Driver Profile:**
```javascript
// Collection: drivers/{driverUid}
{
  "uid": "<driver_uid>",
  "phone": "+22233456789",
  "displayName": "Ahmed Driver",
  "vehicleType": "motorcycle",
  "vehiclePlate": "NKC-123",
  "rating": 4.8,
  "totalOrders": 150,
  "isActive": true,
  "isVerified": true,
  "status": "available",
  "createdAt": <Timestamp.now()>
}
```

- [ ] Document created

**Driver Location:**
```javascript
// Collection: driver_locations/{driverUid}
{
  "driverId": "<driver_uid>",
  "location": {
    "lat": 18.0800,
    "lng": -15.9700
  },
  "heading": 90,
  "status": "available",
  "updatedAt": <Timestamp.now()>
}
```

- [ ] Document created

**Driver Wallet:**
```javascript
// Collection: wallets/{driverUid}
{
  "id": "<driver_uid>",
  "type": "driver",
  "ownerId": "<driver_uid>",
  "balance": 49000,
  "totalCredited": 200000,
  "totalDebited": 151000,
  "pendingPayout": 0,
  "currency": "MRU",
  "createdAt": <Timestamp.now()>,
  "updatedAt": <Timestamp.now()>
}
```

- [ ] Document created
- [ ] Initial balance: 49,000 MRU

**Platform Wallet (if not exists):**
```javascript
// Collection: wallets/platform_main
{
  "id": "platform_main",
  "type": "platform",
  "ownerId": null,
  "balance": 2500000,
  "totalCredited": 2500000,
  "totalDebited": 0,
  "pendingPayout": 0,
  "currency": "MRU",
  "createdAt": <Timestamp.now()>,
  "updatedAt": <Timestamp.now()>
}
```

- [ ] Document exists or created
- [ ] Initial balance: 2,500,000 MRU

---

## 📦 Phase C: Execute Order Lifecycle

### **C1. Create Order** ⏱️ Est: 2 min

**Firestore Console:**
```javascript
// Collection: orders/{orderId}
// Document ID: order_e2e_test_001
{
  "id": "order_e2e_test_001",
  "ownerId": "<client_uid>",
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
  "createdAt": <Timestamp.now()>,
  "updatedAt": <Timestamp.now()>
}
```

- [ ] Document created successfully
- [ ] Order ID: `order_e2e_test_001`
- [ ] Status: `matching`
- [ ] Price: 1,250 MRU

**Verification:**
- [ ] Document visible in Firestore Console
- [ ] All required fields present
- [ ] Timestamps auto-populated

---

### **C2. Driver Accepts Order** ⏱️ Est: 1 min

**Update Order:**
```javascript
// Update: orders/order_e2e_test_001
{
  "status": "accepted",
  "driverId": "<driver_uid>",
  "acceptedAt": <Timestamp.now()>,
  "updatedAt": <Timestamp.now()>
}
```

- [ ] Status changed to `accepted`
- [ ] `driverId` field added
- [ ] `acceptedAt` timestamp added

---

### **C3. Driver En Route** ⏱️ Est: 1 min

**Update Order:**
```javascript
// Update: orders/order_e2e_test_001
{
  "status": "on_route",
  "updatedAt": <Timestamp.now()>
}
```

- [ ] Status changed to `on_route`
- [ ] Timestamp updated

---

### **C4. Complete Order (TRIGGERS SETTLEMENT)** ⏱️ Est: 1 min + 5 sec

**🚨 CRITICAL STEP - Triggers Cloud Function**

**Update Order:**
```javascript
// Update: orders/order_e2e_test_001
{
  "status": "completed",
  "completedAt": <Timestamp.now()>,
  "updatedAt": <Timestamp.now()>
}
```

- [ ] Status changed to `completed`
- [ ] `completedAt` timestamp added

**⏱️ Wait 5 seconds for Cloud Function execution**

---

### **C5. Verify Automatic Settlement** ⏱️ Est: 3 min

**Check Order Document:**
- [ ] Order has `settledAt` timestamp
- [ ] `driverEarning` = 1,000 MRU (80% of 1,250)
- [ ] `platformFee` = 250 MRU (20% of 1,250)

**Check Driver Wallet:**
- [ ] Balance = 50,000 MRU (was 49,000)
- [ ] `totalCredited` = 201,000 MRU (was 200,000)
- [ ] `updatedAt` timestamp recent

**Check Platform Wallet:**
- [ ] Balance = 2,500,250 MRU (was 2,500,000)
- [ ] `totalCredited` = 2,500,250 MRU (was 2,500,000)
- [ ] `updatedAt` timestamp recent

**Check Transactions Collection:**

**Driver Transaction:**
- [ ] Document exists with `walletId` = driver UID
- [ ] `type` = "credit"
- [ ] `source` = "order_settlement"
- [ ] `amount` = 1,000
- [ ] `orderId` = "order_e2e_test_001"
- [ ] `balanceBefore` = 49,000
- [ ] `balanceAfter` = 50,000

**Platform Transaction:**
- [ ] Document exists with `walletId` = "platform_main"
- [ ] `type` = "credit"
- [ ] `source` = "order_settlement"
- [ ] `amount` = 250
- [ ] `orderId` = "order_e2e_test_001"
- [ ] `balanceBefore` = 2,500,000
- [ ] `balanceAfter` = 2,500,250

**Check Cloud Functions Logs:**
```bash
firebase functions:log --only onOrderCompleted --limit 20
```

- [ ] Log shows: "Order order_e2e_test_001: Settling 1250 MRU"
- [ ] Log shows: "Transaction committed successfully"
- [ ] Log shows: "Successfully settled"
- [ ] No errors in logs

---

## 🖥️ Phase D: Admin Panel Verification

### **D1. Admin Login** ⏱️ Est: 2 min

**Open:** `https://wawapp-952d6.web.app`

- [ ] Login page loads
- [ ] Enter email: `admin.e2e@wawapp.mr`
- [ ] Enter password: `AdminE2ETest2025!`
- [ ] Click "Sign In"
- [ ] Login successful
- [ ] Dashboard loads

**Console Verification:**
```
🚀 WAWAPP ADMIN PANEL
====================================
📍 Environment: PROD
🔒 Strict Auth: true
✅ Production mode: Strict authentication enforced
```

- [ ] Console shows PROD mode
- [ ] No dev warnings
- [ ] No JavaScript errors

---

### **D2. Live Ops Verification** ⏱️ Est: 5 min

**Navigate:** Live Ops

**Map Display:**
- [ ] Map loads correctly
- [ ] No map errors

**Order Visibility:**
- [ ] Order `order_e2e_test_001` appears on map
- [ ] Order marker at correct location
- [ ] Order status: Completed

**Order Details Panel:**
- [ ] Click on order marker
- [ ] Details panel opens
- [ ] Shows:
  - Order ID: order_e2e_test_001
  - Client: Fatima
  - Driver: Ahmed
  - Status: Completed
  - Price: 1,250 MRU
  - Pickup: Tevragh-Zeina
  - Dropoff: Ksar
  - Settlement info visible

**Filter Tests:**
- [ ] Filter: All Orders → Order visible
- [ ] Filter: Completed → Order visible
- [ ] Filter: On Route → Order disappears
- [ ] Filter: Matching → Order disappears

**Search Test:**
- [ ] Search: "order_e2e_test_001" → Order found
- [ ] Search: "Ahmed" → Order found
- [ ] Search: "Fatima" → Order found

---

### **D3. Reports Verification** ⏱️ Est: 5 min

**Navigate:** Reports → Financial Report Tab

**Generate Report:**
- [ ] Period: Today (or custom including order time)
- [ ] Click "Generate Report"
- [ ] Report loads within 5 seconds

**Financial Summary Cards:**

**Gross Revenue:**
- [ ] Shows at least +1,250 MRU
- [ ] Value reasonable

**Driver Earnings:**
- [ ] Shows at least +1,000 MRU
- [ ] Matches 80% calculation

**Platform Commission:**
- [ ] Shows at least +250 MRU
- [ ] Matches 20% calculation

**Total Orders:**
- [ ] Shows at least +1
- [ ] Count matches expectation

**Average Commission Rate:**
- [ ] Shows ~20%
- [ ] Calculation correct

**Total Payouts in Period:**
- [ ] Shows 0 MRU (before payout creation)

**Outstanding Driver Balances:**
- [ ] Shows at least 50,000 MRU
- [ ] Includes Ahmed's balance

**Platform Wallet Balance:**
- [ ] Shows 2,500,250 MRU
- [ ] Matches Firestore

**Daily Breakdown Table:**
- [ ] Today's row present
- [ ] Orders: ≥1
- [ ] Revenue: ≥1,250 MRU
- [ ] Driver Share: ≥1,000 MRU
- [ ] Platform Share: ≥250 MRU

**CSV Export:**
- [ ] Click "Export Financial Report"
- [ ] File downloads: `wawapp_financial_report_YYYY-MM-DD_to_YYYY-MM-DD.csv`
- [ ] File opens in Excel/Sheets
- [ ] Contains correct data
- [ ] UTF-8 encoding correct

---

### **D4. Wallets Verification** ⏱️ Est: 5 min

**Navigate:** Wallets

**Platform Wallet Summary:**
- [ ] Balance: 2,500,250 MRU
- [ ] Total Credited: 2,500,250 MRU
- [ ] Total Debited: 0 MRU
- [ ] Pending Payouts: 0 MRU

**Driver Wallets Table:**
- [ ] Table loads
- [ ] Multiple drivers visible (if any)

**Search for Ahmed:**
- [ ] Enter "Ahmed" in search
- [ ] Driver row appears

**Ahmed's Wallet Data:**
- [ ] Driver Name: Ahmed Driver
- [ ] Balance: 50,000 MRU
- [ ] Total Credited: 201,000 MRU
- [ ] Total Debited: 151,000 MRU
- [ ] Pending Payout: 0 MRU
- [ ] Action button visible

**Transaction History:**
- [ ] Click "View Details" on Ahmed's row
- [ ] Dialog opens
- [ ] Transaction list loads

**Recent Transaction:**
- [ ] Type: Credit (green indicator)
- [ ] Amount: +1,000 MRU
- [ ] Source: Order Settlement
- [ ] Date: Today
- [ ] Note: "Driver earning from order #order_e2e_test_001"

**CSV Export (Driver Transactions):**
- [ ] Click "Export Transactions" in dialog
- [ ] File downloads: `wawapp_driver_<driverId>_transactions_YYYY-MM-DD_to_YYYY-MM-DD.csv`
- [ ] File contains settlement transaction
- [ ] Data accurate

---

## 💸 Phase E: Payout Creation & Completion

### **E1. Create Payout Request** ⏱️ Est: 3 min

**Navigate:** Payouts

- [ ] Payouts screen loads
- [ ] Table shows existing payouts (if any)

**Click:** "New Payout Request" (Floating Action Button)

- [ ] Dialog opens

**Fill Form:**
- [ ] Driver ID: `<driver_uid>` (or select "Ahmed Driver")
- [ ] Amount: 50000
- [ ] Method: Bank Transfer
- [ ] Bank Name: Bank of Mauritania
- [ ] Account Number: MR1234567890
- [ ] Account Name: Ahmed Mohamed
- [ ] Note: "Weekly payout for Ahmed - E2E Test"

**Click:** "Create Payout"

- [ ] Success message: "Payout request created successfully"
- [ ] Dialog closes

**Verify in Table:**
- [ ] New payout row appears
- [ ] Driver: Ahmed Driver
- [ ] Amount: 50,000 MRU
- [ ] Method: Bank Transfer
- [ ] Status: Requested (orange chip)
- [ ] Date: Today

**Verify in Firestore:**
```javascript
// Collection: payouts/{payoutId}
```

- [ ] Document exists
- [ ] `driverId` = driver UID
- [ ] `amount` = 50000
- [ ] `method` = "bank_transfer"
- [ ] `status` = "requested"
- [ ] `requestedBy` = admin UID
- [ ] `requestedAt` timestamp present

**Verify Wallet Update:**
```javascript
// wallets/{driverId}
```

- [ ] `balance` = 50,000 (unchanged)
- [ ] `pendingPayout` = 50,000 (NEW!)
- [ ] `updatedAt` timestamp recent

---

### **E2. Complete Payout** ⏱️ Est: 2 min

**🚨 CRITICAL STEP - Triggers Wallet Debit & Transaction Creation**

**In Payouts Table:**
- [ ] Find payout with status "Requested"
- [ ] Click "Actions" button (three dots)
- [ ] Menu opens

**Options:**
- [ ] "View Details" visible
- [ ] "Mark as Completed" visible

**Click:** "Mark as Completed"

- [ ] Confirmation dialog appears
- [ ] Confirm action
- [ ] Success message: "Payout marked as completed"

**Verify Status Change:**
- [ ] Status chip changes to "Completed" (green)
- [ ] Completion timestamp visible
- [ ] Row updated in real-time

**⏱️ Wait 2 seconds for updates**

---

### **E3. Verify Payout Completion** ⏱️ Est: 5 min

**Check Payout Document:**
```javascript
// payouts/{payoutId}
```

- [ ] `status` = "completed"
- [ ] `completedBy` = admin UID
- [ ] `completedAt` timestamp present

**Check Driver Wallet:**
```javascript
// wallets/{driverId}
```

- [ ] `balance` = 0 MRU (was 50,000) ✅ DEBITED
- [ ] `totalDebited` = 201,000 MRU (was 151,000) ✅ +50,000
- [ ] `pendingPayout` = 0 MRU (was 50,000) ✅ CLEARED
- [ ] `updatedAt` timestamp recent

**Check Payout Transaction:**
```javascript
// transactions/{txnId}
```

- [ ] Document exists
- [ ] `walletId` = driver UID
- [ ] `type` = "debit"
- [ ] `source` = "payout"
- [ ] `amount` = 50,000
- [ ] `payoutId` = payout ID
- [ ] `adminId` = admin UID
- [ ] `balanceBefore` = 50,000
- [ ] `balanceAfter` = 0
- [ ] Note mentions "Payout to driver Ahmed"

**Verify in Wallets Screen:**
- [ ] Navigate to Wallets
- [ ] Search for Ahmed
- [ ] Balance: 0 MRU ✅
- [ ] Total Debited: 201,000 MRU ✅
- [ ] Pending Payout: 0 MRU ✅
- [ ] Click "View Details"
- [ ] Transaction list shows:
  - Credit (+1,000 from order)
  - Debit (-50,000 payout) ← NEW

**Verify in Reports:**
- [ ] Navigate to Reports → Financial Report
- [ ] Generate new report
- [ ] "Total Payouts in Period": 50,000 MRU ✅
- [ ] "Outstanding Driver Balances" decreased ✅

---

## ✅ Final Verification

### **System State After E2E Test**

**Orders:**
- [ ] 1 completed order
- [ ] Order settled correctly
- [ ] Settlement timestamp present

**Wallets:**
- [ ] Driver balance: 0 MRU
- [ ] Driver total credited: 201,000 MRU
- [ ] Driver total debited: 201,000 MRU
- [ ] Platform balance: 2,500,250 MRU
- [ ] Platform total credited: 2,500,250 MRU

**Transactions:**
- [ ] 3 total transactions:
  1. Driver credit (settlement): +1,000 MRU
  2. Platform credit (settlement): +250 MRU
  3. Driver debit (payout): -50,000 MRU
- [ ] All balanceBefore/After correct
- [ ] All timestamps present

**Payouts:**
- [ ] 1 completed payout
- [ ] Payout amount: 50,000 MRU
- [ ] All timestamps present

**Reports:**
- [ ] Financial report accurate
- [ ] CSV exports functional
- [ ] All metrics match Firestore

**Admin Panel:**
- [ ] No errors in console
- [ ] All screens functional
- [ ] Real-time updates working

---

## 📊 Performance Metrics

**Record actual times:**

| Operation | Expected | Actual | Status |
|-----------|----------|--------|--------|
| Settlement trigger latency | <2s | _____ | ⬜ |
| Admin panel load time | <3s | _____ | ⬜ |
| Report generation | <5s | _____ | ⬜ |
| CSV export | <2s | _____ | ⬜ |
| Payout completion | <2s | _____ | ⬜ |

---

## 🐛 Issues Encountered

**Document any deviations, errors, or unexpected behavior:**

| Issue # | Description | Severity | Status | Resolution |
|---------|-------------|----------|--------|------------|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |

**Severity:** 🔴 Blocker | 🟡 Major | 🟢 Minor

---

## 📸 Required Screenshots

- [ ] Admin login success
- [ ] Live Ops with completed order
- [ ] Financial Report summary cards
- [ ] Wallets screen showing driver balance
- [ ] Payout creation dialog
- [ ] Payout completion confirmation
- [ ] Transaction history dialog
- [ ] Firestore: orders/order_e2e_test_001 (after settlement)
- [ ] Firestore: wallets/<driverId> (after payout)
- [ ] Firestore: transactions (all 3 transactions)
- [ ] Cloud Functions logs (settlement)

---

## ✅ Sign-Off

**Test Executed By:** _________________  
**Signature:** _________________  
**Date:** _________________

**Result:** 
- [ ] ✅ PASSED - All checkboxes completed, system functioning correctly
- [ ] ⚠️ PASSED WITH ISSUES - Minor issues documented above
- [ ] ❌ FAILED - Critical issues preventing completion

**Notes:**
_____________________________________________________________________________
_____________________________________________________________________________
_____________________________________________________________________________

---

**Checklist Version:** 1.0  
**Last Updated:** December 2025  
**Status:** ✅ READY FOR EXECUTION
