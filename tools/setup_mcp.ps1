# Setup MCP and VS Code settings
if (!(Test-Path .mcp)) { mkdir .mcp | Out-Null }
if (!(Test-Path .vscode)) { mkdir .vscode | Out-Null }
if (!(Test-Path .git-hooks)) { mkdir .git-hooks | Out-Null }

Copy-Item mcp_servers.json .mcp\servers.json -Force
Copy-Item mcp_ignore.txt .mcp\ignore.txt -Force
Copy-Item vscode_settings.json .vscode\settings.json -Force
Copy-Item tools\arch_guard.ps1 .git-hooks\pre-commit.ps1 -Force

git config core.hooksPath .git-hooks

Write-Host "[setup] MCP and VS Code configured successfully"
