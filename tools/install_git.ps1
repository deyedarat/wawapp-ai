# Install Git via Scoop

Write-Host "[install] Setting up Git..." -ForegroundColor Cyan

# 1) Enable TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 2) Check if Scoop exists
if (!(Get-Command scoop -ErrorAction SilentlyContinue)) {
  Write-Host "[install] Installing Scoop..." -ForegroundColor Yellow
  iwr -useb get.scoop.sh | iex
} else {
  Write-Host "✓ Scoop already installed" -ForegroundColor Green
}

# 3) Install Git
if (!(Get-Command git -ErrorAction SilentlyContinue)) {
  Write-Host "[install] Installing Git..." -ForegroundColor Yellow
  scoop install git
} else {
  Write-Host "✓ Git already installed" -ForegroundColor Green
}

# 4) Verify
Write-Host "`n[install] Verification:" -ForegroundColor Cyan
git --version
where.exe git

Write-Host "`n[install] Git setup complete. Restart PowerShell if needed." -ForegroundColor Green
