# tools\spec-kit\modules\env.ps1

function Fix-NodeExecutionPolicy {
  Write-Host "[Speckit] Temporarily bypassing execution policy for current process..."
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
  
  Write-Host "[Speckit] Probing npm availability..."
  try {
    $result = & npm.cmd -v 2>&1
    if ($LASTEXITCODE -eq 0) {
      Write-Host "[Speckit] OK npm is available (version: $result)" -ForegroundColor Green
      Write-Host '[Speckit] To install Firebase CLI, run: npm i -g firebase-tools' -ForegroundColor Cyan
    } else {
      Write-Host "[Speckit] FAILED npm command failed" -ForegroundColor Red
    }
  } catch {
    Write-Host "[Speckit] FAILED npm not accessible: $($_.Exception.Message)" -ForegroundColor Red
  }
}

function Invoke-EnvVerify {
  Write-Host "`n[Speckit] == Environment Verification ==" -ForegroundColor Cyan
  
  $checks = @(
    @{Name='flutter'; Args='--version'; Required=$false},
    @{Name='java'; Args='-version'; Required=$true},
    @{Name='gradle'; Args='--version'; Required=$true},
    @{Name='node'; Args='-v'; Required=$true},
    @{Name='npm'; Args='-v'; Required=$true},
    @{Name='firebase'; Args='--version'; Required=$false}
  )
  
  foreach ($check in $checks) {
    Write-Host -NoNewline ("[{0,-10}] " -f $check.Name)
    try {
      $cmd = if ($check.Name -eq 'npm') { 'npm.cmd' } else { $check.Name }
      $output = & $cmd $check.Args 2>&1 | Select-Object -First 1
      if ($LASTEXITCODE -eq 0) {
        Write-Host "OK $output" -ForegroundColor Green
      } else {
        Write-Host "FAILED" -ForegroundColor Yellow
      }
    } catch {
      if ($check.Required) {
        Write-Host "MISSING (required)" -ForegroundColor Red
      } else {
        Write-Host "MISSING (optional)" -ForegroundColor Yellow
        if ($check.Name -eq 'flutter') {
          Write-Host '           -> Install from: https://flutter.dev/docs/get-started/install' -ForegroundColor Gray
        } elseif ($check.Name -eq 'firebase') {
          Write-Host '           -> Install with: npm i -g firebase-tools' -ForegroundColor Gray
        }
      }
    }
  }
  
  Write-Host "`n[Speckit] Hints:" -ForegroundColor Cyan
  Write-Host '  * If npm is blocked, run: .\speckit.ps1 fix:node-policy' -ForegroundColor Gray
  Write-Host '  * Flutter must be installed manually from flutter.dev' -ForegroundColor Gray
  Write-Host '  * Firebase CLI: npm i -g firebase-tools (after npm is working)' -ForegroundColor Gray
}
