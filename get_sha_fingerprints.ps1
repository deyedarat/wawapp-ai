# Extract SHA-1 and SHA-256 Fingerprints for Firebase Registration
# These fingerprints are needed to register Android apps in Firebase Console

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "WawApp Production Keystore Fingerprints" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Use these fingerprints when registering apps in Firebase Console" -ForegroundColor Yellow
Write-Host ""

# Locate keytool
$keytool = (Get-Command keytool -ErrorAction SilentlyContinue).Source
if (-not $keytool) {
    $keytool = "C:\Program Files\Eclipse Adoptium\jdk-17.0.6.10-hotspot\bin\keytool.exe"
}

# Read passwords
$clientSecretsPath = "apps\wawapp_client\android\app\keystore_secrets.local"
$clientSecrets = Get-Content $clientSecretsPath -Raw
$clientStorePass = ($clientSecrets -split "`n" | Where-Object { $_ -match '^storePassword=' }) -replace 'storePassword=', ''

$driverSecretsPath = "apps\wawapp_driver\android\app\keystore_secrets.local"
$driverSecrets = Get-Content $driverSecretsPath -Raw
$driverStorePass = ($driverSecrets -split "`n" | Where-Object { $_ -match '^storePassword=' }) -replace 'storePassword=', ''

# Extract Client fingerprints
Write-Host "CLIENT APP (com.wawapp.client)" -ForegroundColor Green
Write-Host "==============================" -ForegroundColor Green
$clientKeystore = "apps\wawapp_client\android\app\upload-keystore.jks"
$clientOutput = & $keytool -list -v -keystore $clientKeystore -storepass $clientStorePass -alias upload 2>&1

$clientSHA1 = ($clientOutput | Select-String -Pattern "SHA1:" | Out-String).Trim() -replace '.*SHA1:\s*', ''
$clientSHA256 = ($clientOutput | Select-String -Pattern "SHA256:" | Out-String).Trim() -replace '.*SHA256:\s*', ''

Write-Host "Package Name: com.wawapp.client" -ForegroundColor White
Write-Host "SHA-1:   $clientSHA1" -ForegroundColor Yellow
Write-Host "SHA-256: $clientSHA256" -ForegroundColor Yellow
Write-Host ""

# Extract Driver fingerprints
Write-Host "DRIVER APP (com.wawapp.driver)" -ForegroundColor Green
Write-Host "==============================" -ForegroundColor Green
$driverKeystore = "apps\wawapp_driver\android\app\upload-keystore.jks"
$driverOutput = & $keytool -list -v -keystore $driverKeystore -storepass $driverStorePass -alias upload 2>&1

$driverSHA1 = ($driverOutput | Select-String -Pattern "SHA1:" | Out-String).Trim() -replace '.*SHA1:\s*', ''
$driverSHA256 = ($driverOutput | Select-String -Pattern "SHA256:" | Out-String).Trim() -replace '.*SHA256:\s*', ''

Write-Host "Package Name: com.wawapp.driver" -ForegroundColor White
Write-Host "SHA-1:   $driverSHA1" -ForegroundColor Yellow
Write-Host "SHA-256: $driverSHA256" -ForegroundColor Yellow
Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Copy these values to Firebase Console" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "When adding Android apps to Firebase, use:" -ForegroundColor White
Write-Host ""
Write-Host "Client App:" -ForegroundColor Yellow
Write-Host "  Package: com.wawapp.client" -ForegroundColor White
Write-Host "  SHA-1:   $clientSHA1" -ForegroundColor White
Write-Host "  SHA-256: $clientSHA256" -ForegroundColor White
Write-Host ""
Write-Host "Driver App:" -ForegroundColor Yellow
Write-Host "  Package: com.wawapp.driver" -ForegroundColor White
Write-Host "  SHA-1:   $driverSHA1" -ForegroundColor White
Write-Host "  SHA-256: $driverSHA256" -ForegroundColor White
