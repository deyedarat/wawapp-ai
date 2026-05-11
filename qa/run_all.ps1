# run_all.ps1
# WawApp Dispatch Reliability Certification Platform
# Full suite: core + reliability + torture scenarios
# One command executes the entire operational certification flow.
#
# Usage: powershell -File qa/run_all.ps1

param(
    [string]$Suite = "all",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
Set-Location "$PSScriptRoot/.."

Write-Host "=================================================="
Write-Host "  WawApp Dispatch Reliability Certification"
Write-Host "  Suite: $Suite"
Write-Host "=================================================="

if ($DryRun) {
    Write-Host "[DRY RUN] Would execute: node qa/orchestrator/orchestrate.js --suite $Suite"
    exit 0
}

# Verify device connected
$devices = adb devices | Select-String "R83Y20PC4EN"
if (-not $devices) {
    Write-Error "ERROR: Driver device R83Y20PC4EN not connected. Aborting."
    exit 1
}

Write-Host "[OK] Driver device connected."

# Ensure reports directories exist
New-Item -ItemType Directory -Force -Path "qa/reports"    | Out-Null
New-Item -ItemType Directory -Force -Path "qa/artifacts"  | Out-Null

# Run
$start = Get-Date
node qa/orchestrator/orchestrate.js --suite $Suite
$exitCode = $LASTEXITCODE
$elapsed = (Get-Date) - $start

Write-Host ""
Write-Host "--------------------------------------------------"
Write-Host "  Total elapsed: $([int]$elapsed.TotalSeconds)s"
if ($exitCode -eq 0) {
    Write-Host "  STATUS: CERTIFIED"
} else {
    Write-Host "  STATUS: FAILED"
}
Write-Host "--------------------------------------------------"
exit $exitCode
