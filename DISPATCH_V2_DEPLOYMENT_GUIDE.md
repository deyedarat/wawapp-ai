# 🚀 WawApp Dispatch Engine v2.0 — Deployment Guide

## 📋 Overview

This document describes the deployment process for the **Production-Grade Hybrid Dispatch System**.

### What Changed

| Component | v1.0 (Old) | v2.0 (New) |
|-----------|------------|------------|
| **Dispatch Model** | Broadcast (all drivers simultaneously) | Hybrid Wave (sequential + backup) |
| **Offer Control** | Logging only (not enforced) | Real offer-based acceptance |
| **Duplicate Notifications** | Yes (from 2 sources) | Zero (single source of truth) |
| **State Management** | Scattered across functions | Centralized (`dispatch_queue` + `driver_dispatch_state`) |
| **Firestore Reads** | High (sequential per driver) | Optimized (batch + parallel) |
| **Wave System** | None | 3-wave hybrid (15s → 30s → 45s) |

---

## 🎯 Migration Strategy

### Option A: Big Bang (Recommended for Low-Traffic Period)

**When**: During maintenance window (2-4 AM local time)

**Steps**:

1. Deploy new Cloud Functions
2. Deploy new Firestore indexes
3. Deploy new security rules
4. Update Flutter driver app
5. Test end-to-end
6. Monitor for 24 hours

**Downtime**: ~15 minutes

### Option B: Gradual Rollout (Recommended for Production)

**When**: During business hours with phased rollout

**Steps**:

1. **Phase 1 (Backend)**:
   - Deploy v2 functions alongside v1
   - Keep v1 active
   - Test v2 with synthetic orders

2. **Phase 2 (Indexes & Rules)**:
   - Deploy new indexes (no impact on v1)
   - Deploy updated rules (backward compatible)

3. **Phase 3 (App Update)**:
   - Release driver app v2.0 to 10% of drivers
   - Monitor metrics
   - Increase to 50%, then 100%

4. **Phase 4 (Cleanup)**:
   - Disable v1 functions
   - Remove old code

**Downtime**: Zero

---

## 📦 Phase 1: Deploy Cloud Functions

### 1.1. Build TypeScript

```bash
cd functions
npm run build
```

**Expected output**:

```
✓ Compiled successfully
✓ No type errors
```

### 1.2. Deploy New Functions

```bash
# Deploy all v2 functions
firebase deploy --only functions:acceptOrderV2,functions:notifyNewOrderV2,functions:rejectOffer,functions:processExpiredWaves
```

**Expected output**:

```
✔  functions: 4 functions deployed successfully
```

### 1.3. Verify Deployment

```bash
# Check function status
firebase functions:list
```

**Expected**:

```
acceptOrderV2         us-central1  https.onCall
notifyNewOrderV2      us-central1  firestore.onCreate
rejectOffer           us-central1  https.onCall
processExpiredWaves   us-central1  pubsub.schedule (every 30 seconds)
```

---

## 🗂️ Phase 2: Deploy Firestore Indexes

### 2.1. Deploy Indexes

```bash
firebase deploy --only firestore:indexes
```

**Expected output**:

```
✔  firestore: indexes deployed successfully
```

### 2.2. Wait for Index Build

Indexes build asynchronously. Check status:

```bash
firebase firestore:indexes
```

**Expected**:

```
dispatch_offers (orderId, round, status)       READY
dispatch_queue (waveExpiresAt)                 READY
driver_dispatch_state (status, updatedAt)      READY
```

⚠️ **IMPORTANT**: Wait for all indexes to show `READY` before proceeding.

---

## 🔒 Phase 3: Deploy Security Rules

### 3.1. Deploy Rules

```bash
firebase deploy --only firestore:rules
```

**Expected output**:

```
✔  firestore: rules deployed successfully
```

### 3.2. Test Rules

Use Firebase Console → Firestore → Rules Playground:

```javascript
// Test: Driver can read their own offer
match /dispatch_offers/ORDER123_DRIVER456
auth: { uid: 'DRIVER456' }
operation: get
Result: ✅ Allow

// Test: Driver cannot read another driver's offer
match /dispatch_offers/ORDER123_DRIVER789
auth: { uid: 'DRIVER456' }
operation: get
Result: ❌ Deny

// Test: Only Cloud Functions can write to dispatch_queue
match /dispatch_queue/ORDER123
auth: { uid: 'DRIVER456' }
operation: create
Result: ❌ Deny
```

---

## 📱 Phase 4: Update Flutter Driver App

### 4.1. Update Dependencies

No new dependencies required! The dispatch system works with existing packages.

### 4.2. Update `orders_service.dart`

**Change**:

```dart
// ❌ Old (v1.0)
await callable.call({'orderId': orderId});

// ✅ New (v2.0)
await callable.call({
  'orderId': orderId,
  'offerId': offerId,  // Now required!
});
```

### 4.3. Update Function Names

```dart
// ❌ Old
final callable = FirebaseFunctions.instance.httpsCallable('acceptOrder');

// ✅ New
final callable = FirebaseFunctions.instance.httpsCallable('acceptOrderV2');
```

### 4.4. Add Rejection Support

```dart
Future<void> rejectOffer(String offerId) async {
  final callable = FirebaseFunctions.instance.httpsCallable('rejectOffer');
  await callable.call({'offerId': offerId});
}
```

---

## 🧪 Phase 5: Testing

