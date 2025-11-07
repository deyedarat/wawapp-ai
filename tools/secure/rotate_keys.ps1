# rotate_keys.ps1 - Secure API Key Rotation Script
# Purpose: Rotate Google Maps API key and secure environment variables

param(
    [switch]$CreateEnvFiles,
    [switch]$Help
)

if ($Help) {
    Write-Host @"
Usage: .\rotate_keys.ps1 [-CreateEnvFiles]

Steps to rotate Google Maps API key:

1. CREATE NEW RESTRICTED KEY IN GCP CONSOLE:
   a. Go to: https://console.cloud.google.com/apis/credentials
   b. Click "CREATE CREDENTIALS" > "API key"
   c. Copy the new key immediately
   d. Click "RESTRICT KEY"
   e. Set Name: "WawApp Maps Key - $(Get-Date -Format 'yyyy-MM-dd')"
   f. Application restrictions:
      - Android apps: Add SHA-1 fingerprints + package names
        * com.wawapp.client
        * com.wawapp.driver
      - iOS apps: Add bundle IDs
        * com.wawapp.client
        * com.wawapp.driver
   g. API restrictions: Select "Restrict key"
      - Maps SDK for Android
      - Maps SDK for iOS
      - Places API
      - Directions API
      - Geocoding API
   h. Click "SAVE"

2. RUN THIS SCRIPT:
   .\rotate_keys.ps1 -CreateEnvFiles

3. UPDATE .env FILES:
   - apps/wawapp_client/.env
   - apps/wawapp_driver/.env
   Paste the new key: MAPS_API_KEY=AIza...

4. TEST NEW KEY:
   cd apps/wawapp_client
   flutter run
   # Verify maps load correctly

5. DISABLE OLD KEY:
   - Return to GCP Console > Credentials
   - Find old key, click "DISABLE"
   - Wait 24-48 hours, monitor for issues

6. DELETE OLD KEY:
   - After verification period, click "DELETE"

"@
    exit 0
}

Write-Host "🔐 API Key Rotation Tool" -ForegroundColor Cyan
Write-Host "========================`n" -ForegroundColor Cyan

# Create .env.example files
if ($CreateEnvFiles) {
    Write-Host "📝 Creating .env.example files..." -ForegroundColor Yellow
    
    $envExample = @"
# Google Maps API Key
# Get from: https://console.cloud.google.com/apis/credentials
MAPS_API_KEY=your_api_key_here

# Firebase Configuration (if needed)
# FIREBASE_API_KEY=your_firebase_key_here
"@

    $clientEnvExample = "apps/wawapp_client/.env.example"
    $driverEnvExample = "apps/wawapp_driver/.env.example"
    
    Set-Content -Path $clientEnvExample -Value $envExample -Encoding UTF8
    Set-Content -Path $driverEnvExample -Value $envExample -Encoding UTF8
    
    Write-Host "✅ Created: $clientEnvExample" -ForegroundColor Green
    Write-Host "✅ Created: $driverEnvExample" -ForegroundColor Green
    
    # Create actual .env files if they don't exist
    $clientEnv = "apps/wawapp_client/.env"
    $driverEnv = "apps/wawapp_driver/.env"
    
    if (-not (Test-Path $clientEnv)) {
        Copy-Item $clientEnvExample $clientEnv
        Write-Host "✅ Created: $clientEnv (copy from example)" -ForegroundColor Green
    }
    
    if (-not (Test-Path $driverEnv)) {
        Copy-Item $driverEnvExample $driverEnv
        Write-Host "✅ Created: $driverEnv (copy from example)" -ForegroundColor Green
    }
    
    Write-Host "`n⚠️  IMPORTANT: Edit .env files and add your actual API key!" -ForegroundColor Yellow
    Write-Host "   Never commit .env files to Git!" -ForegroundColor Yellow
}

Write-Host "`n📋 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Follow GCP Console steps (run with -Help to see details)"
Write-Host "2. Update .env files with new key"
Write-Host "3. Test both apps"
Write-Host "4. Disable old key after 24h"
Write-Host "5. Delete old key after 48h"
Write-Host "`n✅ Done!" -ForegroundColor Green
