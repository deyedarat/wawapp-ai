# WawApp Driver - Android Visual Assets Generator
# Generates adaptive icons, legacy mipmaps, and splash assets from design files

param(
    [switch]$WhatIf = $false
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "WawApp Driver - Visual Assets Generator" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Paths
$sourceDir = "apps\wawapp_driver\assets\icons"
$resDir = "apps\wawapp_driver\android\app\src\main\res"
$sourceLogo = "$sourceDir\driver_logo_main.png"
$splashDark = "$sourceDir\splash_screen_dark.png"

# Dark background color for Driver app
$darkBgHex = "#000609"

# Verify source files exist
if (-not (Test-Path $sourceLogo)) {
    Write-Host "[ERROR] Source logo not found: $sourceLogo" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Found source logo: $sourceLogo" -ForegroundColor Green

# Check for ImageMagick
$magick = Get-Command magick -ErrorAction SilentlyContinue
if (-not $magick) {
    Write-Host "[WARNING] ImageMagick not found. Attempting .NET image processing..." -ForegroundColor Yellow
    $useNET = $true
} else {
    Write-Host "[OK] ImageMagick found: $($magick.Source)" -ForegroundColor Green
    $useNET = $false
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Step 1: Create Adaptive Icon Layers" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Adaptive icon densities
$adaptiveDensities = @(
    @{Name="mdpi"; Size=108},
    @{Name="hdpi"; Size=162},
    @{Name="xhdpi"; Size=216},
    @{Name="xxhdpi"; Size=324},
    @{Name="xxxhdpi"; Size=432}
)

# Legacy icon densities
$legacyDensities = @(
    @{Name="mdpi"; Size=48},
    @{Name="hdpi"; Size=72},
    @{Name="xhdpi"; Size=96},
    @{Name="xxhdpi"; Size=144},
    @{Name="xxxhdpi"; Size=192}
)

function Create-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        if (-not $WhatIf) {
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
        }
        Write-Host "  [CREATE] $Path" -ForegroundColor Yellow
    }
}

function Resize-ImageNET {
    param(
        [string]$Source,
        [string]$Destination,
        [int]$Width,
        [int]$Height,
        [string]$BackgroundColor = $null
    )

    try {
        Add-Type -AssemblyName System.Drawing

        $srcImage = [System.Drawing.Image]::FromFile((Resolve-Path $Source).Path)
        $destImage = New-Object System.Drawing.Bitmap($Width, $Height)
        $graphics = [System.Drawing.Graphics]::FromImage($destImage)

        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

        if ($BackgroundColor) {
            $color = [System.Drawing.ColorTranslator]::FromHtml($BackgroundColor)
            $graphics.Clear($color)
        } else {
            $graphics.Clear([System.Drawing.Color]::Transparent)
        }

        # Center the image
        $x = ($Width - $srcImage.Width) / 2
        $y = ($Height - $srcImage.Height) / 2
        $graphics.DrawImage($srcImage, $x, $y, $srcImage.Width, $srcImage.Height)

        if (-not $WhatIf) {
            $destImage.Save($Destination, [System.Drawing.Imaging.ImageFormat]::Png)
        }

        $srcImage.Dispose()
        $graphics.Dispose()
        $destImage.Dispose()

        return $true
    } catch {
        Write-Host "[ERROR] Failed to resize image: $_" -ForegroundColor Red
        return $false
    }
}

function Resize-ImageMagick {
    param(
        [string]$Source,
        [string]$Destination,
        [int]$Size,
        [string]$BackgroundColor = $null
    )

    if ($BackgroundColor) {
        & magick convert "$Source" -resize "${Size}x${Size}" -background "$BackgroundColor" -gravity center -extent "${Size}x${Size}" "$Destination"
    } else {
        & magick convert "$Source" -resize "${Size}x${Size}" -background transparent -gravity center -extent "${Size}x${Size}" "$Destination"
    }
}

# Generate Adaptive Icon Foreground Layers
Write-Host "Generating adaptive icon foreground layers..." -ForegroundColor Yellow

foreach ($density in $adaptiveDensities) {
    $mipmapDir = "$resDir\mipmap-$($density.Name)"
    Create-Directory $mipmapDir

    $foregroundPath = "$mipmapDir\ic_launcher_foreground.png"

    if ($useNET) {
        Resize-ImageNET -Source $sourceLogo -Destination $foregroundPath -Width $density.Size -Height $density.Size
    } else {
        Resize-ImageMagick -Source $sourceLogo -Destination $foregroundPath -Size $density.Size
    }

    Write-Host "  [OK] Created $($density.Name): ic_launcher_foreground.png ($($density.Size)x$($density.Size))" -ForegroundColor Green
}

Write-Host ""
Write-Host "Generating adaptive icon background layers..." -ForegroundColor Yellow

# Create solid color background layers
foreach ($density in $adaptiveDensities) {
    $mipmapDir = "$resDir\mipmap-$($density.Name)"
    $backgroundPath = "$mipmapDir\ic_launcher_background.png"

    if ($useNET) {
        # Create solid color image using .NET
        Add-Type -AssemblyName System.Drawing
        $size = $density.Size
        $bitmap = New-Object System.Drawing.Bitmap($size, $size)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $color = [System.Drawing.ColorTranslator]::FromHtml($darkBgHex)
        $graphics.Clear($color)

        if (-not $WhatIf) {
            $bitmap.Save($backgroundPath, [System.Drawing.Imaging.ImageFormat]::Png)
        }

        $graphics.Dispose()
        $bitmap.Dispose()
    } else {
        & magick convert -size "$($density.Size)x$($density.Size)" "xc:$darkBgHex" "$backgroundPath"
    }

    Write-Host "  [OK] Created $($density.Name): ic_launcher_background.png ($($density.Size)x$($density.Size))" -ForegroundColor Green
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Step 2: Generate Legacy Icon Mipmaps" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

foreach ($density in $legacyDensities) {
    $mipmapDir = "$resDir\mipmap-$($density.Name)"
    Create-Directory $mipmapDir

    $iconPath = "$mipmapDir\ic_launcher.png"
    $roundIconPath = "$mipmapDir\ic_launcher_round.png"

    if ($useNET) {
        Resize-ImageNET -Source $sourceLogo -Destination $iconPath -Width $density.Size -Height $density.Size -BackgroundColor $darkBgHex
        Resize-ImageNET -Source $sourceLogo -Destination $roundIconPath -Width $density.Size -Height $density.Size -BackgroundColor $darkBgHex
    } else {
        Resize-ImageMagick -Source $sourceLogo -Destination $iconPath -Size $density.Size -BackgroundColor $darkBgHex
        Resize-ImageMagick -Source $sourceLogo -Destination $roundIconPath -Size $density.Size -BackgroundColor $darkBgHex
    }

    Write-Host "  [OK] Created $($density.Name): ic_launcher.png & ic_launcher_round.png ($($density.Size)x$($density.Size))" -ForegroundColor Green
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Step 3: Create Adaptive Icon XML" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$mipmapAnydpiV26 = "$resDir\mipmap-anydpi-v26"
Create-Directory $mipmapAnydpiV26

$adaptiveIconXML = @"
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
"@

$launcherXMLPath = "$mipmapAnydpiV26\ic_launcher.xml"
$launcherRoundXMLPath = "$mipmapAnydpiV26\ic_launcher_round.xml"

if (-not $WhatIf) {
    Set-Content -Path $launcherXMLPath -Value $adaptiveIconXML -Encoding UTF8
    Set-Content -Path $launcherRoundXMLPath -Value $adaptiveIconXML -Encoding UTF8
}

Write-Host "  [OK] Created ic_launcher.xml" -ForegroundColor Green
Write-Host "  [OK] Created ic_launcher_round.xml" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "COMPLETE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Update AndroidManifest.xml with icon references" -ForegroundColor White
Write-Host "  2. Update launch_background.xml with dark background" -ForegroundColor White
Write-Host "  3. Build and test on Android 8+ device" -ForegroundColor White
Write-Host ""
