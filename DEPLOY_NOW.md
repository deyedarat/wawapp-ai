# 🚀 Deploy V2 Dispatch Engine — Final Checklist

**Date**: 2026-04-16
**Version**: 2.0.0
**Status**: ✅ Ready for Production

---

## ✅ Pre-Deployment Verification

- ✅ TypeScript build successful (no errors)
- ✅ All modules load correctly
- ✅ Transactions verified in code
- ✅ Batch operations confirmed
- ✅ v1 notifyNewOrder **disabled** (no conflict)
- ✅ Indexes configuration updated
- ✅ Security rules updated

---

## 📋 Deployment Commands (Copy-Paste)

### Step 1: Verify you're in the right directory

```bash
pwd
# Expected: /path/to/wawapp-ai
```

---

### Step 2: Deploy Firestore Indexes FIRST

```bash
firebase deploy --only firestore:indexes
```

**Expected output**:
```
✔  firestore: indexes deployed successfully
```

**⏱️ Wait Time**: 5-10 minutes for indexes to build

**Check status**:
```bash
firebase firestore:indexes
```

**Wait for all to show `READY`**:
```
dispatch_offers (orderId, round, status)       READY
dispatch_queue (waveExpiresAt)                 READY
driver_dispatch_state (status, updatedAt)      READY
```

---

### Step 3: Deploy Firestore Rules

```bash
firebase deploy --only firestore:rules
```

**Expected output**:
```
✔  firestore: rules deployed successfully
```

---

### Step 4: Deploy Cloud Functions

```bash
firebase deploy --only functions:acceptOrderV2,functions:notifyNewOrderV2,functions:rejectOffer,functions:processExpiredWaves
```

**Expected output**:
```
✔  functions[us-central1-acceptOrderV2]: Successful create operation
✔  functions[us-central1-notifyNewOrderV2]: Successful create operation
✔  functions[us-central1-rejectOffer]: Successful create operation
✔  functions[us-central1-processExpiredWaves]: Successful create operation
```

**⏱️ Deploy Time**: ~3-5 minutes

---

## ⚠️ Important Notes

### 1. Cloud Scheduler

`processExpiredWaves` uses `pubsub.schedule('every 30 seconds')`.

**This will automatically create a Cloud Scheduler job.**

**Cost**: ~$0.10/month (1 job)

**Verify after deployment**:
```bash
gcloud scheduler jobs list
```

Expected:
```
firebase-schedule-processExpiredWaves-us-central1
```

---

### 2. Breaking Change Warning

`acceptOrderV2` **requires `offerId`** in the request.

**Old driver apps will get**:
```
Error: offerId is required. Please update your app to the latest version.
```

**Action**: Update driver app before this deploy, OR keep `acceptOrder` v1 active temporarily.

**Current status**: v1 `acceptOrder` is **still active** as fallback.

---

### 3. Function Triggers

After deployment, **two functions will be active**:

```
❌ notifyNewOrder (v1)       — DISABLED in code
✅ notifyNewOrderV2 (v2)     — ACTIVE

✅ acceptOrder (v1)          — ACTIVE (fallback)
✅ acceptOrderV2 (v2)        — ACTIVE (primary)
```

**No conflict** because v1 notifyNewOrder is commented out in `index.ts`.

---

## 🧪 Post-Deployment Testing

### Test 1: Create Order

1. Create order from client app
2. Check Firestore:
   ```
   dispatch_queue/{orderId}
   ```
   Should exist with `currentWave: 0`

3. Wait 5 seconds
4. Check:
   ```
   dispatch_offers/{orderId}_{driverId}
   ```
   Should exist with `status: 'sent'`, `round: 1`

---

### Test 2: Driver Receives Notification

1. Driver app should receive FCM within 5 seconds
2. Notification data should include:
   - `offerId`
   - `notificationType: 'new_order'` or `'wave_offer'`
   - `round: '1'`

---

### Test 3: Accept Order

**In driver app**:
```dart
await ordersService.acceptOrder(orderId, offerId); // ← Must pass offerId
```

**Check Firestore**:
```
orders/{orderId}
  status: 'accepted'
  assignedDriverId: {driverId}
  acceptedAt: {timestamp}

dispatch_offers/{orderId}_{driverId}
  status: 'accepted'

dispatch_queue/{orderId}
  (should be deleted)

dispatch_metrics/{orderId}
  acceptedByDriverId: {driverId}
  acceptedAtWave: 1
  timeToAcceptSeconds: ~XX
```

---

### Test 4: Wave Expiration

1. Create order
2. **Don't accept** from driver
3. Wait 15 seconds
4. Check logs:
   ```bash
   firebase functions:log --only processExpiredWaves
   ```

Expected:
```
[ProcessExpiredWaves] Function triggered
[DispatchEngine] Wave expired, moving to next
[DispatchEngine] Starting wave 2
```

5. Check Firestore:
   ```
   dispatch_offers/{orderId}_{driver1}
     status: 'expired'

   dispatch_offers/{orderId}_{driver2}
     status: 'sent'
     round: 2
   ```

---

## 📊 Monitoring Commands

### Check Function Logs

```bash
# All v2 functions
firebase functions:log | grep -E "V2|Dispatch|Wave|Offer"

# Specific function
firebase functions:log --only processExpiredWaves

# Last 100 lines
firebase functions:log --lines 100

# Real-time
firebase functions:log --follow
```

---

### Check Firestore Collections

Firebase Console → Firestore:

```
dispatch_queue          → Active orders in dispatch
dispatch_offers         → Individual offers
driver_dispatch_state   → Driver availability
dispatch_metrics        → Performance data
```

---

### Check Cloud Scheduler

```bash
gcloud scheduler jobs describe firebase-schedule-processExpiredWaves-us-central1

# Run manually for testing
gcloud scheduler jobs run firebase-schedule-processExpiredWaves-us-central1
```

---

## 🚨 Rollback Plan

If issues occur:

### 1. Quick Rollback (5 minutes)

```bash
# Delete v2 functions
firebase functions:delete acceptOrderV2 notifyNewOrderV2 rejectOffer processExpiredWaves

# Re-enable v1 notifyNewOrder
# Edit functions/src/index.ts:
# Uncomment: export { notifyNewOrder } from './notifyNewOrder';

# Rebuild and deploy
cd functions
npm run build
firebase deploy --only functions:notifyNewOrder
```

---

### 2. Full Rollback (if needed)

```bash
# Restore from git
git checkout HEAD~1 -- functions/src/index.ts
git checkout HEAD~1 -- firestore.rules
git checkout HEAD~1 -- firestore.indexes.json

# Deploy
firebase deploy --only firestore:rules,firestore:indexes
cd functions && npm run build
firebase deploy --only functions
```

---

## ✅ Success Criteria (Check after 1 hour)

- [ ] Zero "duplicate notification" reports
- [ ] All new orders dispatched successfully
- [ ] Average acceptance time < 30 seconds
- [ ] No "order already taken" errors spike
- [ ] `processExpiredWaves` runs every 30 seconds
- [ ] Firestore read cost reduced (check Firebase Console → Usage)

---

## 📞 Support

**Logs**: `firebase functions:log`
**Firestore**: Firebase Console → Firestore
**Metrics**: Firebase Console → Functions → Dashboard

---

## 🎉 You're Ready!

Copy the commands above and deploy with confidence.

**Estimated total time**: 15-20 minutes (including index build wait)

**Good luck!** 🚀

---

**Deployment by**: WawApp Development Team
**Reviewed by**: Claude Code + Amazon Q
**Architecture**: Option C (Hybrid Wave Dispatch)
**Version**: 2.0.0 Production-Grade
