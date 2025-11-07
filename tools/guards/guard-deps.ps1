# Guard against vulnerable dependencies
$ErrorActionPreference = "Stop"

Write-Host "Checking dependencies..." -ForegroundColor Cyan

$issues = @()

# Check Flutter pubspec.lock files
$pubspecs = Get-ChildItem -Path "apps" -Filter "pubspec.lock" -Recurse -ErrorAction SilentlyContinue
foreach ($pubspec in $pubspecs) {
    $content = Get-Content $pubspec.FullName -Raw
    # Check for known vulnerable packages
    if ($content -match 'http:\s*\n\s*version:\s*"0\.[0-8]\.') {
        $issues += "  [!] $($pubspec.Directory.Name) - outdated http package"
    }
}

# Check package.json files (top-level only)
$topLevelDirs = @("functions", "admin_web")
foreach ($dir in $topLevelDirs) {
    if (Test-Path $dir) {
        $pkgPath = Join-Path $dir "package.json"
        $lockPath = Join-Path $dir "package-lock.json"
        if ((Test-Path $pkgPath) -and -not (Test-Path $lockPath)) {
            $issues += "  [!] $dir - missing package-lock.json"
        }
    }
}

# Check for keystore files in wrong locations
$keystores = Get-ChildItem -Path . -Include "*.jks","*.keystore" -Recurse -ErrorAction SilentlyContinue
foreach ($ks in $keystores) {
    $androidDir = [regex]::Escape(".android")
    $secureDir = [regex]::Escape("secure")
    if ($ks.FullName -notmatch "$androidDir|$secureDir") {
        $issues += "  [X] $($ks.FullName) - keystore in repository"
    }
}

if ($issues.Count -gt 0) {
    Write-Host ""
    Write-Host "DEPENDENCY ISSUES FOUND:" -ForegroundColor Yellow
    $issues | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
    Write-Host ""
    Write-Host "Push blocked. Fix issues above." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host "[OK] Dependencies OK" -ForegroundColor Green
exit 0
