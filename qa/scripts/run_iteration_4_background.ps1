Write-Host "[INTEGRITY] Ensuring app is active and primed..."
adb -s R83Y20PC4EN shell monkey -p com.wawapp.driver -c android.intent.category.LAUNCHER 1 | Out-Null
Start-Sleep -Seconds 10 # Let it fully boot

Write-Host "[INTEGRITY] Sending app to absolute background..."
adb -s R83Y20PC4EN shell input keyevent 3 # Home button
Start-Sleep -Seconds 2
adb -s R83Y20PC4EN shell input keyevent 3 # Home again just in case

Write-Host "[INTEGRITY] WAITING 30 SECONDS TO FORCE PROCESSLIFECYCLE TIMEOUT..."
Start-Sleep -Seconds 30 # Crucial for ProcessLifecycle to transition to BACKGROUND

Write-Host "[INTEGRITY] Starting live monitor..."
$job = Start-Job -ScriptBlock {
    Set-Location "c:\Users\hp\Music\wawapp-ai"
    powershell -File qa/scripts/monitor_phase_4_5.ps1 -Device "R83Y20PC4EN" -DurationSeconds 45
}

Write-Host "[INTEGRITY] Firing Background cannon..."
node qa/scripts/submit_order.js "ITERATION_4_BACKGROUND"

Wait-Job $job | Out-Null
Receive-Job $job
Write-Host "[INTEGRITY] COMPLETE. Fetching final conclusive logs."
