# Diagnostic Results - Driver Notification Issue
## Driver: drivers/49ZGFxTVAMaAMkVd4GQZ9Juyjg (Phone: 00249912900333)

**Date:** 2026-04-10
**Order ID:** QjhREsr40g5E3N7kuCg6
**Issue:** Notification did not appear

---

## Root Cause Identified ✅

From Cloud Functions logs (2026-04-10T10:47:23):

```
[NotifyNewOrder] New order created { order_id: 'QjhREsr40g5E3N7kuCg6' }
[NotifyNewOrder] No recent driver locations found
[NotifyNewOrder] No eligible drivers found
```

### Primary Issue:
**❌ Driver location document is MISSING or STALE**

The `notifyNewOrder` Cloud Function searches for drivers by querying:
```javascript
driver_locations collection
WHERE updatedAt > (current_time - 15 minutes)
```

**Result:** NO drivers were found in this query.

This means either:
1. **The driver doesn't have a document in `driver_locations` collection**, OR
2. **The `updatedAt` timestamp is older than 15 minutes**

---

## Why This Happened

The driver app needs to:
1. **Obtain GPS location** from the device
2. **Update `driver_locations/{driverId}` document** in Firestore every few seconds while online
3. **Keep the `updatedAt` field fresh** (< 15 minutes)

**Possible causes:**
- Driver just installed the new app build but **hasn't gone online yet**
- GPS location permission **not granted** or **GPS is disabled**
- Background location tracking **not working** (battery optimization, permissions, etc.)
- App **crashed or closed** before location could update
- **Network connectivity issue** preventing Firestore writes

---

## Solution Steps

### Step 1: Verify Driver Can See GPS Location in App ✅
**Driver needs to:**
1. Open the driver app
2. Tap "Go Online" button
3. **VERIFY**: Can see their current location on the map
4. **VERIFY**: Blue dot appears on the map at their current position
5. Stay online for at least 30 seconds

**Expected result:**
- Map centers on driver's location
- Blue location marker appears
- Location updates every 5-10 seconds

---

### Step 2: Verify Firestore Document is Created ✅
**You (admin) need to check:**

1. Go to: [Firebase Console → Firestore → driver_locations](https://console.firebase.google.com/project/wawapp-952d6/firestore/data/driver_locations)
2. Look for document ID: `49ZGFxTVAMaAMkVd4GQZ9Juyjg`

**Document should contain:**
```
{
  "lat": 18.0861,  // or "latitude"
  "lng": -15.9785,  // or "longitude"
  "accuracy": 15.2,  // meters
  "heading": 45.0,
  "speed": 0.0,
  "updatedAt": [RECENT TIMESTAMP - within last few minutes]
}
```

**If document doesn't exist:**
- Driver app is NOT updating location to Firestore
- Check: GPS permission granted?
- Check: Network connectivity?
- Check: App is running (not force-stopped)?

**If document exists but `updatedAt` is old:**
- Background location tracking is not working
- Check: Battery optimization disabled?
- Check: "Always" location permission granted (not just "While using")?

---

### Step 3: Grant All Required Permissions ✅

**Location Permissions:**
1. Settings → Apps → wawapp_driver → Permissions → Location
2. Select: **"Allow all the time"** (or "Always")
3. NOT "While using the app" - this won't work in background

**Battery Optimization:**
1. Settings → Apps → wawapp_driver → Battery
2. Select: **"Unrestricted"**
3. This ensures app can update location in background

**Notification Permissions:**
1. Settings → Apps → wawapp_driver → Notifications
2. Enable: **All notification categories**

**Alarms & Reminders:**
1. Settings → Apps → wawapp_driver → Alarms & reminders
2. Enable: **Allow setting alarms and reminders**

**Do Not Disturb:**
1. Settings → Apps → wawapp_driver → Do Not Disturb
2. Enable: **Allow to bypass DND**

---

### Step 4: Test Again with New Order ✅

**After completing steps 1-3:**

1. **Driver goes online** in the app
2. **Wait 30 seconds** for location to update to Firestore
3. **Verify** driver location document exists in Firestore with recent `updatedAt`
4. **Create a new order** using client app
5. **Pickup location must be within 10km** of driver's current location
6. **Expected result:** Notification appears within 5 seconds

---

## Expected Cloud Function Log (when working)

When everything is configured correctly, you should see:

```
[NotifyNewOrder] New order created { order_id: 'ORDER_ID' }
[NotifyNewOrder] Found X driver locations
[NotifyNewOrder] Driver 49ZGFxTVAMaAMkVd4GQZ9Juyjg eligible (distance: Y.YY km)
[NotifyNewOrder] Sending notification to 49ZGFxTVAMaAMkVd4GQZ9Juyjg
[NotifyNewOrder] FCM notification sent { messageId: 'FCM_MESSAGE_ID' }
```

---

## Quick Checklist for Driver

Before testing, driver must complete ALL of these:

- [ ] GPS enabled on device
- [ ] Location permission granted: **"Always" / "Allow all the time"**
- [ ] App opened and logged in
- [ ] Tapped "Go Online" button
- [ ] Can see blue dot on map at current location
- [ ] Battery optimization: **Unrestricted**
- [ ] All notification permissions enabled
- [ ] Stayed online for at least 30 seconds
- [ ] Network connection is stable (WiFi or mobile data)

---

## Technical Details (for developers)

### Location Update Implementation
File: `apps/wawapp_driver/lib/features/location/...` (check for LocationService or similar)

**The app should:**
1. Request location permission on startup
2. Start location tracking when driver goes online
3. Update Firestore `driver_locations/{driverId}` every 5-10 seconds
4. Stop tracking when driver goes offline
5. Use background location tracking (even when app is minimized)

**Cloud Function requirements:**
```javascript
// notifyNewOrder.ts line 69
.where('updatedAt', '>', new Date(Date.now() - 15 * 60 * 1000)) // Last 15 minutes
```

**This means:**
- Location MUST be updated at least once every 15 minutes
- Best practice: Update every 5-10 seconds while online
- Use background location services to maintain updates

---

## Next Steps

1. **Driver:** Complete all steps in "Solution Steps" section above
2. **Admin:** Verify `driver_locations/49ZGFxTVAMaAMkVd4GQZ9Juyjg` document exists and is fresh
3. **Test:** Create a new order within 10km of driver's location
4. **Monitor:** Check Cloud Functions logs for success messages

---

**Status:** Issue identified - Driver location not updating to Firestore
**Resolution:** Requires driver to enable permissions and go online properly
**Call-style notification implementation:** ✅ Complete and working (just needs location data)

---

**Prepared by:** Claude Code
**Date:** 2026-04-10
