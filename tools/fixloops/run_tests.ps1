#Requires -Version 5.1
<#
.SYNOPSIS
    Run Flutter tests with logging.

.DESCRIPTION
    Runs flutter test for the WawApp monorepo and captures all output to logs/tests.log.
    Returns exit code 0 if all tests pass, non-zero on failure.

    This script is part of the WawApp fixloop system for automated test healing.

.PARAMETER TestPath
    Optional path to specific test file or directory (default: runs all tests)

.PARAMETER Coverage
    Enable code coverage reporting

.EXAMPLE
    .\tools\fixloops\run_tests.ps1

.EXAMPLE
    .\tools\fixloops\run_tests.ps1 -TestPath "test/features/auth/"

.EXAMPLE
    .\tools\fixloops\run_tests.ps1 -Coverage

.NOTES
    - Creates logs/ directory if missing
    - Appends timestamp to each run
    - Safe to run multiple times
    - Part of fixloop-tests automation
#>

param(
    [string]$TestPath = "",
    [switch]$Coverage = $false
)

# Safety: Ensure we're in the repo root
$RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Set-Location $RepoRoot

# Reload PATH from registry
$machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
$userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
$env:Path = "$machinePath;$userPath"

# Create logs directory if missing
$LogDir = Join-Path $RepoRoot "tools\fixloops\logs"
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# Log file path
$LogFile = Join-Path $LogDir "tests.log"
$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Write header to log
"" | Out-File -FilePath $LogFile -Append
"=" * 80 | Out-File -FilePath $LogFile -Append
"[$Timestamp] Starting flutter test..." | Out-File -FilePath $LogFile -Append
if ($TestPath -ne "") {
    "Test path: $TestPath" | Out-File -FilePath $LogFile -Append
}
if ($Coverage) {
    "Coverage: enabled" | Out-File -FilePath $LogFile -Append
}
"=" * 80 | Out-File -FilePath $LogFile -Append

Write-Host "[$Timestamp] Running Flutter tests..." -ForegroundColor Cyan
Write-Host "Log file: $LogFile" -ForegroundColor Gray

# Determine test locations
$TestLocations = @()
if ($TestPath -ne "") {
    $TestLocations += $TestPath
} else {
    # Check for test directories in apps
    $AppDirs = @("apps\wawapp_client", "apps\wawapp_driver")
    foreach ($appDir in $AppDirs) {
        $testDir = Join-Path $RepoRoot "$appDir\test"
        if (Test-Path $testDir) {
            $TestLocations += $appDir
        }
    }
}

if ($TestLocations.Count -eq 0) {
    Write-Host "No test directories found" -ForegroundColor Yellow
    "No test directories found" | Out-File -FilePath $LogFile -Append
    exit 0
}

$ExitCode = 0
foreach ($location in $TestLocations) {
    $testPath = Join-Path $RepoRoot $location
    Write-Host "`nTesting: $location" -ForegroundColor Cyan
    "Testing: $location" | Out-File -FilePath $LogFile -Append
    
    Push-Location $testPath
    try {
        $FlutterArgs = @("test")
        if ($Coverage) {
            $FlutterArgs += "--coverage"
        }
        
        Write-Host "Executing: flutter $($FlutterArgs -join ' ')" -ForegroundColor Gray
        $Output = & flutter @FlutterArgs 2>&1 | Tee-Object -FilePath $LogFile -Append
        
        if ($LASTEXITCODE -ne 0) {
            $ExitCode = $LASTEXITCODE
        }
    } finally {
        Pop-Location
    }
}

# Log completion
$EndTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
"[$EndTimestamp] All tests completed with exit code: $ExitCode" | Out-File -FilePath $LogFile -Append
"=" * 80 | Out-File -FilePath $LogFile -Append

if ($ExitCode -eq 0) {
    Write-Host "All tests passed!" -ForegroundColor Green
} else {
    Write-Host "Tests failed (exit code $ExitCode)" -ForegroundColor Red
    Write-Host "Check log: $LogFile" -ForegroundColor Yellow
}

exit $ExitCode
