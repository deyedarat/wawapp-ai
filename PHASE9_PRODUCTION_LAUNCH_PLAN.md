# Phase 9: Production Launch Plan

**WawApp Monorepo**  
**Date**: December 2025  
**Status**: 🚀 **READY FOR GO-LIVE**  
**Priority**: 🔴 CRITICAL - Production Deployment

---

## 🎯 Executive Summary

This document provides the complete **Go-Live Checklist** and **Launch Protocol** for deploying the WawApp delivery platform to production. The launch follows a **rolling deployment strategy** with built-in **rollback capability** and **90-minute observation window**.

**Launch Scope:**
- ✅ Firebase Cloud Functions (all financial & operational functions)
- ✅ Firestore Database (production rules & indexes)
- ✅ Admin Panel Web App (React + Firebase Hosting)
- ✅ Authentication System (Firebase Auth + custom claims)
- ✅ Monitoring & Alerting (Firebase + custom monitoring)

**Launch Prerequisites:**
- Phase 1-8 completed and tested
- E2E test passed (Phase 8)
- Environment config validated (Phase 7)
- All security audits passed
- Stakeholder sign-off obtained

---

## 📋 Table of Contents

1. [Pre-Launch Checklist](#pre-launch-checklist)
2. [Environment Selection](#environment-selection)
3. [Deployment Sequence](#deployment-sequence)
4. [Smoke Tests](#smoke-tests)
5. [Rolling Deployment Strategy](#rolling-deployment-strategy)
6. [Rollback Plan](#rollback-plan)
7. [Post-Launch Observation](#post-launch-observation)
8. [Communication Plan](#communication-plan)
9. [Troubleshooting](#troubleshooting)

---

## 🔍 Pre-Launch Checklist

### **A. Repository & Code**

- [ ] **Latest code pulled from remote**
  ```bash
  git checkout driver-auth-stable-work
  git pull origin driver-auth-stable-work
  ```
  - Latest commit: `53bffa8` or newer
  - All Phase 1-8 changes merged

- [ ] **No uncommitted changes**
  ```bash
  git status
  # Should show: "nothing to commit, working tree clean"
  ```

- [ ] **All tests passing**
  - Phase 8 E2E test: ✅ PASSED
  - Unit tests (if any): ✅ PASSED
  - Integration tests: ✅ PASSED

- [ ] **Code review completed**
  - Backend engineer sign-off
  - Frontend engineer sign-off
  - Security review completed
  - DevOps review completed

---

### **B. Firebase Project**

- [ ] **Correct project selected**
  ```bash
  firebase use wawapp-952d6
  firebase projects:list
  # Should show: (current) wawapp-952d6
  ```

- [ ] **Billing enabled and limits set**
  - Firebase Console → Billing
  - Verify active billing account
  - Set budget alerts:
    - Warning at 50% ($50/month if $100 limit)
    - Alert at 80% ($80/month)
    - Hard cap at 100% ($100/month)

- [ ] **Firebase CLI authenticated**
  ```bash
  firebase login:list
  # Verify logged in with correct account
  ```

- [ ] **Firebase Admin SDK service account exists**
  - Firebase Console → Project Settings → Service Accounts
  - Verify service account key downloaded (for backup scripts)

---

### **C. Firestore Database**

- [ ] **Production Firestore instance ready**
  - Database created in production project
  - Location: `us-central1` (or appropriate region)
  - Mode: Native mode

- [ ] **Backup of current data (if upgrading)**
  ```bash
  firebase firestore:export gs://wawapp-952d6-backups/pre-launch-$(date +%Y%m%d)
  ```
  - Verify export completed successfully
  - Export location noted for rollback

- [ ] **Security rules validated**
  ```bash
  firebase firestore:rules:get
  ```
  - Verify `isAdmin()` function present
  - Verify order creation rules
  - Verify wallet access restrictions

- [ ] **Indexes deployed**
  ```bash
  firebase firestore:indexes:list
  ```
  - Verify composite indexes for orders
  - Verify no "Index Required" warnings

---

### **D. Authentication**

- [ ] **Firebase Authentication enabled**
  - Email/Password: ✅ Enabled
  - Phone (SMS): ✅ Enabled for Mauritania (+222)

- [ ] **Admin user created with custom claim**
  - Test admin: `admin.prod@wawapp.mr`
  - Custom claim: `{ isAdmin: true }`
  - Verify login works

- [ ] **Phone authentication tested**
  - Test client phone auth
  - Test driver phone auth
  - Verify Mauritania format (+222XXXXXXXX)

---

### **E. Cloud Functions**

- [ ] **Functions built successfully**
  ```bash
  cd functions
  npm install
  npm run build
  # Should complete without errors
  ```

- [ ] **Function dependencies up to date**
  ```bash
  npm outdated
  # Check for critical vulnerabilities
  npm audit
  ```

- [ ] **Environment variables set (if any)**
  ```bash
  firebase functions:config:get
  ```

---

### **F. Admin Panel**

- [ ] **Flutter dependencies resolved**
  ```bash
  cd apps/wawapp_admin
  flutter pub get
  # Should complete without errors
  ```

- [ ] **Production build configured**
  - Environment: `ENVIRONMENT=prod`
  - Auth mode: `useStrictAuth = true`
  - No dev bypass in production

- [ ] **Build artifacts ready**
  ```bash
  flutter build web --release --dart-define=ENVIRONMENT=prod --web-renderer canvaskit
  ```
  - Build completes without errors
  - `build/web/` directory created
  - Assets optimized

---

### **G. Monitoring & Alerts**

- [ ] **Firebase Performance Monitoring enabled**
  - Firebase Console → Performance
  - Verify SDK configured

- [ ] **Cloud Functions logging configured**
  - Log level: `INFO` for production
  - Error tracking enabled

- [ ] **Alert channels configured**
  - Email notifications: ✅ Set up
  - (Optional) Slack webhook: ✅ Set up
  - (Optional) SMS alerts: ✅ Set up

- [ ] **Budget alerts active**
  - Firebase Console → Billing → Budgets & Alerts
  - Verify alert emails working

---

### **H. Backup & Recovery**

- [ ] **Backup script tested**
  - Daily backup script ready
  - Backup destination verified (Cloud Storage bucket)
  - Test restore procedure completed

- [ ] **Disaster recovery plan reviewed**
  - Team trained on recovery procedures
  - Contact list updated
  - Escalation path documented

---

### **I. Documentation**

- [ ] **Operations runbook available**
  - Location: `/docs/admin/OPERATIONS_RUNBOOK.md`
  - Team has access

- [ ] **Deployment guide reviewed**
  - Location: `/docs/admin/PHASE6_DEPLOYMENT_GUIDE.md`
  - All steps validated

- [ ] **Phase 9 documents available**
  - Monitoring & Alerts
  - SLO/SLA definitions
  - Backup & DR plan
  - Cost optimization

---

### **J. Team Readiness**

- [ ] **Launch team identified**
  - Launch coordinator: _______________
  - Backend engineer: _______________
  - Frontend engineer: _______________
  - DevOps/SRE: _______________
  - On-call engineer: _______________

- [ ] **Launch time scheduled**
  - Date: _______________
  - Time: _______________ (ideally low-traffic period)
  - Duration: 2-3 hours (including observation)

- [ ] **Communication plan ready**
  - Stakeholders notified
  - Team chat channel active
  - Video call link ready (for launch coordination)

- [ ] **Rollback criteria defined**
  - Error rate threshold: > 5%
  - Response time threshold: > 5 seconds
  - Critical bug severity

---

## 🌍 Environment Selection

### **Production Environment Configuration**

**Firebase Project:** `wawapp-952d6`

**Key Configuration:**

```yaml
Project ID:       wawapp-952d6
Region:           us-central1
Database:         Firestore (Native Mode)
Hosting:          https://wawapp-952d6.web.app
Functions Region: us-central1
Auth Domain:      wawapp-952d6.firebaseapp.com
```

**Admin Panel Build Command:**

```bash
flutter build web \
  --release \
  --dart-define=ENVIRONMENT=prod \
  --web-renderer canvaskit
```

**Critical: ENVIRONMENT=prod must be set!**

**What this enforces:**
- ✅ `useStrictAuth = true` (isAdmin claim required)
- ✅ `enableDebugLogging = false` (clean production logs)
- ✅ `showDevTools = false` (no dev UI)
- ✅ Firebase project: `wawapp-952d6`
- ✅ Safe default: Always defaults to prod if flag missing

**Verification:**

After deployment, check browser console:
```
🚀 WAWAPP ADMIN PANEL
====================================
📍 Environment: PROD
🔒 Strict Auth: true
✅ Production mode: Strict authentication enforced
✅ Admin access requires isAdmin custom claim
```

**If you see dev warnings, STOP and rollback immediately!**

---

## 🚀 Deployment Sequence

### **Phase 1: Firestore Rules & Indexes** ⏱️ 5 min

**Deploy security rules and indexes first** (they take effect immediately).

```bash
# 1. Navigate to project root
cd /path/to/wawapp-ai

# 2. Deploy Firestore rules
firebase deploy --only firestore:rules --project wawapp-952d6

# 3. Deploy Firestore indexes
firebase deploy --only firestore:indexes --project wawapp-952d6

# 4. Verify deployment
firebase firestore:rules:list
firebase firestore:indexes:list
```

**Expected Output:**
```
✔ Deploy complete!

Firestore Rules:
- Updated at: 2025-12-10 14:00:00
- Version: <version_id>

Firestore Indexes:
- orders: 7 composite indexes
- Status: ACTIVE
```

**Verification Checklist:**
- [ ] Rules deployed successfully
- [ ] No syntax errors
- [ ] Indexes in ACTIVE state (not PENDING)
- [ ] No red "Index Required" warnings in console

**Rollback (if needed):**
```bash
# Revert to previous rules version
firebase firestore:rules:release <previous_version_id>
```

---

### **Phase 2: Cloud Functions** ⏱️ 10 min

**Deploy all Cloud Functions** (financial, admin, reports, core).

```bash
# 1. Navigate to functions directory
cd functions

# 2. Install dependencies (if not done)
npm install

# 3. Build TypeScript
npm run build

# 4. Deploy all functions
firebase deploy --only functions --project wawapp-952d6

# Alternative: Deploy specific functions only
firebase deploy --only functions:onOrderCompleted,functions:adminCreatePayoutRequest --project wawapp-952d6
```

**Expected Output:**
```
✔ functions: Finished running predeploy script.
✔ functions[onOrderCompleted(us-central1)]: Successful update operation.
✔ functions[adminCreatePayoutRequest(us-central1)]: Successful update operation.
✔ functions[adminUpdatePayoutStatus(us-central1)]: Successful update operation.
✔ functions[getFinancialReport(us-central1)]: Successful update operation.
✔ functions[getReportsOverview(us-central1)]: Successful update operation.
...
✔ Deploy complete!

Functions deployed:
- onOrderCompleted
- adminCreatePayoutRequest
- adminUpdatePayoutStatus
- getFinancialReport
- getReportsOverview
- setAdminRole
- removeAdminRole
- adminCancelOrder
- adminBlockDriver
...
```

**Verification Checklist:**
- [ ] All functions deployed successfully
- [ ] No compilation errors
- [ ] Function logs show no immediate errors
  ```bash
  firebase functions:log --limit 50
  ```
- [ ] Function list shows all expected functions
  ```bash
  firebase functions:list
  ```

**Critical Functions to Verify:**
- ✅ `onOrderCompleted` (settlement automation)
- ✅ `adminCreatePayoutRequest` (payout creation)
- ✅ `adminUpdatePayoutStatus` (payout completion)
- ✅ `getFinancialReport` (financial reporting)

**Rollback (if needed):**
```bash
# Option 1: Redeploy from previous commit
git checkout <previous_commit_hash>
cd functions && npm run build
firebase deploy --only functions

# Option 2: Delete malfunctioning function
firebase functions:delete <function_name>

# Option 3: Revert to previous version via console
# Firebase Console → Functions → Select function → Versions → Revert
```

---

### **Phase 3: Admin Panel (Firebase Hosting)** ⏱️ 7 min

**Build and deploy the Admin Panel web application.**

```bash
# 1. Navigate to admin app directory
cd apps/wawapp_admin

# 2. Get Flutter dependencies
flutter pub get

# 3. Build for web (PRODUCTION)
flutter build web \
  --release \
  --dart-define=ENVIRONMENT=prod \
  --web-renderer canvaskit

# 4. Verify build output
ls -la build/web/
# Should see: index.html, main.dart.js, assets/, etc.

# 5. Navigate back to project root
cd ../..

# 6. Deploy to Firebase Hosting
firebase deploy --only hosting --project wawapp-952d6
```

**Expected Output:**
```
=== Deploying to 'wawapp-952d6'...

i  hosting[wawapp-952d6]: beginning deploy...
i  hosting[wawapp-952d6]: found 47 files in build/web
✔  hosting[wawapp-952d6]: file upload complete
i  hosting[wawapp-952d6]: finalizing version...
✔  hosting[wawapp-952d6]: version finalized
i  hosting[wawapp-952d6]: releasing new version...
✔  hosting[wawapp-952d6]: release complete

✔  Deploy complete!

Project Console: https://console.firebase.google.com/project/wawapp-952d6/overview
Hosting URL: https://wawapp-952d6.web.app
```

**Verification Checklist:**
- [ ] Hosting deployment successful
- [ ] URL accessible: https://wawapp-952d6.web.app
- [ ] Admin login page loads
- [ ] No 404 errors
- [ ] Assets load correctly (images, fonts, JavaScript)
- [ ] Browser console shows no critical errors
- [ ] Environment banner shows "PROD" mode

**Rollback (if needed):**
```bash
# List recent hosting releases
firebase hosting:releases:list

# Rollback to previous release
firebase hosting:rollback
```

---

### **Phase 4: Initial Data Seeding (If First Launch)** ⏱️ 5 min

**Only required for first-time production deployment.**

If launching for the first time, seed initial data:

```bash
# 1. Create platform wallet (if not exists)
# Use Firestore Console or admin script
```

**Platform Wallet Document:**
```javascript
// Collection: wallets
// Document ID: platform_main
{
  "id": "platform_main",
  "type": "platform",
  "ownerId": null,
  "balance": 0,
  "totalCredited": 0,
  "totalDebited": 0,
  "pendingPayout": 0,
  "currency": "MRU",
  "createdAt": <Timestamp.now()>,
  "updatedAt": <Timestamp.now()>
}
```

**Verification:**
- [ ] Platform wallet document exists
- [ ] Initial balance: 0 MRU
- [ ] Type: "platform"

---

## ✅ Smoke Tests

### **Smoke Test Checklist** ⏱️ 20 min

Execute these tests **immediately after deployment** to verify core functionality.

---

#### **1. Admin Panel Access** ⏱️ 3 min

**Test:** Can admin user log in?

```
1. Open: https://wawapp-952d6.web.app
2. Enter credentials:
   - Email: admin.prod@wawapp.mr
   - Password: <secure_password>
3. Click "Sign In"
```

**Expected Result:**
- ✅ Login successful
- ✅ Dashboard loads
- ✅ Navigation menu visible
- ✅ No JavaScript errors in console
- ✅ Environment banner shows "PROD"

**If Failed:**
- Check custom claim: `{ isAdmin: true }`
- Check Firestore rules deployed
- Check Cloud Functions deployed
- Check authentication enabled

---

#### **2. Dashboard Statistics** ⏱️ 2 min

**Test:** Does dashboard load statistics?

```
1. Navigate to Dashboard
2. Check statistics cards
```

**Expected Result:**
- ✅ Statistics load (may be 0 if no data)
- ✅ No "Error loading data" messages
- ✅ Loading indicators disappear within 3 seconds

**If Failed:**
- Check `getReportsOverview` function logs
- Check Firestore read permissions
- Check network tab for API errors

---

#### **3. Live Ops Map** ⏱️ 3 min

**Test:** Does Live Ops map render?

```
1. Navigate to Live Ops
2. Check map display
3. Try filter options
```

**Expected Result:**
- ✅ Map renders correctly
- ✅ No map errors
- ✅ Filters work (even if no orders to show)
- ✅ Search box functional

**If Failed:**
- Check Google Maps API key
- Check Firestore query permissions
- Check browser console for errors

---

#### **4. Financial Report** ⏱️ 3 min

**Test:** Can generate financial report?

```
1. Navigate to Reports → Financial Report
2. Select date range (today)
3. Click "Generate Report"
```

**Expected Result:**
- ✅ Report generates within 5 seconds
- ✅ Summary cards display (may be 0)
- ✅ Daily breakdown table shows
- ✅ CSV export button works

**If Failed:**
- Check `getFinancialReport` function logs
- Check function timeout (should be 60s)
- Check Firestore read permissions

---

#### **5. Wallets Screen** ⏱️ 3 min

**Test:** Can view wallets?

```
1. Navigate to Wallets
2. Check platform wallet summary
3. Check driver wallets table
```

**Expected Result:**
- ✅ Platform wallet displays (balance: 0 if fresh)
- ✅ Driver wallets table loads (empty if no drivers)
- ✅ Search box functional
- ✅ No errors

**If Failed:**
- Check Firestore rules for wallets collection
- Check platform wallet document exists
- Check query permissions

---

#### **6. Payouts Screen** ⏱️ 3 min

**Test:** Can view payouts?

```
1. Navigate to Payouts
2. Check payouts table
3. Try "New Payout Request" button
```

**Expected Result:**
- ✅ Payouts table loads (empty if no payouts)
- ✅ "New Payout Request" button opens dialog
- ✅ Dialog has all fields (Driver ID, Amount, Method, etc.)
- ✅ No errors

**If Failed:**
- Check Firestore rules for payouts collection
- Check Cloud Functions deployed
- Check admin authentication

---

#### **7. Settlement Test (Critical!)** ⏱️ 5 min

**Test:** Does order settlement work?

**Prerequisites:**
- Test driver account exists with wallet
- Test client account exists

**Steps:**
```
1. Create test order in Firestore:
   - Collection: orders
   - Status: matching
   - Price: 1000 MRU
   - driverId: <test_driver_uid>
   - ownerId: <test_client_uid>

2. Update order status to "completed"

3. Wait 5 seconds

4. Check order document:
   - settledAt: <should be set>
   - driverEarning: 800 (80%)
   - platformFee: 200 (20%)

5. Check driver wallet:
   - balance: increased by 800
   - totalCredited: increased by 800

6. Check platform wallet:
   - balance: increased by 200
   - totalCredited: increased by 200

7. Check transactions collection:
   - 2 new transactions (driver credit + platform credit)
```

**Expected Result:**
- ✅ Order settledAt timestamp set
- ✅ Driver earnings: 800 MRU
- ✅ Platform fee: 200 MRU
- ✅ Driver wallet updated correctly
- ✅ Platform wallet updated correctly
- ✅ 2 transactions created

**If Failed:**
- Check `onOrderCompleted` function logs
- Check function deployed and active
- Check Firestore trigger configuration
- Check wallet documents exist
- **CRITICAL: This is a blocker - ROLLBACK if not working!**

---

#### **8. Payout Test** ⏱️ 5 min

**Test:** Can create and complete payout?

**Prerequisites:**
- Test driver with wallet balance ≥ 10,000 MRU

**Steps:**
```
1. Navigate to Payouts screen
2. Click "New Payout Request"
3. Fill form:
   - Driver ID: <test_driver_uid>
   - Amount: 10000
   - Method: bank_transfer
   - Bank Name: Test Bank
   - Account Number: 123456
   - Note: "Test payout"
4. Click "Create Payout"
5. Verify payout appears in table (status: requested)
6. Check driver wallet:
   - pendingPayout: 10000 (increased)
7. Click "Mark as Completed"
8. Check driver wallet:
   - balance: decreased by 10000
   - pendingPayout: 0 (cleared)
9. Check transactions collection:
   - New debit transaction created
```

**Expected Result:**
- ✅ Payout created successfully
- ✅ pendingPayout increased
- ✅ Payout completion successful
- ✅ Wallet balance decreased
- ✅ pendingPayout cleared
- ✅ Debit transaction created

**If Failed:**
- Check `adminCreatePayoutRequest` function logs
- Check `adminUpdatePayoutStatus` function logs
- Check admin authentication
- Check wallet balance sufficient
- **CRITICAL: This is a blocker - ROLLBACK if not working!**

---

### **Smoke Test Sign-Off**

- [ ] All 8 smoke tests passed
- [ ] No critical errors encountered
- [ ] Performance acceptable (< 5s load times)
- [ ] Ready to proceed to observation phase

**If any critical test failed:**
- 🚨 **EXECUTE ROLLBACK IMMEDIATELY**
- Do not proceed to observation
- Investigate and fix issues
- Redeploy after fixes

---

## 🔄 Rolling Deployment Strategy

**WawApp uses a phased rollout approach:**

### **Deployment Phases**

```
Phase 1: Firestore Rules & Indexes
         ↓ (Immediate effect)
         
Phase 2: Cloud Functions
         ↓ (New function versions go live)
         
Phase 3: Admin Panel Hosting
         ↓ (CDN propagates within minutes)
         
Phase 4: Smoke Tests
         ↓ (Verify core functionality)
         
Phase 5: Observation Window (90 minutes)
         ↓ (Monitor metrics, logs, alerts)
         
Phase 6: Go/No-Go Decision
         ↓
         
✅ Success: Launch complete
❌ Issues: Execute rollback
```

### **Phased Rollout Benefits**

1. **Immediate Rollback Capability**
   - Each phase can be reverted independently
   - Hosting has instant rollback via Firebase Console

2. **Reduced Blast Radius**
   - Functions roll out one by one
   - Can pause between phases if issues detected

3. **Gradual Traffic Shift**
   - Admin panel CDN propagates gradually
   - Old version still accessible during propagation

4. **Observability Window**
   - 90 minutes to monitor metrics
   - Time to detect subtle issues

---

## ⏮️ Rollback Plan

### **1-Click Rollback: Firebase Hosting**

**Fastest rollback method** (< 30 seconds):

```bash
# View recent releases
firebase hosting:releases:list

# Example output:
# Release ID            | Version | Deploy Time         | Status
# abc123def456789...    | v42     | 2025-12-10 14:30:00 | DEPLOYED
# xyz789abc123456...    | v41     | 2025-12-10 12:00:00 | DEPLOYED

# Rollback to previous version
firebase hosting:rollback

# Verify rollback
curl -I https://wawapp-952d6.web.app
```

**Expected Result:**
- Previous admin panel version restored
- Takes effect within 30 seconds
- No data loss

---

### **Cloud Functions Rollback**

**Method 1: Redeploy from Previous Commit**

```bash
# 1. Find previous working commit
git log --oneline -10

# 2. Checkout previous commit
git checkout <previous_commit_hash>

# 3. Rebuild functions
cd functions
npm run build

# 4. Redeploy
firebase deploy --only functions --project wawapp-952d6

# 5. Verify logs
firebase functions:log --limit 50
```

**Method 2: Delete Malfunctioning Function**

```bash
# Delete specific function
firebase functions:delete onOrderCompleted

# Redeploy from known-good version
git checkout <previous_commit>
firebase deploy --only functions:onOrderCompleted
```

**Method 3: Console Rollback**

1. Open Firebase Console → Functions
2. Select malfunctioning function
3. Click "Versions" tab
4. Find previous version
5. Click "Revert to this version"

---

### **Firestore Rules Rollback**

```bash
# 1. List previous rule versions
firebase firestore:rules:list

# Example output:
# Version ID        | Deploy Time         | Status
# v42               | 2025-12-10 14:30    | ACTIVE
# v41               | 2025-12-10 12:00    | RELEASED

# 2. Rollback to previous version
firebase firestore:rules:release v41

# 3. Verify
firebase firestore:rules:get
```

---

### **Firestore Data Rollback**

**Only use in disaster scenario** (data corruption):

```bash
# 1. Export current state (for investigation)
firebase firestore:export gs://wawapp-952d6-backups/rollback-export-$(date +%Y%m%d-%H%M%S)

# 2. Restore from backup
firebase firestore:import gs://wawapp-952d6-backups/pre-launch-YYYYMMDD

# WARNING: This will overwrite all current data!
# Only use if data integrity compromised
```

---

### **Full Rollback Procedure**

**Execute in this order if critical issues detected:**

```bash
# Step 1: Rollback Admin Panel (30 seconds)
firebase hosting:rollback

# Step 2: Rollback Cloud Functions (5 minutes)
git checkout <previous_commit>
cd functions && npm run build
firebase deploy --only functions

# Step 3: Rollback Firestore Rules (1 minute)
firebase firestore:rules:release <previous_version>

# Step 4: Verify System State (5 minutes)
# - Test admin login
# - Test dashboard load
# - Test settlement (with test order)
# - Check logs for errors

# Step 5: Notify Team
# - Post in team chat
# - Email stakeholders
# - Update status page (if applicable)

# Step 6: Post-Mortem
# - Document what went wrong
# - Identify root cause
# - Plan fix and re-deploy
```

---

## 👀 Post-Launch Observation Window

### **90-Minute Observation Protocol**

After successful deployment and smoke tests, monitor the system for **90 minutes** before declaring launch complete.

---

### **Monitoring Dashboard**

**Open these tabs/windows:**

1. **Firebase Console - Overview**
   - https://console.firebase.google.com/project/wawapp-952d6/overview

2. **Firebase Console - Functions**
   - https://console.firebase.google.com/project/wawapp-952d6/functions

3. **Firebase Console - Firestore**
   - https://console.firebase.google.com/project/wawapp-952d6/firestore

4. **Cloud Functions Logs**
   ```bash
   firebase functions:log --limit 100 --follow
   ```

5. **Admin Panel (Live)**
   - https://wawapp-952d6.web.app

6. **Firebase Performance Monitoring**
   - https://console.firebase.google.com/project/wawapp-952d6/performance

---

### **Metrics to Watch** (Every 15 minutes)

| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| Admin Panel Response Time | < 3 seconds | > 5 seconds |
| Cloud Functions Error Rate | < 1% | > 5% |
| Cloud Functions Execution Time | < 2 seconds | > 5 seconds |
| Firestore Reads | Baseline | Spike > 2x baseline |
| Firestore Writes | Baseline | Spike > 2x baseline |
| Authentication Success Rate | > 99% | < 95% |
| Settlement Latency | < 60 seconds | > 3 minutes |
| Payout Creation Success | 100% | Any failure |

---

### **Observation Checklist**

**T+15 minutes:**
- [ ] Check Cloud Functions logs for errors
- [ ] Verify no error spikes in Functions dashboard
- [ ] Check Firestore read/write metrics
- [ ] Verify admin panel responsive
- [ ] Check for any alerts fired
- [ ] Test one admin panel feature (e.g., load dashboard)

**T+30 minutes:**
- [ ] Review Firebase Performance traces
- [ ] Check for any slow endpoints (> 5s)
- [ ] Verify no auth anomalies
- [ ] Test settlement with real/test order (if applicable)
- [ ] Check wallet balances consistency
- [ ] Review any user feedback (if users active)

**T+45 minutes:**
- [ ] Analyze Cloud Functions invocation patterns
- [ ] Check for any cold start issues
- [ ] Verify Firestore indexes being used
- [ ] Test payout creation (if safe to do so)
- [ ] Review transaction ledger accuracy
- [ ] Check budget/cost tracking

**T+60 minutes:**
- [ ] Comprehensive smoke test repeat
- [ ] Check all admin panel screens
- [ ] Verify CSV exports work
- [ ] Test search and filter features
- [ ] Review error logs (should be minimal)
- [ ] Check for memory leaks (Functions)

**T+75 minutes:**
- [ ] Final metrics review
- [ ] Compare against baseline (if available)
- [ ] Check for gradual degradation
- [ ] Verify no cascading failures
- [ ] Review cost accumulation

**T+90 minutes:**
- [ ] **GO/NO-GO DECISION**
- [ ] If all checks passed: **Declare launch successful** 🎉
- [ ] If issues detected: **Execute rollback** 🔙
- [ ] Document observations
- [ ] Notify stakeholders of status

---

### **Go-Live Decision Criteria**

**✅ Proceed with Launch if:**
- All smoke tests passed
- Error rate < 1%
- No critical bugs detected
- Performance within targets
- No security issues
- Team confidence high

**❌ Execute Rollback if:**
- Error rate > 5%
- Any critical function failing
- Settlement not working correctly
- Data integrity issues
- Security vulnerability detected
- Performance severely degraded (> 10s response)
- Team consensus to rollback

---

## 📢 Communication Plan

### **Pre-Launch Communication** (T-24 hours)

**Stakeholders to Notify:**
- Executive team
- Operations team
- Customer support team
- Marketing team (if public launch)
- All engineers on-call

**Message Template:**
```
Subject: WawApp Production Launch - [Date] at [Time]

Team,

We will be launching WawApp to production on [DATE] at [TIME].

Launch Window: [START TIME] - [END TIME] (approximately 3 hours)
Launch Team: [Names and roles]
Communication Channel: [Slack/Teams channel]
Status Page: [URL if applicable]

What to expect:
- Brief service interruption during deployment (< 5 minutes)
- Observation period of 90 minutes post-launch
- Go-live decision at T+90 minutes

Rollback Plan:
- Prepared and tested
- Can be executed within 10 minutes

Contact:
- Launch Coordinator: [Name, phone, email]
- On-Call Engineer: [Name, phone, email]

We will send updates at:
- T+0 (Deployment start)
- T+30 (Post-deployment)
- T+60 (Observation midpoint)
- T+90 (Go-live decision)

Thank you,
[Launch Coordinator]
```

---

### **During Launch Communication** (Every 30 min)

**Update Template:**
```
[T+30] WawApp Launch Update

Status: [Green/Yellow/Red]

Completed:
- ✅ Firestore rules deployed
- ✅ Cloud Functions deployed
- ✅ Admin Panel deployed

In Progress:
- 🔄 Smoke tests running

Next Steps:
- Smoke test completion (10 minutes)
- Begin observation window

Issues:
- None / [List any issues]

Next update in 30 minutes.
```

---

### **Post-Launch Communication** (T+90)

**Success Template:**
```
Subject: ✅ WawApp Production Launch - SUCCESSFUL

Team,

WawApp production launch is COMPLETE and SUCCESSFUL! 🎉

Deployment Summary:
- Deployment Time: [START] - [END]
- Total Duration: [X] hours
- Smoke Tests: ✅ All Passed
- Observation Period: ✅ No issues detected

Key Metrics (T+90):
- Error Rate: [X%] (Target: < 1%)
- Response Time: [X]s (Target: < 3s)
- Settlement Latency: [X]s (Target: < 60s)

System Status:
- Admin Panel: ✅ Live at https://wawapp-952d6.web.app
- Cloud Functions: ✅ All operational
- Firestore: ✅ Healthy

Next Steps:
- Continue monitoring for next 24 hours
- On-call engineer available for any issues
- Next check-in: Tomorrow at [TIME]

Launch Team:
- Thank you to everyone involved!

Questions? Contact [Launch Coordinator]

Regards,
[Launch Coordinator]
```

**Rollback Template:**
```
Subject: ⚠️ WawApp Production Launch - ROLLBACK EXECUTED

Team,

WawApp production launch encountered issues and we have executed a rollback.

Current Status:
- System rolled back to previous version
- Services operational with previous version
- No data loss occurred

Issues Encountered:
- [List issues that triggered rollback]

Next Steps:
- Root cause analysis in progress
- Team meeting scheduled for [TIME]
- Fix plan will be shared by [DATE]
- Estimated re-launch date: [DATE]

Current System:
- Admin Panel: Previous version (stable)
- Cloud Functions: Previous version (stable)
- All user data intact

Questions? Contact [Launch Coordinator]

Thank you for your patience.

Regards,
[Launch Coordinator]
```

---

## 🐛 Troubleshooting

### **Common Issues During Launch**

---

#### **Issue 1: Admin Login Fails**

**Symptoms:**
- "Access denied" error
- User can sign in but gets rejected

**Diagnosis:**
```bash
# Check custom claims
firebase auth:export users.json --project wawapp-952d6
# Look for "customClaims": { "isAdmin": true }
```

**Fix:**
```bash
# Set admin claim using Cloud Function
# (Requires setAdminRole function deployed)
curl -X POST https://us-central1-wawapp-952d6.cloudfunctions.net/setAdminRole \
  -H "Content-Type: application/json" \
  -d '{"uid": "<user_uid>", "email": "admin.prod@wawapp.mr"}'
```

**Verification:**
- Try logging in again
- Check browser console for errors

---

#### **Issue 2: Settlement Not Triggering**

**Symptoms:**
- Order status changes to "completed"
- No `settledAt` timestamp
- Wallets not updated

**Diagnosis:**
```bash
# Check Cloud Functions logs
firebase functions:log --only onOrderCompleted --limit 50
```

**Possible Causes:**
1. Function not deployed
2. Order missing required fields (price, driverId)
3. Order already settled (idempotency)
4. Firestore trigger not firing

**Fix:**
```bash
# Redeploy function
cd functions
npm run build
firebase deploy --only functions:onOrderCompleted
```

**Verification:**
- Create test order
- Update to "completed"
- Wait 5 seconds
- Check logs and wallet balance

---

#### **Issue 3: Admin Panel Not Loading**

**Symptoms:**
- White screen
- Infinite loading spinner
- JavaScript errors

**Diagnosis:**
- Open browser DevTools (F12)
- Check Console tab for errors
- Check Network tab for failed requests

**Possible Causes:**
1. Build failed with dev mode
2. Firebase config incorrect
3. Authentication not initialized
4. Network issues

**Fix:**
```bash
# Rebuild with correct environment
cd apps/wawapp_admin
flutter clean
flutter pub get
flutter build web --release --dart-define=ENVIRONMENT=prod --web-renderer canvaskit

# Redeploy
cd ../..
firebase deploy --only hosting
```

**Verification:**
- Clear browser cache
- Hard refresh (Ctrl+Shift+R)
- Check console for "PROD" environment

---

#### **Issue 4: High Error Rate**

**Symptoms:**
- Error rate > 5%
- Multiple functions failing
- Users reporting issues

**Diagnosis:**
```bash
# Check functions dashboard
firebase functions:log --limit 100

# Check error patterns
firebase functions:log --only onOrderCompleted,adminCreatePayoutRequest
```

**Immediate Action:**
- **EXECUTE ROLLBACK**
- Do not wait for root cause analysis

**Post-Rollback:**
- Analyze logs for common error patterns
- Check for missing dependencies
- Verify Firestore permissions
- Review function timeout settings

---

#### **Issue 5: Firestore Read/Write Spikes**

**Symptoms:**
- Firestore read/write count abnormally high
- Quota warnings
- Cost spike

**Diagnosis:**
- Firebase Console → Firestore → Usage tab
- Identify which queries are hot

**Possible Causes:**
1. Admin panel polling too frequently
2. Missing Firestore indexes (full scans)
3. Infinite loop in Cloud Function
4. N+1 query problem

**Fix:**
```bash
# Check for missing indexes
firebase firestore:indexes:list

# Deploy missing indexes
firebase deploy --only firestore:indexes
```

**Immediate Mitigation:**
- Increase index coverage
- Add caching to admin panel
- Reduce polling frequency

---

## ✅ Launch Completion Checklist

### **Final Sign-Off**

- [ ] **Deployment Complete**
  - All phases executed successfully
  - No rollback required

- [ ] **Smoke Tests Passed**
  - All 8 critical tests passed
  - No critical bugs detected

- [ ] **Observation Complete**
  - 90-minute window completed
  - All metrics within targets
  - No degradation observed

- [ ] **Communication Sent**
  - Stakeholders notified of success
  - Status page updated (if applicable)
  - Team debriefed

- [ ] **Monitoring Active**
  - Alerts configured and tested
  - On-call engineer assigned
  - Escalation path confirmed

- [ ] **Documentation Updated**
  - Launch notes documented
  - Known issues logged
  - Runbook updated with learnings

- [ ] **Next Steps Planned**
  - 24-hour monitoring plan
  - Next release scheduled
  - Improvement backlog updated

---

### **Post-Launch Activities**

**Day 1 (T+24 hours):**
- Monitor metrics closely
- Check for delayed issues
- Review cost accumulation
- User feedback collection

**Day 2-7:**
- Daily metrics review
- Address any minor issues
- Optimize based on usage patterns
- Update documentation

**Week 2:**
- Comprehensive metrics report
- Launch retrospective meeting
- Lessons learned documentation
- Plan for improvements

**Week 4:**
- Monthly review
- Cost optimization analysis
- SLO/SLA compliance check
- Planning for next features

---

## 📊 Launch Success Metrics

| Metric | Target | Achieved | Status |
|--------|--------|----------|--------|
| Deployment Duration | < 30 min | _____ | ⬜ |
| Smoke Tests Pass Rate | 100% | _____ | ⬜ |
| Error Rate (T+90) | < 1% | _____ | ⬜ |
| Response Time (T+90) | < 3s | _____ | ⬜ |
| Settlement Latency | < 60s | _____ | ⬜ |
| Rollback Executed | No | _____ | ⬜ |
| Observation Issues | 0 | _____ | ⬜ |
| User Impact | None | _____ | ⬜ |

---

## 📝 Launch Sign-Off

**Launch Coordinator:** _________________  
**Signature:** _________________  
**Date:** _________________  
**Time:** _________________

**Backend Engineer:** _________________  
**Signature:** _________________

**Frontend Engineer:** _________________  
**Signature:** _________________

**DevOps/SRE:** _________________  
**Signature:** _________________

**Launch Status:** 
- [ ] ✅ SUCCESSFUL - Production live
- [ ] ⚠️ PARTIAL - Live with known issues
- [ ] ❌ ROLLBACK - Returned to previous version

**Notes:**
_____________________________________________________________________________
_____________________________________________________________________________
_____________________________________________________________________________

---

**Document Version:** 1.0  
**Last Updated:** December 2025  
**Status:** ✅ READY FOR GO-LIVE
