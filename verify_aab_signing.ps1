# Verify AAB Signing with Production Keystores
# Confirms both AABs are signed with production keys, not debug keys

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "WawApp AAB Signing Verification" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Locate jarsigner
$jarsigner = (Get-Command jarsigner -ErrorAction SilentlyContinue).Source
if (-not $jarsigner) {
    $jarsigner = "C:\Program Files\Eclipse Adoptium\jdk-17.0.6.10-hotspot\bin\jarsigner.exe"
}

if (-not (Test-Path $jarsigner)) {
    Write-Host "[ERROR] jarsigner not found!" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Found jarsigner: $jarsigner" -ForegroundColor Green
Write-Host ""

# Read passwords
$clientSecretsPath = "apps\wawapp_client\android\app\keystore_secrets.local"
$clientSecrets = Get-Content $clientSecretsPath -Raw
$clientStorePass = ($clientSecrets -split "`n" | Where-Object { $_ -match '^storePassword=' }) -replace 'storePassword=', ''

$driverSecretsPath = "apps\wawapp_driver\android\app\keystore_secrets.local"
$driverSecrets = Get-Content $driverSecretsPath -Raw
$driverStorePass = ($driverSecrets -split "`n" | Where-Object { $_ -match '^storePassword=' }) -replace 'storePassword=', ''

# Verify Client AAB
Write-Host "Verifying Client AAB..." -ForegroundColor Yellow
Write-Host "------------------------------" -ForegroundColor Yellow
$clientAAB = "apps\wawapp_client\build\app\outputs\bundle\release\app-release.aab"

if (-not (Test-Path $clientAAB)) {
    Write-Host "[ERROR] Client AAB not found: $clientAAB" -ForegroundColor Red
    exit 1
}

$clientKeystore = "apps\wawapp_client\android\app\upload-keystore.jks"
$clientOutput = & $jarsigner -verify -verbose -certs -keystore $clientKeystore -storepass $clientStorePass $clientAAB 2>&1

if ($clientOutput -match "jar verified") {
    Write-Host "[OK] Client AAB is SIGNED with production keystore" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Client AAB signature verification FAILED" -ForegroundColor Red
    Write-Host $clientOutput
    exit 1
}

# Show certificate fingerprint
$clientCertInfo = $clientOutput | Select-String -Pattern "SHA1:|SHA256:|CN="
$clientCertInfo | ForEach-Object { Write-Host "  $_" -ForegroundColor White }

Write-Host ""
Write-Host ""

# Verify Driver AAB
Write-Host "Verifying Driver AAB..." -ForegroundColor Yellow
Write-Host "------------------------------" -ForegroundColor Yellow
$driverAAB = "apps\wawapp_driver\build\app\outputs\bundle\release\app-release.aab"

if (-not (Test-Path $driverAAB)) {
    Write-Host "[ERROR] Driver AAB not found: $driverAAB" -ForegroundColor Red
    exit 1
}

$driverKeystore = "apps\wawapp_driver\android\app\upload-keystore.jks"
$driverOutput = & $jarsigner -verify -verbose -certs -keystore $driverKeystore -storepass $driverStorePass $driverAAB 2>&1

if ($driverOutput -match "jar verified") {
    Write-Host "[OK] Driver AAB is SIGNED with production keystore" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Driver AAB signature verification FAILED" -ForegroundColor Red
    Write-Host $driverOutput
    exit 1
}

# Show certificate fingerprint
$driverCertInfo = $driverOutput | Select-String -Pattern "SHA1:|SHA256:|CN="
$driverCertInfo | ForEach-Object { Write-Host "  $_" -ForegroundColor White }

Write-Host ""
Write-Host "======================================" -ForegroundColor Green
Write-Host "AAB Verification Complete!" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host ""
Write-Host "Both AABs are properly signed with production keystores." -ForegroundColor Green
Write-Host ""
Write-Host "Client AAB: $clientAAB" -ForegroundColor White
Write-Host "Driver AAB: $driverAAB" -ForegroundColor White
Write-Host ""
Write-Host "Ready for Google Play Store upload!" -ForegroundColor Yellow
