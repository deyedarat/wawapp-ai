# Notification Troubleshooting Guide
## For Driver: drivers/49ZGFxTVAMaAMkVd4GQZ9Juyjg

**Date:** 2026-04-10
**Issue:** Notification not appearing after implementing call-style notifications

---

## Quick Diagnostic Checklist

Use the Firebase Console to check these requirements:

### 1. Driver Document (`drivers/49ZGFxTVAMaAMkVd4GQZ9Juyjg`)

Navigate to: [Firebase Console → Firestore → drivers collection](https://console.firebase.google.com/project/wawapp-952d6/firestore/data/drivers/49ZGFxTVAMaAMkVd4GQZ9Juyjg)

Check these fields:
- [ ] `isOnline` = `true` ✅ **REQUIRED**
- [ ] `isVerified` = `true` ✅ **REQUIRED**
- [ ] `fcmToken` exists and is not empty ✅ **REQUIRED**
- [ ] `phone` = `00249912900333` (verify correct driver)

**If `fcmToken` is missing:**
- Driver needs to close and reopen the app
- App will automatically register FCM token on startup

**If `isOnline` is `false`:**
- Driver needs to tap "Go Online" button in the app

---

### 2. Driver Location (`driver_locations/49ZGFxTVAMaAMkVd4GQZ9Juyjg`)

Navigate to: [Firebase Console → Firestore → driver_locations collection](https://console.firebase.google.com/project/wawapp-952d6/firestore/data/driver_locations/49ZGFxTVAMaAMkVd4GQZ9Juyjg)

Check these fields:
- [ ] `lat` or `latitude` exists (e.g., 15.5527) ✅ **REQUIRED**
- [ ] `lng` or `longitude` exists (e.g., -61.5333) ✅ **REQUIRED**
- [ ] `updatedAt` is within last 15 minutes ✅ **REQUIRED**
- [ ] `accuracy` < 100 meters (optional but recommended)

**If location document doesn't exist:**
- Driver needs to enable GPS location permissions
- Driver needs to grant "Location" permission to the app (Always)

**If `updatedAt` is stale (> 15 minutes):**
- Driver needs to move around a bit or restart the app
- Background location tracking might be disabled

---

### 3. Active Orders Check

Navigate to: [Firebase Console → Firestore → orders collection](https://console.firebase.google.com/project/wawapp-952d6/firestore/data/orders)

Search for orders where:
- `driverId` = `49ZGFxTVAMaAMkVd4GQZ9Juyjg` OR
- `assignedDriverId` = `49ZGFxTVAMaAMkVd4GQZ9Juyjg`
- `status` IN [`accepted`, `onRoute`]

**Result must be EMPTY** ✅ **REQUIRED**

**If there are active orders:**
- Driver cannot receive new notifications until current order is completed
- Complete or cancel the existing order first

---

### 4. Test Order Requirements

For a test order to trigger notification, verify:

Navigate to: [Firebase Console → Firestore → orders collection](https://console.firebase.google.com/project/wawapp-952d6/firestore/data/orders)

The order document must have:
- [ ] `status` = `matching` ✅ **REQUIRED**
- [ ] `pickup.lat` exists (e.g., 18.0861) ✅ **REQUIRED**
- [ ] `pickup.lng` exists (e.g., -15.9785) ✅ **REQUIRED**
- [ ] Driver is within 10km of pickup location ✅ **REQUIRED**

**Calculate distance:**
Use this tool: https://www.movable-type.co.uk/scripts/latlong.html
- Enter driver's `lat`, `lng` (from `driver_locations`)
- Enter order's `pickup.lat`, `pickup.lng`
- Distance must be ≤ 10 km

---

## Common Issues & Solutions

### Issue 1: "fcmToken is missing"
**Symptoms:** Token field is empty or doesn't exist in driver document

**Solution:**
1. Close the driver app completely (swipe away from recent apps)
2. Reopen the app
3. Log in again
4. Check Firestore - `fcmToken` should now be populated

---

### Issue 2: "Location is stale (> 15 minutes)"
**Symptoms:** `updatedAt` timestamp is too old

**Solution:**
1. Ensure GPS is enabled on the device
2. Grant location permission to the app (Settings → Apps → wawapp_driver → Permissions → Location → Always)
3. Restart the app
4. Move around a bit to trigger location update
5. Check if `updatedAt` is now recent

---

### Issue 3: "Driver too far from pickup (> 10 km)"
**Symptoms:** Driver is not receiving notifications for orders

**Solution:**
1. Create a test order with pickup location close to driver's current location
2. Use the same neighborhood or within 5km for testing
3. Verify driver's location in Firebase Console matches their physical location

---

### Issue 4: "Notification permissions not granted"
**Symptoms:** App installed but no notification channels visible in Android settings

**Solution:**
1. Go to: **Settings → Apps → wawapp_driver → Notifications**
2. Enable: ✅ **All notifications**
3. Enable: ✅ **New Orders** category
4. Enable: ✅ **Unassigned Orders** category
5. Enable: ✅ **Trip Reminders** category
6. Go to: **Settings → Apps → wawapp_driver → Battery**
7. Select: **Unrestricted**
8. Go to: **Settings → Apps → wawapp_driver → Alarms & reminders**
9. Enable: ✅ **Allow setting alarms and reminders**

---

### Issue 5: "Battery optimization blocking notifications"
**Symptoms:** Notifications work when app is open, but not in background/terminated

**Solution:**
1. Open **Permissions Diagnostic Screen** in the app (if route is added)
2. OR manually check:
   - Settings → Apps → wawapp_driver → Battery → **Unrestricted**
   - Settings → Apps → wawapp_driver → Do Not Disturb → **Allow**
3. For Samsung devices:
   - Settings → Apps → wawapp_driver → App Settings
   - Disable: **"Remove permissions if app unused"**

---

## Testing Steps (Proper Method)

### Step 1: Verify Driver is Ready
1. ✅ Check all items in sections 1-3 above
2. ✅ Driver is online in the app
3. ✅ Driver can see "Available" status
4. ✅ GPS location is accurate

### Step 2: Create Test Order
1. ✅ Use client app to create a new order
2. ✅ Set pickup location within 5km of driver's current location
3. ✅ Use a real address (not just random coordinates)
4. ✅ Complete order creation

### Step 3: Expected Behavior (within 5 seconds)
1. ✅ Full-screen notification appears
2. ✅ Screen turns on automatically (even if locked)
3. ✅ Notification sound plays 3 times (1.5s and 3s delays)
4. ✅ Vibration pattern executes
5. ✅ Notification bypasses DND mode
6. ✅ Notification shows order details (pickup, dropoff, price, distance)

### Step 4: If Notification Still Doesn't Appear
Check Cloud Functions logs:
```bash
firebase functions:log --only notifyNewOrder --limit 50
```

Look for:
- ✅ Function executed for the order ID
- ✅ Driver was found in eligible drivers list
- ✅ FCM notification sent successfully
- ❌ Any errors or rejections

---

## Device-Specific Notes

### Samsung Devices
- **Aggressive battery optimization** - disable "Remove permissions if app unused"
- **Notification channels** - ensure all categories are enabled
- **Background restrictions** - set to "Unrestricted"

### Xiaomi / Oppo / Vivo
- **Autostart permission required** - Settings → Security → Permissions → Autostart → Enable for wawapp_driver
- **Battery saver** - add app to whitelist
- **Notification importance** - set to "Urgent" or "Important"

### Stock Android (Pixel, Motorola, etc.)
- Usually works without special configuration
- Just ensure Battery → Unrestricted

---

## Advanced Debugging

### Check FCM Token Validity
Run this in Cloud Functions console or Firebase CLI:
```javascript
const admin = require('firebase-admin');
admin.initializeApp();

async function testToken() {
  const token = 'PASTE_DRIVER_FCM_TOKEN_HERE';

  const message = {
    notification: {
      title: 'Test Notification',
      body: 'This is a test'
    },
    token: token,
    android: {
      priority: 'high'
    }
  };

  try {
    const response = await admin.messaging().send(message);
    console.log('✅ Notification sent successfully:', response);
  } catch (error) {
    console.error('❌ Error sending notification:', error);
  }
}

testToken();
```

### Check Cloud Function Execution
1. Go to: [Firebase Console → Functions → Logs](https://console.firebase.google.com/project/wawapp-952d6/functions/logs)
2. Filter by: `notifyNewOrder`
3. Look for logs related to the order ID
4. Check for errors or warnings

---

## Contact Support

If you've verified all the above and notifications still don't work:

1. **Collect diagnostics:**
   - Screenshot of driver document in Firestore
   - Screenshot of driver_locations document
   - Screenshot of app permissions screen
   - Device model and Android version
   - Order ID that didn't trigger notification

2. **Send to development team with:**
   - Driver ID: `49ZGFxTVAMaAMkVd4GQZ9Juyjg`
   - Phone: `00249912900333`
   - All screenshots from step 1

---

**Last Updated:** 2026-04-10
**Implemented By:** Claude Code + Human Developer
**Status:** Ready for testing
