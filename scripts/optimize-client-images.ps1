# Memory Optimization Phase 1.1: Image Compression Script
# Converts PNG images to WebP format for Client App
# Expected savings: 15-25MB

$ErrorActionPreference = "Stop"

Write-Host "=== Client App Image Optimization ===" -ForegroundColor Cyan
Write-Host ""

$iconsDir = "apps\wawapp_client\assets\icons"
$images = @(
    @{Name="splash_client_bg.png"; ExpectedSize="200KB"},
    @{Name="splash_client_logo.png"; ExpectedSize="150KB"},
    @{Name="wawapp_client_1024.png"; ExpectedSize="220KB"},
    @{Name="wawapp_client_adaptive_bg.png"; ExpectedSize="80KB"}
)

# Check if cwebp is available
$cwebpPath = Get-Command cwebp -ErrorAction SilentlyContinue
if (-not $cwebpPath) {
    Write-Host "❌ ERROR: cwebp not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install WebP tools:" -ForegroundColor Yellow
    Write-Host "  Windows: Download from https://developers.google.com/speed/webp/download" -ForegroundColor Yellow
    Write-Host "  Or use: choco install webp" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Alternative: Use online converter or ImageMagick:" -ForegroundColor Yellow
    Write-Host "  magick convert input.png -quality 85 output.webp" -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ cwebp found at: $($cwebpPath.Source)" -ForegroundColor Green
Write-Host ""

# Check if icons directory exists
if (-not (Test-Path $iconsDir)) {
    Write-Host "❌ ERROR: Icons directory not found: $iconsDir" -ForegroundColor Red
    exit 1
}

Write-Host "Processing images in: $iconsDir" -ForegroundColor Cyan
Write-Host ""

$converted = 0
$skipped = 0
$failed = 0

foreach ($img in $images) {
    $pngPath = Join-Path $iconsDir $img.Name
    $webpName = $img.Name -replace "\.png$", ".webp"
    $webpPath = Join-Path $iconsDir $webpName
    
    if (-not (Test-Path $pngPath)) {
        Write-Host "⚠️  SKIP: $($img.Name) not found" -ForegroundColor Yellow
        $skipped++
        continue
    }
    
    if (Test-Path $webpPath) {
        Write-Host "⚠️  SKIP: $webpName already exists" -ForegroundColor Yellow
        $skipped++
        continue
    }
    
    $pngSize = (Get-Item $pngPath).Length / 1KB
    Write-Host "Converting: $($img.Name) ($([math]::Round($pngSize, 2)) KB)..." -ForegroundColor Cyan
    
    try {
        # Convert to WebP with quality 85
        & cwebp -q 85 $pngPath -o $webpPath
        
        if (Test-Path $webpPath) {
            $webpSize = (Get-Item $webpPath).Length / 1KB
            $savings = $pngSize - $webpSize
            $savingsPercent = [math]::Round(($savings / $pngSize) * 100, 1)
            
            Write-Host "  ✓ Created: $webpName ($([math]::Round($webpSize, 2)) KB)" -ForegroundColor Green
            Write-Host "  ✓ Savings: $([math]::Round($savings, 2)) KB ($savingsPercent%)" -ForegroundColor Green
            
            if ($webpSize -gt ($img.ExpectedSize -replace "KB", "")) {
                Write-Host "  ⚠️  Size larger than expected ($($img.ExpectedSize))" -ForegroundColor Yellow
            }
            
            $converted++
        } else {
            Write-Host "  ❌ Failed: Output file not created" -ForegroundColor Red
            $failed++
        }
    } catch {
        Write-Host "  ❌ Error: $_" -ForegroundColor Red
        $failed++
    }
    
    Write-Host ""
}

Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "Converted: $converted" -ForegroundColor Green
Write-Host "Skipped: $skipped" -ForegroundColor Yellow
Write-Host "Failed: $failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($converted -gt 0) {
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Update pubspec.yaml to use .webp files" -ForegroundColor Yellow
    Write-Host "2. Run: flutter pub get" -ForegroundColor Yellow
    Write-Host "3. Test the app to ensure images load correctly" -ForegroundColor Yellow
    Write-Host "4. Delete original .png files after verification" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "⚠️  NOTE: flutter_launcher_icons and flutter_native_splash" -ForegroundColor Yellow
    Write-Host "    may need PNG files. Keep originals until verified." -ForegroundColor Yellow
}

