# qa/run_overnight_certification.ps1
#
# Runs the regression suite continuously for a configured duration.
# Designed for unattended overnight execution.
#
# Features:
#   - Loops until DurationHours elapsed or MaxRuns reached
#   - Isolates each run in a timestamped report directory
#   - Force-cleans device and backend state between runs
#   - ADB watchdog: reconnects if device disappears
#   - Screen wake before every run
#   - Auto-generates failure summary at the end
#
# Usage:
#   powershell -File qa/run_overnight_certification.ps1 -DurationHours 8
#   powershell -File qa/run_overnight_certification.ps1 -MaxRuns 20

param(
    [int]    $DurationHours  = 8,
    [int]    $MaxRuns        = 999,
    [string] $DeviceSerial   = "R83Y20PC4EN",
    [string] $Suite          = "regression"
)

$ErrorActionPreference = "Stop"
Set-Location "$PSScriptRoot/.."

$StartTime   = Get-Date
$DeadlineTs  = $StartTime.AddHours($DurationHours)
$RunCount    = 0
$PassCount   = 0
$FailCount   = 0
$FailureLog  = @()

New-Item -ItemType Directory -Force -Path "qa/reports"   | Out-Null
New-Item -ItemType Directory -Force -Path "qa/artifacts" | Out-Null

function Assert-DeviceConnected {
    param([string]$Serial)
    $found = adb devices 2>&1 | Select-String $Serial
    if (-not $found) {
        Write-Host "[WATCHDOG] Device $Serial not found. Waiting 10s and retrying..."
        Start-Sleep -Seconds 10
        $found = adb devices 2>&1 | Select-String $Serial
        if (-not $found) {
            Write-Error "[WATCHDOG] Device $Serial permanently lost. Aborting overnight run."
            exit 2
        }
    }
    return $true
}

function Wake-Device {
    param([string]$Serial)
    adb -s $Serial shell input keyevent KEYCODE_WAKEUP 2>$null
    adb -s $Serial shell input swipe 360 800 360 400 300 2>$null
    adb -s $Serial shell input keyevent 82 2>$null
}

function Clean-DeviceState {
    param([string]$Serial, [string]$Package)
    adb -s $Serial shell am force-stop $Package 2>$null
    adb -s $Serial shell cmd notification clear 2>$null
    adb -s $Serial logcat -c 2>$null
}

Write-Host "=================================================="
Write-Host "  WawApp OVERNIGHT CERTIFICATION"
Write-Host "  Suite      : $Suite"
Write-Host "  Duration   : $DurationHours hours"
Write-Host "  Max Runs   : $MaxRuns"
Write-Host "  Start      : $($StartTime.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Host "  Deadline   : $($DeadlineTs.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Host "=================================================="

while ((Get-Date) -lt $DeadlineTs -and $RunCount -lt $MaxRuns) {
    $RunCount++
    $RunStart = Get-Date
    Write-Host ""
    Write-Host ">>> RUN $RunCount  [$(($RunStart).ToString('HH:mm:ss'))]"
    Write-Host "    Remaining: $([int]($DeadlineTs - (Get-Date)).TotalMinutes)m"

    # ── Pre-run device health check ──────────────────────────────────────────
    Assert-DeviceConnected -Serial $DeviceSerial | Out-Null
    Wake-Device -Serial $DeviceSerial
    Clean-DeviceState -Serial $DeviceSerial -Package "com.wawapp.driver"

    # ── Pre-run backend cleanup ──────────────────────────────────────────────
    node -e "require('./qa/backend/backend').cleanupOrders().then(() => process.exit(0))" 2>&1 | Out-Null

    # ── Execute suite ────────────────────────────────────────────────────────
    node qa/orchestrator/orchestrate.js --suite $Suite
    $ExitCode = $LASTEXITCODE

    $Elapsed = (Get-Date) - $RunStart

    if ($ExitCode -eq 0) {
        $PassCount++
        Write-Host "    RESULT: PASS  ($('{0:F0}' -f $Elapsed.TotalSeconds)s)"
    } else {
        $FailCount++
        Write-Host "    RESULT: FAIL  ($('{0:F0}' -f $Elapsed.TotalSeconds)s)"
        $FailureLog += "Run $RunCount @ $($RunStart.ToString('HH:mm:ss'))"
    }

    # ── Post-run cooldown ────────────────────────────────────────────────────
    Start-Sleep -Seconds 15
}

# ── Final Summary ─────────────────────────────────────────────────────────────
$TotalSecs  = [int]((Get-Date) - $StartTime).TotalSeconds
$StabilityPct = if ($RunCount -gt 0) { [math]::Round(($PassCount / $RunCount) * 100, 1) } else { 0 }

Write-Host ""
Write-Host "=================================================="
Write-Host "  OVERNIGHT CERTIFICATION COMPLETE"
Write-Host "  Total Runs : $RunCount"
Write-Host "  Passed     : $PassCount"
Write-Host "  Failed     : $FailCount"
Write-Host "  Stability  : $StabilityPct%"
Write-Host "  Duration   : $TotalSecs s"
Write-Host "=================================================="

if ($FailureLog.Count -gt 0) {
    Write-Host "  FAILED RUNS:"
    $FailureLog | ForEach-Object { Write-Host "    - $_" }
}

# Append overnight summary to metrics file
$Summary = @{
    date          = (Get-Date).ToString("yyyy-MM-dd")
    suite         = $Suite
    totalRuns     = $RunCount
    passed        = $PassCount
    failed        = $FailCount
    stabilityPct  = $StabilityPct
    durationSecs  = $TotalSecs
    failedRuns    = $FailureLog
} | ConvertTo-Json -Compress

Add-Content -Path "qa/reports/overnight_history.jsonl" -Value $Summary

if ($FailCount -gt 0) { exit 1 } else { exit 0 }
