# QA Exploration Report: WawApp Driver Notification Reliability

**Author:** Antigravity (Advanced Agentic Coding AI)  
**Date:** May 6, 2026  
**Focus:** Full-screen notifications, tray flooding, force-stop/reboot behavior, lifecycle consistency, and Xiaomi/MIUI battery optimizations.  
**Scope:** Real Android Device Testing (specifically tested on `R83Y20PC4EN` 720x1600 and `R8YW40AW58L` 1080x2408 running Android 12-14).

---

## 1. Executive Summary

A comprehensive, automated, and manual QA exploration of the **WawApp Driver** notification architecture was conducted to evaluate the reliability of driver order dispatch notifications. Full-screen intents (FSI) are critical for dispatching high-priority "New Order" invitations that drivers must accept or reject within a tight window. 

This exploration revealed key vulnerabilities across the notification lifecycle—ranging from silent failures when the device is locked/screen-off, to stuck full-screen overlays after client cancellations or TTL timeouts, and aggressive battery saver suppressions on OEM-customized Android flavors (such as Xiaomi's MIUI). 

This report documents these findings, provides step-by-step reproduction flows using local ADB payloads (eliminating production backend dependency), and outlines actionable recommendations for the engineering team.

---

## 2. Detailed Findings & Failure Modes

### 🔍 Finding 1: Full-Screen Intent Failures (Locked State / Screen Off)
* **Symptom:** When the driver's device screen is **OFF** and locked, receiving a high-priority FCM data message fails to launch the full-screen invitation activity (`FullScreenNotificationActivity`). The device remains dark or only plays audio without waking the screen.
* **Root Cause:**
  1. **Bypassing the Keyguard:** In Android 10+, activities cannot turn on the screen or show over the lock screen unless they configure the WindowManager flags early in `onCreate()` (before `super.onCreate()` and `setContentView()`):
     ```kotlin
     if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
         setShowWhenLocked(true)
         setTurnScreenOn(true)
         val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
         keyguardManager.requestDismissKeyguard(this, null)
     } else {
         window.addFlags(
             WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
             WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
             WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
         )
     }
     ```
  2. **Android 14 special permission:** `USE_FULL_SCREEN_INTENT` is a revokable special permission in Android 14. If the app is categorized incorrectly or the user manually revokes it, the full-screen intent is downgraded by the system to a standard heads-up banner.
* **Log/Test Evidence:** `test_results_2026-05-06T14-45-28.md` shows `S6: Driver Device LOCKED (screen off)` consistently **FAIL** in 30,230ms: `"driver online ✓; screen OFF confirmed; order created; FS NOT launched in 30s. Focus: NotificationShade"`.

---

### 🔍 Finding 2: Stuck Overlays & Blocked Navigation (TTL/Cancellation)
* **Symptom:** Once `FullScreenNotificationActivity` is launched, it remains permanently on screen, blocking the driver from navigating elsewhere or receiving other orders, even after:
  1. The client **cancels** the order while matching.
  2. The invitation **Time-To-Live (TTL) expires** (no-response auto-dismiss).
* **Root Cause:**
  1. **Cancellation Handling:** `FullScreenNotificationActivity` does not register a broadcast receiver or subscribe to the event stream tracking order cancellations. When a cancel FCM arrives, the activity is completely unaware and fails to call `finish()`.
  2. **TTL Auto-Dismiss Handler:** The auto-dismiss countdown timer or handler inside `FullScreenNotificationActivity` either:
     - Is never started or initialized.
     - Is garbage collected because it's not held as a strong reference.
     - Fails to invoke `finish()` because of an unhandled context lifecycle exception when the app is in the background.
* **Log/Test Evidence:** `test_results_2026-05-06T14-07-39.md` shows `S3: Client Cancels During Matching` and `S5: No Response (TTL Auto-Dismiss)` both **FAIL** because the full-screen activity was still showing on top.

---

### 🔍 Finding 3: Duplicate Full-Screen Launches & Audio Loop Stacking
* **Symptom:** Under rapid or multiple FCM/broadcast sends (stress/spam scenarios), multiple overlapping instances of `FullScreenNotificationActivity` are launched in a stack. This leads to duplicate sound loops, stuttering vibrations, and requires the driver to tap "Reject" or "Accept" multiple times to clear the screen.
* **Root Cause:**
  1. **Incorrect Launch Mode:** In `AndroidManifest.xml`, `FullScreenNotificationActivity` is configured with default (`standard`) launch mode instead of `singleTop` or `singleInstance`.
  2. **Lack of Intent Flags:** The intent triggering the activity from `MyFirebaseMessagingService` does not use `FLAG_ACTIVITY_CLEAR_TOP` or `FLAG_ACTIVITY_SINGLE_TOP`.
  3. **No Active Check:** The messaging service does not verify if an instance of the activity is already active before launching another one.
* **Log/Test Evidence:** Automated spam tests (`qa/scripts/run_notification_spam.ps1`) verified that without active deduplication, `dumpsys activity activities` records multiple stacked instances of `.FullScreenNotificationActivity`.

---

### 🔍 Finding 4: Notification Tray Flooding
* **Symptom:** If the backend sends multiple updates for the same order, or if the driver receives multiple distinct orders, the notification tray gets flooded with identical/overlapping notification items.
* **Root Cause:**
  1. **Unstable Notification IDs:** The app generates a random integer or a sequential ID (`System.currentTimeMillis()`) for each notification instead of utilizing a stable hash of the unique `orderId`.
  2. **Lack of Replacement:** Because the notification ID is unique each time, the Android `NotificationManager` treats them as separate alerts instead of updating/replacing the existing alert.
* **Log/Test Evidence:** `test_results_2026-05-06T14-07-39.md` recorded multiple notification items for the same app in the tray during S5: `"0|com.wawapp.driver|75415|null|10372; 0|com.wawapp.driver|2000|null|10372"`.

---

### 🔍 Finding 5: Background & Killed-State Failures (Force-Stop/Reboot)
* **Symptom:** After a device reboot or an explicit `force-stop` by the user, the driver misses all incoming order notifications until they manually open the app.
* **Root Cause:**
  1. **Stopped State:** Under Android's security model, a force-stopped app is placed in a "stopped state" where no broadcasts can wake it unless they explicitly use `FLAG_INCLUDE_STOPPED_PACKAGES`. FCM high-priority data messages can wake up the app, but aggressive OEM modifications completely override this.
  2. **Missing Boot Receiver:** The app lacks a registered `BroadcastReceiver` listening for `android.intent.action.BOOT_COMPLETED` to re-register the background synchronization services and Firestore listeners on boot.

---

## 3. Focus Area: Xiaomi / MIUI Behavior & Battery Optimization

Xiaomi's MIUI is notoriously aggressive with background process management and restricts key notification pathways by default:

| Feature | MIUI Default Behavior | Impact on WawApp | Solution / Workaround Required |
|---------|-----------------------|------------------|--------------------------------|
| **Autostart** | **Disabled** by default for user-installed apps. | Completely blocks FCM messages from waking the app from a killed state or background state. | Must guide the driver to enable **Autostart** in `Settings → Security → Permissions → Autostart`. |
| **Battery Saver** | **Active (Smart Mode)**. Pinches background activities and network access after a period of inactivity. | Delays location tracking updates and drops incoming FCM connections when the app is in the background. | Must guide driver to set battery optimization to **No Restrictions** under `Settings → Apps → Manage Apps → wawapp_driver → Battery Saver`. |
| **Show on Lock Screen** | **Disabled** for background launches. | Bypasses the Full-Screen Intent and forces it into a silent, hidden tray notification, which drivers miss. | Must request `SYSTEM_ALERT_WINDOW` or guide driver to enable "Show on Lock screen" in MIUI app permissions. |
| **Start in Background** | **Disabled** by default. | Prevents background services from launching new activities (like `FullScreenNotificationActivity`). | Must guide the driver to enable "Start in background" in MIUI app permissions. |

---

## 4. Local-Only Reproduction Steps (ADB)

To test and reproduce these scenarios on a real Android device without affecting the production backend or writing code, use the following ADB broadcast commands:

### Test 1: Full-Screen Intent Trigger (App in Background / Screen On)
1. Open WawApp Driver and put it in the background (press Home).
2. Ensure the screen is **ON**.
3. Execute the following ADB command:
   ```powershell
   adb shell am broadcast -a com.wawapp.driver.TEST_NOTIFICATION `
     --es type "new_order" `
     --es orderId "test_fsi_background" `
     --es pickupLat "18.0735" `
     --es pickupLng "-15.9582" `
     --es dropoffLat "18.0800" `
     --es dropoffLng "-15.9500" `
     --es price "500" `
     --es clientName "QA_Tester"
   ```
4. **Expected Result:** `FullScreenNotificationActivity` launches instantly, playing audio/vibration and showing order details.

### Test 2: Full-Screen Intent Wake-Up (Screen OFF & Locked)
1. Connect the device, lock it, and turn the screen **OFF**.
2. Run the same command as above with a unique `orderId`:
   ```powershell
   adb shell am broadcast -a com.wawapp.driver.TEST_NOTIFICATION `
     --es type "new_order" `
     --es orderId "test_fsi_locked" `
     --es price "650" `
     --es clientName "QA_Locked_Test"
   ```
3. **Expected Result:** The device screen should immediately wake up, turning ON and displaying the full-screen invitation activity over the lock screen.

### Test 3: Notification Spam / Dedup Stress
To verify that rapid notifications do not flood the tray or stack multiple full-screen activities, run the local stress script:
```powershell
.\qa\scripts\run_notification_spam.ps1 -Count 5 -IntervalMs 200 -Mode duplicate
```
* **Success Criteria:** Only **one** full-screen activity is active, and only **one** notification is visible in the notification tray (updated with the latest price).

---

## 5. Summary of Recommended Code Improvements (For Engineers)

> [!IMPORTANT]
> The following recommendations are local guidelines for resolving the discovered issues without touching production code during exploration.

1. **Activity Launch Mode Configuration:**
   In `AndroidManifest.xml`, configure `FullScreenNotificationActivity` to prevent multiple stacked instances:
   ```xml
   <activity
       android:name=".FullScreenNotificationActivity"
       android:launchMode="singleTop"
       android:excludeFromRecents="true"
       android:showOnLockScreen="true"
       android:turnScreenOn="true"/>
   ```

2. **Timer-Based Auto-Dismiss (TTL):**
   Implement a solid `Handler` or `CountDownTimer` inside `FullScreenNotificationActivity.kt` to auto-close the activity if the driver fails to respond within the allotted time (e.g., 15 seconds):
   ```kotlin
   private val autoDismissHandler = Handler(Looper.getMainLooper())
   private val dismissRunnable = Runnable {
       Log.d("FSI", "TTL Expired. Dismissing full-screen activity.")
       finish()
   }

   override fun onCreate(savedInstanceState: Bundle?) {
       super.onCreate(savedInstanceState)
       // Start TTL countdown
       autoDismissHandler.postDelayed(dismissRunnable, 15000)
   }

   override fun onDestroy() {
       autoDismissHandler.removeCallbacks(dismissRunnable)
       super.onDestroy()
   }
   ```

3. **Active Dedup on Notification IDs:**
   Inside `MyFirebaseMessagingService.kt` (or corresponding native receiver), generate a unique, stable notification ID by hashing the `orderId`:
   ```kotlin
   val notificationId = orderId.hashCode()
   ```
   This ensures that any subsequent FCM update for the same order replaces the existing notification item instead of spawning duplicate entries in the tray.

4. **Integration of Permissions Diagnostic Screen:**
   Maintain and promote the `PermissionsDiagnosticScreen` inside the driver app to actively check for **Xiaomi/Samsung specific autostart and battery optimization statuses**, warning the driver with clear UX prompts if their device settings will cause them to miss high-paying orders.

---

## 6. QA Sign-Off & Next Steps

This exploration confirms that while the core full-screen call-style notification architecture is technically capable of delivering real-time orders, it is highly susceptible to **lifecycle inconsistencies (stuck screens)** and **aggressive OEM background restrictions (Xiaomi MIUI)**.

**Recommended Next Steps:**
1. Provide the reproduction steps in **Section 4** to the developers to demonstrate the locked-screen wake-up failure.
2. Implement the `singleTop` launch mode and TTL `Handler` inside the next sprint to resolve stuck overlay issues.
3. Validate the fixes on a physical Xiaomi/MIUI device using the local scripts.
