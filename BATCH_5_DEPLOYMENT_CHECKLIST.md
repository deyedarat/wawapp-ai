# BATCH 5: Order Expiration - Deployment Checklist

**Date**: 2025-11-20
**Status**: ✅ BUILD SUCCESSFUL - Ready for Deployment

---

## Pre-Deployment Verification

- [x] TypeScript compiled successfully (no errors)
- [x] Output files created: `functions/lib/expireStaleOrders.js`
- [x] OrderStatus.expired verified in state machine
- [x] Firebase project ID configured: `wawapp-952d6`
- [x] Documentation complete

---

## Deployment Commands

### Step 1: Login to Firebase (if not already logged in)

```bash
firebase login
```

### Step 2: Verify Project

```bash
firebase projects:list
```

Expected output should show `wawapp-952d6` as the default project.

### Step 3: Deploy the Function

```bash
# From repository root (C:\Users\hp\Music\WawApp)
firebase deploy --only functions:expireStaleOrders
```

**Expected output**:
```
=== Deploying to 'wawapp-952d6'...

i  deploying functions
i  functions: ensuring required API cloudfunctions.googleapis.com is enabled...
i  functions: ensuring required API cloudbuild.googleapis.com is enabled...
✔  functions: required API cloudfunctions.googleapis.com is enabled
✔  functions: required API cloudbuild.googleapis.com is enabled
i  functions: preparing functions directory for uploading...
i  functions: packaged functions (X.XX KB) for uploading
✔  functions: functions folder uploaded successfully
i  functions: creating Node.js 18 function expireStaleOrders(us-central1)...
✔  functions[expireStaleOrders(us-central1)]: Successful create operation.
Function URL (expireStaleOrders): https://us-central1-wawapp-952d6.cloudfunctions.net/expireStaleOrders

✔  Deploy complete!
```

### Step 4: Verify Cloud Scheduler Created

```bash
firebase functions:list
```

Expected output should include:
```
expireStaleOrders(us-central1)
  Trigger: Cloud Scheduler
```

---

## Post-Deployment Verification

### 1. Check Firebase Console

**Navigate to**: Firebase Console → Functions → expireStaleOrders

Verify:
- ✅ Status: Deployed (green checkmark)
- ✅ Trigger: Cloud Pub/Sub (scheduled)
- ✅ Runtime: Node.js 18
- ✅ Region: us-central1
- ✅ Memory: 256 MB
- ✅ Timeout: 120 seconds

### 2. Check Cloud Scheduler

**Navigate to**: Google Cloud Console → Cloud Scheduler

Verify job exists:
- ✅ Name: `firebase-schedule-expireStaleOrders-us-central1`
- ✅ Frequency: `every 2 minutes`
- ✅ Timezone: Africa/Nouakchott
- ✅ Status: Enabled
- ✅ Next run: Within 2 minutes

### 3. Check Initial Logs

```bash
firebase functions:log --only expireStaleOrders --limit 5
```

Wait 2 minutes for first scheduled run, then check logs again.

Expected output:
```
[ExpireOrders] Function triggered at: 2025-11-20T...
[ExpireOrders] Expiration threshold: 2025-11-20T...
[ExpireOrders] No stale orders found.
```

