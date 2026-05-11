Param(
    [string]$Device = "R83Y20PC4EN"
)

Write-Host "STARTING DETERMINISTIC FORENSIC TRACE TRAP"

# Ensure clean
adb -s $Device shell am force-stop com.wawapp.driver
node qa/scripts/reproduce_resurrection.js cleanup | Out-Null

# CLEAR LOGS
Write-Host "[TEST] Clearing device logcat buffer..."
adb -s $Device logcat -c

# Inject
Write-Host "[TEST] Injecting unique offer for cache injection..."
node qa/scripts/reproduce_resurrection.js inject

# 1. Open App, let it cache it while online
Write-Host "[TEST] Opening App to seed the local cache..."
adb -s $Device shell monkey -p com.wawapp.driver -c android.intent.category.LAUNCHER 1 | Out-Null
Start-Sleep -Seconds 15
# Go to nearby
Write-Host "[TEST] Navigating to Nearby Screen to trigger Firestore Listener..."
adb -s $Device shell input tap 532 650
# Wait 10s for Firestore to definitely write to local persistence disk
Start-Sleep -Seconds 10

# 2. Force Stop (Offline Cache locks state)
Write-Host "[TEST] KILLING APP TO LOCK OFFLINE CACHE STATE..."
adb -s $Device shell am force-stop com.wawapp.driver
Start-Sleep -Seconds 3

# 3. Terminate
Write-Host "[TEST] TERMINATING OFFER ON BACKEND (SIMULATE ALREADY ACCEPTED)..."
node qa/scripts/reproduce_resurrection.js terminate | Out-Null
Start-Sleep -Seconds 2

# 4. Relaunch and observe startup hydration
Write-Host "[TEST] RELAUNCHING APP FOR COLD START HYDRATION FORENSICS..."
adb -s $Device shell monkey -p com.wawapp.driver -c android.intent.category.LAUNCHER 1 | Out-Null
Start-Sleep -Seconds 15

# Navigate to nearby to trigger re-emission
Write-Host "[TEST] Re-navigating to Nearby Screen to trigger cache re-hydrate..."
adb -s $Device shell input tap 532 650
Start-Sleep -Seconds 10

Write-Host "[TEST] EXPORTING DETERMINISTIC FORENSIC TRACES..."
# Pull full logcat filtered by our trace tag
adb -s $Device logcat -d | Select-String -Pattern "FORENSIC_TRACE" > qa_forensics/forensic_trace_results.txt

Write-Host "TRAP COMPLETE. READING FILE NOW"
Get-Content qa_forensics/forensic_trace_results.txt
