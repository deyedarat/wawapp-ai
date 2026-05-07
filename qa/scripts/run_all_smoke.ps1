# ============================================================================
# WawApp QA — Unified Smoke Runner
# ============================================================================
# Usage:
#   .\qa\scripts\run_all_smoke.ps1
#   .\qa\scripts\run_all_smoke.ps1 -Include "killed_state"
#   .\qa\scripts\run_all_smoke.ps1 -Exclude "spam"
#   .\qa\scripts\run_all_smoke.ps1 -StopOnFailure
# ============================================================================

param(
    [string]$Include = "",
    [string]$Exclude = "",
    [switch]$StopOnFailure
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\lib\common.ps1"

# ============================================================================
# DISCOVER SCRIPTS
# ============================================================================
function Get-SmokeScripts {
    $all = Get-ChildItem -Path $PSScriptRoot -Filter "run_*.ps1" |
        Where-Object { $_.Name -ne "run_all_smoke.ps1" } |
        Sort-Object Name

    if ($Include) {
        $all = $all | Where-Object { $_.Name -match $Include }
    }
    if ($Exclude) {
        $all = $all | Where-Object { $_.Name -notmatch $Exclude }
    }
    return $all
}

# ============================================================================
# MAIN
# ============================================================================
Write-QA-Banner "WawApp QA — Unified Smoke Runner"

$scripts = Get-SmokeScripts
if ($scripts.Count -eq 0) {
    Write-QA-Fail "No smoke scripts found (Include='$Include', Exclude='$Exclude')"
    exit 1
}

Write-QA-Info "Found $($scripts.Count) script(s):"
$scripts | ForEach-Object { Write-Host "  • $($_.Name)" -ForegroundColor DarkGray }
Write-Host ""

# --- Pre-flight ---
Write-QA-Step "Pre-flight check"
Assert-AdbAvailable
$serial = Get-QA-Device
Write-Host ""

# --- Execute ---
$results = @()
$suiteStart = Get-Date
$exitCode = 0

foreach ($script in $scripts) {
    $scenarioName = $script.BaseName -replace "^run_", ""
    Write-Host "───────────────────────────────────────────────────────" -ForegroundColor DarkCyan
    Write-QA-Step "Running: $($script.Name)"
    Write-Host ""

    $runStart = Get-Date

    try {
        & $script.FullName
        $runExit = $LASTEXITCODE
        if ($null -eq $runExit) { $runExit = 0 }
    } catch {
        $runExit = 1
        Write-QA-Fail "Script threw exception: $_"
    }

    $runEnd = Get-Date
    $duration = [math]::Round(($runEnd - $runStart).TotalSeconds, 1)

    # Determine result from latest artifact PASS_FAIL.txt
    $latestArtifact = Get-ChildItem -Path (Join-Path $PSScriptRoot "..\..\qa\artifacts") -Directory |
        Where-Object { $_.Name -match "^$($scenarioName.ToUpper().Split('_')[0])|^$($scenarioName.ToUpper())" } |
        Sort-Object CreationTime -Descending |
        Select-Object -First 1

    $verdict = "UNKNOWN"
    $reason = ""
    $artifactPath = ""

    if ($latestArtifact) {
        $artifactPath = $latestArtifact.FullName
        $passFile = Join-Path $latestArtifact.FullName "PASS_FAIL.txt"
        if (Test-Path $passFile) {
            $content = Get-Content $passFile -Raw
            if ($content -match "VERDICT:\s*(PASS|FAIL)") { $verdict = $Matches[1] }
            if ($content -match "REASONS:\s*(.+)") { $reason = $Matches[1].Trim() }
        }
    }

    if ($verdict -eq "UNKNOWN" -and $runExit -ne 0) { $verdict = "FAIL"; $reason = "Non-zero exit code: $runExit" }
    if ($verdict -eq "UNKNOWN" -and $runExit -eq 0) { $verdict = "PASS" }

    if ($verdict -eq "FAIL") { $exitCode = 1 }

    $results += @{
        Name      = $scenarioName
        Script    = $script.Name
        Verdict   = $verdict
        Duration  = $duration
        Reason    = $reason
        Artifacts = $artifactPath
    }

    Write-Host ""
    if ($verdict -eq "PASS") { Write-QA-Pass "$scenarioName completed (${duration}s)" }
    else { Write-QA-Fail "$scenarioName FAILED (${duration}s): $reason" }

    if ($StopOnFailure -and $verdict -eq "FAIL") {
        Write-QA-Warn "StopOnFailure triggered — aborting remaining scripts"
        break
    }
}

# ============================================================================
# REPORT
# ============================================================================
$suiteEnd = Get-Date
$totalDuration = [math]::Round(($suiteEnd - $suiteStart).TotalSeconds, 1)
$passed = ($results | Where-Object { $_.Verdict -eq "PASS" }).Count
$failed = ($results | Where-Object { $_.Verdict -eq "FAIL" }).Count
$unknown = ($results | Where-Object { $_.Verdict -eq "UNKNOWN" }).Count

# Ensure reports directory exists
$reportsDir = Join-Path $PSScriptRoot "..\..\qa\reports"
$reportsDir = [System.IO.Path]::GetFullPath($reportsDir)
New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null

$reportTimestamp = Get-QA-Timestamp
$reportFile = Join-Path $reportsDir "smoke_$reportTimestamp.md"

$resultRows = ($results | ForEach-Object {
    $icon = if ($_.Verdict -eq "PASS") { "✅" } elseif ($_.Verdict -eq "FAIL") { "❌" } else { "⚠️" }
    "| $($_.Name) | $icon $($_.Verdict) | $($_.Duration)s | $($_.Reason) |"
}) -join "`n"

$report = @"
# Smoke Test Report

| Field | Value |
|-------|-------|
| Timestamp | $reportTimestamp |
| Device | $serial |
| Scripts run | $($results.Count) |
| Total duration | ${totalDuration}s |

## Results

| Scenario | Verdict | Duration | Failure Reason |
|----------|---------|----------|----------------|
$resultRows

## Summary

| Metric | Count |
|--------|-------|
| ✅ Passed | $passed |
| ❌ Failed | $failed |
| ⚠️ Unknown | $unknown |
| Total | $($results.Count) |
| Duration | ${totalDuration}s |

## Artifact Directories

$(($results | ForEach-Object { "- **$($_.Name)**: ``$($_.Artifacts)``" }) -join "`n")

## Configuration

| Parameter | Value |
|-----------|-------|
| Include filter | $(if ($Include) { $Include } else { "(none)" }) |
| Exclude filter | $(if ($Exclude) { $Exclude } else { "(none)" }) |
| StopOnFailure | $StopOnFailure |
"@

$report | Out-File $reportFile -Encoding utf8
Write-QA-Info "Report → $reportFile"

# ============================================================================
# FINAL OUTPUT
# ============================================================================
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host "  SMOKE SUITE COMPLETE" -ForegroundColor Magenta
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host "  Passed: $passed" -ForegroundColor Green
if ($failed -gt 0) { Write-Host "  Failed: $failed" -ForegroundColor Red }
if ($unknown -gt 0) { Write-Host "  Unknown: $unknown" -ForegroundColor Yellow }
Write-Host "  Duration: ${totalDuration}s" -ForegroundColor Gray
Write-Host "  Report: $reportFile" -ForegroundColor Gray
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host ""

exit $exitCode
