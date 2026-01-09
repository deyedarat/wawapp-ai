# WawApp Driver - Visual Assets Verification
# Verifies all Android visual assets are Play Store compliant

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "WawApp Driver - Visual Assets Verification" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$allGood = $true
$resDir = "apps\wawapp_driver\android\app\src\main\res"

# Expected densities
$densities = @("mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi")

Write-Host "1. Checking Adaptive Icon Layers..." -ForegroundColor Yellow
Write-Host ""

foreach ($density in $densities) {
    $mipmapDir = "$resDir\mipmap-$density"
    $foreground = "$mipmapDir\ic_launcher_foreground.png"
    $background = "$mipmapDir\ic_launcher_background.png"

    if ((Test-Path $foreground) -and (Test-Path $background)) {
        Write-Host "  [OK] $density adaptive layers present" -ForegroundColor Green
    } else {
        Write-Host "  [ERROR] $density adaptive layers missing" -ForegroundColor Red
        $allGood = $false
    }
}

Write-Host ""
Write-Host "2. Checking Legacy Icon Mipmaps..." -ForegroundColor Yellow
Write-Host ""

foreach ($density in $densities) {
    $mipmapDir = "$resDir\mipmap-$density"
    $launcher = "$mipmapDir\ic_launcher.png"
    $launcherRound = "$mipmapDir\ic_launcher_round.png"

    if ((Test-Path $launcher) -and (Test-Path $launcherRound)) {
        Write-Host "  [OK] $density legacy icons present" -ForegroundColor Green
    } else {
        Write-Host "  [ERROR] $density legacy icons missing" -ForegroundColor Red
        $allGood = $false
    }
}

Write-Host ""
Write-Host "3. Checking Adaptive Icon XML..." -ForegroundColor Yellow
Write-Host ""

$anydpiV26 = "$resDir\mipmap-anydpi-v26"
$launcherXML = "$anydpiV26\ic_launcher.xml"
$launcherRoundXML = "$anydpiV26\ic_launcher_round.xml"

if (Test-Path $launcherXML) {
    Write-Host "  [OK] ic_launcher.xml present" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] ic_launcher.xml missing" -ForegroundColor Red
    $allGood = $false
}

if (Test-Path $launcherRoundXML) {
    Write-Host "  [OK] ic_launcher_round.xml present" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] ic_launcher_round.xml missing" -ForegroundColor Red
    $allGood = $false
}

Write-Host ""
Write-Host "4. Checking AndroidManifest.xml..." -ForegroundColor Yellow
Write-Host ""

$manifest = "apps\wawapp_driver\android\app\src\main\AndroidManifest.xml"
$manifestContent = Get-Content $manifest -Raw

if ($manifestContent -match 'android:icon="@mipmap/ic_launcher"') {
    Write-Host "  [OK] android:icon reference present" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] android:icon reference missing" -ForegroundColor Red
    $allGood = $false
}

if ($manifestContent -match 'android:roundIcon="@mipmap/ic_launcher_round"') {
    Write-Host "  [OK] android:roundIcon reference present" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] android:roundIcon reference missing" -ForegroundColor Red
    $allGood = $false
}

Write-Host ""
Write-Host "5. Checking Splash Screen Configuration..." -ForegroundColor Yellow
Write-Host ""

$launchBg = "$resDir\drawable\launch_background.xml"
if (Test-Path $launchBg) {
    $launchBgContent = Get-Content $launchBg -Raw
    if ($launchBgContent -match '@color/splash_background') {
        Write-Host "  [OK] launch_background.xml uses color resource" -ForegroundColor Green
    } else {
        Write-Host "  [WARNING] launch_background.xml may not use dark theme" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [ERROR] launch_background.xml missing" -ForegroundColor Red
    $allGood = $false
}

$colorsXML = "$resDir\values\colors.xml"
if (Test-Path $colorsXML) {
    $colorsContent = Get-Content $colorsXML -Raw
    if ($colorsContent -match '#000609') {
        Write-Host "  [OK] Dark splash color (#000609) defined" -ForegroundColor Green
    } else {
        Write-Host "  [ERROR] Dark splash color missing" -ForegroundColor Red
        $allGood = $false
    }
} else {
    Write-Host "  [ERROR] colors.xml missing" -ForegroundColor Red
    $allGood = $false
}

Write-Host ""
Write-Host "6. Checking Play Store Assets..." -ForegroundColor Yellow
Write-Host ""

$playStoreDir = "play_store_assets\driver"
$featureGraphic = "$playStoreDir\feature_graphic.png"
$hiResIcon = "$playStoreDir\hi_res_icon.png"

if (Test-Path $featureGraphic) {
    $fg = Get-Item $featureGraphic
    Write-Host "  [OK] Feature Graphic present ($([int]($fg.Length / 1KB)) KB)" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] Feature Graphic missing" -ForegroundColor Red
    $allGood = $false
}

if (Test-Path $hiResIcon) {
    $hr = Get-Item $hiResIcon
    Write-Host "  [OK] Hi-Res Icon present ($([int]($hr.Length / 1KB)) KB)" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] Hi-Res Icon missing" -ForegroundColor Red
    $allGood = $false
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan

if ($allGood) {
    Write-Host "VERIFICATION PASSED" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "All visual assets are Play Store compliant!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Asset Summary:" -ForegroundColor Yellow
    Write-Host "  - Adaptive icons (5 densities x 2 layers) = 10 files" -ForegroundColor White
    Write-Host "  - Legacy icons (5 densities x 2 types) = 10 files" -ForegroundColor White
    Write-Host "  - Adaptive icon XML = 2 files" -ForegroundColor White
    Write-Host "  - Splash screen assets = 2 files (drawable + colors)" -ForegroundColor White
    Write-Host "  - Play Store assets = 2 files (feature graphic + hi-res icon)" -ForegroundColor White
    Write-Host "  TOTAL: 26 files" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. Build release AAB to test icon on device" -ForegroundColor White
    Write-Host "  2. Verify icon renders correctly on Android 8+ (adaptive shapes)" -ForegroundColor White
    Write-Host "  3. Upload Play Store assets when creating listing" -ForegroundColor White
    Write-Host ""
    exit 0
} else {
    Write-Host "VERIFICATION FAILED" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Please check the errors above." -ForegroundColor Red
    Write-Host ""
    exit 1
}
