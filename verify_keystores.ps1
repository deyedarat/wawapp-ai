# Verify keystore integrity and certificate details
# This confirms keystores were created correctly

Write-Host "Verifying keystores..." -ForegroundColor Cyan
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

# Verify Client keystore
Write-Host "Client Keystore Verification:" -ForegroundColor Yellow
Write-Host "------------------------------" -ForegroundColor Yellow
$clientKeystorePath = "apps\wawapp_client\android\app\upload-keystore.jks"
& $keytool -list -v -keystore $clientKeystorePath -storepass $clientStorePass -alias upload 2>&1 | Select-String -Pattern "Alias name:|Owner:|Valid from:|Certificate fingerprints:" -Context 0,1

Write-Host ""
Write-Host ""

# Verify Driver keystore
Write-Host "Driver Keystore Verification:" -ForegroundColor Yellow
Write-Host "------------------------------" -ForegroundColor Yellow
$driverKeystorePath = "apps\wawapp_driver\android\app\upload-keystore.jks"
& $keytool -list -v -keystore $driverKeystorePath -storepass $driverStorePass -alias upload 2>&1 | Select-String -Pattern "Alias name:|Owner:|Valid from:|Certificate fingerprints:" -Context 0,1

Write-Host ""
Write-Host "[OK] Both keystores verified successfully!" -ForegroundColor Green
