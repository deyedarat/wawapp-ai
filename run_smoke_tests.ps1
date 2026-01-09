Write-Host "=== WAWAPP AUTH SMOKE TESTS ===" -ForegroundColor Cyan

# 0. Setup Logs
$logDir = "logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
}
$timestamp = Get-Date -Format "yyyyMMdd_HHmm"
$clientLog = "$logDir/smoke_client_$timestamp.txt"
$driverLog = "$logDir/smoke_driver_$timestamp.txt"

# 1. Auto-detect connected device
$deviceInfo = flutter devices --machine | ConvertFrom-Json
$device = $deviceInfo | Where-Object { $_.id -ne "windows" -and $_.id -ne "chrome" -and $_.id -ne "edge" } | Select-Object -First 1

if ($null -eq $device) {
    Write-Error "No suitable mobile device found. Please connect an Android/iOS device."
    exit 1
}

$deviceId = $device.id
Write-Host "📱 Target Device: $($device.name) ($deviceId)" -ForegroundColor Yellow
Write-Host "📂 Logs will be saved to: $logDir" -ForegroundColor Gray

# 2. Run Client Test
Write-Host ""
Write-Host "[1/2] 🧪 Running Client Auth Smoke Test..." -ForegroundColor Magenta
Set-Location "apps/wawapp_client"
Write-Host "   > Logging to: $clientLog"
flutter test integration_test/smoke_auth_flow_test.dart -d $deviceId | Tee-Object -FilePath "../../$clientLog"
if ($LASTEXITCODE -ne 0) { 
    Write-Error "❌ Client Test Failed. See $clientLog for details."
    Set-Location "../../"
    exit 1 
}

# 3. Run Driver Test
Write-Host ""
Write-Host "[2/2] 🧪 Running Driver Auth Smoke Test..." -ForegroundColor Magenta
Set-Location "../wawapp_driver"
Write-Host "   > Logging to: $driverLog"
flutter test integration_test/smoke_auth_flow_test.dart -d $deviceId | Tee-Object -FilePath "../../$driverLog"
if ($LASTEXITCODE -ne 0) { 
    Write-Error "❌ Driver Test Failed. See $driverLog for details."
    Set-Location "../../"
    exit 1 
}

Set-Location "../../"
Write-Host ""
Write-Host "✅ All Smoke Tests Passed Successfully!" -ForegroundColor Green