(Or if stale orders exist, you'll see expiration messages)

---

## Manual Test

### 1. Create Test Order in Firestore Console

**Navigate to**: Firebase Console → Firestore Database → `orders` collection

**Click**: "+ Add Document"

**Enter**:

**Document ID**: `test-expire-123` (or auto-generate)

**Fields**:
```javascript
{
  "status": "matching",
  "assignedDriverId": null,
  "createdAt": [SET TO 15 MINUTES AGO],  // ← Click timestamp, set to past!
  "ownerId": "test-user-123",
  "pickup": {
    "lat": 18.0735,
    "lng": -15.9582,
    "label": "نواكشوط - تست"
  },
  "dropoff": {
    "lat": 18.0835,
    "lng": -15.9682,
    "label": "كيبه - تست"
  },
  "price": 500,
  "distanceKm": 5.2,
  "pickupAddress": "نواكشوط",
  "dropoffAddress": "كيبه"
}
```

**IMPORTANT**: For `createdAt`, click the timestamp picker and set it to 15 minutes before current time.

### 2. Wait for Next Scheduled Run

Maximum wait: 2 minutes

You can check the Cloud Scheduler to see exact next run time.

### 3. Verify Order Expired

Refresh the test order document in Firestore Console.

Expected changes:
- ✅ `status` changed from `"matching"` to `"expired"`
- ✅ `expiredAt` field added (timestamp)
- ✅ `updatedAt` field updated (timestamp)

### 4. Check Function Logs

```bash
firebase functions:log --only expireStaleOrders --limit 10
```

Expected output:
```
[ExpireOrders] Function triggered at: 2025-11-20T...
[ExpireOrders] Found 1 stale orders to expire.
[ExpireOrders] Expiring order test-expire-123 (created: 2025-11-20T...)
[ExpireOrders] Successfully expired 1 orders.
```

### 5. Delete Test Order

After verification, delete the test order from Firestore Console.

---

## Troubleshooting

### Issue: "Cloud Functions API not enabled"

**Solution**:
```bash
gcloud services enable cloudfunctions.googleapis.com --project=wawapp-952d6
gcloud services enable cloudbuild.googleapis.com --project=wawapp-952d6
gcloud services enable cloudscheduler.googleapis.com --project=wawapp-952d6
```

### Issue: "Permission denied"

**Solution**: Ensure you're logged in with an account that has Owner or Editor role on the project:
```bash
firebase login
firebase projects:list
```

### Issue: "Deployment timed out"

**Solution**: First-time deployments can take 5-10 minutes. Wait and check status in Firebase Console → Functions.

### Issue: "Cloud Scheduler job not created"

**Solution**: Redeploy the function:
```bash
firebase deploy --only functions:expireStaleOrders --force
```

### Issue: "No stale orders found" (when you expect some)

**Checklist**:
1. Verify test order `createdAt` is truly >10 minutes old
2. Verify `status` is exactly `"matching"` (case-sensitive)
3. Verify `assignedDriverId` is `null` (not missing, not empty string)
4. Check function logs for any errors
5. Manually trigger function to test immediately (see below)

### Manual Trigger (for testing)

You can manually trigger the function for immediate testing:

```bash
# Requires gcloud CLI
gcloud functions call expireStaleOrders --region=us-central1 --project=wawapp-952d6
```

Or use Firebase Console → Functions → expireStaleOrders → "Testing" tab.

---

## Rollback (if needed)

If something goes wrong:

### Option 1: Delete the Function

```bash
firebase functions:delete expireStaleOrders
```

This stops all scheduled runs immediately.

### Option 2: Disable Cloud Scheduler Job

In Cloud Scheduler console:
1. Find: `firebase-schedule-expireStaleOrders-us-central1`
2. Click: "Pause"

Function remains deployed but won't run automatically.

### Fix and Redeploy

1. Fix the issue in `functions/src/expireStaleOrders.ts`
2. Rebuild: `cd functions && npm run build`
3. Redeploy: `firebase deploy --only functions:expireStaleOrders`

---

## Success Criteria

BATCH 5 is considered successfully deployed when:

- [x] TypeScript compiles without errors
- [ ] Function deployed to Firebase successfully
- [ ] Cloud Scheduler job created and enabled
- [ ] Function appears in Firebase Console → Functions
- [ ] Initial logs show function triggered (even if "No stale orders found")
- [ ] Manual test order expires successfully within 2 minutes
- [ ] Logs confirm: "Successfully expired 1 orders"
- [ ] Expired order has correct status and timestamps

---

## Monitoring (First 24 Hours)

### Check Logs Periodically

```bash
# Stream logs in real-time
firebase functions:log --only expireStaleOrders --follow

# Check for errors
firebase functions:log --only expireStaleOrders | grep ERROR

# Check latest 20 executions
firebase functions:log --only expireStaleOrders --limit 20
```

### Monitor Metrics

**Firebase Console → Functions → expireStaleOrders → Metrics**

Watch for:
- Invocation count: ~720/day (every 2 minutes)
- Execution time: Should be <5 seconds typically
- Error rate: Should be 0%
- Memory usage: Should be well below 256MB

### Set Up Alerts (Optional)

In Cloud Monitoring, create alerts for:
- Function execution failures (>1% error rate)
- Execution time >30 seconds
- Batch limit warnings (check logs for "WARNING: Hit batch limit")

---

## Next Steps After Deployment

1. **Monitor for 24 hours**: Watch logs and metrics
2. **Verify client/driver apps**: Ensure expired orders don't appear in UI
3. **Document any issues**: Report in project notes
4. **Plan BATCH 6**: Consider FCM notifications, UI indicators, analytics

---

## Estimated Deployment Time

- **Firebase CLI deployment**: 3-5 minutes (first time: 8-10 minutes)
- **Cloud Scheduler provisioning**: 1-2 minutes
- **Manual testing**: 5 minutes (including 2-min wait)
- **Total**: ~15 minutes

---

**Ready to Deploy!** ✅

Run the commands in Step 3 above to deploy the Cloud Function.

---

**Last Updated**: 2025-11-20
**Build Status**: ✅ SUCCESS
**Deployment Status**: ⏳ PENDING USER ACTION
