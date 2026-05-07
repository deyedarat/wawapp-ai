# ============================================================================
# WawApp QA - Release Gate (Master Orchestrator)
# ============================================================================
# Runs all production gates sequentially.
# Gate approval depends ONLY on test verdicts from PASS_FAIL.txt artifacts.
#
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
. "$PSScriptRoot\..\scripts\lib\verdict.ps1"

Write-QA-Banner "WawApp Release Gate"

# ============================================================================
# GATE REGISTRY
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
    Write-Host "========================================================" -ForegroundColor DarkYellow
    Write-QA-Step "Gate: $($gate.Name)"
    Write-Host "========================================================" -ForegroundColor DarkYellow

    $gateStart = Get-Date
    $runtimeStatus = "RUNTIME_PASS"
    $testStatus = "TEST_PASS"
    $verdict = "PASSED"
    $reason = ""

    try {
        & $gate.Script
        $code = $LASTEXITCODE
        if ($null -eq $code) { $code = 0 }
        if ($code -ne 0) {
            $runtimeStatus = "RUNTIME_PASS"
            $testStatus = "TEST_FAIL"
            $verdict = "BLOCKED"
            $reason = "Gate test verdict: FAIL exit code $code"
        }
    } catch {
        $runtimeStatus = "RUNTIME_FAIL"
        $testStatus = "TEST_FAIL"
        $verdict = "BLOCKED"
        $reason = "Runtime exception: $_"
    }

    $gateDuration = [math]::Round(((Get-Date) - $gateStart).TotalSeconds, 1)

    $gateResults += @{
        Name          = $gate.Name
        Verdict       = $verdict
        RuntimeStatus = $runtimeStatus
        TestStatus    = $testStatus
        Duration      = $gateDuration
        Reason        = $reason
    }

    $durLabel = "${gateDuration}s"
    if ($verdict -eq "PASSED") {
        Write-QA-Pass "Gate $($gate.Name): PASSED [$runtimeStatus | $testStatus] $durLabel"
    } else {
        Write-QA-Fail "Gate $($gate.Name): BLOCKED [$runtimeStatus | $testStatus] $durLabel"
        if (-not $blockingGate) { $blockingGate = $gate.Name }
        if ($StopOnFailure) {
            Write-QA-Warn "StopOnFailure - skipping remaining gates"
            break
        }
    }
}

# ============================================================================
# VERDICT
# ============================================================================
$releaseEnd = Get-Date
$totalDuration = [math]::Round(($releaseEnd - $releaseStart).TotalSeconds, 1)
$passedGates = @($gateResults | Where-Object { $_.Verdict -eq "PASSED" }).Count
$blockedGates = @($gateResults | Where-Object { $_.Verdict -eq "BLOCKED" }).Count
$releaseVerdict = if ($blockedGates -eq 0) { "APPROVED" } else { "BLOCKED" }

# ============================================================================
# REPORT
# ============================================================================
$reportsDir = [System.IO.Path]::GetFullPath("$PSScriptRoot\..\..\qa\reports")
New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null

$reportTimestamp = Get-QA-Timestamp
$reportFile = Join-Path $reportsDir "release_gate_$reportTimestamp.md"

$gateRows = ($gateResults | ForEach-Object {
    $icon = if ($_.Verdict -eq "PASSED") { "PASS" } else { "BLOCK" }
    "| $($_.Name) | $icon $($_.Verdict) | $($_.RuntimeStatus) | $($_.TestStatus) | $($_.Duration)s | $($_.Reason) |"
}) -join "`n"

$blockLabel = if ($blockingGate) { $blockingGate } else { "none" }

$report = @"
# Release Gate Report

## Decision

| Field | Value |
|-------|-------|
| Verdict | **$releaseVerdict** |
| Timestamp | $reportTimestamp |
| Total duration | ${totalDuration}s |
| Blocking gate | $blockLabel |

## Gate Results

| Gate | Verdict | Runtime | Test | Duration | Reason |
|------|---------|---------|------|----------|--------|
$gateRows

## Classification Legend

| Classification | Meaning |
|----------------|---------|
| RUNTIME_PASS | Script executed without crash/exception |
| RUNTIME_FAIL | Script crashed, threw, or timed out |
| TEST_PASS | PASS_FAIL.txt contains VERDICT: PASS |
| TEST_FAIL | PASS_FAIL.txt contains VERDICT: FAIL or missing/malformed |
| GATE_BLOCKED | Release cannot proceed due to TEST_FAIL |

## Key Principle

A script can execute successfully RUNTIME_PASS but still FAIL the test.
Gate approval depends ONLY on test verdicts from PASS_FAIL.txt artifacts.

## Summary

| Metric | Value |
|--------|-------|
| Gates passed | $passedGates / $($gateResults.Count) |
| Gates blocked | $blockedGates |
| Total duration | ${totalDuration}s |
| StopOnFailure | $StopOnFailure |

## Release Criteria

- All gates must have TEST_PASS for release approval
- Any single TEST_FAIL blocks the release GATE_BLOCKED
- RUNTIME_PASS alone does NOT constitute gate approval
- Missing or malformed PASS_FAIL.txt = TEST_FAIL
"@

$report | Out-File $reportFile -Encoding utf8
Write-QA-Info "Report: $reportFile"

# ============================================================================
# FINAL OUTPUT
# ============================================================================
Write-Host ""
Write-Host "========================================================" -ForegroundColor Magenta
if ($releaseVerdict -eq "APPROVED") {
    Write-Host "  RELEASE: APPROVED" -ForegroundColor Green
} else {
    Write-Host "  RELEASE: BLOCKED" -ForegroundColor Red
    Write-Host "  Blocking gate: $blockingGate" -ForegroundColor Red
}
$totalLabel = "${totalDuration}s"
Write-Host "  Gates: $passedGates passed, $blockedGates blocked" -ForegroundColor Gray
Write-Host "  Duration: $totalLabel" -ForegroundColor Gray
Write-Host "  Report: $reportFile" -ForegroundColor Gray
Write-Host "========================================================" -ForegroundColor Magenta
Write-Host ""

if ($blockedGates -gt 0) { exit 1 } else { exit 0 }
