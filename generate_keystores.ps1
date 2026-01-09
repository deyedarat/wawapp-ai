# Non-Interactive Keystore Generation for WawApp Production Release
# Generates production keystores for both Client and Driver apps

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "WawApp Production Keystore Generation" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Locate keytool (try common paths)
$keytoolPaths = @(
    "$env:JAVA_HOME\bin\keytool.exe",
    "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe",
    "C:\Program Files\Java\jdk-17\bin\keytool.exe",
    "C:\Program Files\Java\jdk-11\bin\keytool.exe",
    "keytool.exe"  # Try PATH
)

$keytool = $null
foreach ($path in $keytoolPaths) {
    if (Test-Path $path -ErrorAction SilentlyContinue) {
        $keytool = $path
        Write-Host "[OK] Found keytool at: $keytool" -ForegroundColor Green
        break
    }
}

if (-not $keytool) {
    # Try from PATH
    $keytool = (Get-Command keytool -ErrorAction SilentlyContinue).Source
    if ($keytool) {
        Write-Host "[OK] Found keytool in PATH: $keytool" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] keytool not found! Please install JDK 11+ or set JAVA_HOME" -ForegroundColor Red
        exit 1
    }
}

# Read passwords from secrets files
Write-Host ""
Write-Host "Reading keystore passwords..." -ForegroundColor Yellow

$clientSecretsPath = "apps\wawapp_client\android\app\keystore_secrets.local"
$driverSecretsPath = "apps\wawapp_driver\android\app\keystore_secrets.local"

if (-not (Test-Path $clientSecretsPath)) {
    Write-Host "[ERROR] Client secrets file not found: $clientSecretsPath" -ForegroundColor Red
    Write-Host "Run generate_keystore_passwords.ps1 first!" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $driverSecretsPath)) {
    Write-Host "[ERROR] Driver secrets file not found: $driverSecretsPath" -ForegroundColor Red
    Write-Host "Run generate_keystore_passwords.ps1 first!" -ForegroundColor Red
    exit 1
}

# Parse secrets files
$clientSecrets = Get-Content $clientSecretsPath -Raw
$clientStorePass = ($clientSecrets -split "`n" | Where-Object { $_ -match '^storePassword=' }) -replace 'storePassword=', ''
$clientKeyPass = ($clientSecrets -split "`n" | Where-Object { $_ -match '^keyPassword=' }) -replace 'keyPassword=', ''

$driverSecrets = Get-Content $driverSecretsPath -Raw
$driverStorePass = ($driverSecrets -split "`n" | Where-Object { $_ -match '^storePassword=' }) -replace 'storePassword=', ''
$driverKeyPass = ($driverSecrets -split "`n" | Where-Object { $_ -match '^keyPassword=' }) -replace 'keyPassword=', ''

Write-Host "[OK] Passwords loaded" -ForegroundColor Green

# Generate Client Keystore
Write-Host ""
Write-Host "Generating WawApp Client production keystore..." -ForegroundColor Cyan
$clientKeystorePath = "apps\wawapp_client\android\app\upload-keystore.jks"

$clientArgs = @(
    "-genkeypair",
    "-v",
    "-keystore", $clientKeystorePath,
    "-storepass", $clientStorePass,
    "-keypass", $clientKeyPass,
    "-alias", "upload",
    "-keyalg", "RSA",
    "-keysize", "2048",
    "-validity", "10000",
    "-dname", "CN=WawApp Client, OU=Engineering, O=WawApp, L=Nouakchott, ST=Nouakchott, C=MR"
)

& $keytool $clientArgs 2>&1 | Out-Null

if (Test-Path $clientKeystorePath) {
    Write-Host "[OK] Client keystore created: $clientKeystorePath" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Failed to create Client keystore" -ForegroundColor Red
    exit 1
}

# Generate Driver Keystore
Write-Host ""
Write-Host "Generating WawApp Driver production keystore..." -ForegroundColor Cyan
$driverKeystorePath = "apps\wawapp_driver\android\app\upload-keystore.jks"

$driverArgs = @(
    "-genkeypair",
    "-v",
    "-keystore", $driverKeystorePath,
    "-storepass", $driverStorePass,
    "-keypass", $driverKeyPass,
    "-alias", "upload",
    "-keyalg", "RSA",
    "-keysize", "2048",
    "-validity", "10000",
    "-dname", "CN=WawApp Driver, OU=Engineering, O=WawApp, L=Nouakchott, ST=Nouakchott, C=MR"
)

& $keytool $driverArgs 2>&1 | Out-Null

if (Test-Path $driverKeystorePath) {
    Write-Host "[OK] Driver keystore created: $driverKeystorePath" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Failed to create Driver keystore" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "======================================" -ForegroundColor Green
Write-Host "Keystore Generation Complete!" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host ""
Write-Host "Created files:" -ForegroundColor Yellow
Write-Host "  - $clientKeystorePath" -ForegroundColor White
Write-Host "  - $driverKeystorePath" -ForegroundColor White
Write-Host ""
Write-Host "Next: Create key.properties files for Gradle" -ForegroundColor Yellow
