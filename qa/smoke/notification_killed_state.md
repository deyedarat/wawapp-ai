# Smoke Test: Killed-State Notification (N3)

## Objective
Verify that a driver receives and sees a full-screen notification when the app is force-stopped and an FCM data message arrives.

---

## Preconditions

1. Driver app installed on physical device (not emulator)
2. Device connected via ADB: `adb devices` shows device serial
3. Driver is logged in and has valid FCM token in Firestore
4. Device battery optimization disabled for `com.wawapp.driver`
5. AlarmManager exact alarm permission granted (Android 12+)
6. Full-screen intent permission granted (Android 14+)

### Verify permissions
```bash
# Check exact alarm
adb shell dumpsys alarm | findstr "com.wawapp.driver"

# Check full-screen intent (Android 14+)
adb shell cmd appops get com.wawapp.driver USE_FULL_SCREEN_INTENT
```

---

## Steps

### 1. Force-stop the app
```bash
adb shell am force-stop com.wawapp.driver
```

### 2. Verify app is killed
```bash
adb shell pidof com.wawapp.driver
# Expected: empty output (no PID)
```

### 3. Send test FCM data message
Use Firebase Admin SDK or `curl` to send a data-only message:

```bash
curl -X POST https://fcm.googleapis.com/v1/projects/<PROJECT_ID>/messages:send \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d '{
    "message": {
      "token": "<DRIVER_FCM_TOKEN>",
      "data": {
        "type": "new_order",
        "orderId": "test_smoke_n3_001",
        "pickupLat": "18.0735",
        "pickupLng": "-15.9582",
        "dropoffLat": "18.0800",
        "dropoffLng": "-15.9500",
        "price": "500",
        "clientName": "Test Client"
      }
    }
  }'
```

### 4. Wait for delivery
```bash
# Wait 5 seconds for FCM delivery
timeout /t 5
```

### 5. Capture screen state
```bash
adb shell screencap -p /sdcard/smoke_n3.png
adb pull /sdcard/smoke_n3.png qa/artifacts/
```

### 6. Dump UI hierarchy
```bash
adb shell uiautomator dump /sdcard/ui_n3.xml
adb pull /sdcard/ui_n3.xml qa/artifacts/
```

---

## Expected Behavior

| Check | Expected |
|-------|----------|
| Screen wakes | Yes — device screen turns on |
| Full-screen intent shown | Yes — `FullScreenNotificationActivity` visible |
| Order details displayed | orderId, price, pickup visible on screen |
| Sound/vibration | Device vibrates or plays notification sound |
| App process started | `adb shell pidof com.wawapp.driver` returns PID |

---

## Failure Indicators

| Symptom | Likely Cause |
|---------|--------------|
| No screen wake | Missing `USE_FULL_SCREEN_INTENT` permission |
| Notification in tray only | FCM sent as notification msg, not data msg |
| No notification at all | FCM token stale, or battery optimization killed delivery |
| App crash on wake | Null intent extras or missing order fields |
| Duplicate notifications | Missing dedup logic in `MyFirebaseMessagingService` |

---

## Artifact Collection

After each run, collect:

```bash
# Screenshot
adb shell screencap -p /sdcard/smoke_n3.png
adb pull /sdcard/smoke_n3.png qa/artifacts/smoke_n3_$(date +%s).png

# UI dump
adb shell uiautomator dump /sdcard/ui_n3.xml
adb pull /sdcard/ui_n3.xml qa/artifacts/ui_n3_$(date +%s).xml

# Logcat (last 500 lines, FCM related)
adb logcat -d -t 500 | findstr /i "FCM firebase messaging wawapp" > qa/artifacts/logcat_n3_%date%.txt

# Notification log
adb shell dumpsys notification > qa/artifacts/notif_dump_n3.txt
```

---

## Automation Hook

This scenario maps to `test-runner/index.js` step S5 (killed-state notification).
Future: integrate into `qa/scripts/run_smoke.ps1` for CI gate.
