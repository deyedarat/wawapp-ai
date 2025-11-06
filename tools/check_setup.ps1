Write-Host "[check] Verifying MCP + Guard setup..." -ForegroundColor Cyan

# 0) Git check
if (Get-Command git -ErrorAction SilentlyContinue) {
  Write-Host "✓ Git installed: $(git --version)" -ForegroundColor Green
} else {
  Write-Host "✗ Git not found. Run: .\tools\install_git.ps1" -ForegroundColor Red
  exit 1
}

# 1) Git hooks
$hooksPath = git config --get core.hooksPath
if ($hooksPath -eq ".git-hooks") {
  Write-Host "✓ Git hooks enabled: $hooksPath" -ForegroundColor Green
} else {
  Write-Host "✗ Git hooks not configured. Run: git config core.hooksPath .git-hooks" -ForegroundColor Red
}

# 2) Architecture guard
if (Test-Path tools\arch_guard.ps1) {
  Write-Host "✓ Architecture guard exists" -ForegroundColor Green
  Write-Host "  Running guard check..." -ForegroundColor Yellow
  & .\tools\arch_guard.ps1
} else {
  Write-Host "✗ Architecture guard missing" -ForegroundColor Red
}

# 3) MCP files
if (Test-Path mcp_servers.json) {
  Write-Host "✓ MCP servers config exists" -ForegroundColor Green
} else {
  Write-Host "✗ MCP servers config missing" -ForegroundColor Red
}

# 4) VS Code settings
if (Test-Path vscode_settings.json) {
  Write-Host "✓ VS Code settings template exists" -ForegroundColor Green
  Write-Host "  Note: Copy to .vscode\settings.json if needed" -ForegroundColor Yellow
} else {
  Write-Host "✗ VS Code settings missing" -ForegroundColor Red
}

Write-Host "`n[check] Setup verification complete" -ForegroundColor Cyan
