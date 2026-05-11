# qa/run_release_certification.ps1
#
# Production release gate — single command, definitive verdict.
# Executes ALL core + ALL reliability + SELECTED torture scenarios.
#
# PASS criteria:
#   - all invariants respected
#   - no regressions on known bugs
#   - SLA thresholds met
#   - zero zombie authority
#   - zero cache resurrection
#   - zero duplicate accept
#
# FAIL criteria:
#   - any invariant violation
#   - any deterministic scenario failure
#
# Usage:
#   powershell -File qa/run_release_certification.ps1 [-BuildVersion "1.2.3"]

param(
    [string] $BuildVersion  = "unknown",
    [string] $DeviceSerial  = "R83Y20PC4EN"
)

$ErrorActionPreference = "Stop"
Set-Location "$PSScriptRoot/.."

$CertStart = Get-Date
$RunId     = "release_$($CertStart.ToString('yyyyMMdd_HHmmss'))"

Write-Host ""
Write-Host "####################################################"
Write-Host "#  WawApp PRODUCTION RELEASE CERTIFICATION GATE"
Write-Host "#  Build      : $BuildVersion"
Write-Host "#  Run ID     : $RunId"
Write-Host "#  Started    : $($CertStart.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Host "####################################################"
Write-Host ""

# ── Pre-flight device check ───────────────────────────────────────────────────
$found = adb devices 2>&1 | Select-String $DeviceSerial
if (-not $found) {
    Write-Error "RELEASE CERTIFICATION ABORTED: Driver device $DeviceSerial not connected."
    exit 2
}
Write-Host "[PREFLIGHT] Driver device connected."

# ── Pre-flight backend state ──────────────────────────────────────────────────
Write-Host "[PREFLIGHT] Cleaning backend state..."
node -e "require('./qa/backend/backend').cleanupOrders().then(() => process.exit(0))"
Write-Host "[PREFLIGHT] Backend state clean."

# ── Wake device ───────────────────────────────────────────────────────────────
adb -s $DeviceSerial shell input keyevent KEYCODE_WAKEUP 2>$null
adb -s $DeviceSerial shell input swipe 360 800 360 400 300 2>$null

# ── Execute all scenarios (core + reliability + selected torture) ─────────────
Write-Host "[CERT] Starting full certification run..."
node qa/orchestrator/orchestrate.js --suite all
$ExitCode = $LASTEXITCODE

$CertEnd     = Get-Date
$DurationSec = [int]($CertEnd - $CertStart).TotalSeconds
$Verdict     = if ($ExitCode -eq 0) { "CERTIFIED" } else { "FAILED" }

Write-Host ""
Write-Host "####################################################"
Write-Host "#  RELEASE CERTIFICATION VERDICT: $Verdict"
Write-Host "#  Build      : $BuildVersion"
Write-Host "#  Duration   : $DurationSec s"
Write-Host "#  Completed  : $($CertEnd.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Host "####################################################"

# ── Write certification record ────────────────────────────────────────────────
$record = @{
    runId        = $RunId
    buildVersion = $BuildVersion
    verdict      = $Verdict
    passed       = ($ExitCode -eq 0)
    durationSecs = $DurationSec
    timestamp    = $CertEnd.ToString("o")
    deviceSerial = $DeviceSerial
} | ConvertTo-Json -Compress

New-Item -ItemType Directory -Force -Path "qa/reports" | Out-Null
Add-Content -Path "qa/reports/release_certifications.jsonl" -Value $record

Write-Host "[CERT] Record appended to qa/reports/release_certifications.jsonl"

# ── Operational Invariant Check Summary ──────────────────────────────────────
Write-Host ""
Write-Host "Invariant Certification Status:"
$invariants = @(
    "Dead offers never resurrect               [stale_cache_resurrection]",
    "Fullscreen authority never zombifies       [zombie_fullscreen_protection]",
    "Duplicate accept is impossible             [duplicate_accept_guard]",
    "Silent suppression cannot persist          [stale_active_trip_recovery]",
    "Cache snapshots cannot create authority    [stale_cache_resurrection]",
    "Notification authority is singular         [rapid_sequential_orders]",
    "FCM wake latency within SLA               [dispatch_accept_success]",
    "Driver cannot be silently starved          [stale_active_trip_recovery]",
    "Terminal states revoke actionable UI       [dispatch_timeout]",
    "All lifecycle paths terminate cleanly      [process_kill_during_offer]"
)

$status = if ($ExitCode -eq 0) { "PASS" } else { "FAIL (see report)" }
$invariants | ForEach-Object { Write-Host "  [$status] $_" }

exit $ExitCode
