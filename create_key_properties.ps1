# Create key.properties files for Gradle signing configuration
# Reads passwords from keystore_secrets.local files

Write-Host "Creating key.properties files..." -ForegroundColor Cyan

# Read Client secrets
$clientSecretsPath = "apps\wawapp_client\android\app\keystore_secrets.local"
$clientSecrets = Get-Content $clientSecretsPath -Raw
$clientStorePass = ($clientSecrets -split "`n" | Where-Object { $_ -match '^storePassword=' }) -replace 'storePassword=', ''
$clientKeyPass = ($clientSecrets -split "`n" | Where-Object { $_ -match '^keyPassword=' }) -replace 'keyPassword=', ''

# Read Driver secrets
$driverSecretsPath = "apps\wawapp_driver\android\app\keystore_secrets.local"
$driverSecrets = Get-Content $driverSecretsPath -Raw
$driverStorePass = ($driverSecrets -split "`n" | Where-Object { $_ -match '^storePassword=' }) -replace 'storePassword=', ''
$driverKeyPass = ($driverSecrets -split "`n" | Where-Object { $_ -match '^keyPassword=' }) -replace 'keyPassword=', ''

# Create Client key.properties
$clientKeyPropertiesPath = "apps\wawapp_client\android\key.properties"
$clientKeyPropertiesContent = @"
storePassword=$clientStorePass
keyPassword=$clientKeyPass
keyAlias=upload
storeFile=app/upload-keystore.jks
"@
Set-Content -Path $clientKeyPropertiesPath -Value $clientKeyPropertiesContent -NoNewline
Write-Host "[OK] Client key.properties created: $clientKeyPropertiesPath" -ForegroundColor Green

# Create Driver key.properties
$driverKeyPropertiesPath = "apps\wawapp_driver\android\key.properties"
$driverKeyPropertiesContent = @"
storePassword=$driverStorePass
keyPassword=$driverKeyPass
keyAlias=upload
storeFile=app/upload-keystore.jks
"@
Set-Content -Path $driverKeyPropertiesPath -Value $driverKeyPropertiesContent -NoNewline
Write-Host "[OK] Driver key.properties created: $driverKeyPropertiesPath" -ForegroundColor Green

Write-Host ""
Write-Host "key.properties files created successfully!" -ForegroundColor Green
Write-Host "Gradle will now use these for release signing." -ForegroundColor Yellow
