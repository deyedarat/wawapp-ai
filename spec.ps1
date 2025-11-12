param(
    [Parameter(Position=0)]
    [ValidateSet('init','doctor','help','env:verify','fix:node-policy','format','analyze','flutter:refresh','build:driver','build:client','test:unit','test:analyze','env:verify-Firebase','fcm:verify')]
    [string]$Command = 'help',
    
    [Parameter(Position=1)]
    [string]$Config
)

$ErrorActionPreference = "Stop"
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptRoot

# Reload PATH from registry
$machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
$userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
$env:Path = "$machinePath;$userPath"

function Show-Help {
    Write-Host @"
Spec tasks:
  .\spec.ps1 init
  .\spec.ps1 doctor
  .\spec.ps1 env:verify
  .\spec.ps1 fix:node-policy
  .\spec.ps1 format
  .\spec.ps1 analyze
  .\spec.ps1 flutter:refresh
  .\spec.ps1 build:driver           [Debug|Release]
  .\spec.ps1 build:client           [Debug|Release]
  .\spec.ps1 test:unit
  .\spec.ps1 test:analyze
  .\spec.ps1 env:verify-Firebase
  .\spec.ps1 fcm:verify

Examples:
  .\spec.ps1 flutter:refresh
  .\spec.ps1 build:driver Debug
  .\spec.ps1 build:client Release
"@
}

function Invoke-Init {
    Write-Host "[INIT] Creating .specify/config.yaml..."
    $specifyDir = Join-Path $ScriptRoot ".specify"
    if (-not (Test-Path $specifyDir)) {
        New-Item -ItemType Directory -Path $specifyDir -Force | Out-Null
    }
    $configPath = Join-Path $specifyDir "config.yaml"
    if (-not (Test-Path $configPath)) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        @"
version: 1.0
name: WawApp
timestamp: $timestamp
"@ | Out-File -FilePath $configPath -Encoding UTF8
        Write-Host "[INIT] SUCCESS: Config created at .specify/config.yaml"
    } else {
        Write-Host "[INIT] Config already exists"
    }
}

function Invoke-Doctor {
    Write-Host "[DOCTOR] Running diagnostics..."
    $doctorPath = Join-Path $ScriptRoot "tools\spec-kit\doctor.ps1"
    if (Test-Path $doctorPath) {
        & $doctorPath -Light:$true
        Write-Host "[DOCTOR] SUCCESS"
    } else {
        Write-Warning "doctor script not found at $doctorPath"
    }
}

function Invoke-EnvVerify {
    Write-Host "[ENV:VERIFY] Verifying environment..."
    $envPath = Join-Path $ScriptRoot "tools\spec-kit\modules\env.ps1"
    if (Test-Path $envPath) {
        . $envPath
        Invoke-EnvVerify
        Write-Host "[ENV:VERIFY] SUCCESS"
    } else {
        Write-Warning "env module not found at $envPath"
    }
}

function Invoke-FixNodePolicy {
    Write-Host "[FIX:NODE-POLICY] Fixing Node execution policy..."
    $envPath = Join-Path $ScriptRoot "tools\spec-kit\modules\env.ps1"
    if (Test-Path $envPath) {
        . $envPath
        Fix-NodeExecutionPolicy
        Write-Host "[FIX:NODE-POLICY] SUCCESS"
    } else {
        Write-Warning "env module not found at $envPath"
    }
}

function Invoke-Format {
    Write-Host "[FORMAT] Running dart format..."
    dart format .
    if ($LASTEXITCODE -ne 0) {
        Write-Error "dart format failed"
        exit 1
    }
    Write-Host "[FORMAT] SUCCESS"
}

function Invoke-Analyze {
    Write-Host "[ANALYZE] Running flutter analyze..."
    flutter analyze
    if ($LASTEXITCODE -ne 0) {
        Write-Error "flutter analyze failed"
        exit 1
    }
    Write-Host "[ANALYZE] SUCCESS"
}

function Invoke-FlutterRefresh {
    Write-Host "[FLUTTER:REFRESH] Refreshing Flutter projects..."
    $apps = @('apps\wawapp_client', 'apps\wawapp_driver')
    foreach ($app in $apps) {
        $appPath = Join-Path $ScriptRoot $app
        $pubspecPath = Join-Path $appPath "pubspec.yaml"
        if (Test-Path $pubspecPath) {
            $appName = Split-Path $app -Leaf
            Write-Host "Refreshing $appName..."
            Push-Location $appPath
            try {
                flutter clean
                if ($LASTEXITCODE -ne 0) {
                    Write-Error "flutter clean failed for $appName"
                    exit 1
                }
                flutter pub get
                if ($LASTEXITCODE -ne 0) {
                    Write-Error "flutter pub get failed for $appName"
                    exit 1
                }
            } finally {
                Pop-Location
            }
        }
    }
    Write-Host "[FLUTTER:REFRESH] SUCCESS"
}

