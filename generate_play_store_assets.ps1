# WawApp Driver - Play Store Assets Generator
# Generates Play Store feature graphic (1024x500) and hi-res icon (512x512)

param(
    [switch]$WhatIf = $false
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "WawApp Driver - Play Store Assets" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Paths
$sourceLogo = "apps\wawapp_driver\assets\icons\driver_logo_main.png"
$sourceLogoWithText = "apps\wawapp_driver\assets\icons\driver_logo_with_text.png"
$outputDir = "play_store_assets\driver"
$darkBgHex = "#000609"

# Verify source files
if (-not (Test-Path $sourceLogo)) {
    Write-Host "[ERROR] Source logo not found: $sourceLogo" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Found source logo" -ForegroundColor Green

# Create output directory
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    Write-Host "[CREATE] Output directory: $outputDir" -ForegroundColor Yellow
}

# Check for ImageMagick
$magick = Get-Command magick -ErrorAction SilentlyContinue
if (-not $magick) {
    Write-Host "[WARNING] ImageMagick not found. Using .NET image processing..." -ForegroundColor Yellow
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

    # Load logo with text if available, otherwise use main logo
    $logoPath = if (Test-Path $sourceLogoWithText) { $sourceLogoWithText } else { $sourceLogo }
    $logo = [System.Drawing.Image]::FromFile((Resolve-Path $logoPath).Path)

    # Calculate scaling to fit nicely in feature graphic (leave margins)
    $maxLogoWidth = [int]($width * 0.6)  # Use 60% of width
    $maxLogoHeight = [int]($height * 0.7) # Use 70% of height

    $scale = [Math]::Min($maxLogoWidth / $logo.Width, $maxLogoHeight / $logo.Height)
    $scaledWidth = [int]($logo.Width * $scale)
    $scaledHeight = [int]($logo.Height * $scale)

    # Center the logo
    $x = ($width - $scaledWidth) / 2
    $y = ($height - $scaledHeight) / 2

    $graphics.DrawImage($logo, $x, $y, $scaledWidth, $scaledHeight)

    if (-not $WhatIf) {
        $bitmap.Save($featureGraphicPath, [System.Drawing.Imaging.ImageFormat]::Png)
    }

    $logo.Dispose()
    $graphics.Dispose()
    $bitmap.Dispose()

    Write-Host "  [OK] Created: feature_graphic.png (1024x500)" -ForegroundColor Green
} else {
    # Use ImageMagick
    $logoPath = if (Test-Path $sourceLogoWithText) { $sourceLogoWithText } else { $sourceLogo }
    & magick convert -size 1024x500 "xc:$darkBgHex" `
        "$logoPath" -resize 600x350 -gravity center -composite `
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

    # Dark background
    $color = [System.Drawing.ColorTranslator]::FromHtml($darkBgHex)
    $graphics.Clear($color)

    # Load main logo (no text for icon)
    $logo = [System.Drawing.Image]::FromFile((Resolve-Path $sourceLogo).Path)

    # Scale to fit within safe zone (80% of size)
    $maxSize = [int]($size * 0.8)
    $scale = [Math]::Min($maxSize / $logo.Width, $maxSize / $logo.Height)
    $scaledWidth = [int]($logo.Width * $scale)
    $scaledHeight = [int]($logo.Height * $scale)

    # Center
    $x = ($size - $scaledWidth) / 2
    $y = ($size - $scaledHeight) / 2

    $graphics.DrawImage($logo, $x, $y, $scaledWidth, $scaledHeight)

    if (-not $WhatIf) {
        $bitmap.Save($hiResIconPath, [System.Drawing.Imaging.ImageFormat]::Png)
    }

    $logo.Dispose()
    $graphics.Dispose()
    $bitmap.Dispose()

    Write-Host "  [OK] Created: hi_res_icon.png (512x512)" -ForegroundColor Green
} else {
    & magick convert -size 512x512 "xc:$darkBgHex" `
        "$sourceLogo" -resize 410x410 -gravity center -composite `
        "$hiResIconPath"
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
Write-Host "  1. Upload these assets when creating Play Store listing" -ForegroundColor White
Write-Host "  2. Add screenshots (at least 2, up to 8)" -ForegroundColor White
Write-Host "  3. Complete app description and metadata" -ForegroundColor White
Write-Host ""
