# Generate strong random passwords for Android keystores
# WawApp Production Release - Non-Interactive Keystore Generation

Write-Host "Generating secure random passwords for keystores..." -ForegroundColor Cyan

# Generate 32-character random passwords with alphanumeric + special characters
function Generate-StrongPassword {
    $chars = @()
    $chars += 65..90 | ForEach-Object { [char]$_ }  # A-Z
    $chars += 97..122 | ForEach-Object { [char]$_ } # a-z
    $chars += 48..57 | ForEach-Object { [char]$_ }  # 0-9
    $chars += @('!', '#', '$', '%', '&', '*', '+', '-', '=', '?', '@')

    $password = -join ($chars | Get-Random -Count 32)
    return $password
}

# Generate passwords
$clientStorePass = Generate-StrongPassword
$clientKeyPass = $clientStorePass  # Same as store password

$driverStorePass = Generate-StrongPassword
$driverKeyPass = $driverStorePass  # Same as store password

# Save Client secrets
$clientSecretsPath = "apps\wawapp_client\android\app\keystore_secrets.local"
$clientContent = @"
storePassword=$clientStorePass
keyPassword=$clientKeyPass
"@
Set-Content -Path $clientSecretsPath -Value $clientContent -NoNewline
Write-Host "[OK] Client keystore secrets saved to: $clientSecretsPath" -ForegroundColor Green

# Save Driver secrets
$driverSecretsPath = "apps\wawapp_driver\android\app\keystore_secrets.local"
$driverContent = @"
storePassword=$driverStorePass
keyPassword=$driverKeyPass
"@
Set-Content -Path $driverSecretsPath -Value $driverContent -NoNewline
Write-Host "[OK] Driver keystore secrets saved to: $driverSecretsPath" -ForegroundColor Green

Write-Host "`nPasswords generated successfully!" -ForegroundColor Green
Write-Host "These files are gitignored and contain secure 32-character passwords." -ForegroundColor Yellow
Write-Host "`nNOTE: Store these passwords in a secure password manager as backup!" -ForegroundColor Yellow