function Invoke-BuildDriver {
    param([string]$Config)
    $mode = if ($Config) { $Config } else { "Debug" }
    Write-Host "[BUILD:DRIVER] Building DRIVER ($mode)..."
    $appPath = Join-Path $ScriptRoot "apps\wawapp_driver"
    Push-Location $appPath
    try {
        if ($mode -eq "Release") {
            flutter build apk --release
        } else {
            flutter build apk --debug
        }
        $exitCode = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    exit $exitCode
}

function Invoke-BuildClient {
    param([string]$Config)
    $mode = if ($Config) { $Config } else { "Debug" }
    Write-Host "[BUILD:CLIENT] Building CLIENT ($mode)..."
    $appPath = Join-Path $ScriptRoot "apps\wawapp_client"
    Push-Location $appPath
    try {
        if ($mode -eq "Release") {
            flutter build apk --release
        } else {
            flutter build apk --debug
        }
        $exitCode = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    exit $exitCode
}

function Invoke-TestUnit {
    Write-Host "[TEST:UNIT] Running unit tests..."
    flutter test
    exit $LASTEXITCODE
}

function Invoke-TestAnalyze {
    Write-Host "[TEST:ANALYZE] Running format and analyze..."
    dart format . > $null
    flutter analyze
    exit $LASTEXITCODE
}

function Invoke-EnvVerifyFirebase {
    Write-Host "[ENV:VERIFY-FIREBASE] Checking Firebase configuration..."
    $appsDir = Join-Path $ScriptRoot "apps"
    $found = $false
    
    $googleServices = Get-ChildItem -Path $appsDir -Recurse -Filter "google-services.json" -ErrorAction SilentlyContinue
    foreach ($file in $googleServices) {
        Write-Host "FOUND: $($file.FullName)"
        $found = $true
    }
    
    $firebaseOptions = Get-ChildItem -Path $appsDir -Recurse -Filter "firebase_options.dart" -ErrorAction SilentlyContinue
    foreach ($file in $firebaseOptions) {
        Write-Host "FOUND: $($file.FullName)"
        $found = $true
    }
    
    if (-not $found) {
        Write-Warning "No Firebase configs found under apps/"
    }
    
    Write-Host "[ENV:VERIFY-FIREBASE] SUCCESS"
}

function Invoke-FcmVerify {
    Write-Host "[FCM:VERIFY] Verifying FCM configuration..."
    $fcmVerifyPath = Join-Path $ScriptRoot "tools\spec-kit\modules\fcm_verify.ps1"
    if (Test-Path $fcmVerifyPath) {
        . $fcmVerifyPath
        $clientPath = Join-Path $ScriptRoot "apps\wawapp_client"
        $driverPath = Join-Path $ScriptRoot "apps\wawapp_driver"
        
        $clientOk = Invoke-FcmVerify -AppPath $clientPath
        $driverOk = Invoke-FcmVerify -AppPath $driverPath
        
        if ($clientOk -and $driverOk) {
            Write-Host "[FCM:VERIFY] SUCCESS"
        } else {
            Write-Warning "[FCM:VERIFY] Some checks failed"
        }
    } else {
        Write-Warning "fcm_verify module not found at $fcmVerifyPath"
    }
}

# Main execution
switch ($Command) {
    'init' { Invoke-Init }
    'doctor' { Invoke-Doctor }
    'help' { Show-Help }
    'env:verify' { Invoke-EnvVerify }
    'fix:node-policy' { Invoke-FixNodePolicy }
    'format' { Invoke-Format }
    'analyze' { Invoke-Analyze }
    'flutter:refresh' { Invoke-FlutterRefresh }
    'build:driver' { Invoke-BuildDriver -Config $Config }
    'build:client' { Invoke-BuildClient -Config $Config }
    'test:unit' { Invoke-TestUnit }
    'test:analyze' { Invoke-TestAnalyze }
    'env:verify-Firebase' { Invoke-EnvVerifyFirebase }
    'fcm:verify' { Invoke-FcmVerify }
}
