node qa/scripts/cleanup_active_orders.js
Start-Sleep -Seconds 2
adb -s R83Y20PC4EN shell input keyevent 224
Start-Sleep -Seconds 1

Write-Host "[PHASE 4.5] Spawning background forensic monitor..."
$job = Start-Job -ScriptBlock {
    Set-Location "c:\Users\hp\Music\wawapp-ai"
    powershell -File qa/scripts/monitor_phase_4_5.ps1 -Device "R83Y20PC4EN" -DurationSeconds 60
}

Write-Host "[PHASE 4.5] Firing Ultimate GPS Order Cannon..."
node qa/scripts/submit_order.js "PHASE_4_5_INTEGRITY"

Write-Host "[PHASE 4.5] Waiting 60 seconds for lifecycle capture..."
Wait-Job $job | Out-Null
Receive-Job $job
Write-Host "[PHASE 4.5] ORCHESTRATION COMPLETE. Forensic evidence safe in local qa_forensics folder."
