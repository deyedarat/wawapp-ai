# WawApp Operations Runbook

**Platform**: WawApp Mauritania Ride & Delivery  
**Component**: Admin Panel + Cloud Functions + Firestore  
**Version**: 1.0  
**Last Updated**: December 2025

---

## 📋 Table of Contents

1. [Daily Operations](#daily-operations)
2. [Monitoring Dashboards](#monitoring-dashboards)
3. [Alert Response Procedures](#alert-response-procedures)
4. [Common Incidents & Resolution](#common-incidents--resolution)
5. [Backup & Recovery](#backup--recovery)
6. [Release Process](#release-process)
7. [On-Call Procedures](#on-call-procedures)

---

## 📅 Daily Operations

### Morning Health Check (10 minutes)

**Time**: First thing each business day  
**Responsibility**: Operations team or designated admin

#### Checklist

```bash
# 1. Check Firebase Console
# https://console.firebase.google.com/project/wawapp-952d6

# 2. Verify Cloud Functions Health
✅ All functions showing "Healthy" status
✅ No error spikes in last 24h
✅ Execution times within normal range (<5s for reports)

# 3. Check Firestore Metrics
✅ Read/write operations normal
✅ No quota warnings
✅ Storage within limits
✅ Index status: All "Enabled"

# 4. Verify Admin Panel Accessibility
✅ https://wawapp-952d6.web.app loads
✅ Login works
✅ Dashboard displays KPIs
✅ No console errors

# 5. Check Recent Orders
✅ Orders being created
✅ Orders being assigned to drivers
✅ Orders being completed
✅ Wallet settlements occurring

# 6. Verify Financial Data
✅ Platform wallet balance increasing
✅ Driver wallets showing activity
✅ Payout requests being processed
```

**If any check fails**: See [Alert Response Procedures](#alert-response-procedures)

---

### Weekly Operations (30 minutes)

**Time**: Monday morning  
**Responsibility**: Technical lead

#### Weekly Checklist

```bash
# 1. Review Function Performance
📊 Check execution time trends
📊 Identify slow queries
📊 Review error patterns
📊 Check for new error types

# 2. Firestore Analysis
📊 Review read/write patterns
📊 Check for missing indexes
📊 Analyze query performance
📊 Review storage growth

# 3. Cost Analysis
💰 Review Firebase billing
💰 Check for unexpected spikes
💰 Optimize expensive queries
💰 Review function invocations

# 4. Security Review
🔒 Check admin_actions audit log
🔒 Review failed auth attempts
🔒 Verify no unauthorized access
🔒 Check for suspicious patterns

# 5. Data Quality
✅ Verify wallet balance accuracy
✅ Check transaction ledger integrity
✅ Review payout status consistency
✅ Verify order state transitions
```

---

## 📊 Monitoring Dashboards

### Primary Dashboards

#### 1. Firebase Console - Functions

**URL**: `https://console.firebase.google.com/project/wawapp-952d6/functions`

**Key Metrics:**

| Metric | Green | Yellow | Red |
|--------|-------|--------|-----|
| **Error Rate** | <1% | 1-5% | >5% |
| **Avg Execution Time** | <2s | 2-5s | >5s |
| **Invocations/hour** | Steady | Spike +50% | Spike +200% |
| **Memory Usage** | <256MB | 256-512MB | >512MB |

**Functions to Watch:**

- **Critical**:
  - `onOrderCompleted` (wallet settlements)
  - `adminCreatePayoutRequest` (payout creation)
  - `getFinancialReport` (reports)

- **Important**:
  - `expireStaleOrders` (scheduled cleanup)
  - `adminCancelOrder` (order management)
  - `getAdminStats` (dashboard)

#### 2. Firebase Console - Firestore

**URL**: `https://console.firebase.google.com/project/wawapp-952d6/firestore`

**Key Metrics:**

| Metric | Daily Limit | Warning Threshold | Action |
|--------|-------------|-------------------|--------|
| **Document Reads** | 50,000 | 40,000 (80%) | Optimize queries |
| **Document Writes** | 20,000 | 16,000 (80%) | Review write patterns |
| **Storage** | Unlimited | N/A | Monitor growth |

**Collections to Monitor:**

- **orders**: Read-heavy, check for missing indexes
- **wallets**: Low volume, critical accuracy
- **transactions**: Write-heavy, ensure idempotency
- **payouts**: Medium volume, check status distribution

#### 3. Firebase Console - Authentication

**URL**: `https://console.firebase.google.com/project/wawapp-952d6/authentication`

**Monitor:**
- Total users (drivers + clients + admins)
- Sign-ins per day
- Failed authentication attempts (>100 = investigate)
- Admin users with `isAdmin` claim

#### 4. Google Cloud Console - Monitoring

**URL**: `https://console.cloud.google.com/monitoring`

**Custom Dashboards:**

Create dashboard with these widgets:

1. **Function Errors**
   - Chart: Error count by function (last 24h)
   - Alert: Error rate > 5% for 5 minutes

2. **Function Latency**
   - Chart: 95th percentile execution time
   - Alert: >10s for any function

3. **Firestore Operations**
   - Chart: Reads/writes per hour
   - Alert: Approaching quota (80%)

4. **Cost Trends**
   - Chart: Daily Firebase costs
   - Alert: >20% increase week-over-week

---

## 🚨 Alert Response Procedures

### Alert Types

#### 🔴 CRITICAL - Immediate Response (5 minutes)

**Triggers:**
- Admin panel completely down
- All functions failing (>50% error rate)
- Database write failures
- Wallet settlement failures

**Response:**
1. **Acknowledge alert immediately**
2. **Check status**:
   ```bash
   firebase functions:log --limit 50
   ```
3. **Identify scope**: All users? Specific feature?
4. **Rollback if recent deploy**: See [Release Process](#release-process)
5. **Notify team in #incidents Slack channel**
6. **Begin investigation**: Check logs, metrics, recent changes

#### 🟡 WARNING - Response within 30 minutes

**Triggers:**
- Function error rate 5-10%
- Slow response times (>5s)
- Approaching quota limits (>80%)
- Failed auth attempts spike

**Response:**
1. **Acknowledge alert**
2. **Assess impact**: How many users affected?
3. **Check recent changes**: New deploy? Traffic spike?
4. **Monitor trends**: Getting worse or stable?
5. **Plan fix**: Immediate or can wait for next deploy?

#### ℹ️ INFO - Monitor, log, address in next sprint

**Triggers:**
- Minor error rate increase (<5%)
- Slow non-critical functions
- Data quality issues
- UI bugs

**Response:**
1. **Log in issue tracker**
2. **Add to monitoring dashboard**
3. **Schedule for next sprint**
4. **Document workaround if applicable**

---

### Incident Response Playbooks

#### Playbook 1: Admin Panel Won't Load

**Symptoms:**
- Blank white screen
- "Failed to initialize Firebase" error
- Console errors

**Diagnosis:**
```bash
# 1. Check hosting status
firebase hosting:channel:list

# 2. Check browser console (F12)
# Look for: CORS errors, 404s, Firebase init errors

# 3. Check Firebase project status
# https://status.firebase.google.com

# 4. Verify firebase_options.dart is correct
cd apps/wawapp_admin
cat lib/firebase_options.dart | grep apiKey
```

**Resolution:**
```bash
# Option 1: Rollback hosting
firebase hosting:rollback

# Option 2: Redeploy
cd apps/wawapp_admin
flutter clean
flutter pub get
flutter build web --release --dart-define=ENVIRONMENT=prod
cd ../..
firebase deploy --only hosting

# Option 3: Check if Firebase service is down
# If yes, wait and communicate status to users
```

**Estimated Time to Resolve**: 10-30 minutes

---

#### Playbook 2: Wallet Settlement Failing

**Symptoms:**
- Orders completing but wallet not credited
- Errors in `onOrderCompleted` function logs
- Driver balances not updating

**Diagnosis:**
```bash
# 1. Check function logs
firebase functions:log --only onOrderCompleted --limit 100

# Look for:
# - "Order already settled" (duplicate trigger)
# - "Wallet not found" (wallet creation failed)
# - "Transaction write failed" (Firestore issue)

# 2. Check recent order
# Firebase Console → Firestore → orders → [recent order ID]
# Verify:
# - status: "completed"
# - completedAt: timestamp exists
# - driverId: valid

# 3. Check transactions collection
# Firebase Console → Firestore → transactions
# Filter by orderId
# Should see 2 transactions:
# - Driver credit
# - Platform credit

# 4. Check wallet balances
# Manually sum transactions vs wallet.balance
```

**Resolution:**

**If settlement failed:**
```bash
# Option 1: Manually create transactions (via admin function)
# TODO: Create admin function for manual settlement

# Option 2: Re-trigger settlement
# Update order to re-fire trigger (change updatedAt)

# Option 3: Wait for next deploy with fix
# Coordinate with developers
```

**Immediate Mitigation:**
```javascript
// In Firebase Console → Firestore
// Manually create transaction documents:

// Transaction 1: Driver credit
{
  id: "txn_[orderId]_driver",
  walletId: "driver_[driverId]",
  type: "credit",
  source: "order_settlement",
  amount: 800,  // 80% of order price
  currency: "MRU",
  orderId: "[orderId]",
  createdAt: Timestamp.now(),
  balanceSnapshot: [calculate: currentBalance + 800],
  note: "Manual settlement for order [orderId]"
}

// Transaction 2: Platform credit
{
  id: "txn_[orderId]_platform",
  walletId: "platform_main",
  type: "credit",
  source: "order_settlement",
  amount: 200,  // 20% of order price
  currency: "MRU",
  orderId: "[orderId]",
  createdAt: Timestamp.now(),
  balanceSnapshot: [calculate: currentBalance + 200],
  note: "Manual settlement for order [orderId]"
}

// Update wallet balances
// wallets/driver_[driverId]
{
  balance: balance + 800,
  totalCredited: totalCredited + 800,
  updatedAt: Timestamp.now()
}

// wallets/platform_main
{
  balance: balance + 200,
  totalCredited: totalCredited + 200,
  updatedAt: Timestamp.now()
}
```

**Estimated Time to Resolve**: 15-60 minutes

---

#### Playbook 3: Reports Not Generating

**Symptoms:**
- Empty reports
- "No data" message
- Timeout errors
- Function errors in logs

**Diagnosis:**
```bash
# 1. Check function logs
firebase functions:log --only getFinancialReport
firebase functions:log --only getReportsOverview

# 2. Check Firestore indexes
# Firebase Console → Firestore → Indexes
# All should be "Enabled" not "Building"

# 3. Test manually with date range
# In admin panel, select:
# - Last 7 days (should have data)
# - Custom: specific date with known orders

# 4. Check orders collection
# Firebase Console → Firestore → orders
# Filter: status == "completed"
# Verify data exists in selected range
```

**Resolution:**

**If index missing:**
```bash
# Deploy indexes
firebase deploy --only firestore:indexes

# Wait 5-15 minutes for building
# Monitor: Firebase Console → Firestore → Indexes
```

**If query timeout:**
```typescript
// Optimization needed in Cloud Function
// Check functions/src/reports/getFinancialReport.ts
// Consider:
// 1. Smaller date ranges
// 2. Pagination
// 3. Cached aggregations
```

**If no data:**
```bash
# Check if orders have completedAt timestamps
# If missing, update manually or via function
```

**Estimated Time to Resolve**: 10-30 minutes (indexes) or 1-4 hours (optimization)

---

#### Playbook 4: Payout Creation Failing

**Symptoms:**
- "Insufficient balance" error
- "Wallet not found" error
- Payout status stuck in "requested"

**Diagnosis:**
```bash
# 1. Check function logs
firebase functions:log --only adminCreatePayoutRequest

# 2. Verify driver wallet exists
# Firebase Console → Firestore → wallets/driver_[driverId]

# 3. Check wallet balance
# balance >= payout amount?
# pendingPayout should not block new payouts

# 4. Check existing payouts for driver
# Firebase Console → Firestore → payouts
# Filter: driverId == "[driverId]" AND status IN ["requested", "approved", "processing"]
```

**Resolution:**

**If insufficient balance:**
```
# Inform admin that balance is too low
# Current balance: X MRU
# Requested: Y MRU
# Driver needs to complete more trips
```

**If wallet not found:**
```javascript
// Create wallet manually in Firestore
// wallets/driver_[driverId]
{
  id: "driver_[driverId]",
  driverId: "[driverId]",
  balance: 0,
  pendingPayout: 0,
  totalCredited: 0,
  totalDebited: 0,
  currency: "MRU",
  createdAt: Timestamp.now(),
  updatedAt: Timestamp.now()
}
```

**If payout stuck:**
```bash
# Update payout status manually
# Firebase Console → Firestore → payouts/[payoutId]
# Change status to appropriate value:
# - "approved" if balance is sufficient
# - "rejected" if balance is insufficient or other issue
```

**Estimated Time to Resolve**: 5-20 minutes

---

## 💾 Backup & Recovery

### Firestore Backups

#### Automated Daily Backups

**Setup** (one-time):
```bash
# Enable Firestore automatic backups
gcloud firestore backups schedules create \
  --database='(default)' \
  --recurrence=daily \
  --retention=7d

# Verify schedule
gcloud firestore backups schedules list
```

**Location**: Google Cloud Storage bucket

#### Manual Backup

**When**: Before major deployments or data migrations

```bash
# Export all collections
gcloud firestore export gs://wawapp-952d6-backups/manual-backup-$(date +%Y%m%d)

# Or specific collections
gcloud firestore export gs://wawapp-952d6-backups/manual-backup-$(date +%Y%m%d) \
  --collection-ids=orders,drivers,wallets,transactions,payouts
```

#### Recovery Procedure

**Scenario**: Need to restore data from backup

```bash
# 1. Identify backup to restore
gcloud firestore backups list

# 2. Restore to new collection (DO NOT overwrite production)
gcloud firestore import gs://wawapp-952d6-backups/backup-20251210 \
  --collection-ids=orders_restored

# 3. Verify restored data
# Firebase Console → Firestore → orders_restored

# 4. If correct, migrate to production collection
# Use admin function or manual process
```

**Estimated Time**: 30 minutes - 2 hours (depending on data size)

---

### Code Backups

**Git Repository**: `github.com/deyedarat/wawapp-ai`

**Critical Branches:**
- `main`: Stable production code
- `driver-auth-stable-work`: Current development
- `hotfix/*`: Emergency fixes

**Recovery**:
```bash
# Checkout specific version
git checkout <commit-hash>

# Redeploy
./scripts/deploy-production.sh --all
```

---

## 🚀 Release Process

### Standard Release (Planned)

**Frequency**: Weekly or bi-weekly  
**Duration**: 30-60 minutes  
**Timing**: Off-peak hours (e.g., Sunday 22:00 GMT)

#### Pre-Release Checklist

- [ ] All tests passing
- [ ] Code reviewed and approved
- [ ] Staging tested successfully
- [ ] Firestore backup completed
- [ ] Team notified of release window
- [ ] Rollback plan reviewed

#### Release Steps

```bash
# 1. Sync with latest
git checkout driver-auth-stable-work
git pull origin driver-auth-stable-work

# 2. Tag release
git tag -a v1.x.x -m "Release v1.x.x: [description]"
git push origin v1.x.x

# 3. Deploy
./scripts/deploy-production.sh --all

# 4. Monitor for 30 minutes
# Watch dashboards for errors

# 5. Verify functionality
# Run smoke tests (see checklist in PHASE6_DEPLOYMENT_GUIDE.md)

# 6. Announce completion
# Notify team in Slack
```

#### Post-Release

- [ ] Monitor error rates for 24 hours
- [ ] Check key metrics (orders, settlements, reports)
- [ ] Document any issues
- [ ] Update release notes

---

### Hotfix Release (Emergency)

**Trigger**: Critical bug in production  
**Duration**: 15-30 minutes

```bash
# 1. Create hotfix branch
git checkout -b hotfix/critical-bug-fix driver-auth-stable-work

# 2. Make minimal fix
# Edit only necessary files

# 3. Test locally (if possible)
# Or deploy to staging first

# 4. Deploy immediately
./scripts/deploy-production.sh --functions-only  # If function fix
# or
./scripts/deploy-production.sh --hosting-only  # If UI fix

# 5. Verify fix
# Test the specific bug

# 6. Merge back
git checkout driver-auth-stable-work
git merge hotfix/critical-bug-fix
git push origin driver-auth-stable-work
```

---

## 📞 On-Call Procedures

### On-Call Rotation

**Schedule**: 24/7 coverage  
**Rotation**: Weekly  
**Handoff**: Friday 17:00 GMT

#### On-Call Responsibilities

- Respond to critical alerts within 5 minutes
- Investigate and resolve incidents
- Escalate if needed
- Document all incidents
- Update runbooks based on learnings

#### Escalation Path

1. **Level 1**: On-call engineer (5 min response)
2. **Level 2**: Technical lead (15 min response)
3. **Level 3**: CTO / Senior management (30 min response)

#### Contact Information

```
On-Call Engineer: [Phone] [Email]
Technical Lead: [Phone] [Email]
Firebase Support: firebase-support@google.com
Emergency: [Emergency hotline]
```

---

## 📊 Metrics & SLAs

### Service Level Objectives (SLOs)

| Metric | Target | Warning | Critical |
|--------|--------|---------|----------|
| **Admin Panel Uptime** | 99.5% | <99% | <95% |
| **Function Success Rate** | 99% | <97% | <95% |
| **Report Generation Time** | <5s (p95) | >10s | >30s |
| **Order Settlement Latency** | <10s | >30s | >60s |
| **API Response Time** | <2s (p95) | >5s | >10s |

### Key Performance Indicators (KPIs)

**Daily Tracking:**
- Total orders processed
- Order completion rate
- Average order value
- Total wallet settlements
- Payout requests processed
- Admin panel active users
- Function error rate

**Weekly Review:**
- Revenue trends
- Driver performance trends
- Report usage statistics
- Function cost analysis
- Data growth rate

---

## 📚 Reference Links

### Quick Access

- [Firebase Console](https://console.firebase.google.com/project/wawapp-952d6)
- [Google Cloud Console](https://console.cloud.google.com/)
- [GitHub Repository](https://github.com/deyedarat/wawapp-ai)
- [Admin Panel](https://wawapp-952d6.web.app)
- [Deployment Guide](./PHASE6_DEPLOYMENT_GUIDE.md)
- [Config Strategy](./DEV_VS_PROD_CONFIG_STRATEGY.md)

### Support Resources

- [Firebase Documentation](https://firebase.google.com/docs)
- [Cloud Functions Troubleshooting](https://firebase.google.com/docs/functions/troubleshooting)
- [Firestore Best Practices](https://firebase.google.com/docs/firestore/best-practices)

---

**Document Version**: 1.0  
**Last Updated**: December 2025  
**Next Review**: [Set date 3 months from now]  
**Owner**: Operations Team

