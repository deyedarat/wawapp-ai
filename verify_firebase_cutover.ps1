# Verify Firebase Production Cutover
# Checks that google-services.json files are correctly configured for production

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Firebase Production Cutover Verification" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$clientConfigPath = "apps\wawapp_client\android\app\google-services.json"
$driverConfigPath = "apps\wawapp_driver\android\app\google-services.json"

$allGood = $true

# Check Client google-services.json
Write-Host "Checking Client google-services.json..." -ForegroundColor Yellow
if (Test-Path $clientConfigPath) {
    $clientConfig = Get-Content $clientConfigPath -Raw | ConvertFrom-Json
    $clientProjectId = $clientConfig.project_info.project_id
    $clientPackageName = $clientConfig.client[0].client_info.android_client_info.package_name

    Write-Host "  Project ID:    $clientProjectId" -ForegroundColor White
    Write-Host "  Package Name:  $clientPackageName" -ForegroundColor White

    if ($clientProjectId -eq "wawapp-production") {
        Write-Host "  [OK] Project ID is production" -ForegroundColor Green
    } else {
        Write-Host "  [ERROR] Project ID is NOT production (expected: wawapp-production)" -ForegroundColor Red
        $allGood = $false
    }

    if ($clientPackageName -eq "com.wawapp.client") {
        Write-Host "  [OK] Package name is correct" -ForegroundColor Green
    } else {
        Write-Host "  [ERROR] Package name mismatch (expected: com.wawapp.client)" -ForegroundColor Red
        $allGood = $false
    }
} else {
    Write-Host "  [ERROR] File not found: $clientConfigPath" -ForegroundColor Red
    $allGood = $false
}

Write-Host ""

# Check Driver google-services.json
Write-Host "Checking Driver google-services.json..." -ForegroundColor Yellow
if (Test-Path $driverConfigPath) {
    $driverConfig = Get-Content $driverConfigPath -Raw | ConvertFrom-Json
    $driverProjectId = $driverConfig.project_info.project_id
    $driverPackageName = $driverConfig.client[0].client_info.android_client_info.package_name

    Write-Host "  Project ID:    $driverProjectId" -ForegroundColor White
    Write-Host "  Package Name:  $driverPackageName" -ForegroundColor White

    if ($driverProjectId -eq "wawapp-production") {
        Write-Host "  [OK] Project ID is production" -ForegroundColor Green
    } else {
        Write-Host "  [ERROR] Project ID is NOT production (expected: wawapp-production)" -ForegroundColor Red
        $allGood = $false
    }

    if ($driverPackageName -eq "com.wawapp.driver") {
        Write-Host "  [OK] Package name is correct" -ForegroundColor Green
    } else {
        Write-Host "  [ERROR] Package name mismatch (expected: com.wawapp.driver)" -ForegroundColor Red
        $allGood = $false
    }
} else {
    Write-Host "  [ERROR] File not found: $driverConfigPath" -ForegroundColor Red
    $allGood = $false
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan

if ($allGood) {
    Write-Host "VERIFICATION PASSED" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Both google-services.json files are correctly configured for production." -ForegroundColor Green
    Write-Host "Ready to rebuild release AABs." -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "VERIFICATION FAILED" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Please check the errors above and fix the google-services.json files." -ForegroundColor Red
    exit 1
}
