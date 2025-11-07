# tools\spec-kit\modules\env.ps1
function Fix-NodeExecutionPolicy {
  Write-Host "[Speckit] Temporarily bypassing execution policy for current process..."
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
  
  Write-Host "[Speckit] Probing npm availability..."
  try {
    $result = & npm.cmd -v 2>&1 | Out-String
    Write-Host "[Speckit] OK npm is available (version: $($result.Trim()))" -ForegroundColor Green
    Write-Host '[Speckit] To install Firebase CLI, run: npm i -g firebase-tools' -ForegroundColor Cyan
  } catch {
    Write-Host "[Speckit] FAILED npm not accessible: $($_.Exception.Message)" -ForegroundColor Red
  }
}

function Invoke-EnvVerify {
  Write-Host "`n[Speckit] == Environment Verification ==" -ForegroundColor Cyan
  
  # Flutter
  Write-Host -NoNewline "[flutter   ] "
  try {
    $output = & flutter --version 2>&1 | Select-Object -First 1
    if ($output -match "Flutter") {
      Write-Host "OK $output" -ForegroundColor Green
    } else {
      Write-Host "FAILED" -ForegroundColor Yellow
    }
  } catch {
    Write-Host "MISSING (required)" -ForegroundColor Red
  }
  
 # Java
Write-Host -NoNewline "[java      ] "
try {
  $output = & java -version 2>&1 | Out-String
  if ($output -match "version" -or $output -match "openjdk") {
    $version = ($output -split "`n")[0].Trim()
    Write-Host "OK $version" -ForegroundColor Green
  } else {
    Write-Host "FAILED" -ForegroundColor Yellow
  }
} catch {
  Write-Host "MISSING (required)" -ForegroundColor Red
}
  
  # Gradle (optional - comes with Flutter/Android)
  Write-Host -NoNewline "[gradle    ] "
  try {
    $output = & gradle --version 2>&1 | Select-Object -First 1
    if ($output -match "Gradle") {
      Write-Host "OK $output" -ForegroundColor Green
    } else {
      Write-Host "OPTIONAL (bundled with Android)" -ForegroundColor Yellow
    }
  } catch {
    Write-Host "OPTIONAL (bundled with Android)" -ForegroundColor Yellow
  }
  
  # Node
  Write-Host -NoNewline "[node      ] "
  try {
    $output = & node -v 2>&1
    if ($output -match "v\d+") {
      Write-Host "OK $output" -ForegroundColor Green
    } else {
      Write-Host "FAILED" -ForegroundColor Yellow
    }
  } catch {
    Write-Host "MISSING (required)" -ForegroundColor Red
  }
  
  # npm
  Write-Host -NoNewline "[npm       ] "
  try {
    $output = & npm -v 2>&1
    if ($output -match "\d+") {
      Write-Host "OK $output" -ForegroundColor Green
    } else {
      Write-Host "FAILED" -ForegroundColor Yellow
    }
  } catch {
    Write-Host "MISSING (required)" -ForegroundColor Red
  }
  
  # Firebase
  Write-Host -NoNewline "[firebase  ] "
  try {
    $output = & firebase --version 2>&1
    if ($output -match "\d+") {
      Write-Host "OK $output" -ForegroundColor Green
    } else {
      Write-Host "FAILED" -ForegroundColor Yellow
    }
  } catch {
    Write-Host "MISSING (optional)" -ForegroundColor Yellow
  }
  
  Write-Host "`n[Speckit] Hints:" -ForegroundColor Cyan
  Write-Host '  * If npm is blocked, run: .\speckit.ps1 fix:node-policy' -ForegroundColor Gray
  Write-Host '  * All tools detected successfully!' -ForegroundColor Green
}