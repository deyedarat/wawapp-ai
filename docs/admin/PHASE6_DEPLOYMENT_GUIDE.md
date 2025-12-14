# Phase 6: Production Deployment & Operations Guide

**WawApp Admin Panel & Backend Infrastructure**  
**Version**: 1.0  
**Date**: December 2025  
**Status**: 🚀 PRODUCTION READY

---

## 📋 Table of Contents

1. [Quick Start](#quick-start)
2. [Environment Setup](#environment-setup)
3. [Pre-Deployment Checklist](#pre-deployment-checklist)
4. [Deployment Procedures](#deployment-procedures)
5. [Post-Deployment Verification](#post-deployment-verification)
6. [Rollback Procedures](#rollback-procedures)
7. [Monitoring & Alerts](#monitoring--alerts)
8. [Troubleshooting](#troubleshooting)

---

## 🚀 Quick Start

### One-Command Full Deployment

```bash
# From repository root
./scripts/deploy-production.sh --all
```

### Selective Deployment

```bash
# Deploy only Cloud Functions
./scripts/deploy-production.sh --functions-only

# Deploy only Firestore rules/indexes
./scripts/deploy-production.sh --firestore-only

# Deploy only Admin Panel
./scripts/deploy-production.sh --hosting-only

# Dry run (preview without deploying)
./scripts/deploy-production.sh --all --dry-run
```

---

## 🌍 Environment Setup

### Recommended Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    ENVIRONMENT TIERS                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  DEVELOPMENT          STAGING           PRODUCTION           │
│  ┌──────────────┐    ┌──────────┐     ┌──────────────┐     │
│  │ wawapp-dev   │    │ wawapp-  │     │ wawapp-952d6 │     │
│  │              │──> │ staging  │──>  │ (current)    │     │
│  │ Local/Dev    │    │          │     │              │     │
│  └──────────────┘    └──────────┘     └──────────────┘     │
│                                                              │
│  Features:            Features:        Features:            │
│  • Dev auth bypass   • Full auth       • Strict auth        │
│  • Local emulator    • Test data       • Live data          │
│  • Hot reload        • Pre-prod test   • Custom claims      │
│  • Mock data         • Staging URL     • Monitoring         │
│                                        • Backups            │
└─────────────────────────────────────────────────────────────┘
```

### Current Setup

- **Single Firebase Project**: `wawapp-952d6`
- **Collections**: Production data
- **Functions**: All deployed to production project

### Recommended Multi-Environment Setup

#### Option 1: Multiple Firebase Projects (Recommended)

```bash
# Create staging environment
firebase projects:create wawapp-staging

# Add to .firebaserc
{
  "projects": {
    "default": "wawapp-952d6",
    "staging": "wawapp-staging",
    "production": "wawapp-952d6"
  }
}

# Deploy to staging
firebase use staging
firebase deploy --only functions,firestore,hosting

# Deploy to production
firebase use production
firebase deploy --only functions,firestore,hosting
```

#### Option 2: Collection-Based Separation (Not Recommended)

Use prefixes: `dev_orders`, `staging_orders`, `orders`

**Pros**: Single project, simple billing  
**Cons**: Shared security rules, risk of data mixing

---

## ✅ Pre-Deployment Checklist

### Before Any Production Deployment

- [ ] **Code Review**: All PRs merged and reviewed
- [ ] **Tests Pass**: All unit/integration tests pass
- [ ] **Firebase CLI**: Latest version installed (`firebase --version`)
- [ ] **Flutter SDK**: Version 3.0.0+ installed (`flutter --version`)
- [ ] **Node.js**: Version 20.x installed (`node --version`)
- [ ] **Firebase Login**: Authenticated (`firebase login`)
- [ ] **Project Selected**: Correct project active (`firebase use production`)
- [ ] **Git Status**: All changes committed (`git status`)
- [ ] **Backup**: Recent Firestore backup exists
- [ ] **Dev Auth**: Bypass code removed/disabled (See Section 4)

### Security Checklist

- [ ] **Admin Claims**: At least one admin user with `{ isAdmin: true }`
- [ ] **Firestore Rules**: Reviewed and tested
- [ ] **Function Auth**: All admin functions check `isAdmin` claim
- [ ] **Dev Service**: `admin_auth_service_dev.dart` NOT used in production
- [ ] **Secrets**: No hardcoded secrets or API keys in code
- [ ] **CORS**: Properly configured for Cloud Functions

### Data Checklist

- [ ] **Indexes**: All composite indexes deployed
- [ ] **Migrations**: Any data migrations completed
- [ ] **Test Data**: Production has real (not test) data
- [ ] **Wallets**: Platform wallet (`platform_main`) exists

---

## 🚀 Deployment Procedures

### Full Stack Deployment

#### Step 1: Prepare

```bash
# Navigate to repository root
cd /path/to/wawapp-ai

# Verify branch
git checkout driver-auth-stable-work
git pull origin driver-auth-stable-work

# Verify project
firebase use production  # or wawapp-952d6
firebase projects:list
```

#### Step 2: Deploy Cloud Functions

```bash
cd functions

# Install dependencies
npm install

# Build TypeScript
npm run build

# Check for errors
# If build fails, fix errors before proceeding

# Deploy functions
cd ..
firebase deploy --only functions

# Expected output:
# ✔ functions[expireStaleOrders]: Successful create operation
# ✔ functions[aggregateDriverRating]: Successful create operation
# ... (all 20+ functions)
```

**Functions Deployed:**

| Category | Function Name | Trigger Type |
|----------|---------------|--------------|
| **Core** | `expireStaleOrders` | Scheduled (hourly) |
| | `aggregateDriverRating` | Firestore (orders) |
| | `notifyOrderEvents` | Firestore (orders) |
| | `cleanStaleDriverLocations` | Scheduled (15 min) |
| **Admin** | `setAdminRole` | Callable |
| | `removeAdminRole` | Callable |
| | `getAdminStats` | Callable |
| | `adminCancelOrder` | Callable |
| | `adminReassignOrder` | Callable |
| | `adminBlockDriver` | Callable |
| | `adminUnblockDriver` | Callable |
| | `adminVerifyDriver` | Callable |
| | `adminSetClientVerification` | Callable |
| | `adminBlockClient` | Callable |
| | `adminUnblockClient` | Callable |
| **Reports** | `getReportsOverview` | Callable |
| | `getFinancialReport` | Callable |
| | `getDriverPerformanceReport` | Callable |
| **Finance** | `onOrderCompleted` | Firestore (orders) |
| | `adminCreatePayoutRequest` | Callable |
| | `adminUpdatePayoutStatus` | Callable |

#### Step 3: Deploy Firestore Rules & Indexes

```bash
# Deploy rules and indexes
firebase deploy --only firestore

# Monitor index creation
# Go to: Firebase Console → Firestore → Indexes
# Indexes may take 5-15 minutes to build
```

**Deployed Indexes:**

1. **orders**: `(status ASC, createdAt DESC)`
2. **orders**: `(driverId ASC, status ASC, completedAt DESC)`
3. **orders**: `(status ASC, assignedDriverId ASC, createdAt DESC)`
4. **orders**: `(ownerId ASC, createdAt DESC)`
5. **orders**: `(ownerId ASC, status ASC, createdAt DESC)`
6. **orders**: `(driverId ASC, status ASC)`
7. **orders**: `(driverId ASC, status ASC, updatedAt DESC)`

#### Step 4: Build & Deploy Admin Panel

```bash
cd apps/wawapp_admin

# Install Flutter dependencies
flutter pub get

# Build for web (production)
# CRITICAL: Must include --dart-define=ENVIRONMENT=prod for security
flutter build web --release --web-renderer canvaskit --dart-define=ENVIRONMENT=prod

# Verify build
ls -la build/web/
# Should see: index.html, main.dart.js, flutter_service_worker.js, etc.

# Deploy to Firebase Hosting
cd ../..
firebase deploy --only hosting

# Expected output:
# ✔ hosting[wawapp-952d6]: file upload complete
# ✔ hosting[wawapp-952d6]: version finalized
# ✔ hosting[wawapp-952d6]: release complete
```

#### Step 5: Verify Deployment

```bash
# Get hosting URL
firebase hosting:channel:list

# URLs:
# Production: https://wawapp-952d6.web.app
#         or: https://wawapp-952d6.firebaseapp.com
```

---

### Individual Component Deployment

#### Deploy Only Functions (Faster Updates)

```bash
cd functions
npm run build
cd ..
firebase deploy --only functions

# Or specific functions:
firebase deploy --only functions:getFinancialReport,getReportsOverview
```

#### Deploy Only Firestore (Rule Changes)

```bash
firebase deploy --only firestore:rules

# Or just indexes:
firebase deploy --only firestore:indexes
```

#### Deploy Only Hosting (UI Updates)

```bash
cd apps/wawapp_admin
# CRITICAL: Must include environment flag for production
flutter build web --release --dart-define=ENVIRONMENT=prod
cd ../..
firebase deploy --only hosting
```

---

## ✅ Post-Deployment Verification

### Automated Verification Script

```bash
# Run verification tests (TODO: Create this script)
./scripts/verify-deployment.sh
```

### Manual Verification Checklist

#### 1. Admin Panel Access

- [ ] Visit: `https://wawapp-952d6.web.app`
- [ ] Login with admin credentials
- [ ] Dashboard loads without errors
- [ ] No console errors in browser DevTools

#### 2. Core Screens

- [ ] **Dashboard**: KPI cards display
- [ ] **Live Ops**: Map loads, real-time markers appear
- [ ] **Orders**: Table loads, filtering works
- [ ] **Drivers**: List loads, details clickable
- [ ] **Clients**: List loads, verification status visible

#### 3. Reports Module

- [ ] **Overview Report**: KPIs load
- [ ] **Financial Report**: Revenue, earnings, wallet metrics display
- [ ] **Driver Performance**: Rankings load, sorting works
- [ ] **CSV Export**: Downloads work, files open correctly

#### 4. Finance Module

- [ ] **Wallets**: Driver balances load, platform wallet displays
- [ ] **Transactions**: Ledger displays in wallet details
- [ ] **Payouts**: List loads, status filtering works
- [ ] **Create Payout**: Dialog opens, validation works
- [ ] **CSV Export**: Payouts export downloads

#### 5. Cloud Functions

```bash
# Check function logs
firebase functions:log

# Expected: No errors in recent logs
# Look for successful executions
```

**Test Callable Functions:**

```bash
# Via Firebase console or client app
# Test: getAdminStats
# Expected: Returns dashboard statistics

# Test: getFinancialReport
# Input: { startDate: "2025-12-01", endDate: "2025-12-10" }
# Expected: Returns financial summary and daily breakdown
```

#### 6. Database Operations

- [ ] **Read Operations**: Data loads in UI
- [ ] **Write Operations**: Admin actions create audit log entries
- [ ] **Triggers**: Order completion triggers wallet settlement
- [ ] **Scheduled Functions**: Check last execution time

### Performance Checks

```bash
# Check function execution times
# Firebase Console → Functions → Metrics
# Expected: <2s for most functions, <5s for reports

# Check Firestore reads
# Firebase Console → Firestore → Usage
# Monitor for unexpected spikes
```

---

## 🔄 Rollback Procedures

### Quick Rollback

#### Rollback Cloud Functions

```bash
# List recent deployments
firebase functions:list

# Rollback to previous version
firebase functions:delete <function_name>
firebase deploy --only functions:<function_name>

# Or deploy specific git commit:
git checkout <previous_commit_hash>
cd functions && npm run build && cd ..
firebase deploy --only functions
git checkout driver-auth-stable-work
```

#### Rollback Hosting

```bash
# List recent releases
firebase hosting:releases:list

# Rollback to previous release
firebase hosting:rollback
```

#### Rollback Firestore Rules

```bash
# Restore previous rules file from git
git checkout HEAD~1 firestore.rules
firebase deploy --only firestore:rules

# Then restore current version
git checkout driver-auth-stable-work firestore.rules
```

### Emergency Rollback Plan

**If major issues detected post-deployment:**

1. **Stop the Bleeding**
   ```bash
   # Disable affected functions
   firebase functions:delete <problematic_function>
   ```

2. **Rollback Hosting**
   ```bash
   firebase hosting:rollback
   ```

3. **Restore Firestore Rules**
   ```bash
   git checkout <last_stable_commit> firestore.rules
   firebase deploy --only firestore:rules
   ```

4. **Communicate**
   - Notify team in Slack/email
   - Update status page if applicable
   - Document incident

5. **Investigate**
   - Review function logs: `firebase functions:log --limit 100`
   - Check Firestore metrics
   - Analyze error patterns

6. **Fix & Redeploy**
   - Create hotfix branch
   - Fix issue
   - Test locally
   - Deploy fix

---

## 📊 Monitoring & Alerts

### Firebase Console Dashboards

#### Functions Dashboard

**URL**: `https://console.firebase.google.com/project/wawapp-952d6/functions`

**Key Metrics to Monitor:**
- ✅ Invocations: Should be consistent
- ⚠️ Errors: Should be <1%
- ⏱️ Execution time: Most <2s
- 💰 Cost: Monitor for unexpected spikes

#### Firestore Dashboard

**URL**: `https://console.firebase.google.com/project/wawapp-952d6/firestore`

**Key Metrics:**
- 📖 Document reads: Monitor for excessive queries
- ✍️ Document writes: Check for write patterns
- 💾 Storage: Track growth
- 🔍 Index usage: Ensure indexes are being used

### Google Cloud Monitoring

#### Set Up Log-Based Alerts

```bash
# Install Google Cloud CLI (if not already installed)
gcloud init

# Create alert for function errors
gcloud alpha monitoring policies create \
  --notification-channels=<channel_id> \
  --display-name="WawApp Function Errors" \
  --condition-display-name="Function error rate > 5%" \
  --condition-threshold-value=0.05 \
  --condition-threshold-duration=300s
```

#### Recommended Alerts

1. **Function Error Rate**
   - Condition: Error rate > 5% for 5 minutes
   - Action: Email to admin@wawapp.mr

2. **Function Timeout**
   - Condition: Execution time > 60s
   - Action: Email alert

3. **Firestore Quota**
   - Condition: Daily reads > 80% of quota
   - Action: Email + Slack notification

4. **Authentication Failures**
   - Condition: Failed auth attempts > 100 in 15 min
   - Action: Immediate email alert

### Logging Best Practices

**In Cloud Functions:**

```typescript
// Use structured logging
import * as functions from 'firebase-functions';

functions.logger.info('Order completed', {
  orderId: order.id,
  driverId: order.driverId,
  amount: order.price,
  timestamp: Date.now()
});

// Error logging with context
try {
  // ... operation
} catch (error) {
  functions.logger.error('Wallet settlement failed', {
    orderId: order.id,
    error: error.message,
    stack: error.stack
  });
  throw error;
}
```

**Log Query Examples:**

```bash
# View recent function errors
firebase functions:log --only getFinancialReport --limit 50

# View all errors in last hour
firebase functions:log --limit 100 | grep ERROR

# View specific order processing
firebase functions:log | grep "orderId: ORDER123"
```

---

## 🔧 Troubleshooting

### Common Issues & Solutions

#### Issue 1: Function Deployment Fails

**Symptoms:**
```
Error: HTTP Error: 403, Permission denied
```

**Solution:**
```bash
# Re-authenticate
firebase login --reauth

# Check project
firebase use --add

# Check IAM permissions in Google Cloud Console
# Ensure service account has "Cloud Functions Developer" role
```

#### Issue 2: Firestore Index Not Found

**Symptoms:**
```
Error: The query requires an index
```

**Solution:**
```bash
# Deploy indexes
firebase deploy --only firestore:indexes

# Wait 5-15 minutes for index building

# Check index status
# Firebase Console → Firestore → Indexes
```

#### Issue 3: Admin Panel Won't Load

**Symptoms:**
- Blank screen
- Console errors: `Failed to load firebase config`

**Solution:**

1. Check `firebase_options.dart` is correct
2. Verify hosting deployment succeeded
3. Check browser console for errors
4. Clear browser cache
5. Try incognito mode

```bash
# Redeploy hosting
cd apps/wawapp_admin
flutter clean
flutter pub get
# CRITICAL: Must include environment flag
flutter build web --release --dart-define=ENVIRONMENT=prod
cd ../..
firebase deploy --only hosting
```

#### Issue 4: Admin Login Fails

**Symptoms:**
- "Permission denied" error
- Can login but can't access admin features

**Solution:**

1. **Check custom claim:**
   ```javascript
   // In Firebase Console → Authentication → Users
   // Select user → Custom claims
   // Should show: { "isAdmin": true }
   ```

2. **Set custom claim:**
   ```bash
   firebase functions:shell
   > setAdminRole({email: 'admin@wawapp.mr'})
   ```

3. **Verify not using dev auth service:**
   - Check `apps/wawapp_admin/lib/providers/admin_auth_providers.dart`
   - Should use production auth service, not `admin_auth_service_dev.dart`

#### Issue 5: Wallet Balances Wrong

**Symptoms:**
- Driver balances don't match expected values
- Platform balance incorrect

**Solution:**

1. **Check transaction ledger:**
   ```bash
   # Firebase Console → Firestore
   # Navigate to: transactions collection
   # Filter by walletId
   # Verify all transactions recorded
   ```

2. **Verify order settlement trigger:**
   ```bash
   # Check function logs
   firebase functions:log --only onOrderCompleted

   # Look for:
   # ✓ "Order settled successfully"
   # ✗ "Settlement failed" errors
   ```

3. **Recalculate balances (if needed):**
   ```typescript
   // Create admin Cloud Function to recalculate
   // Sum all transactions for each wallet
   // Update wallet.balance field
   ```

#### Issue 6: Reports Not Loading

**Symptoms:**
- Empty reports
- "No data" message
- Timeout errors

**Solution:**

1. **Check date range:**
   - Ensure date range includes orders
   - Try "Last 7 days" preset

2. **Check function logs:**
   ```bash
   firebase functions:log --only getFinancialReport
   ```

3. **Verify indexes:**
   - Firebase Console → Firestore → Indexes
   - All indexes should be "Enabled"

4. **Check Firestore data:**
   - Verify `orders` collection has documents
   - Check `completedAt` timestamps are set

---

## 📚 Additional Resources

### Documentation

- [Firebase Console](https://console.firebase.google.com/project/wawapp-952d6)
- [Google Cloud Console](https://console.cloud.google.com/)
- [Firebase CLI Reference](https://firebase.google.com/docs/cli)
- [Firestore Best Practices](https://firebase.google.com/docs/firestore/best-practices)
- [Cloud Functions Best Practices](https://firebase.google.com/docs/functions/best-practices)

### Internal Documentation

- `docs/admin/FIRESTORE_SCHEMA_ADMIN_VIEW.md` - Database schema
- `docs/admin/REPORTS_PHASE4.md` - Reports module documentation
- `docs/admin/WALLETS_PHASE5_SCHEMA.md` - Wallet system schema
- `docs/admin/WALLETS_PHASE5_5_INTEGRATION.md` - Finance integration
- `PHASE4_COMPLETION_SUMMARY.md` - Phase 4 summary
- `WALLETS_PHASE5_COMPLETION_SUMMARY.md` - Phase 5 summary

### Support Contacts

- **Technical Lead**: [Your contact]
- **Firebase Support**: firebase-support@google.com
- **Emergency Hotline**: [Your emergency contact]

---

## ✅ Deployment Checklist Template

Copy this for each deployment:

```markdown
# WawApp Deployment - [DATE]

## Pre-Deployment
- [ ] Code reviewed and approved
- [ ] All tests passing
- [ ] Firebase CLI up to date
- [ ] Correct project selected
- [ ] Backup completed
- [ ] Dev auth bypass disabled/removed

## Deployment
- [ ] Cloud Functions deployed
- [ ] Firestore rules deployed
- [ ] Firestore indexes deployed
- [ ] Admin Panel built
- [ ] Admin Panel deployed

## Verification
- [ ] Admin panel accessible
- [ ] Admin login works
- [ ] Dashboard loads
- [ ] Reports generate
- [ ] Wallets display correctly
- [ ] Payouts functional
- [ ] Function logs clean
- [ ] No unexpected errors

## Monitoring
- [ ] Function metrics normal
- [ ] Firestore usage normal
- [ ] No error alerts
- [ ] Performance acceptable

## Rollback Plan
- [ ] Previous version noted: [commit hash]
- [ ] Rollback procedure reviewed
- [ ] Team notified of deployment

## Sign-Off
- Deployed by: [Name]
- Date: [Date]
- Time: [Time]
- Status: ✅ Success / ❌ Rolled Back
```

---

**Document Version**: 1.0  
**Last Updated**: December 2025  
**Status**: 🚀 Production Ready

