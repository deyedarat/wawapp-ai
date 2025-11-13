# speckit.ps1 (drop-in)
[CmdletBinding()]
param(
  [Parameter(Position=0)]
  [ValidateSet(
    "init","doctor","help","fix:node-policy","env:verify","format","analyze",
    "flutter:refresh","build:driver","build:client","test:unit","test:analyze","env:verify-Firebase"
  )]
  [string]$cmd = "help",

  [switch]$VerboseLog
)

$ErrorActionPreference = "Stop"

# ثابت: مسار مجلد السكربت نفسه مهما كان مجلد التشغيل الحالي
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptRoot

function Write-Info($msg){ Write-Host "[Speckit] $msg" }
function Die($msg){ Write-Error "[Speckit] $msg"; exit 1 }

switch ($cmd) {
  "init" {
    $specDir   = Join-Path $ScriptRoot ".specify"
    $configYml = Join-Path $specDir "config.yaml"

    if (-not (Test-Path $specDir)) { New-Item -ItemType Directory -Force -Path $specDir | Out-Null }

    if (-not (Test-Path $configYml)) {
      Write-Info "Creating .specify/config.yaml ..."
@"
version: 1
meta:
  name: WawApp
  updated_at: $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
"@ | Set-Content $configYml -Encoding UTF8
    } else {
      Write-Info ".specify/config.yaml already exists."
    }
    Write-Info "Init complete."; exit 0
  }

  "doctor" {
    # تحديث PATH من سجل النظام
    $machine = [Environment]::GetEnvironmentVariable('Path','Machine')
    $user    = [Environment]::GetEnvironmentVariable('Path','User')
    $env:Path = "$machine;$user"
    
    $doctorPath = Join-Path $PSScriptRoot "tools\spec-kit\doctor.ps1"
    if (-not (Test-Path $doctorPath)) {
      Write-Error "[Speckit] Missing doctor script: $doctorPath"
      exit 1
    }
    Write-Host "[Speckit] == Speckit Doctor =="
    # نفّذ نفس الجلسة لتجنب مشاكل PATH/assoc
    & $doctorPath -Light:$true -VerboseLog:$VerboseLog
    $code = $LASTEXITCODE; if ($code -eq $null) { $code = 0 }
    Write-Host "[Speckit] Doctor finished with exit code $code"
    exit $code
  }

  "fix:node-policy" {
    $envModule = Join-Path $PSScriptRoot "tools\spec-kit\modules\env.ps1"
    if (-not (Test-Path $envModule)) {
      Die "Missing env module: $envModule"
    }
    . $envModule
    Fix-NodeExecutionPolicy
    exit 0
  }

  "env:verify" {
    $envModule = Join-Path $PSScriptRoot "tools\spec-kit\modules\env.ps1"
    if (-not (Test-Path $envModule)) {
      Die "Missing env module: $envModule"
    }
    . $envModule
    Invoke-EnvVerify
    exit 0
  }

  "format" {
    Write-Host "[SpecKit] Running dart formatter..." -ForegroundColor Cyan
    dart format .
    exit 0
  }

  "analyze" {
    Write-Host "[SpecKit] Running Flutter analyzer..." -ForegroundColor Cyan
    flutter analyze
    exit 0
  }

  # === Flutter helpers (Speckit) ===
  "flutter:refresh" {
    Write-Host "[Speckit] == Flutter Environment Refresh ==" -ForegroundColor Cyan
    foreach ($app in @("wawapp_client","wawapp_driver")) {
      $path = Join-Path $ScriptRoot "apps\$app"
      if (Test-Path "$path\pubspec.yaml") {
        Write-Host "[Speckit] -> Refreshing $app"
        Push-Location $path
        flutter clean
        flutter pub get
        Pop-Location
      } else {
        Write-Host "[Speckit] Skipped $app (no pubspec.yaml found)"
      }
    }
    Write-Host "[Speckit] Refresh done."
    exit 0
  }

 "build:driver" {
    # استخدم وسيط ثاني اختياري (Release أو Debug)
    $Configuration = if ($args.Length -gt 0) { $args[0] } else { "Debug" }
    $target = "apps/wawapp_driver/lib/main.dart"
    Write-Host "[Specify] == Building DRIVER ($Configuration) ==" -ForegroundColor Cyan
    if ($Configuration -eq "Release") {
        flutter build apk --release -t $target
    } else {
        flutter build apk --debug -t $target
    }
    exit $LASTEXITCODE
}

"build:client" {
    $Configuration = if ($args.Length -gt 0) { $args[0] } else { "Debug" }
    $target = "apps/wawapp_client/lib/main.dart"
    Write-Host "[Specify] == Building CLIENT ($Configuration) ==" -ForegroundColor Cyan
    if ($Configuration -eq "Release") {
        flutter build apk --release -t $target
    } else {
        flutter build apk --debug -t $target
    }
    exit $LASTEXITCODE
}


  "test:unit" {
    Write-Host "[Speckit] == Running unit/widget tests ==" -ForegroundColor Cyan
    flutter test
    exit $LASTEXITCODE
  }

  "test:analyze" {
    Write-Host "[Speckit] == Dart/Flutter Analyze (strict) ==" -ForegroundColor Cyan
    dart format . | Out-Null
    flutter analyze
    exit $LASTEXITCODE
  }

  "env:verify-Firebase" {
    Write-Host "[Speckit] == Verifying Firebase bindings ==" -ForegroundColor Cyan
    $found = $false
    Get-ChildItem -Path ".\apps" -Recurse -Include "google-services.json","firebase_options.dart" -ErrorAction SilentlyContinue | ForEach-Object {
      $found = $true
      Write-Host ("✔ " + $_.FullName)
    }
    if (-not $found) { Write-Host "⚠ No Firebase configs found under apps/" -ForegroundColor Yellow }
    exit 0
  }

  default {
@"
SpecKit (lite) commands:
  ./speckit.ps1 init            - create/refresh .specify/config.yaml (under script folder)
  ./speckit.ps1 doctor          - run environment & files checks
  ./speckit.ps1 fix:node-policy - bypass execution policy & verify npm
  ./speckit.ps1 env:verify      - verify all environment tools with hints
  ./speckit.ps1 format          - run dart format . --fix
  ./speckit.ps1 analyze         - run flutter analyze
  ./speckit.ps1 flutter:refresh - flutter clean + pub get via Speckit
  ./speckit.ps1 build:driver    - build driver APK (add -Configuration Release)
  ./speckit.ps1 build:client    - build client APK (add -Configuration Release)
  ./speckit.ps1 test:unit       - run flutter test
  ./speckit.ps1 test:analyze    - format + analyze
  ./speckit.ps1 env:verify-Firebase - quick Firebase linkage check
  ./speckit.ps1 help            - show this help
Options:
  -VerboseLog                   - pass through extra logging to doctor
"@ | Write-Host
    exit 0
  }
}
