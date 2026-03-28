# WawApp Debug & Observability Kit - Setup Script
# Run this script to install dependencies and verify setup

Write-Host "🔍 WawApp Debug & Observability Kit Setup" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Continue"

# Step 1: Install core_shared dependencies
Write-Host "📦 Step 1/5: Installing core_shared dependencies..." -ForegroundColor Yellow
Set-Location "packages\core_shared"
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to install core_shared dependencies" -ForegroundColor Red
    exit 1
}
Write-Host "✅ core_shared dependencies installed" -ForegroundColor Green
Write-Host ""

# Step 2: Install client app dependencies
Write-Host "📦 Step 2/5: Installing client app dependencies..." -ForegroundColor Yellow
Set-Location "..\..\apps\wawapp_client"
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to install client app dependencies" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Client app dependencies installed" -ForegroundColor Green
Write-Host ""

# Step 3: Install driver app dependencies
Write-Host "📦 Step 3/5: Installing driver app dependencies..." -ForegroundColor Yellow
Set-Location "..\wawapp_driver"
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to install driver app dependencies" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Driver app dependencies installed" -ForegroundColor Green
Write-Host ""

# Step 4: Verify client build
Write-Host "🔨 Step 4/5: Verifying client app build..." -ForegroundColor Yellow
Set-Location "..\wawapp_client"
flutter build apk --debug
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️  Client app build failed - check errors above" -ForegroundColor Red
} else {
    Write-Host "✅ Client app builds successfully" -ForegroundColor Green
}
Write-Host ""

# Step 5: Verify driver build
Write-Host "🔨 Step 5/5: Verifying driver app build..." -ForegroundColor Yellow
Set-Location "..\wawapp_driver"
flutter build apk --debug
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️  Driver app build failed - check errors above" -ForegroundColor Red
} else {
    Write-Host "✅ Driver app builds successfully" -ForegroundColor Green
}
Write-Host ""

# Return to root
Set-Location "..\..\"

# Summary
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "✨ Setup Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "📚 Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Read: docs\QUICK_DEBUG_SETUP.md" -ForegroundColor White
Write-Host "  2. Run client: cd apps\wawapp_client && flutter run" -ForegroundColor White
Write-Host "  3. Run driver: cd apps\wawapp_driver && flutter run" -ForegroundColor White
Write-Host "  4. Test Crashlytics: CrashlyticsObserver.testCrash()" -ForegroundColor White
Write-Host ""
Write-Host "📖 Full Documentation:" -ForegroundColor Cyan
Write-Host "  - docs\DEBUG_OBSERVABILITY_GUIDE.md" -ForegroundColor White
Write-Host "  - docs\DEBUG_KIT_VERIFICATION_CHECKLIST.md" -ForegroundColor White
Write-Host ""
Write-Host "🎯 Quick Test:" -ForegroundColor Cyan
Write-Host "  cd apps\wawapp_client" -ForegroundColor White
Write-Host "  flutter run" -ForegroundColor White
Write-Host "  # Look for: [App][DEBUG] 🚀 WawApp Client initializing..." -ForegroundColor White
Write-Host ""
