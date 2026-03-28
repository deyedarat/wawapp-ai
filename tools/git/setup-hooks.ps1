# Setup Git hooks for security guards
$ErrorActionPreference = "Stop"

$hooksDir = ".git\hooks"
$rootDir = (Get-Location).Path

if (-not (Test-Path $hooksDir)) {
    Write-Host "ERROR: Not a git repository" -ForegroundColor Red
    exit 1
}

Write-Host "Installing Git hooks..." -ForegroundColor Cyan

# Pre-commit hook
$preCommitPath = Join-Path $hooksDir "pre-commit"
$preCommitContent = "#!/bin/sh`npowershell.exe -ExecutionPolicy Bypass -File `"$rootDir\tools\guards\guard-secrets.ps1`""

Set-Content -Path $preCommitPath -Value $preCommitContent -NoNewline
Write-Host "[OK] Installed pre-commit hook (secrets guard)" -ForegroundColor Green

# Pre-push hook
$prePushPath = Join-Path $hooksDir "pre-push"
$prePushContent = "#!/bin/sh`npowershell.exe -ExecutionPolicy Bypass -File `"$rootDir\tools\guards\guard-deps.ps1`""

Set-Content -Path $prePushPath -Value $prePushContent -NoNewline
Write-Host "[OK] Installed pre-push hook (deps guard)" -ForegroundColor Green

Write-Host ""
Write-Host "Git hooks installed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Hooks active:" -ForegroundColor Cyan
Write-Host "  - pre-commit: Blocks secrets" -ForegroundColor White
Write-Host "  - pre-push: Checks dependencies" -ForegroundColor White
Write-Host ""

exit 0
