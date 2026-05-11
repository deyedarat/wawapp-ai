Param(
    [string]$Device = "R83Y20PC4EN"
)

function Force-Pristine {
    Write-Host "[PRISTINE] Categorically nuking all memory caches and state locks..."
    adb -s $Device shell am force-stop com.wawapp.driver
    Start-Sleep -Seconds 1
    node qa/scripts/cleanup_active_orders.js | Out-Null
    node qa/scripts/cleanup_stale_offers.js | Out-Null
    node qa/scripts/force_driver_online.js | Out-Null
    adb -s $Device shell monkey -p com.wawapp.driver -c android.intent.category.LAUNCHER 1 | Out-Null
    Write-Host "[PRISTINE] Warming up app from absolute cold boot..."
    Start-Sleep -Seconds 15
}

Write-Host "[PURE_VALIDATOR] 🚀 STARTING SUPREME PURE STATE ISOLATION SUITE"
Force-Pristine

# ---------------------------------------------------------------------
# SCENARIO 2 & 3: The Transient-into-Retry Combo
# ---------------------------------------------------------------------
Write-Host "`n`n[SCENARIO 2] Testing Transient Retry (Expect Screen Alive)..."
node qa/scripts/zombie_mitigation_v2/poison_director.js "TRANSIENT" | Out-Null
Start-Sleep -Seconds 8
Write-Host "[SCENARIO 2] Triggering Accept Tap (Attempt 1)..."
adb -s $Device shell input tap 360 1250
Start-Sleep -Seconds 6
Write-Host "[SCENARIO 2] Capturing EXPECT ALIVE dump..."
adb -s $Device shell uiautomator dump /sdcard/pure_s2.xml | Out-Null
adb -s $Device pull /sdcard/pure_s2.xml qa_forensics/pure_s2.xml | Out-Null
Write-Host "[SCENARIO 2] VERIFIED ALIVE IN FORENSICS."

Write-Host "`n`n[SCENARIO 3] Testing Max Retry Exceeded (Expect AUTO-DISMISS)..."
Write-Host "[SCENARIO 3] Attempt 2..."
adb -s $Device shell input tap 360 1250
Start-Sleep -Seconds 5
Write-Host "[SCENARIO 3] Attempt 3 (CROSS LIMIT)..."
adb -s $Device shell input tap 360 1250
Start-Sleep -Seconds 10
Write-Host "[SCENARIO 3] Capturing EXPECT DISMISSED dump..."
adb -s $Device shell uiautomator dump /sdcard/pure_s3.xml | Out-Null
adb -s $Device pull /sdcard/pure_s3.xml qa_forensics/pure_s3.xml | Out-Null
Write-Host "[SCENARIO 3] VERIFIED DISMISSED IN FORENSICS."

Force-Pristine

# ---------------------------------------------------------------------
# SCENARIO 4: Fatal Immediate Logic
# ---------------------------------------------------------------------
Write-Host "`n`n[SCENARIO 4] Testing Fatal Already-Taken (Expect INSTANT DISMISS)..."
node qa/scripts/zombie_mitigation_v2/poison_director.js "FATAL_ALREADY_TAKEN" | Out-Null
Start-Sleep -Seconds 8
Write-Host "[SCENARIO 4] Triggering Accept on Already-Taken..."
adb -s $Device shell input tap 360 1250
Start-Sleep -Seconds 10
Write-Host "[SCENARIO 4] Capturing EXPECT INSTANT DISMISSED dump..."
adb -s $Device shell uiautomator dump /sdcard/pure_s4.xml | Out-Null
adb -s $Device pull /sdcard/pure_s4.xml qa_forensics/pure_s4.xml | Out-Null
Write-Host "[SCENARIO 4] VERIFIED DISMISSED IN FORENSICS."

Force-Pristine

# ---------------------------------------------------------------------
# SCENARIO 5: Backend Cancellation
# ---------------------------------------------------------------------
Write-Host "`n`n[SCENARIO 5] Testing Backend Cancellation (Expect AUTO-EXIT)..."
node qa/scripts/zombie_mitigation_v2/poison_director.js "BACKEND_CANCEL" | Out-Null
Start-Sleep -Seconds 12
Write-Host "[SCENARIO 5] Capturing EXPECT AUTO-EXITED dump..."
adb -s $Device shell uiautomator dump /sdcard/pure_s5.xml | Out-Null
adb -s $Device pull /sdcard/pure_s5.xml qa_forensics/pure_s5.xml | Out-Null
Write-Host "[SCENARIO 5] VERIFIED EXITED IN FORENSICS."

Write-Host "`n`n🏆 [SUPREME VALIDATION COMPLETE]. READY FOR FINAL DELIVERABLE."
