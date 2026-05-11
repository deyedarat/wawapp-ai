Param(
    [string]$Device = "R83Y20PC4EN"
)

function Reset-Environment {
    Write-Host "[RESET] Commencing supreme state reset between scenarios..."
    node qa/scripts/cleanup_active_orders.js | Out-Null
    node qa/scripts/cleanup_stale_offers.js | Out-Null
    node qa/scripts/force_driver_online.js | Out-Null
    adb -s $Device shell monkey -p com.wawapp.driver -c android.intent.category.LAUNCHER 1 | Out-Null
    Start-Sleep -Seconds 5
    adb -s $Device logcat -c
    Write-Host "[RESET] Environment PRISTINE. Ready for next phase."
}

Write-Host "[MASTER_VERIFY] 🚀 STARTING ZOMBIE MITIGATION SUITE"
Reset-Environment

# ---------------------------------------------------------------------
# SCENARIO 1: Double Tap Spam Guard
# ---------------------------------------------------------------------
Write-Host "`n`n[SCENARIO 1] Testing Rapid Double-Tap Spam Guard..."
node qa/scripts/submit_order.js "S1_DOUBLE_TAP" | Out-Null
Write-Host "[SCENARIO 1] Waiting 12s for rendering..."
Start-Sleep -Seconds 12
Write-Host "[SCENARIO 1] Firing rapid dual inputs (100ms separation)..."
adb -s $Device shell input tap 360 1250; adb -s $Device shell input tap 360 1250
Start-Sleep -Seconds 10
Write-Host "[SCENARIO 1] Snapshotting Logcat for double firing protection..."
adb -s $Device logcat -d | Select-String "acceptOfferV2" > qa_forensics/s1_logcat.txt
Write-Host "[SCENARIO 1] COMPLETE."

# RESET BEFORE NEXT
Reset-Environment

# ---------------------------------------------------------------------
# SCENARIO 2: Transient Retry (Click once, fails, verify screen remains)
# ---------------------------------------------------------------------
Write-Host "`n`n[SCENARIO 2] Testing Transient Retry (Recoverable Fault)..."
# Inject wave + poison (GODMODE)
node qa/scripts/zombie_mitigation_v2/poison_director.js "TRANSIENT" | Out-Null
Start-Sleep -Seconds 5
Write-Host "[SCENARIO 2] Triggering Accept Tap (Attempt 1)..."
adb -s $Device shell input tap 360 1250
Start-Sleep -Seconds 6
Write-Host "[SCENARIO 2] Capturing mid-failure persistence (EXPECT ALIVE)..."
adb -s $Device shell uiautomator dump /sdcard/s2_dump.xml | Out-Null
adb -s $Device pull /sdcard/s2_dump.xml qa_forensics/s2_dump.xml | Out-Null
Write-Host "[SCENARIO 2] COMPLETE."

# ---------------------------------------------------------------------
# SCENARIO 3: Max Retry Terminal Logic (Hit 2 more times -> must dismiss)
# ---------------------------------------------------------------------
Write-Host "`n`n[SCENARIO 3] Testing Max Retry Exceeded (Fatal Dismissal)..."
Write-Host "[SCENARIO 3] Triggering Attempt 2..."
adb -s $Device shell input tap 360 1250
Start-Sleep -Seconds 6
Write-Host "[SCENARIO 3] Triggering Attempt 3 (SHOULD CROSS LIMIT & DISMISS)..."
adb -s $Device shell input tap 360 1250
Start-Sleep -Seconds 10
Write-Host "[SCENARIO 3] Verifying screen auto-dismissed to Dashboard..."
adb -s $Device shell uiautomator dump /sdcard/s3_dump.xml | Out-Null
adb -s $Device pull /sdcard/s3_dump.xml qa_forensics/s3_dump.xml | Out-Null
Write-Host "[SCENARIO 3] COMPLETE."

# RESET BEFORE NEXT
Reset-Environment

# ---------------------------------------------------------------------
# SCENARIO 4: Fatal Immediate Response (Already Taken -> Instant Dismiss)
# ---------------------------------------------------------------------
Write-Host "`n`n[SCENARIO 4] Testing Fatal Already-Taken (Instant Logic)..."
node qa/scripts/zombie_mitigation_v2/poison_director.js "FATAL_ALREADY_TAKEN" | Out-Null
Start-Sleep -Seconds 5
Write-Host "[SCENARIO 4] Firing Single Accept on Poisoned Order..."
adb -s $Device shell input tap 360 1250
Start-Sleep -Seconds 10
Write-Host "[SCENARIO 4] Verifying Instant _safeDismiss() fired..."
adb -s $Device shell uiautomator dump /sdcard/s4_dump.xml | Out-Null
adb -s $Device pull /sdcard/s4_dump.xml qa_forensics/s4_dump.xml | Out-Null
Write-Host "[SCENARIO 4] COMPLETE."

# RESET BEFORE NEXT
Reset-Environment

# ---------------------------------------------------------------------
# SCENARIO 5: Backend Cancellation Event (Client Cancel -> Instant Dismiss)
# ---------------------------------------------------------------------
Write-Host "`n`n[SCENARIO 5] Testing Backend Cancellation Active Monitor..."
node qa/scripts/zombie_mitigation_v2/poison_director.js "BACKEND_CANCEL" | Out-Null
Start-Sleep -Seconds 8 # Let Firestore Sync
Write-Host "[SCENARIO 5] Verifying Screen Cleanly Exited without user tap..."
adb -s $Device shell uiautomator dump /sdcard/s5_dump.xml | Out-Null
adb -s $Device pull /sdcard/s5_dump.xml qa_forensics/s5_dump.xml | Out-Null
Write-Host "[SCENARIO 5] COMPLETE."

Write-Host "`n`n🏆 [ALL SCENARIOS EXECUTED]. Analyzing forensics..."

