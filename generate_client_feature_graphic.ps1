# WawApp Client - Feature Graphic Generator
# Generates Play Store feature graphic (1024x500) and hi-res icon (512x512)

param(
    [switch]$WhatIf = $false
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "WawApp Client - Feature Graphic Generator" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Paths
$sourceIcon = "apps\wawapp_client\android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png"
$outputDir = "play_store_assets\client"
$darkBgHex = "#000609"

# Verify source file
if (-not (Test-Path $sourceIcon)) {
    Write-Host "[ERROR] Source icon not found: $sourceIcon" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Found source icon: $sourceIcon" -ForegroundColor Green

# Create output directory
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    Write-Host "[CREATE] Output directory: $outputDir" -ForegroundColor Yellow
}

# Check for ImageMagick
$magick = Get-Command magick -ErrorAction SilentlyContinue
if (-not $magick) {
    Write-Host "[INFO] Using .NET image processing..." -ForegroundColor Yellow
    $useNET = $true
} else {
    Write-Host "[OK] ImageMagick found" -ForegroundColor Green
    $useNET = $false
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Generating Play Store Assets" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Asset 1: Feature Graphic (1024x500)
Write-Host "1. Feature Graphic (1024x500)..." -ForegroundColor Yellow

$featureGraphicPath = "$outputDir\feature_graphic.png"

if ($useNET) {
    Add-Type -AssemblyName System.Drawing

    $width = 1024
    $height = 500
    $bitmap = New-Object System.Drawing.Bitmap($width, $height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

    # High quality rendering
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

    # Dark background
    $color = [System.Drawing.ColorTranslator]::FromHtml($darkBgHex)
    $graphics.Clear($color)

    # Load icon
    $icon = [System.Drawing.Image]::FromFile((Resolve-Path $sourceIcon).Path)

    # Calculate scaling to fit nicely in feature graphic (leave margins)
    $maxIconWidth = [int]($width * 0.4)  # Use 40% of width for simpler look
    $maxIconHeight = [int]($height * 0.6) # Use 60% of height

    $scale = [Math]::Min($maxIconWidth / $icon.Width, $maxIconHeight / $icon.Height)
    $scaledWidth = [int]($icon.Width * $scale)
    $scaledHeight = [int]($icon.Height * $scale)

    # Center the icon
    $x = ($width - $scaledWidth) / 2
    $y = ($height - $scaledHeight) / 2

    $graphics.DrawImage($icon, $x, $y, $scaledWidth, $scaledHeight)

    if (-not $WhatIf) {
        $bitmap.Save($featureGraphicPath, [System.Drawing.Imaging.ImageFormat]::Png)
    }

    $icon.Dispose()
    $graphics.Dispose()
    $bitmap.Dispose()

    Write-Host "  [OK] Created: feature_graphic.png (1024x500)" -ForegroundColor Green
} else {
    # Use ImageMagick
    & magick convert -size 1024x500 "xc:$darkBgHex" `
        "$sourceIcon" -resize 400x300 -gravity center -composite `
        "$featureGraphicPath"
    Write-Host "  [OK] Created: feature_graphic.png (1024x500)" -ForegroundColor Green
}

# Asset 2: Hi-Res Icon (512x512) - For Play Store listing
Write-Host "2. Hi-Res Icon (512x512)..." -ForegroundColor Yellow

$hiResIconPath = "$outputDir\hi_res_icon.png"

if ($useNET) {
    Add-Type -AssemblyName System.Drawing

    $size = 512
    $bitmap = New-Object System.Drawing.Bitmap($size, $size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

    # Transparent background for hi-res icon (Play Store requirement)
    $graphics.Clear([System.Drawing.Color]::Transparent)

    # Load icon
    $icon = [System.Drawing.Image]::FromFile((Resolve-Path $sourceIcon).Path)

    # Scale to 512x512 (upscale from 192x192 xxxhdpi)
    $graphics.DrawImage($icon, 0, 0, $size, $size)

    if (-not $WhatIf) {
        $bitmap.Save($hiResIconPath, [System.Drawing.Imaging.ImageFormat]::Png)
    }

    $icon.Dispose()
    $graphics.Dispose()
    $bitmap.Dispose()

    Write-Host "  [OK] Created: hi_res_icon.png (512x512)" -ForegroundColor Green
} else {
    & magick convert "$sourceIcon" -resize 512x512 -background transparent -gravity center -extent 512x512 "$hiResIconPath"
    Write-Host "  [OK] Created: hi_res_icon.png (512x512)" -ForegroundColor Green
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "COMPLETE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Play Store assets created in: $outputDir" -ForegroundColor Green
Write-Host ""
Write-Host "Assets created:" -ForegroundColor Yellow
Write-Host "  - feature_graphic.png (1024x500) - Required for Play Store listing" -ForegroundColor White
Write-Host "  - hi_res_icon.png (512x512) - Required for Play Store listing" -ForegroundColor White
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Build Client release AAB" -ForegroundColor White
Write-Host "  2. Test on Android 12+ device to verify splash screen" -ForegroundColor White
Write-Host "  3. Upload assets when creating Play Store listing" -ForegroundColor White
Write-Host ""
