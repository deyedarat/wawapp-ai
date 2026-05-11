# run_torture_suite.ps1
# Torture/stress scenarios — intended for release gating only.
# These run longer and stress-test concurrent/high-load dispatch paths.
#
# Usage: powershell -File qa/run_torture_suite.ps1

$ErrorActionPreference = "Stop"
Set-Location "$PSScriptRoot/.."

Write-Host "=================================================="
Write-Host "  WawApp TORTURE Suite (stress/release gate)"
Write-Host "=================================================="

$devices = adb devices | Select-String "R83Y20PC4EN"
if (-not $devices) { Write-Error "Driver device not connected."; exit 1 }

New-Item -ItemType Directory -Force -Path "qa/reports"   | Out-Null
New-Item -ItemType Directory -Force -Path "qa/artifacts" | Out-Null

$start = Get-Date
node qa/orchestrator/orchestrate.js --suite torture
$exitCode = $LASTEXITCODE
$elapsed = (Get-Date) - $start

Write-Host "Elapsed: $([int]$elapsed.TotalSeconds)s | Exit: $exitCode"
exit $exitCode
