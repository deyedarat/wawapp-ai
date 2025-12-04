#Requires -Version 5.1
<#
.SYNOPSIS
    Build wawapp_driver APK with logging.

.DESCRIPTION
    Runs flutter build apk for wawapp_driver and captures all output to logs/build_driver.log.
    Returns exit code 0 if build succeeds, non-zero on failure.

    This script is part of the WawApp fixloop system for automated build fixing.

.PARAMETER BuildMode
    Build mode: debug, profile, or release (default: debug)

.PARAMETER SplitPerAbi
    Generate separate APKs per ABI (reduces APK size)

.EXAMPLE
    .\tools\fixloops\run_build_driver.ps1

.EXAMPLE
    .\tools\fixloops\run_build_driver.ps1 -BuildMode release

.EXAMPLE
    .\tools\fixloops\run_build_driver.ps1 -BuildMode release -SplitPerAbi

.NOTES
    - Creates logs/ directory if missing
    - Appends timestamp to each run
    - Safe to run multiple times
    - Part of fixloop-build automation
#>

param(
    [ValidateSet("debug", "profile", "release")]
    [string]$BuildMode = "debug",
    [switch]$SplitPerAbi = $false
)

# Safety: Ensure we're in the repo root
$RepoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Set-Location $RepoRoot

# Create logs directory if missing
$LogDir = Join-Path $RepoRoot "tools\fixloops\logs"
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# Log file path
$LogFile = Join-Path $LogDir "build_driver.log"
$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Write header to log
"" | Out-File -FilePath $LogFile -Append
"=" * 80 | Out-File -FilePath $LogFile -Append
"[$Timestamp] Starting flutter build apk for wawapp_driver..." | Out-File -FilePath $LogFile -Append
"Build mode: $BuildMode" | Out-File -FilePath $LogFile -Append
if ($SplitPerAbi) {
    "Split per ABI: enabled" | Out-File -FilePath $LogFile -Append
}
"=" * 80 | Out-File -FilePath $LogFile -Append

Write-Host "[$Timestamp] Building wawapp_driver APK ($BuildMode)..." -ForegroundColor Cyan
Write-Host "Log file: $LogFile" -ForegroundColor Gray

# Navigate to driver app
$DriverPath = Join-Path $RepoRoot "apps\wawapp_driver"
if (-not (Test-Path $DriverPath)) {
    Write-Host "ERROR: apps/wawapp_driver not found!" -ForegroundColor Red
    "ERROR: apps/wawapp_driver not found at $DriverPath" | Out-File -FilePath $LogFile -Append
    exit 1
}

Set-Location $DriverPath

# Build flutter build apk command
$FlutterArgs = @("build", "apk")
if ($BuildMode -eq "debug") {
    $FlutterArgs += "--debug"
} elseif ($BuildMode -eq "profile") {
    $FlutterArgs += "--profile"
} elseif ($BuildMode -eq "release") {
    $FlutterArgs += "--release"
}

if ($SplitPerAbi) {
    $FlutterArgs += "--split-per-abi"
}

Write-Host "Executing: flutter $($FlutterArgs -join ' ')" -ForegroundColor Gray

# Run flutter build with output capture
$ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
$ProcessInfo.FileName = "flutter"
$ProcessInfo.Arguments = $FlutterArgs -join " "
$ProcessInfo.RedirectStandardOutput = $true
$ProcessInfo.RedirectStandardError = $true
$ProcessInfo.UseShellExecute = $false
$ProcessInfo.WorkingDirectory = $DriverPath

$Process = New-Object System.Diagnostics.Process
$Process.StartInfo = $ProcessInfo

# Event handlers for output
$OutputBuilder = New-Object System.Text.StringBuilder
$ErrorBuilder = New-Object System.Text.StringBuilder

$OutputHandler = {
    if (-not [string]::IsNullOrEmpty($EventArgs.Data)) {
        $line = $EventArgs.Data
        Write-Host $line
        $line | Out-File -FilePath $using:LogFile -Append
        [void]$using:OutputBuilder.AppendLine($line)
    }
}

$ErrorHandler = {
    if (-not [string]::IsNullOrEmpty($EventArgs.Data)) {
        $line = $EventArgs.Data
        Write-Host $line -ForegroundColor Red
        $line | Out-File -FilePath $using:LogFile -Append
        [void]$using:ErrorBuilder.AppendLine($line)
    }
}

Register-ObjectEvent -InputObject $Process -EventName OutputDataReceived -Action $OutputHandler | Out-Null
Register-ObjectEvent -InputObject $Process -EventName ErrorDataReceived -Action $ErrorHandler | Out-Null

# Start the process
$Process.Start() | Out-Null
$Process.BeginOutputReadLine()
$Process.BeginErrorReadLine()

# Wait for process to complete
try {
    $Process.WaitForExit()
    $ExitCode = $Process.ExitCode
} catch {
    Write-Host "Process interrupted or failed: $_" -ForegroundColor Red
    "ERROR: Process interrupted or failed: $_" | Out-File -FilePath $LogFile -Append
    $ExitCode = 1
} finally {
    # Cleanup event handlers
    Get-EventSubscriber | Where-Object { $_.SourceObject -eq $Process } | Unregister-Event
    $Process.Dispose()
}

# Log completion
$EndTimestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
"[$EndTimestamp] flutter build apk completed with exit code: $ExitCode" | Out-File -FilePath $LogFile -Append

# Check if APK was generated
$ApkPath = Join-Path $DriverPath "build\app\outputs\flutter-apk"
if (Test-Path $ApkPath) {
    $ApkFiles = Get-ChildItem -Path $ApkPath -Filter "*.apk" | Sort-Object LastWriteTime -Descending
    if ($ApkFiles.Count -gt 0) {
        "Generated APK(s):" | Out-File -FilePath $LogFile -Append
        foreach ($apk in $ApkFiles) {
            $sizeKB = [math]::Round($apk.Length / 1KB, 2)
            "  - $($apk.Name) ($sizeKB KB)" | Out-File -FilePath $LogFile -Append
            Write-Host "  ✓ Generated: $($apk.Name) ($sizeKB KB)" -ForegroundColor Green
        }
    }
}

"=" * 80 | Out-File -FilePath $LogFile -Append

if ($ExitCode -eq 0) {
    Write-Host "✓ Build succeeded!" -ForegroundColor Green
} else {
    Write-Host "✗ Build failed (exit code $ExitCode)" -ForegroundColor Red
    Write-Host "Check log file for details: $LogFile" -ForegroundColor Yellow
}

# Return to repo root
Set-Location $RepoRoot

exit $ExitCode
