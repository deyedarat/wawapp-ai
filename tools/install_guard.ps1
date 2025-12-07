Write-Host "[install] Setting up architecture guard..."

if (!(Test-Path .git-hooks)) { mkdir .git-hooks | Out-Null }

@"
pwsh -NoProfile -File tools/arch_guard.ps1
if (`$LASTEXITCODE -ne 0) { exit 1 }
"@ | Out-File -Encoding utf8 .git-hooks\pre-commit.ps1

git config core.hooksPath .git-hooks

Write-Host "[install] Architecture guard installed successfully"
Write-Host "[install] Test it: .\tools\arch_guard.ps1"
