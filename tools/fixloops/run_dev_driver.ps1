#Requires -Version 5.1
<#
.SYNOPSIS
    Run wawapp_driver in development mode with logging.

.DESCRIPTION
    Starts the Flutter dev server for wawapp_driver and captures all output to logs/dev_driver.log.
    Returns exit code 0 on success, non-zero on failure.

    This script is part of the WawApp fixloop system for automated debugging.

.PARAMETER Device
    Optional device ID or name to run on (default: uses first available device)

.EXAMPLE
    .\tools\fixloops\run_dev_driver.ps1

.EXAMPLE
    .\tools\fixloops\run_dev_driver.ps1 -Device "emulator-5554"

.NOTES
    - Creates logs/ directory if missing
    - Appends timestamp to each run
    - Safe to run multiple times
    - Part of fixloop-dev-driver automation
#>

param(
    [string]$Device = ""
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
$LogFile = Join-Path $LogDir "dev_driver.log"
$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Write header to log
"" | Out-File -FilePath $LogFile -Append
"=" * 80 | Out-File -FilePath $LogFile -Append
"[$Timestamp] Starting flutter run for wawapp_driver..." | Out-File -FilePath $LogFile -Append
"=" * 80 | Out-File -FilePath $LogFile -Append

Write-Host "[$Timestamp] Starting wawapp_driver dev server..." -ForegroundColor Cyan
Write-Host "Log file: $LogFile" -ForegroundColor Gray

# Navigate to driver app
$DriverPath = Join-Path $RepoRoot "apps\wawapp_driver"
if (-not (Test-Path $DriverPath)) {
    Write-Host "ERROR: apps/wawapp_driver not found!" -ForegroundColor Red
    "ERROR: apps/wawapp_driver not found at $DriverPath" | Out-File -FilePath $LogFile -Append
    exit 1
}

Set-Location $DriverPath

# Build flutter run command
$FlutterArgs = @("run")
if ($Device -ne "") {
    $FlutterArgs += @("-d", $Device)
}

Write-Host "Executing: flutter $($FlutterArgs -join ' ')" -ForegroundColor Gray

# Run flutter with output capture
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

# Wait for process to complete (or user to Ctrl+C)
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
"[$EndTimestamp] flutter run completed with exit code: $ExitCode" | Out-File -FilePath $LogFile -Append
"=" * 80 | Out-File -FilePath $LogFile -Append

if ($ExitCode -eq 0) {
    Write-Host "✓ Dev server exited cleanly (exit code 0)" -ForegroundColor Green
} else {
    Write-Host "✗ Dev server exited with errors (exit code $ExitCode)" -ForegroundColor Red
    Write-Host "Check log file: $LogFile" -ForegroundColor Yellow
}

# Return to repo root
Set-Location $RepoRoot

exit $ExitCode
