# WawApp Quick Debug Setup Script
# Run this once to optimize your development environment

Write-Host "WawApp Quick Debug Setup" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Check if running in project root
if (-not (Test-Path ".\apps\wawapp_client")) {
    Write-Host "Error: Run this script from the WawApp project root" -ForegroundColor Red
    exit 1
}

# 1. Check Flutter installation
Write-Host "1. Checking Flutter installation..." -ForegroundColor Yellow
$flutterVersion = flutter --version 2>&1 | Select-String "Flutter" | Select-Object -First 1
if ($flutterVersion) {
    Write-Host "   Flutter installed: $flutterVersion" -ForegroundColor Green
} else {
    Write-Host "   Flutter not found. Install from https://flutter.dev" -ForegroundColor Red
    exit 1
}

# 2. Check Firebase CLI
Write-Host ""
Write-Host "2. Checking Firebase CLI..." -ForegroundColor Yellow
$firebaseVersion = firebase --version 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "   Firebase CLI installed: $firebaseVersion" -ForegroundColor Green
} else {
    Write-Host "   Firebase CLI not found. Installing..." -ForegroundColor Yellow
    npm install -g firebase-tools
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   Firebase CLI installed successfully" -ForegroundColor Green
    } else {
        Write-Host "   Failed to install Firebase CLI" -ForegroundColor Red
    }
}

# 3. Initialize Firebase Emulators
Write-Host ""
Write-Host "3. Initializing Firebase Emulators..." -ForegroundColor Yellow
if (Test-Path "firebase.json") {
    Write-Host "   Firebase already initialized" -ForegroundColor Green
} else {
    Write-Host "   Firebase not initialized. Run: firebase init emulators" -ForegroundColor Yellow
}

# 4. Install dependencies
Write-Host ""
Write-Host "4. Installing Flutter dependencies..." -ForegroundColor Yellow

Write-Host "   Client app..." -ForegroundColor Cyan
Set-Location "apps\wawapp_client"
flutter pub get
Set-Location "..\.."

Write-Host "   Driver app..." -ForegroundColor Cyan
Set-Location "apps\wawapp_driver"
flutter pub get
Set-Location "..\.."

Write-Host "   auth_shared..." -ForegroundColor Cyan
Set-Location "packages\auth_shared"
flutter pub get
Set-Location "..\.."

Write-Host "   core_shared..." -ForegroundColor Cyan
Set-Location "packages\core_shared"
flutter pub get
Set-Location "..\.."

Write-Host "   All dependencies installed" -ForegroundColor Green

# 5. Install Cloud Functions dependencies
Write-Host ""
Write-Host "5. Installing Cloud Functions dependencies..." -ForegroundColor Yellow
if (Test-Path "functions\package.json") {
    Set-Location "functions"
    npm install
    Set-Location ".."
    Write-Host "   Cloud Functions dependencies installed" -ForegroundColor Green
} else {
    Write-Host "   Cloud Functions not found" -ForegroundColor Yellow
}

# 6. Check for Android emulator
Write-Host ""
Write-Host "6. Checking for Android emulators..." -ForegroundColor Yellow
$emulators = emulator -list-avds 2>&1
if ($emulators) {
    Write-Host "   Available emulators:" -ForegroundColor Green
    $emulators | ForEach-Object { Write-Host "      - $_" -ForegroundColor Gray }
} else {
    Write-Host "   No Android emulators found" -ForegroundColor Yellow
    Write-Host "      Create one in Android Studio: Tools > AVD Manager" -ForegroundColor Gray
}

# 7. Check for connected devices
Write-Host ""
Write-Host "7. Checking for connected devices..." -ForegroundColor Yellow
$devices = flutter devices 2>&1 | Select-String "•" | Select-Object -First 5
if ($devices) {
    Write-Host "   Available devices:" -ForegroundColor Green
    $devices | ForEach-Object { Write-Host "      $_" -ForegroundColor Gray }
} else {
    Write-Host "   No devices found. Connect a device or start an emulator" -ForegroundColor Yellow
}

# 8. Run flutter doctor
Write-Host ""
Write-Host "8. Running Flutter Doctor..." -ForegroundColor Yellow
flutter doctor

# 9. Create seed data directory for emulators
Write-Host ""
Write-Host "9. Creating emulator seed data directory..." -ForegroundColor Yellow
if (-not (Test-Path "emulator-seed-data")) {
    New-Item -ItemType Directory -Path "emulator-seed-data" | Out-Null
    Write-Host "   Created emulator-seed-data directory" -ForegroundColor Green
    Write-Host "      (You can add test data here for faster debugging)" -ForegroundColor Gray
} else {
    Write-Host "   emulator-seed-data directory exists" -ForegroundColor Green
}

# Summary
Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "   1. Read docs/DEBUGGING_SPEED_GUIDE.md for best practices" -ForegroundColor Gray
Write-Host "   2. Start Firebase Emulators: firebase emulators:start" -ForegroundColor Gray
Write-Host "   3. Launch app in VSCode: F5 -> Select Client (Debug)" -ForegroundColor Gray
Write-Host "   4. Use 'r' for hot reload, 'R' for hot restart" -ForegroundColor Gray
Write-Host ""
Write-Host "Quick Commands:" -ForegroundColor Cyan
Write-Host "   Ctrl+Shift+P -> Tasks: Run Task -> See all available tasks" -ForegroundColor Gray
Write-Host "   F5 -> Start debugging" -ForegroundColor Gray
Write-Host "   Ctrl+F5 -> Run without debugging (faster)" -ForegroundColor Gray
Write-Host ""
Write-Host "Happy coding!" -ForegroundColor Green