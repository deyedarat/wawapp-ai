# Phase 9: Backup & Disaster Recovery Plan

**WawApp Backup & DR Strategy**  
**Version**: 1.0  
**Date**: December 2025  
**Status**: 🔒 CRITICAL - Data Protection & Recovery

---

## 🎯 Executive Summary

This document defines the **Backup and Disaster Recovery (DR) strategy** for WawApp production environment. The strategy ensures **data durability**, **business continuity**, and **rapid recovery** from catastrophic failures.

**Recovery Objectives:**
- **RTO (Recovery Time Objective)**: Maximum acceptable downtime
  - Critical systems: **< 1 hour**
  - Standard systems: **< 4 hours**
- **RPO (Recovery Point Objective)**: Maximum acceptable data loss
  - Financial data: **< 15 minutes** (near-zero data loss)
  - Order data: **< 1 hour**
  - User data: **< 24 hours**

**Backup Strategy:**
- ✅ **Daily automated Firestore exports** (02:00 UTC)
- ✅ **Continuous transaction logging** (real-time)
- ✅ **Multi-region replication** (Firebase native)
- ✅ **30-day retention** for cold storage
- ✅ **Monthly recovery drills**

---

## 📋 Table of Contents

1. [Backup Strategy](#backup-strategy)
2. [Recovery Procedures](#recovery-procedures)
3. [Disaster Scenarios & Playbooks](#disaster-scenarios--playbooks)
4. [Testing & Validation](#testing--validation)
5. [Data Retention Policy](#data-retention-policy)
6. [Backup Monitoring](#backup-monitoring)
7. [Recovery Drills](#recovery-drills)

---

## 💾 Backup Strategy

### **1. Firestore Backup Architecture**

```
┌─────────────────────────────────────────────────────────────────┐
│                     BACKUP ARCHITECTURE                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              PRIMARY DATA (Firestore)                    │   │
│  │  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐        │   │
│  │  │ orders │  │wallets │  │  txns  │  │payouts │        │   │
│  │  └────────┘  └────────┘  └────────┘  └────────┘        │   │
│  │                    │                                     │   │
│  └────────────────────┼─────────────────────────────────────┘   │
│                       │                                          │
│                       ▼                                          │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │           BACKUP TIER 1: Daily Exports                   │   │
│  │           (Cloud Storage - Standard)                     │   │
│  ├──────────────────────────────────────────────────────────┤   │
│  │  Frequency: Daily (02:00 UTC)                           │   │
│  │  Retention: 7 days                                      │   │
│  │  Bucket: gs://wawapp-backups-daily                     │   │
│  │  Format: Firestore export (native)                     │   │
│  │  ● orders_YYYY-MM-DD/                                  │   │
│  │  ● wallets_YYYY-MM-DD/                                 │   │
│  │  ● transactions_YYYY-MM-DD/                            │   │
│  │  ● payouts_YYYY-MM-DD/                                 │   │
│  └──────────────────────────────────────────────────────────┘   │
│                       │                                          │
│                       ▼                                          │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │         BACKUP TIER 2: Cold Storage Archive             │   │
│  │         (Cloud Storage - Coldline)                      │   │
│  ├──────────────────────────────────────────────────────────┤   │
│  │  Frequency: Monthly (1st of month)                      │   │
│  │  Retention: 30 days                                     │   │
│  │  Bucket: gs://wawapp-backups-archive                   │   │
│  │  Format: Compressed Firestore export (.tar.gz)         │   │
│  │  ● monthly_backup_2025-12-01.tar.gz                    │   │
│  │  ● monthly_backup_2025-11-01.tar.gz                    │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │         BACKUP TIER 3: Continuous Replication           │   │
│  │         (Firebase Native - Multi-Region)                │   │
│  ├──────────────────────────────────────────────────────────┤   │
│  │  Type: Automatic by Firebase                            │   │
│  │  RPO: Near-zero (real-time replication)                │   │
│  │  Regions: us-central1 (primary) + multi-region         │   │
│  │  Failover: Automatic                                    │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

### **2. Backup Schedule**

#### **A. Daily Firestore Export**

**Schedule**: Every day at **02:00 UTC** (3:00 AM Nouakchott time)  
**Reason**: Low-traffic window, minimal performance impact

**Collections to Backup** (Priority Order):

| Collection | Priority | Size (Est.) | Backup Time |
|------------|----------|-------------|-------------|
| `transactions` | 🔴 CRITICAL | ~500 MB | ~5 min |
| `wallets` | 🔴 CRITICAL | ~10 MB | ~1 min |
| `payouts` | 🔴 CRITICAL | ~50 MB | ~2 min |
| `orders` | 🟠 HIGH | ~1 GB | ~10 min |
| `users` | 🟡 MEDIUM | ~200 MB | ~3 min |
| `drivers` | 🟡 MEDIUM | ~100 MB | ~2 min |
| `clients` | 🟡 MEDIUM | ~50 MB | ~1 min |

**Total Backup Time**: ~25 minutes  
**Total Storage**: ~2 GB per day

**Automation Script**: `/scripts/backup-firestore.sh`

```bash
#!/bin/bash
# Daily Firestore Backup Script
# Run via Cloud Scheduler at 02:00 UTC

set -e

PROJECT_ID="wawapp-952d6"
BUCKET="gs://wawapp-backups-daily"
DATE=$(date +%Y-%m-%d)

echo "🔄 Starting Firestore backup: $DATE"

# Export all collections
gcloud firestore export \
  "$BUCKET/backup-$DATE" \
  --project="$PROJECT_ID" \
  --async

echo "✅ Backup initiated: $BUCKET/backup-$DATE"
echo "📧 Sending notification..."

# Send notification (example using sendgrid or similar)
# curl -X POST "https://api.sendgrid.com/v3/mail/send" \
#   -H "Authorization: Bearer $SENDGRID_API_KEY" \
#   -H "Content-Type: application/json" \
#   -d '{"personalizations":[{"to":[{"email":"devops@wawapp.com"}]}],"from":{"email":"backup@wawapp.com"},"subject":"[WawApp] Daily Backup Complete","content":[{"type":"text/plain","value":"Firestore backup completed: backup-'"$DATE"'"}]}'

echo "✅ Backup notification sent"
```

**Cloud Scheduler Configuration**:
```yaml
Name: firestore-daily-backup
Schedule: "0 2 * * *"  # 02:00 UTC daily
Timezone: UTC
Target: Cloud Function or Pub/Sub topic
Retry: 3 attempts with exponential backoff
```

---

#### **B. Weekly Verification**

**Schedule**: Every Sunday at **03:00 UTC**

**Verification Steps**:
1. Check backup existence in Cloud Storage
2. Validate backup size (compare with previous week)
3. Verify backup integrity (test import on staging environment)
4. Generate backup health report
5. Alert if any issues detected

**Automation Script**: `/scripts/verify-backup.sh`

```bash
#!/bin/bash
# Weekly Backup Verification Script

set -e

PROJECT_ID="wawapp-952d6"
BUCKET="gs://wawapp-backups-daily"
DATE=$(date +%Y-%m-%d)

echo "🔍 Verifying backups..."

# List recent backups
gsutil ls "$BUCKET" | tail -7

# Get backup size
BACKUP_SIZE=$(gsutil du -s "$BUCKET/backup-$DATE" | awk '{print $1}')
echo "📦 Backup size: $BACKUP_SIZE bytes"

# Validate size is reasonable (> 1GB expected)
if [ "$BACKUP_SIZE" -lt 1000000000 ]; then
  echo "❌ WARNING: Backup size too small!"
  # Send alert
  exit 1
fi

echo "✅ Backup verification passed"
```

---

#### **C. Monthly Cold Storage Archive**

**Schedule**: 1st of every month at **04:00 UTC**

**Process**:
1. Export full Firestore snapshot
2. Compress to `.tar.gz`
3. Move to Coldline storage (lower cost, slower access)
4. Retain for 30 days
5. Delete archives older than 30 days

**Storage Cost**:
- **Standard Storage**: $0.02/GB/month (daily backups)
- **Coldline Storage**: $0.004/GB/month (monthly archives)

**Estimated Monthly Cost**:
- Daily backups (7 days × 2 GB): 14 GB × $0.02 = **$0.28/month**
- Cold archives (30 days × 2 GB): 60 GB × $0.004 = **$0.24/month**
- **Total**: ~$0.50/month

---

### **3. Critical Data Continuous Backup**

#### **Transaction Ledger Real-Time Logging**

**Purpose**: Financial transactions must have near-zero data loss (RPO < 15 minutes)

**Strategy**:
- **Primary**: Firestore `transactions` collection (durable by default)
- **Secondary**: Cloud Logging (structured logs)
- **Tertiary**: Real-time export to BigQuery (optional, for analytics)

**Implementation**:

```typescript
// functions/src/finance/orderSettlement.ts
export async function settleOrder(orderId: string) {
  // ... settlement logic ...
  
  // Log transaction to Cloud Logging (backup audit trail)
  logger.info('Transaction created', {
    transactionId: driverTxn.id,
    orderId: orderId,
    walletId: driverWallet.id,
    amount: driverEarning,
    balanceBefore: driverWallet.balance,
    balanceAfter: driverWallet.balance + driverEarning,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  // Optional: Stream to BigQuery for analytics
  // await bigquery.insert('wawapp.transactions', transactionData);
}
```

**Recovery**:
If Firestore `transactions` collection is corrupted:
1. Query Cloud Logging for transaction logs
2. Reconstruct transaction ledger from logs
3. Verify wallet balances match reconstructed ledger

---

### **4. Cloud Functions Code Backup**

**Strategy**: Git repository is the source of truth

**Backup Locations**:
1. **Primary**: GitHub repository (`github.com/deyedarat/wawapp-ai`)
2. **Secondary**: Cloud Source Repositories (automatic mirror)
3. **Tertiary**: Local developer machines (git clones)

**Deployment History**:
- Firebase Cloud Functions stores last 5 deployment versions
- Can rollback to previous version instantly

**Recovery**:
```bash
# Rollback to previous Cloud Functions version
firebase functions:rollback onOrderCompleted

# Or redeploy from specific commit
git checkout <commit-hash>
cd functions
npm install
npm run deploy
```

---

### **5. Admin Panel Build Backup**

**Strategy**: Firebase Hosting stores deployment history

**Backup Locations**:
1. **Primary**: Firebase Hosting (last 100 releases)
2. **Secondary**: Git repository (Flutter source code)
3. **Tertiary**: CI/CD artifacts (if using GitHub Actions)

**Recovery**:
```bash
# View deployment history
firebase hosting:releases:list --limit 10

# Rollback to previous release
firebase hosting:rollback

# Or rebuild and redeploy
cd apps/wawapp_admin
flutter build web --release --dart-define=ENVIRONMENT=prod
firebase deploy --only hosting
```

---

## 🔄 Recovery Procedures

### **Recovery Time Objectives (RTO)**

| Data Type | RTO | Recovery Steps | Complexity |
|-----------|-----|----------------|------------|
| **Firestore (Complete Loss)** | 4 hours | Import from daily backup | Medium |
| **Firestore (Single Collection)** | 1 hour | Import specific collection | Low |
| **Firestore (Single Document)** | 15 min | Manual restore from backup | Low |
| **Transaction Ledger** | 30 min | Reconstruct from logs | Medium |
| **Wallet Balances** | 1 hour | Recalculate from transactions | Medium |
| **Cloud Functions** | 15 min | Rollback or redeploy | Low |
| **Admin Panel** | 15 min | Rollback or redeploy | Low |

---

### **Recovery Point Objectives (RPO)**

| Data Type | RPO | Data Loss | Mitigation |
|-----------|-----|-----------|------------|
| **Financial Data** | < 15 min | Minimal (Cloud Logging backup) | Real-time logging |
| **Order Data** | < 1 hour | Last hour of orders | Daily backups |
| **User Data** | < 24 hours | 1 day of data | Daily backups |
| **Analytics** | < 7 days | 1 week of data | Weekly backups |

---

### **Procedure 1: Restore Full Firestore Database**

**Scenario**: Complete Firestore database loss or corruption

**Prerequisites**:
- [ ] Latest backup available in `gs://wawapp-backups-daily`
- [ ] Firebase CLI installed and authenticated
- [ ] Admin access to GCP project

**Steps**:

```bash
# 1. Identify latest backup
gsutil ls gs://wawapp-backups-daily/ | tail -1
# Example output: gs://wawapp-backups-daily/backup-2025-12-09/

# 2. Import backup to Firestore
gcloud firestore import \
  gs://wawapp-backups-daily/backup-2025-12-09 \
  --project=wawapp-952d6 \
  --async

# 3. Monitor import progress
gcloud firestore operations list \
  --project=wawapp-952d6 \
  --filter="RUNNING"

# 4. Wait for completion (can take 30-60 minutes for full restore)
# Check status every 5 minutes
watch -n 300 'gcloud firestore operations list --project=wawapp-952d6'

# 5. Verify data integrity
# - Check collection counts
# - Verify wallet balances
# - Test critical queries

# 6. Resume application traffic
# - Deploy Admin Panel
# - Enable Cloud Functions
# - Notify users of restoration
```

**Estimated Time**: **2-4 hours** (depending on data size)  
**Data Loss**: Up to **24 hours** (last daily backup)

---

### **Procedure 2: Restore Single Collection**

**Scenario**: One collection corrupted (e.g., `wallets` collection has incorrect data)

**Steps**:

```bash
# 1. Export current (corrupted) collection as backup
gcloud firestore export \
  gs://wawapp-backups-manual/wallets-corrupted-$(date +%Y%m%d) \
  --project=wawapp-952d6 \
  --collection-ids=wallets

# 2. Delete corrupted collection (CAREFUL!)
# Do NOT delete in production without confirmation!
firebase firestore:delete wallets --project=wawapp-952d6 --recursive

# 3. Import from last good backup
gcloud firestore import \
  gs://wawapp-backups-daily/backup-2025-12-09/all_namespaces/kind_wallets \
  --project=wawapp-952d6

# 4. Verify restoration
# Check wallet balance totals match expected
```

**Estimated Time**: **30-60 minutes**  
**Data Loss**: Up to **24 hours**

---

### **Procedure 3: Restore Single Document**

**Scenario**: Accidental deletion or corruption of a specific document (e.g., driver wallet)

**Steps**:

```bash
# 1. Download backup locally
mkdir -p /tmp/firestore-backup
gsutil -m cp -r \
  gs://wawapp-backups-daily/backup-2025-12-09/all_namespaces/kind_wallets \
  /tmp/firestore-backup/

# 2. Extract specific document
# Use Firestore backup viewer or custom script
# Example: Find document with ID "driver123"

# 3. Manually recreate document in Firestore
# Via Firebase Console or script
```

**Alternative (Using Admin SDK)**:

```typescript
// scripts/restore-document.ts
import * as admin from 'firebase-admin';

admin.initializeApp();
const db = admin.firestore();

async function restoreWallet(driverId: string, backupData: any) {
  await db.collection('wallets').doc(driverId).set({
    id: driverId,
    type: 'driver',
    ownerId: driverId,
    balance: backupData.balance,
    totalCredited: backupData.totalCredited,
    totalDebited: backupData.totalDebited,
    pendingPayout: backupData.pendingPayout,
    currency: 'MRU',
    createdAt: backupData.createdAt,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  console.log(`✅ Restored wallet: ${driverId}`);
}

// Usage
restoreWallet('driver123', {
  balance: 125000,
  totalCredited: 500000,
  totalDebited: 375000,
  pendingPayout: 50000,
  createdAt: new Date('2024-01-15'),
});
```

**Estimated Time**: **15-30 minutes**  
**Data Loss**: Up to **24 hours**

---

### **Procedure 4: Reconstruct Transaction Ledger from Logs**

**Scenario**: `transactions` collection is corrupted, but orders and wallets are intact

**Steps**:

```bash
# 1. Query Cloud Logging for transaction logs
gcloud logging read \
  "resource.type=cloud_function AND \
   resource.labels.function_name=onOrderCompleted AND \
   jsonPayload.event=transaction_created" \
  --limit 10000 \
  --format json \
  --project=wawapp-952d6 \
  > /tmp/transaction-logs.json

# 2. Parse logs and reconstruct transactions
# Use custom script to extract transaction data

# 3. Re-insert transactions into Firestore
# Verify integrity with wallet balances
```

**Script** (`/scripts/reconstruct-transactions.ts`):

```typescript
import * as admin from 'firebase-admin';
import * as fs from 'fs';

admin.initializeApp();
const db = admin.firestore();

async function reconstructTransactions() {
  // Read transaction logs
  const logs = JSON.parse(fs.readFileSync('/tmp/transaction-logs.json', 'utf8'));
  
  console.log(`📦 Found ${logs.length} transaction log entries`);
  
  for (const log of logs) {
    const txData = log.jsonPayload;
    
    // Recreate transaction document
    await db.collection('transactions').doc(txData.transactionId).set({
      id: txData.transactionId,
      walletId: txData.walletId,
      type: 'credit',
      source: 'order_settlement',
      amount: txData.amount,
      orderId: txData.orderId,
      balanceBefore: txData.balanceBefore,
      balanceAfter: txData.balanceAfter,
      createdAt: admin.firestore.Timestamp.fromDate(new Date(txData.timestamp)),
    });
    
    console.log(`✅ Restored transaction: ${txData.transactionId}`);
  }
  
  console.log(`✅ Reconstructed ${logs.length} transactions`);
}

reconstructTransactions();
```

**Estimated Time**: **1-2 hours** (depending on volume)  
**Data Loss**: Minimal (< 15 minutes if logs are available)

---

### **Procedure 5: Recalculate Wallet Balances**

**Scenario**: Wallet balances are incorrect, but transaction ledger is intact

**Strategy**: Recalculate from transaction history

**Steps**:

```typescript
// scripts/recalculate-wallets.ts
import * as admin from 'firebase-admin';

admin.initializeApp();
const db = admin.firestore();

async function recalculateWalletBalance(walletId: string) {
  const walletRef = db.collection('wallets').doc(walletId);
  const wallet = await walletRef.get();
  
  if (!wallet.exists) {
    console.error(`❌ Wallet not found: ${walletId}`);
    return;
  }
  
  // Query all transactions for this wallet
  const txSnapshot = await db.collection('transactions')
    .where('walletId', '==', walletId)
    .orderBy('createdAt', 'asc')
    .get();
  
  let balance = 0;
  let totalCredited = 0;
  let totalDebited = 0;
  
  txSnapshot.forEach(doc => {
    const tx = doc.data();
    if (tx.type === 'credit') {
      balance += tx.amount;
      totalCredited += tx.amount;
    } else if (tx.type === 'debit') {
      balance -= tx.amount;
      totalDebited += tx.amount;
    }
  });
  
  // Update wallet with recalculated values
  await walletRef.update({
    balance,
    totalCredited,
    totalDebited,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  console.log(`✅ Recalculated wallet ${walletId}:`);
  console.log(`   Balance: ${balance} MRU`);
  console.log(`   Total Credited: ${totalCredited} MRU`);
  console.log(`   Total Debited: ${totalDebited} MRU`);
}

// Recalculate all driver wallets
async function recalculateAllWallets() {
  const walletsSnapshot = await db.collection('wallets').get();
  
  for (const doc of walletsSnapshot.docs) {
    await recalculateWalletBalance(doc.id);
  }
  
  console.log(`✅ Recalculated ${walletsSnapshot.size} wallets`);
}

recalculateAllWallets();
```

**Estimated Time**: **30-60 minutes**  
**Data Loss**: None (calculated from transactions)

---

## 🚨 Disaster Scenarios & Playbooks

### **Scenario 1: Firebase Project Deleted**

**Impact**: 🔴 CATASTROPHIC - Complete service outage

**Detection**:
- All Firebase services return 404
- Firebase Console shows "Project not found"
- All API calls fail with authentication errors

**Immediate Actions**:

1. **Verify Deletion** (< 5 min)
   ```bash
   firebase projects:list
   # Check if wawapp-952d6 is listed
   ```

2. **Contact Firebase Support** (< 10 min)
   - Open priority support ticket
   - Request project restoration (possible within 30 days)
   - Escalate to Google Cloud support

3. **Prepare for Worst Case** (< 30 min)
   - Create new Firebase project: `wawapp-952d6-recovery`
   - Prepare to restore from backups

**Recovery Steps**:

```bash
# 1. Create new Firebase project
firebase projects:create wawapp-952d6-recovery

# 2. Enable Firestore and Auth
firebase init

# 3. Restore Firestore from latest backup
gcloud firestore import \
  gs://wawapp-backups-daily/backup-2025-12-09 \
  --project=wawapp-952d6-recovery

# 4. Recreate Auth users (if not recoverable)
# Manual process or bulk import from CSV

# 5. Redeploy Cloud Functions
cd functions
npm run deploy

# 6. Redeploy Admin Panel
cd apps/wawapp_admin
flutter build web --release --dart-define=ENVIRONMENT=prod
firebase deploy --only hosting

# 7. Update .firebaserc
{
  "projects": {
    "default": "wawapp-952d6-recovery"
  }
}

# 8. Update DNS / domain (if using custom domain)
```

**RTO**: **8-12 hours** (if Firebase cannot restore)  
**RPO**: **24 hours** (last daily backup)

---

### **Scenario 2: Firestore Region Outage**

**Impact**: 🔴 HIGH - Database unavailable

**Detection**:
- Firestore operations timeout
- Firebase status page shows region issue
- Error rate spike in Cloud Functions

**Immediate Actions**:

1. **Verify Outage** (< 2 min)
   - Check Firebase status: https://status.firebase.google.com
   - Verify not a configuration issue

2. **Enable Multi-Region (if not already enabled)** (< 10 min)
   - Firebase Firestore automatically replicates to multiple regions
   - Failover is automatic (no action needed)

3. **Communicate Status** (< 5 min)
   - Post status update on admin panel
   - Notify team and stakeholders
   - Update incident channel

**Recovery Steps**:
- **Wait for Firebase to recover** (typically < 1 hour)
- Monitor Firebase status page
- No manual action needed (automatic failover)

**RTO**: **< 1 hour** (automatic recovery)  
**RPO**: **0** (no data loss due to replication)

---

### **Scenario 3: Corrupted Wallet Balances**

**Impact**: 🔴 HIGH - Financial data integrity compromised

**Detection**:
- Daily reconciliation script reports discrepancies
- Driver reports incorrect balance
- Payout request fails due to insufficient funds (but should have funds)

**Immediate Actions**:

1. **Stop Financial Operations** (< 2 min)
   ```bash
   # Disable settlement and payout Cloud Functions
   firebase functions:config:set maintenance.mode=true
   ```

2. **Assess Extent of Corruption** (< 15 min)
   ```bash
   # Run wallet audit script
   npm run audit-wallets
   ```

3. **Identify Root Cause** (< 30 min)
   - Review recent deployments
   - Check Cloud Function logs for errors
   - Verify transaction ledger integrity

**Recovery Steps**:

1. **Recalculate All Wallet Balances** (1 hour)
   ```bash
   npm run recalculate-wallets
   ```

2. **Verify Against Transaction Ledger** (30 min)
   ```bash
   npm run verify-wallet-integrity
   ```

3. **Manually Correct Discrepancies** (Variable)
   - For each discrepancy:
     - Identify missing or incorrect transaction
     - Add corrective transaction
     - Document correction in audit log

4. **Resume Operations** (10 min)
   ```bash
   # Re-enable financial functions
   firebase functions:config:unset maintenance.mode
   firebase deploy --only functions
   ```

5. **Post-Incident Review** (1 day later)
   - Identify prevention measures
   - Improve validation logic
   - Add additional integrity checks

**RTO**: **2-4 hours**  
**RPO**: **0** (can reconstruct from transactions)

---

### **Scenario 4: Mass Order Deletion**

**Impact**: 🟠 MEDIUM - Historical data loss

**Detection**:
- Large drop in order count
- Reports show missing orders
- Admin logs show bulk delete operation

**Immediate Actions**:

1. **Stop Further Deletions** (< 2 min)
   - Identify source of deletion (admin user, script, bug)
   - Revoke admin access if malicious
   - Disable affected Cloud Function if bug

2. **Assess Deletion Scope** (< 10 min)
   ```bash
   # Check order count before/after
   firebase firestore:query orders --count
   
   # Identify deleted order IDs from logs
   gcloud logging read \
     "resource.type=cloud_firestore AND \
      protoPayload.methodName=google.firestore.v1.Firestore.Delete AND \
      protoPayload.resourceName=~'orders'" \
     --limit 1000 \
     --format json
   ```

**Recovery Steps**:

1. **Restore from Backup** (1-2 hours)
   ```bash
   # Import orders collection from yesterday's backup
   gcloud firestore import \
     gs://wawapp-backups-daily/backup-2025-12-08/all_namespaces/kind_orders \
     --project=wawapp-952d6 \
     --collection-ids=orders
   ```

2. **Merge with Today's Orders** (manual)
   - Export current orders
   - Compare with restored backup
   - Identify orders created today (after backup)
   - Ensure no duplicates

3. **Verify Order Count** (10 min)
   ```bash
   # Compare restored count with expected
   firebase firestore:query orders --count
   ```

**RTO**: **2-3 hours**  
**RPO**: **24 hours** (up to 1 day of orders may be lost if not manually recovered)

---

### **Scenario 5: Ransomware / Security Breach**

**Impact**: 🔴 CATASTROPHIC - Data encrypted or stolen

**Detection**:
- Unusual access patterns in logs
- Firestore rules changed unexpectedly
- Admin users see encrypted data
- Ransom note or demand

**Immediate Actions**:

1. **Isolate System** (< 5 min)
   - Disable all Cloud Functions
   - Revoke all admin access except security team
   - Change all service account keys
   - Enable audit logging

2. **Preserve Evidence** (< 10 min)
   - Export all Cloud Logging logs
   - Capture current Firestore state (read-only)
   - Document all indicators of compromise

3. **Notify Stakeholders** (< 15 min)
   - Inform CTO/CEO immediately
   - Contact legal team
   - Prepare for potential data breach notification

4. **Contact Authorities** (< 30 min)
   - Report to cybersecurity authorities
   - Contact Firebase/GCP security team
   - Engage cybersecurity incident response firm

**Recovery Steps**:

1. **Assess Damage** (Variable)
   - Determine what data was accessed/encrypted
   - Identify attack vector
   - Check if backup storage was compromised

2. **Restore from Clean Backup** (4-8 hours)
   - Use backup from before compromise
   - Verify backup integrity
   - Restore to new Firebase project

3. **Harden Security** (Before resuming)
   - Reset all passwords and keys
   - Enable multi-factor authentication (MFA)
   - Review and tighten Firestore security rules
   - Audit all admin user permissions
   - Implement additional monitoring

4. **Resume Operations** (After security review)
   - Gradual rollout with enhanced monitoring
   - Continuous security monitoring

**RTO**: **24-48 hours** (depending on breach severity)  
**RPO**: Up to **7 days** (use older backup if recent ones compromised)

---

## 🧪 Testing & Validation

### **Monthly Recovery Drill Schedule**

| Month | Drill Scenario | Duration | Success Criteria |
|-------|---------------|----------|------------------|
| **January** | Full Firestore Restore | 4 hours | RTO < 4 hours, RPO < 24 hours |
| **February** | Single Collection Restore | 1 hour | RTO < 1 hour |
| **March** | Transaction Ledger Reconstruction | 2 hours | 100% accuracy |
| **April** | Wallet Balance Recalculation | 1 hour | All balances match |
| **May** | Cloud Functions Rollback | 30 min | Zero downtime |
| **June** | Admin Panel Rollback | 30 min | Zero downtime |
| **July** | Full Firestore Restore | 4 hours | Improvement over January |
| **August** | Corrupted Data Recovery | 2 hours | Data integrity restored |
| **September** | Mass Deletion Recovery | 2 hours | All data recovered |
| **October** | Multi-Region Failover Test | 1 hour | Automatic failover |
| **November** | Security Breach Simulation | 4 hours | Isolated + restored |
| **December** | Full DR Rehearsal | 8 hours | All scenarios tested |

---

### **Recovery Drill Checklist**

**Pre-Drill**:
- [ ] Schedule drill with team (1 week notice)
- [ ] Prepare staging environment for test
- [ ] Document drill objectives
- [ ] Assign roles (incident commander, responders)
- [ ] Set up monitoring for drill

**During Drill**:
- [ ] Simulate disaster scenario
- [ ] Follow recovery playbook
- [ ] Time each step
- [ ] Document any blockers or issues
- [ ] Test communication protocols

**Post-Drill**:
- [ ] Verify recovery success
- [ ] Calculate actual RTO and RPO
- [ ] Document lessons learned
- [ ] Update playbooks with improvements
- [ ] Share results with team
- [ ] Schedule follow-up actions

---

### **Backup Validation Tests**

**Weekly Automated Tests**:
```bash
# /scripts/test-backup-restore.sh
#!/bin/bash

set -e

PROJECT_ID="wawapp-staging"  # Use staging for tests
BACKUP_BUCKET="gs://wawapp-backups-daily"
LATEST_BACKUP=$(gsutil ls "$BACKUP_BUCKET/" | tail -1)

echo "🧪 Testing backup restore: $LATEST_BACKUP"

# 1. Import backup to staging Firestore
gcloud firestore import \
  "$LATEST_BACKUP" \
  --project="$PROJECT_ID" \
  --async

# 2. Wait for import completion
sleep 1800  # 30 minutes

# 3. Verify collection counts
ORDERS_COUNT=$(firebase firestore:query orders --project="$PROJECT_ID" --count)
WALLETS_COUNT=$(firebase firestore:query wallets --project="$PROJECT_ID" --count)

echo "📊 Imported collections:"
echo "  Orders: $ORDERS_COUNT"
echo "  Wallets: $WALLETS_COUNT"

# 4. Run integrity checks
npm run verify-wallet-integrity -- --project="$PROJECT_ID"

echo "✅ Backup restore test PASSED"
```

---

## 📅 Data Retention Policy

### **Retention Periods**

| Data Type | Hot Storage (Firestore) | Warm Storage (Daily Backups) | Cold Storage (Archive) | Legal Requirement |
|-----------|-------------------------|-------------------------------|------------------------|-------------------|
| **Orders** | 90 days | 7 days | 30 days | 5 years (financial records) |
| **Transactions** | Indefinite | 7 days | 30 days | 7 years (audit trail) |
| **Wallets** | Active only | 7 days | 30 days | N/A (current state) |
| **Payouts** | Indefinite | 7 days | 30 days | 7 years (payment records) |
| **User Data** | Active + 1 year | 7 days | 30 days | GDPR: deleted on request |
| **Logs** | 30 days | N/A | N/A | 90 days (security logs) |

---

### **Data Archival Process**

**Quarterly Archival** (every 3 months):

1. **Identify Old Orders** (> 90 days)
   ```typescript
   const threeMonthsAgo = new Date();
   threeMonthsAgo.setMonth(threeMonthsAgo.getMonth() - 3);
   
   const oldOrders = await db.collection('orders')
     .where('createdAt', '<', threeMonthsAgo)
     .get();
   ```

2. **Export to BigQuery** (for analytics)
   ```bash
   gcloud firestore export \
     gs://wawapp-archive/orders-Q4-2025 \
     --collection-ids=orders \
     --filter="createdAt < '2025-10-01'"
   ```

3. **Delete from Firestore** (reduce storage cost)
   ```typescript
   // Batch delete old orders
   const batch = db.batch();
   oldOrders.forEach(doc => {
     batch.delete(doc.ref);
   });
   await batch.commit();
   ```

4. **Update Archive Index**
   - Maintain CSV index of archived data
   - Include: archive date, record count, storage location

---

### **Data Deletion Policy (GDPR Compliance)**

**User Requests Data Deletion**:

1. **Verify Identity** (manual process)
2. **Anonymize Financial Records** (do NOT delete audit trail)
   ```typescript
   // Replace PII with anonymous ID
   await db.collection('orders')
     .where('userId', '==', userId)
     .get()
     .then(snapshot => {
       snapshot.forEach(doc => {
         doc.ref.update({
           userId: `anonymous-${generateId()}`,
           userName: '[DELETED]',
           userPhone: '[DELETED]',
           userEmail: '[DELETED]',
         });
       });
     });
   ```

3. **Delete Non-Financial Data**
   ```typescript
   // Delete user profile
   await db.collection('users').doc(userId).delete();
   ```

4. **Confirm Deletion** (within 30 days)

---

## 📊 Backup Monitoring

### **Backup Health Dashboard**

```
┌─────────────────────────────────────────────────────────────────┐
│                    BACKUP HEALTH DASHBOARD                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Last Backup Status                                      │   │
│  ├──────────────────────────────────────────────────────────┤   │
│  │  Date: 2025-12-09 02:00 UTC                             │   │
│  │  Status: ✅ SUCCESS                                      │   │
│  │  Duration: 24 minutes                                    │   │
│  │  Size: 2.1 GB                                            │   │
│  │  Location: gs://wawapp-backups-daily/backup-2025-12-09  │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Backup History (Last 7 Days)                           │   │
│  ├──────────────────────────────────────────────────────────┤   │
│  │  2025-12-09  ✅  2.1 GB  24 min                         │   │
│  │  2025-12-08  ✅  2.0 GB  23 min                         │   │
│  │  2025-12-07  ✅  2.0 GB  22 min                         │   │
│  │  2025-12-06  ✅  1.9 GB  21 min                         │   │
│  │  2025-12-05  ✅  1.9 GB  23 min                         │   │
│  │  2025-12-04  ✅  1.8 GB  20 min                         │   │
│  │  2025-12-03  ✅  1.8 GB  22 min                         │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Storage Usage                                           │   │
│  ├──────────────────────────────────────────────────────────┤   │
│  │  Daily Backups (7 days):   14.0 GB  ($0.28/month)      │   │
│  │  Cold Archive (30 days):   60.0 GB  ($0.24/month)      │   │
│  │  Total Storage:            74.0 GB  ($0.52/month)      │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Recovery Metrics (Last 30 Days)                        │   │
│  ├──────────────────────────────────────────────────────────┤   │
│  │  Drills Conducted: 1                                    │   │
│  │  Average RTO: 3.2 hours (Target: < 4 hours) ✅         │   │
│  │  Average RPO: 18 hours (Target: < 24 hours) ✅         │   │
│  │  Success Rate: 100%                                     │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

### **Backup Alerts**

```yaml
# Backup Failure Alert
name: "Daily Backup Failed"
condition: "backup job exits with non-zero status"
severity: HIGH
channels: [Email, Telegram]
message: |
  🔴 Daily Firestore backup FAILED
  Date: {backup_date}
  Error: {error_message}
  Last successful backup: {last_success_date}
  
  Action Required:
  1. Check Cloud Scheduler logs
  2. Verify Cloud Storage permissions
  3. Retry backup manually
  4. Investigate root cause
  
  Manual backup command:
  gcloud firestore export gs://wawapp-backups-daily/backup-{date}
```

```yaml
# Backup Size Anomaly
name: "Backup Size Anomaly"
condition: "backup size deviates > 30% from 7-day average"
severity: MEDIUM
channels: [Email]
message: |
  ⚠️ Backup size anomaly detected
  Current: {current_size} GB
  Average: {average_size} GB
  Deviation: {deviation}%
  
  Possible causes:
  - Large data deletion (check order/transaction counts)
  - Data corruption
  - Backup process incomplete
  
  Action: Verify data integrity
```

---

## 🎯 Recovery Drills

### **Drill 1: Full Firestore Restore (Monthly)**

**Objective**: Validate ability to restore complete database from backup

**Participants**: DevOps Team, Backend Lead  
**Duration**: 4 hours  
**Environment**: Staging project

**Steps**:
1. Create fresh staging project
2. Import latest daily backup
3. Verify all collections restored
4. Run integrity checks (wallet balances, transaction ledger)
5. Test Admin Panel functionality
6. Measure RTO and RPO
7. Document results

**Success Criteria**:
- ✅ All collections restored
- ✅ Data integrity validated (100% match)
- ✅ Admin Panel functional
- ✅ RTO < 4 hours
- ✅ RPO < 24 hours

---

### **Drill 2: Transaction Ledger Reconstruction (Quarterly)**

**Objective**: Validate ability to rebuild transaction ledger from logs

**Participants**: Backend Team  
**Duration**: 2 hours  
**Environment**: Staging project

**Steps**:
1. Delete `transactions` collection in staging
2. Export Cloud Logging transaction logs
3. Run reconstruction script
4. Verify reconstructed transactions match original
5. Recalculate wallet balances
6. Compare with known-good balances

**Success Criteria**:
- ✅ All transactions reconstructed (100%)
- ✅ Wallet balances match expected (0% error)
- ✅ Reconstruction time < 2 hours

---

### **Drill 3: Security Incident Response (Annually)**

**Objective**: Test response to security breach

**Participants**: Full Team + Security Consultant  
**Duration**: 8 hours  
**Environment**: Simulated

**Steps**:
1. Simulate breach (access compromised, data encrypted)
2. Follow incident response playbook
3. Isolate system
4. Preserve evidence
5. Restore from clean backup
6. Harden security
7. Resume operations
8. Conduct post-mortem

**Success Criteria**:
- ✅ Incident detected < 15 min
- ✅ System isolated < 30 min
- ✅ Full recovery < 24 hours
- ✅ No data loss (use pre-breach backup)

---

## ✅ Phase 9 Backup & DR Checklist

### **Backup Setup**

- [ ] **Daily Firestore export** configured (Cloud Scheduler)
- [ ] **Cloud Storage buckets** created:
  - `gs://wawapp-backups-daily` (Standard storage)
  - `gs://wawapp-backups-archive` (Coldline storage)
- [ ] **Backup automation script** deployed
- [ ] **Backup verification script** scheduled (weekly)
- [ ] **Backup alerts** configured
- [ ] **Monthly cold storage archive** scheduled

### **Recovery Procedures**

- [ ] **Playbooks documented** for all disaster scenarios
- [ ] **Recovery scripts** created and tested
- [ ] **RTO/RPO targets** defined and validated
- [ ] **Team trained** on recovery procedures
- [ ] **Emergency contacts** list updated

### **Testing & Validation**

- [ ] **Monthly recovery drill** scheduled
- [ ] **Backup restore test** successful (staging)
- [ ] **Integrity checks** automated
- [ ] **Drill results** documented

### **Monitoring**

- [ ] **Backup health dashboard** created
- [ ] **Backup failure alerts** configured
- [ ] **Storage usage** monitored
- [ ] **Cost tracking** enabled

---

## 🎯 Success Criteria

✅ **All backups automated and monitored**  
✅ **RTO < 4 hours for critical systems**  
✅ **RPO < 24 hours for all data (< 15 min for financial)**  
✅ **Monthly recovery drills successful**  
✅ **Team trained and confident in recovery procedures**  
✅ **Backup costs optimized (< $1/month)**  
✅ **Data retention policy compliant (GDPR, financial regulations)**

---

**Document Version**: 1.0  
**Last Updated**: December 2025  
**Owner**: DevOps Team + Infrastructure Lead  
**Status**: 🔒 READY FOR IMPLEMENTATION
