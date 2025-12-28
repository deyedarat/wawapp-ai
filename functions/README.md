# WawApp Cloud Functions

Firebase Cloud Functions for WawApp backend automation and order management.

## Overview

This directory contains serverless Cloud Functions that handle:
- **Order Expiration**: Automatically expires orders that stay in `matching` status for >10 minutes

## Prerequisites

- Node.js 18 or higher
- Firebase CLI installed: `npm install -g firebase-tools`
- Firebase project access (project ID: `wawapp-952d6`)

## Setup

### 1. Install Dependencies

```bash
cd functions
npm install
```

### 2. Login to Firebase

```bash
firebase login
```

### 3. Verify Project Configuration

```bash
# From repository root
firebase projects:list

# Should show wawapp-952d6 as the default project
```

## Development

### Build TypeScript

```bash
cd functions
npm run build
```

### Watch Mode (Auto-rebuild on changes)

```bash
npm run build:watch
```

### Local Testing with Emulators

```bash
# From repository root
firebase emulators:start --only functions

# Functions will be available at http://localhost:5001
```

## Deployment

### Deploy All Functions

```bash
# From repository root
firebase deploy --only functions
```

### Deploy Specific Function

```bash
firebase deploy --only functions:expireStaleOrders
```

### First-Time Deployment Notes

1. **Enable Required APIs**: Firebase CLI will prompt you to enable:
   - Cloud Functions API
   - Cloud Build API
   - Cloud Scheduler API

2. **Grant Permissions**: You may need to grant the Cloud Scheduler service account permissions:
   ```
   gcloud projects add-iam-policy-binding wawapp-952d6 \
     --member serviceAccount:firebase-adminsdk@wawapp-952d6.iam.gserviceaccount.com \
     --role roles/cloudscheduler.admin
   ```

3. **Wait for Build**: First deployment can take 5-10 minutes as Firebase provisions resources.

## Cloud Functions

### expireStaleOrders

**Purpose**: Automatically expires orders that have been in `matching` status for more than 10 minutes without being assigned to a driver.

**Schedule**: Runs every 2 minutes (cron: `*/2 * * * *`)

**Timezone**: Africa/Nouakchott (Mauritania)

**Logic**:
1. Query orders where:
   - `status == 'matching'`
   - `assignedDriverId == null`
   - `createdAt < (now - 10 minutes)`
2. Update matching orders to:
   - `status = 'expired'`
   - `expiredAt = serverTimestamp()`
   - `updatedAt = serverTimestamp()`
3. Batch limit: 500 orders per run

**Firestore Transitions**:
- `matching` → `expired` (defined in `packages/core_shared/lib/src/order_status.dart`)

**Logs**:
```bash
# View logs
firebase functions:log --only expireStaleOrders

# Stream logs in real-time
firebase functions:log --only expireStaleOrders --follow
```

**Monitoring**:
- Check Firebase Console → Functions → expireStaleOrders → Logs
- Cloud Scheduler job created automatically at: Console → Cloud Scheduler

## Testing

### Manual Test: Expire a Test Order

1. **Create a test order** in Firestore Console with past `createdAt`:

```javascript
// In Firestore Console: orders collection → Add Document
{
  "status": "matching",
  "assignedDriverId": null,
  "createdAt": timestamp(15 minutes ago), // Set to past timestamp
  "ownerId": "test-user-id",
  "pickup": { "lat": 18.0735, "lng": -15.9582, "label": "Test Pickup" },
  "dropoff": { "lat": 18.0835, "lng": -15.9682, "label": "Test Dropoff" },
  "price": 500,
  "distanceKm": 5.2
}
```

2. **Wait for next scheduled run** (max 2 minutes)

3. **Verify the order status** changed to `expired` and `expiredAt` was added

4. **Check logs**:
```bash
firebase functions:log --only expireStaleOrders --limit 10
```

### Manual Trigger (for immediate testing)

You can manually trigger the function using Firebase emulators or by temporarily changing the schedule to `every 1 minutes` for faster testing.

## Cost Estimates

**Cloud Scheduler**: $0.10/month for 1 job (first 3 jobs free)
**Cloud Function Invocations**: ~21,600/month (every 2 min) = $0.40/month
**Firestore Reads**: Minimal (only queries stale orders)

**Total**: <$1/month

## Troubleshooting

### Function Not Deploying

**Error**: "Cloud Functions API not enabled"

**Solution**:
```bash
gcloud services enable cloudfunctions.googleapis.com --project=wawapp-952d6
gcloud services enable cloudbuild.googleapis.com --project=wawapp-952d6
gcloud services enable cloudscheduler.googleapis.com --project=wawapp-952d6
```

### Scheduler Not Running

**Error**: "Cloud Scheduler job not found"

**Solution**:
- Go to Firebase Console → Functions → expireStaleOrders
- Verify the Cloud Scheduler job exists under "Triggers"
- If missing, redeploy: `firebase deploy --only functions:expireStaleOrders`

### Permission Errors

**Error**: "Missing permissions to access resource"

**Solution**: Ensure the Firebase service account has proper permissions. Run:
```bash
firebase projects:list
firebase functions:config:get
```

### No Orders Being Expired

**Checklist**:
1. Verify function is deployed: `firebase functions:list`
2. Check logs for errors: `firebase functions:log --only expireStaleOrders`
3. Verify Cloud Scheduler job is running: Firebase Console → Cloud Scheduler
4. Manually trigger function to test
5. Check query matches actual data (status='matching', assignedDriverId=null, old createdAt)

## Architecture Notes

### Why Cloud Scheduler + Pub/Sub?

- **Time-based logic**: We need expiration based on elapsed time, not document writes
- **Predictable cost**: Scheduled functions have fixed cost vs per-document triggers
- **Batch processing**: Can handle multiple stale orders efficiently in one execution

### Why Not Firestore Triggers?

- Firestore triggers fire on document events (create/update/delete)
- Would require additional writes just to trigger the function
- Not suitable for time-based expiration logic

### Safety Against Race Conditions

The function is safe against race conditions where a driver accepts an order while it's being expired:

1. **Query filters** ensure only `assignedDriverId == null` orders are fetched
2. **Double-check** before update verifies status is still `matching` and no driver assigned
3. **Transaction handling** in driver's `acceptOrder()` method validates status hasn't changed
4. **Result**: Either driver's transaction succeeds OR function expires order, never both

## Rollback Procedure

If the Cloud Function causes issues:

### 1. Disable the Function

```bash
firebase functions:delete expireStaleOrders
```

### 2. Manual Cleanup (if needed)

Use Firestore Console to manually update any incorrectly expired orders:
```javascript
// Reset expired order back to matching
{
  "status": "matching",
  "expiredAt": null  // Remove this field
}
```

### 3. Redeploy After Fix

```bash
# Fix the code
npm run build

# Redeploy
firebase deploy --only functions:expireStaleOrders
```

## Future Enhancements

Potential improvements for future batches:
- [ ] Configurable expiration timeout (via Firebase Remote Config)
- [ ] Send push notification to client when order expires
- [ ] Add client UI indicator for expired orders in history
- [ ] Analytics tracking for expiration rate
- [ ] Auto-retry or auto-extend for high-demand times

---

**Maintained By**: WawApp Development Team
**Last Updated**: 2025-11-20
**Related Docs**: `docs/FIRESTORE_INDEXES.md`, `packages/core_shared/lib/src/order_status.dart`
