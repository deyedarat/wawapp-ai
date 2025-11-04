[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Args
)

function Run-Doctor {
    & "$PSScriptRoot\.specify\scripts\powershell\doctor.ps1"
}

function Run-Init {
    if (-not (Test-Path ".specify\config.yaml")) {
        Write-Host "[spec:init] .specify\config.yaml is missing."
    } else {
        Write-Host "[spec:init] config.yaml OK."
    }
    if (-not (Test-Path ".specify\templates\feature-plan.md")) {
        Write-Host "[spec:init] feature-plan template missing."
    } else {
        Write-Host "[spec:init] feature-plan template OK."
    }
    Write-Host "[spec:init] Done."
}

function Run-EnvFix {
    $mapsTargets = @(
        "apps\wawapp_client\android\app\src\main\res\values\api_keys.xml",
        "apps\wawapp_driver\android\app\src\main\res\values\api_keys.xml"
    )
    foreach ($p in $mapsTargets) {
        if (-not (Test-Path $p)) {
@'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="google_maps_api_key">REPLACE_ME</string>
</resources>
'@ | Set-Content -Encoding UTF8 $p
            Write-Host "[env:fix] Created $p with placeholder key."
        } else {
            Write-Host "[env:fix] OK $p"
        }
    }

    $gs = @(
        "apps\wawapp_client\android\app\google-services.json",
        "apps\wawapp_driver\android\app\google-services.json"
    )
    foreach ($g in $gs) {
        if (-not (Test-Path $g)) {
            Write-Host "[env:fix] MISSING $g  => Download from Firebase Console and place it here."
        } else {
            Write-Host "[env:fix] OK $g"
        }
    }
    Write-Host "[env:fix] Done."
}

function Run-EnvVerify {
    $ok = $true

    $driverGs = "apps\wawapp_driver\android\app\google-services.json"
    if (-not (Test-Path $driverGs)) {
        Write-Host "[env:verify] MISSING $driverGs"
        $ok = $false
    } else {
        Write-Host "[env:verify] OK $driverGs"
    }

    $clientGs = "apps\wawapp_client\android\app\google-services.json"
    if (-not (Test-Path $clientGs)) {
        Write-Host "[env:verify] MISSING $clientGs"
        # ليس قاتلاً لو تركز على الدرايفر الآن
    } else {
        Write-Host "[env:verify] OK $clientGs"
    }

    $driverApi = "apps\wawapp_driver\android\app\src\main\res\values\api_keys.xml"
    if (-not (Test-Path $driverApi)) {
        Write-Host "[env:verify] MISSING $driverApi"
        $ok = $false
    } else {
        $content = Get-Content $driverApi -Raw
        if ($content -match "REPLACE_ME") {
            Write-Host "[env:verify] google_maps_api_key not set in driver api_keys.xml"
            $ok = $false
        } else {
            Write-Host "[env:verify] OK $driverApi"
        }
    }

    $clientApi = "apps\wawapp_client\android\app\src\main\res\values\api_keys.xml"
    if (Test-Path $clientApi) {
        $c2 = Get-Content $clientApi -Raw
        if ($c2 -match "REPLACE_ME") {
            Write-Host "[env:verify] google_maps_api_key not set in client api_keys.xml"
        } else {
            Write-Host "[env:verify] OK $clientApi"
        }
    }

    $wrappers = @(
        "apps\wawapp_driver\android\gradlew.bat",
        "apps\wawapp_client\android\gradlew.bat"
    ) | Where-Object { Test-Path $_ }

    if ($wrappers.Count -eq 0) {
        Write-Host "[env:verify] Gradle wrappers not found in apps/*"
        $ok = $false
    } else {
        Write-Host "[env:verify] Gradle wrappers OK"
    }

    if (-not $ok) { exit 1 } else { Write-Host "[env:verify] Passed."; exit 0 }
}

function Set-ApiKey($xmlPath, $key) {
    if (-not (Test-Path $xmlPath)) {
        Write-Host "[maps:set] MISSING $xmlPath"
        return $false
    }
    $xml = Get-Content $xmlPath -Raw
    if ($xml -notmatch '<string name="google_maps_api_key">') {
        Write-Host "[maps:set] No google_maps_api_key entry in $xmlPath"
        return $false
    }
    $new = $xml -replace '(<string name="google_maps_api_key">)(.*?)(</string>)', "`$1$key`$3"
    $new | Set-Content -Encoding UTF8 $xmlPath
    Write-Host "[maps:set] Updated $xmlPath"
    return $true
}

function Run-MapsSet($key, $target) {
    if (-not $key) { Write-Host "Usage: .\spec.ps1 maps:set <API_KEY> [client|driver|all]"; exit 1 }
    if (-not $target) { $target = "all" }

    $okAny = $false
    if ($target -in @("driver","all")) {
        $okAny = (Set-ApiKey "apps\wawapp_driver\android\app\src\main\res\values\api_keys.xml" $key) -or $okAny
    }
    if ($target -in @("client","all")) {
        $okAny = (Set-ApiKey "apps\wawapp_client\android\app\src\main\res\values\api_keys.xml" $key) -or $okAny
    }
    if (-not $okAny) { exit 1 } else { exit 0 }
}

function Run-Feature($name) {
    if (-not $name) { Write-Host "Usage: .\spec.ps1 feature <feature-name>"; exit 1 }
    $slug = $name -replace '[^\w\-\._]','-'
    $dir  = ".specify\features\$slug"
    New-Item -ItemType Directory -Force $dir | Out-Null
    (Get-Content ".specify\templates\feature-plan.md" -Raw).Replace("{{FEATURE_NAME}}", $name) `
      | Set-Content -Encoding UTF8 (Join-Path $dir "PLAN.md")
    Write-Host "[feature] Created $dir\PLAN.md"
}

# Router
if ($Args.Count -eq 0) {
    Write-Host "Usage: .\spec.ps1 <doctor|init|env:fix|env:verify|maps:set <KEY> [client|driver|all]|feature <name>>"
    exit 0
}

switch -Regex ($Args[0].ToLower()) {
    '^doctor$'       { Run-Doctor; break }
    '^init$'         { Run-Init;   break }
    '^env:fix$'      { Run-EnvFix; break }
    '^env:verify$'   { Run-EnvVerify; break }
    '^maps:set$'     { Run-MapsSet ($Args | Select-Object -Skip 1 -First 1) ($Args | Select-Object -Skip 2 -First 1); break }
    '^feature$'      { Run-Feature ($Args | Select-Object -Skip 1 -First 1); break }
    default {
        $script = Join-Path $PSScriptRoot ".specify\scripts\powershell\setup-plan.ps1"
        if (Test-Path $script) {
            powershell -ExecutionPolicy Bypass -File $script @Args
        } else {
            Write-Host "Unknown command '$($Args[0])'."
        }
    }
}