### 5.1. Synthetic Order Test

1. Create test order from client app
2. Verify wave 1 notification arrives within 2 seconds
3. Reject offer from driver 1
4. Verify wave 2 starts after 15 seconds
5. Accept offer from driver 2
6. Verify all other offers expire automatically

### 5.2. Check Firestore Collections

After test order:

```
dispatch_queue/{orderId}
  ✓ Created on order creation
  ✓ Deleted on acceptance

dispatch_offers/{orderId}_{driverId}
  ✓ Created for each wave
  ✓ Status transitions: sent → accepted/rejected/expired

driver_dispatch_state/{driverId}
  ✓ Updated on offer sent
  ✓ Cleared on acceptance/rejection

dispatch_metrics/{orderId}
  ✓ Wave metrics recorded
  ✓ Acceptance time tracked
```

### 5.3. Check Cloud Logs

```bash
firebase functions:log --only processExpiredWaves
```

**Expected output**:

```
[ProcessExpiredWaves] Function triggered
[DispatchEngine] Processing expired waves count: 3
[DispatchEngine] Wave expired, moving to next: wave 2
[DispatchEngine] Notification sent to driver
```

---

## 📊 Phase 6: Monitoring

### 6.1. Key Metrics to Track

| Metric | v1.0 Baseline | v2.0 Target | How to Measure |
|--------|---------------|-------------|----------------|
| Duplicate Notifications | ~15% | 0% | Check `notification_log` duplicates |
| Time to Accept | ~45s avg | ~25s avg | `dispatch_metrics.timeToAcceptSeconds` |
| Firestore Reads per Order | ~200 | ~50 | Cloud Functions metrics |
| Driver Acceptance Rate | ~40% | ~60% | `dispatch_metrics.acceptedAtWave` |

### 6.2. Monitor Cloud Functions Costs

```bash
# Check invocation count
firebase functions:log --only processExpiredWaves --lines 1000 | grep "Function triggered" | wc -l
```

**Expected**: ~120 invocations/hour (every 30 seconds)

### 6.3. Monitor Firestore Usage

Firebase Console → Firestore → Usage

**Expected reductions**:

- Reads: -60% (batch optimization)
- Writes: -20% (single source of truth)

---

## 🛑 Rollback Plan

If issues occur, rollback in reverse order:

### 1. Rollback App (Immediate)

```bash
# Re-release previous driver app version
# No code changes needed — v1 functions still deployed
```

### 2. Rollback Functions

```bash
# Delete v2 functions
firebase functions:delete acceptOrderV2 notifyNewOrderV2 rejectOffer processExpiredWaves
```

### 3. Rollback Rules (Optional)

```bash
git checkout main -- firestore.rules
firebase deploy --only firestore:rules
```

### 4. Rollback Indexes (Not Necessary)

New indexes don't break old queries. Leave them.

---

## ✅ Success Criteria

After 24 hours, verify:

- ✅ Zero duplicate notifications reported
- ✅ Average time-to-accept < 30 seconds
- ✅ No failed acceptances due to "offer_expired"
- ✅ Firestore read cost reduced by >50%
- ✅ No increase in order timeout rate
- ✅ Driver acceptance rate improved

---

## 🚨 Troubleshooting

### Issue 1: "offerId is required" error in old app

**Cause**: Old app calling `acceptOrderV2` without `offerId`

**Fix**: Ensure driver app is updated to v2.0

**Temporary workaround**: Keep `acceptOrder` v1 active

---

### Issue 2: Offers expire too quickly

**Cause**: Wave TTL too short for your market

**Fix**: Adjust wave configuration in `types.ts`:

```typescript
export const DEFAULT_WAVES: DispatchWave[] = [
  { round: 1, maxDrivers: 1, ttl: 30, maxDistance: 3 },   // Increased from 15s
  { round: 2, maxDrivers: 3, ttl: 60, maxDistance: 8 },   // Increased from 30s
  { round: 3, maxDrivers: 5, ttl: 90, maxDistance: 15 },  // Increased from 45s
];
```

---

### Issue 3: No drivers found for wave 1

**Cause**: `maxDistance` too restrictive

**Fix**: Increase wave 1 distance:

```typescript
{ round: 1, maxDrivers: 1, ttl: 15, maxDistance: 5 },  // Increased from 3km
```

---

### Issue 4: `processExpiredWaves` timing out

**Cause**: Too many expired waves to process in 2 minutes

**Fix**: Increase timeout:

```typescript
.runWith({
  timeoutSeconds: 300,  // Increased from 120
  memory: '512MB',       // Increased from 256MB
})
```

---

## 📞 Support

For deployment issues:

1. Check logs: `firebase functions:log`
2. Check Firestore console for data integrity
3. Review error messages in driver app
4. Contact WawApp development team

---

## 🎉 Post-Deployment

After successful deployment:

1. Update documentation
2. Train support team on new error messages
3. Monitor metrics for 1 week
4. Plan v1 function removal (90 days retention)

---

## 🔮 Future Enhancements

After stable v2.0 deployment, consider:

- **Driver preferences**: Allow drivers to set max distance/price filters
- **Smart wave sizing**: Adjust wave size based on market density
- **A/B testing**: Compare sequential vs broadcast for specific markets
- **ML-based matching**: Predict driver acceptance likelihood

---

**Version**: 2.0.0
**Last Updated**: 2026-04-16
**Author**: WawApp Development Team
