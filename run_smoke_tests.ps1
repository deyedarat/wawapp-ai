Write-Host "=== WAWAPP AUTH SMOKE TESTS ==="

# Check for devices
$devices = flutter devices --machine
if ($devices -match "No devices found") {
    Write-Error "No connected devices found. Please connect a device or start an emulator."
    exit 1
}

Write-Host "`n[1/2] Running Client Auth Smoke Test..."
Set-Location "apps/wawapp_client"
flutter test integration_test/smoke_auth_flow_test.dart
if ($LASTEXITCODE -ne 0) { 
    Write-Error "Client Test Failed"
    Set-Location "../../"
    exit 1 
}

Write-Host "`n[2/2] Running Driver Auth Smoke Test..."
Set-Location "../wawapp_driver"
flutter test integration_test/smoke_auth_flow_test.dart
if ($LASTEXITCODE -ne 0) { 
    Write-Error "Driver Test Failed"
    Set-Location "../../"
    exit 1 
}

Set-Location "../../"
Write-Host "`n✅ All Smoke Tests Passed Successfully!"
