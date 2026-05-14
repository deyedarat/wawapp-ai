<#
.SYNOPSIS
  Run the full E2E dual-device scenario (Rider creates order → Driver accepts → Trip completes)

.DESCRIPTION
  This script:
  1. Validates both devices are connected
  2. Runs the full_order_lifecycle scenario
  3. Outputs results and artifacts

.EXAMPLE
  powershell -File qa/run_e2e.ps1
#>

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  WawApp Full E2E Test — Real Dual-Device Flow" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check devices
Write-Host "[1/3] Checking connected devices..." -ForegroundColor Yellow
$adbOutput = adb devices 2>&1
$deviceLines = $adbOutput | Where-Object { $_ -match '\tdevice$' }

if ($deviceLines.Count -lt 2) {
    Write-Host "❌ ERROR: Need 2 devices connected. Found: $($deviceLines.Count)" -ForegroundColor Red
    Write-Host "   Connect both Driver and Rider phones via USB." -ForegroundColor Yellow
    Write-Host ""
    $deviceLines | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
    exit 1
}

Write-Host "✅ Found $($deviceLines.Count) devices:" -ForegroundColor Green
$deviceLines | ForEach-Object { Write-Host "   $_" -ForegroundColor Green }

# Step 2: Validate roles
Write-Host ""
Write-Host "[2/3] Validating device roles..." -ForegroundColor Yellow
node qa/check_devices.js
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Device validation failed. Update qa/device_roles.json" -ForegroundColor Red
    exit 1
}

# Step 3: Run E2E scenario
Write-Host ""
Write-Host "[3/3] Running full E2E scenario..." -ForegroundColor Yellow
Write-Host ""
node qa/scenarios/e2e/full_order_lifecycle.js

$exitCode = $LASTEXITCODE
Write-Host ""
if ($exitCode -eq 0) {
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "  ✅ E2E TEST PASSED" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
} else {
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host "  ❌ E2E TEST FAILED — Check artifacts for evidence" -ForegroundColor Red
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Red
}

Write-Host ""
Write-Host "Artifacts saved to: qa/artifacts/" -ForegroundColor Gray
exit $exitCode
