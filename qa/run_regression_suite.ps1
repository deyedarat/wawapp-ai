# run_regression_suite.ps1
# Fast regression suite: core + reliability scenarios.
# Use this for daily validation and pre-merge checks.
# Skips torture scenarios (those run at release gates).
#
# Usage: powershell -File qa/run_regression_suite.ps1

$ErrorActionPreference = "Stop"
Set-Location "$PSScriptRoot/.."

Write-Host "=================================================="
Write-Host "  WawApp Regression Suite (core + reliability)"
Write-Host "=================================================="

$devices = adb devices | Select-String "R83Y20PC4EN"
if (-not $devices) { Write-Error "Driver device not connected."; exit 1 }

New-Item -ItemType Directory -Force -Path "qa/reports"   | Out-Null
New-Item -ItemType Directory -Force -Path "qa/artifacts" | Out-Null

$start = Get-Date
node qa/orchestrator/orchestrate.js --suite regression
$exitCode = $LASTEXITCODE
$elapsed = (Get-Date) - $start

Write-Host "Elapsed: $([int]$elapsed.TotalSeconds)s | Exit: $exitCode"
exit $exitCode
