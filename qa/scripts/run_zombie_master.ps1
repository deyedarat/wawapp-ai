Param(
    [string]$Device = "R83Y20PC4EN"
)

Write-Host "[MASTER] 1. Preparing Device state and clearing logs..."
adb -s $Device logcat -c
adb -s $Device shell am force-stop com.samsung.android.dialer
adb -s $Device shell am force-stop com.google.android.apps.messaging
adb -s $Device shell input keyevent 3 # Home
Start-Sleep -Seconds 2

# Ensure the App is online
adb -s $Device shell monkey -p com.wawapp.driver -c android.intent.category.LAUNCHER 1 | Out-Null
Start-Sleep -Seconds 8

Write-Host "[MASTER] 2. Launching Poison Inception Subroutine..."
node qa/scripts/repro_zombie_failure.js

Write-Host "[MASTER] 3. Awaiting FullScreen Offer rendered on device (approx 10s)..."
Start-Sleep -Seconds 10

# CAPTURE BASELINE SCREENSHOT OF ARRIVAL
adb -s $Device shell screencap -p /sdcard/zombie_arrival.png
adb -s $Device pull /sdcard/zombie_arrival.png "qa_forensics/zombie_arrival.png" | Out-Null

Write-Host "[MASTER] 4. Executing Dynamic UI Action Selector (Tap Accept)..."
# Standard coordinates for Accept on this hardware derived from earlier UI captures: Center X=360, Y=1100 approx
# We'll perform reliable injection tap:
adb -s $Device shell input tap 360 1250
Write-Host "[MASTER] Tap submitted. Waiting for backend failure network roundtrip..."
Start-Sleep -Seconds 8 # Allow SnackBar to appear

Write-Host "[MASTER] 5. CAPTURING POST-FAILURE FORENSIC EVIDENCE SNAPSHOT 1..."
# Snapshot Activity, Notification, Screen
adb -s $Device shell screencap -p /sdcard/zombie_failure_1.png
adb -s $Device pull /sdcard/zombie_failure_1.png "qa_forensics/zombie_failure_1.png" | Out-Null
adb -s $Device shell dumpsys activity top > qa_forensics/zombie_activity_t1.txt
adb -s $Device shell dumpsys notification --summary > qa_forensics/zombie_notif_t1.txt

Write-Host "[MASTER] 6. WAITING 30 SECONDS (PASSIVE ZOMBIE MONITORING)..."
Start-Sleep -Seconds 30

Write-Host "[MASTER] 7. CAPTURING FINAL POST-OBSERVATION FORENSIC SNAPSHOT 2..."
adb -s $Device shell screencap -p /sdcard/zombie_failure_final.png
adb -s $Device pull /sdcard/zombie_failure_final.png "qa_forensics/zombie_failure_final.png" | Out-Null
adb -s $Device shell dumpsys activity top > qa_forensics/zombie_activity_final.txt
adb -s $Device shell dumpsys window windows | Select-String "mCurrentFocus" > qa_forensics/zombie_focus_final.txt

Write-Host "[MASTER] 8. EXTRACTING RUNTIME LOG TRACES..."
adb -s $Device logcat -d -v time | Select-String -Pattern "flutter|acceptOffer|Exception|SnackBar" > qa_forensics/zombie_logcat.txt

Write-Host "[MASTER] COMPLETED. Forensic evidence secured in local qa_forensics folder."
