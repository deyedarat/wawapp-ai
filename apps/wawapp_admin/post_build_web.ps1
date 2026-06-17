# Post-build script: Fix flutter_bootstrap.js renderer for Google Maps compatibility
# Run this after: flutter build web --release
#
# Problem: google_maps_flutter_web requires "html" renderer to register its ViewFactory.
#          Flutter 3.35+ builds with "canvaskit" by default, which prevents
#          registerViewFactory("plugins.flutter.io/google_maps") from being called.
#
# Usage: 
#   flutter build web --release
#   .\post_build_web.ps1
#   firebase deploy --only hosting

$bootstrapFile = "build\web\flutter_bootstrap.js"

if (Test-Path $bootstrapFile) {
    $content = Get-Content $bootstrapFile -Raw
    if ($content -match '"renderer":"canvaskit"') {
        $content = $content -replace '"renderer":"canvaskit"', '"renderer":"html"'
        Set-Content $bootstrapFile -Value $content -NoNewline
        Write-Host "✅ Patched renderer: canvaskit -> html in $bootstrapFile" -ForegroundColor Green
    } elseif ($content -match '"renderer":"html"') {
        Write-Host "✅ Renderer already set to html — no patch needed." -ForegroundColor Green
    } else {
        Write-Host "⚠️  Could not find renderer field in $bootstrapFile" -ForegroundColor Yellow
    }
} else {
    Write-Host "❌ $bootstrapFile not found. Run 'flutter build web --release' first." -ForegroundColor Red
    exit 1
}
