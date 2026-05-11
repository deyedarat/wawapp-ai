Param(
    [string]$Device = "R83Y20PC4EN"
)

Write-Host "`n🚀 STARTING DETURMINISTIC RESURRECTION TEST"

# 1. ENSURE CLEAN & ONLINE
adb -s $Device shell am force-stop com.wawapp.driver
node qa/scripts/reproduce_resurrection.js cleanup | Out-Null
node qa/scripts/cleanup_stale_offers.js | Out-Null
node qa/scripts/force_driver_online.js | Out-Null

# 2. LAUNCH AND NAVIGATE TO NEARBY
Write-Host "[TEST] Launching App and Navigating to Nearby Screen..."
adb -s $Device shell monkey -p com.wawapp.driver -c android.intent.category.LAUNCHER 1 | Out-Null
Start-Sleep -Seconds 12

# Tap "الطلبات القريبة" (Nearby Requests) - Bounds approx [375,532][690,776] center: 532, 650
adb -s $Device shell input tap 532 650
Start-Sleep -Seconds 5
Write-Host "[TEST] Expected on Nearby Screen."

# 3. INJECT OFFER
Write-Host "[TEST] Injecting active offer..."
node qa/scripts/reproduce_resurrection.js inject

# Wait for it to populate the screen
Start-Sleep -Seconds 8

# 4. FORCE STOP WHILE RENDERING
Write-Host '[TEST] 💥 FATAL INTERRUPT - Force Stopping App while offer is cached...'
adb -s $Device shell am force-stop com.wawapp.driver
Start-Sleep -Seconds 2

# 5. TERMINATE ON BACKEND WHILE APP IS DEAD
Write-Host '[TEST] 💀 TERMINATING OFFER ON BACKEND WHILE APP IS DEAD...'
node qa/scripts/reproduce_resurrection.js terminate | Out-Null
Start-Sleep -Seconds 2

# 6. REOPEN AND ARM HIGH FREQUENCY SAMPLER
Write-Host '[TEST] 🔄 Relaunching App... Sampling trap armed!'
adb -s $Device shell monkey -p com.wawapp.driver -c android.intent.category.LAUNCHER 1 | Out-Null

# We need to reach the Nearby Screen again to see the cache emission
Start-Sleep -Seconds 10
Write-Host '[TEST] Navigating back to Nearby Screen and activating HIGH-FREQ SAMPLER...'
adb -s $Device shell input tap 532 650

# RUN SAMPLER (Executes node script synchronously until match or timeout)
node qa/scripts/ui_sampler.js

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n🏁 SCENARIO COMPLETE. ✅ DETECTED RESURRECTION!"
} else {
    Write-Host "`n🏁 SCENARIO COMPLETE. ❌ NO RESURRECTION DETECTED (Clean or too slow)."
}

