# ============================================================================
# WawApp QA — Release Gate (Master Orchestrator)
# ============================================================================
# Runs all production gates sequentially.
# Exit 0 = release approved, Exit 1 = release blocked
#
# Usage:
#   .\qa\production_gates\release_gate.ps1
#   .\qa\production_gates\release_gate.ps1 -StopOnFailure
# ============================================================================

param(
    [switch]$StopOnFailure
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\scripts\lib\common.ps1"

Write-QA-Banner "WawApp Release Gate"

# ============================================================================
# GATE REGISTRY (order matters)
# ============================================================================
$gates = @(
    @{ Name = "NOTIFICATIONS"; Script = "$PSScriptRoot\notifications_gate.ps1" }
    @{ Name = "AUTH";          Script = "$PSScriptRoot\auth_gate.ps1" }
    @{ Name = "DISPATCH";      Script = "$PSScriptRoot\dispatch_gate.ps1" }
)

# ============================================================================
# EXECUTE GATES
# ============================================================================
$gateResults = @()
$releaseStart = Get-Date
$blockingGate = ""

foreach ($gate in $gates) {
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkYellow
    Write-QA-Step "Gate: $($gate.Name)"
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkYellow

    $gateStart = Get-Date
    $verdict = "PASSED"
    $reason = ""

    try {
        & $gate.Script
        $code = $LASTEXITCODE
        if ($null -eq $code) { $code = 0 }
        if ($code -ne 0) { $verdict = "BLOCKED"; $reason = "Gate returned exit code $code" }
    } catch {
        $verdict = "BLOCKED"; $reason = "$_"
    }

    $gateDuration = [math]::Round(((Get-Date) - $gateStart).TotalSeconds, 1)

    $gateResults += @{
        Name     = $gate.Name
        Verdict  = $verdict
        Duration = $gateDuration
        Reason   = $reason
    }

    if ($verdict -eq "PASSED") {
        Write-QA-Pass "Gate $($gate.Name): PASSED (${gateDuration}s)"
    } else {
        Write-QA-Fail "Gate $($gate.Name): BLOCKED (${gateDuration}s)"
        if (-not $blockingGate) { $blockingGate = $gate.Name }
        if ($StopOnFailure) {
            Write-QA-Warn "StopOnFailure — skipping remaining gates"
            break
        }
    }
}

# ============================================================================
# VERDICT
# ============================================================================
$releaseEnd = Get-Date
$totalDuration = [math]::Round(($releaseEnd - $releaseStart).TotalSeconds, 1)
$passedGates = ($gateResults | Where-Object { $_.Verdict -eq "PASSED" }).Count
$blockedGates = ($gateResults | Where-Object { $_.Verdict -eq "BLOCKED" }).Count
$releaseVerdict = if ($blockedGates -eq 0) { "APPROVED" } else { "BLOCKED" }

# ============================================================================
# REPORT
# ============================================================================
$reportsDir = [System.IO.Path]::GetFullPath("$PSScriptRoot\..\..\qa\reports")
New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null

$reportTimestamp = Get-QA-Timestamp
$reportFile = Join-Path $reportsDir "release_gate_$reportTimestamp.md"

$gateRows = ($gateResults | ForEach-Object {
    $icon = if ($_.Verdict -eq "PASSED") { "✅" } else { "🚫" }
    "| $($_.Name) | $icon $($_.Verdict) | $($_.Duration)s | $($_.Reason) |"
}) -join "`n"

$report = @"
# Release Gate Report

## Decision

| Field | Value |
|-------|-------|
| **Verdict** | **$releaseVerdict** |
| Timestamp | $reportTimestamp |
| Total duration | ${totalDuration}s |
| Blocking gate | $(if ($blockingGate) { $blockingGate } else { "—" }) |

## Gate Results

| Gate | Verdict | Duration | Reason |
|------|---------|----------|--------|
$gateRows

## Summary

| Metric | Value |
|--------|-------|
| Gates passed | $passedGates / $($gateResults.Count) |
| Gates blocked | $blockedGates |
| Total duration | ${totalDuration}s |
| StopOnFailure | $StopOnFailure |

## Release Criteria

- All gates must pass for release approval
- Any single gate failure blocks the release
- Notification gate is the highest-priority blocker

## Next Steps

$(if ($releaseVerdict -eq "APPROVED") {
"- ✅ All gates passed — release is approved
- Proceed with APK signing and Play Store upload"
} else {
"- 🚫 Release blocked by: **$blockingGate**
- Fix the failing tests before re-running
- Re-run: ``.\qa\production_gates\release_gate.ps1``"
})
"@

$report | Out-File $reportFile -Encoding utf8
Write-QA-Info "Report → $reportFile"

# ============================================================================
# FINAL OUTPUT
# ============================================================================
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Magenta
if ($releaseVerdict -eq "APPROVED") {
    Write-Host "  🟢 RELEASE: APPROVED" -ForegroundColor Green
} else {
    Write-Host "  🔴 RELEASE: BLOCKED" -ForegroundColor Red
    Write-Host "  Blocking gate: $blockingGate" -ForegroundColor Red
}
Write-Host "  Gates: $passedGates passed, $blockedGates blocked" -ForegroundColor Gray
Write-Host "  Duration: ${totalDuration}s" -ForegroundColor Gray
Write-Host "  Report: $reportFile" -ForegroundColor Gray
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host ""

if ($blockedGates -gt 0) { exit 1 } else { exit 0 }
