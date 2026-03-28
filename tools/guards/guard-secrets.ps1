# Guard against committing secrets
$ErrorActionPreference = "Stop"

$patterns = @(
    '(?i)(api[_-]?key|apikey)\s*[:=]\s*[''""]?[a-zA-Z0-9_\-]{20,}',
    '(?i)(secret|password|passwd|pwd)\s*[:=]\s*[''""]?[^\s''""\n]{8,}',
    '(?i)(firebase|aws|gcp)[_-]?(key|secret|token)\s*[:=]',
    '(?i)bearer\s+[a-zA-Z0-9_\-\.]{20,}',
    '(?i)(private[_-]?key|privatekey)\s*[:=]',
    'AIza[0-9A-Za-z\-_]{35}',
    'AKIA[0-9A-Z]{16}',
    '[0-9]+-[0-9A-Za-z_]{32}\.apps\.googleusercontent\.com'
)

$excludePaths = @('*.md', '*.example', '*.sample', 'docs/*', '.gitignore')

Write-Host "Scanning for secrets..." -ForegroundColor Cyan

$files = git diff --cached --name-only --diff-filter=ACM
if (-not $files) { 
    Write-Host "[OK] No staged files" -ForegroundColor Green
    exit 0 
}

$violations = @()

foreach ($file in $files) {
    $skip = $false
    foreach ($exclude in $excludePaths) {
        if ($file -like $exclude) { $skip = $true; break }
    }
    if ($skip) { continue }
    if (-not (Test-Path $file)) { continue }

    $content = Get-Content $file -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }

    foreach ($pattern in $patterns) {
        if ($content -match $pattern) {
            $violations += "  [X] $file - potential secret detected"
            break
        }
    }
}

if ($violations.Count -gt 0) {
    Write-Host ""
    Write-Host "SECRET LEAK DETECTED!" -ForegroundColor Red
    $violations | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    Write-Host ""
    Write-Host "Commit blocked. Remove secrets or use .env files." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host "[OK] No secrets detected" -ForegroundColor Green
exit 0
