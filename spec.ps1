param(
  [Parameter(ValueFromRemainingArguments)]
  [string[]]$Rest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function _ok($name,$extra=""){ Write-Host ("{0,-8}: OK  {1}" -f $name,$extra) -ForegroundColor Green }
function _miss($name,$extra=""){ Write-Host ("{0,-8}: MISSING {1}" -f $name,$extra) -ForegroundColor Yellow }

function _firstLine($v){
  if ($null -eq $v) { return "" }
  $s = ($v | Out-String)
  return ($s -split "`r?`n")[0]
}

function _tool($exe, $label){
  try {
    $v = & $exe --version 2>$null
    if ($LASTEXITCODE -eq 0 -and $v) {
      $first = _firstLine $v
      _ok $label "($first)"
    } else {
      _miss $label
    }
  } catch { _miss $label }
}

function Show-Help {
@"
Usage:
  .\spec.ps1 doctor
  .\spec.ps1 env:verify

  .\spec.ps1 app:driver pubget|analyze|build:debug|run
  .\spec.ps1 app:client pubget|analyze|build:debug|run
"@ | Write-Host
}

function Invoke-Doctor {
  Write-Host "[Speckit] == Speckit Doctor ==" -ForegroundColor Cyan
  Write-Host ("Project Root : {0}" -f (Get-Location).Path)

  Write-Host "Environment Report:"
  _tool "flutter"   "flutter"
  _tool "node"      "node"
  _tool "npm"       "npm"
  _tool "java"      "java"
  try {
    $gv = & gradle -v 2>$null
    if ($LASTEXITCODE -eq 0 -and $gv) { _ok "gradle" "(system)" } else { _miss "gradle" }
  } catch { _miss "gradle" }

  # Wrappers (نعرض المسارات نصيًا بلا GetRelativePath)
  $drv = "apps\wawapp_driver\android\gradlew.bat"
  $cli = "apps\wawapp_client\android\gradlew.bat"
  $top = "android\gradlew.bat"

  if (Test-Path $top) { _ok "gradle" "($top)" } else { _miss "gradle" "($top)" }
  if (Test-Path $cli) { _ok "gradle" "($cli)" } else { _miss "gradle" "($cli)" }
  if (Test-Path $drv) { _ok "gradle" "($drv)" } else { _miss "gradle" "($drv)" }
}

function Invoke-EnvVerify {
  Write-Host "[env:verify]" -ForegroundColor Cyan
  $checks = @(
    @{ path="apps\wawapp_client\android\app\google-services.json" },
    @{ path="apps\wawapp_driver\android\app\google-services.json" },
    @{ path="apps\wawapp_driver\android\app\src\main\res\values\api_keys.xml" }
  )
  foreach ($c in $checks){
    if (Test-Path $c.path) { Write-Host ("[env:verify] OK  {0}" -f $c.path) -ForegroundColor Green }
    else { Write-Host ("[env:verify] MISSING {0}" -f $c.path) -ForegroundColor Yellow }
  }
}

function Invoke-AppTask {
  param([string]$app, [string]$task)

  $proj = switch ($app) {
    "driver" { "apps\wawapp_driver" }
    "client" { "apps\wawapp_client" }
    default  { "" }
  }
  if (-not $proj) { throw "Unknown app '$app' (use driver|client)" }

  Push-Location $proj
  try {
    switch ($task) {
      "pubget"      { & flutter pub get }
      "analyze"     { & dart format . --set-exit-if-changed; & flutter analyze }
      "build:debug" { & flutter build apk --debug }
      "run"         { & flutter run }
      default       { throw "Unknown task '$task'" }
    }
  } finally { Pop-Location }
}

if (-not $Rest -or $Rest.Count -eq 0) { Show-Help; exit 0 }

$cmd = $Rest[0]
$sub = @($Rest | Select-Object -Skip 1)

switch -Wildcard ($cmd) {
  "doctor"       { Invoke-Doctor; break }
  "env:verify"   { Invoke-EnvVerify; break }
  "app:driver"   { if ($sub.Count -lt 1) { Show-Help; exit 1 }; Invoke-AppTask -app "driver" -task $sub[0]; break }
  "app:client"   { if ($sub.Count -lt 1) { Show-Help; exit 1 }; Invoke-AppTask -app "client" -task $sub[0]; break }
  default        { Show-Help; exit 1 }
}
