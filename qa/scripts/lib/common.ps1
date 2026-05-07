# ============================================================================
# WawApp QA - Common Library
# ============================================================================
# Import: . "$PSScriptRoot\lib\common.ps1"
# ============================================================================

# ============================================================================
# CONSOLE OUTPUT
# ============================================================================
function Write-QA-Step($msg)  { Write-Host "[STEP] $msg" -ForegroundColor Cyan }
function Write-QA-Pass($msg)  { Write-Host "[PASS] $msg" -ForegroundColor Green }
function Write-QA-Fail($msg)  { Write-Host "[FAIL] $msg" -ForegroundColor Red }
function Write-QA-Info($msg)  { Write-Host "[INFO] $msg" -ForegroundColor Gray }
function Write-QA-Warn($msg)  { Write-Host "[WARN] $msg" -ForegroundColor Yellow }

function Write-QA-Banner([string]$title) {
    Write-Host ""
    Write-Host "=======================================================" -ForegroundColor Magenta
    Write-Host "  $title" -ForegroundColor Magenta
    Write-Host "=======================================================" -ForegroundColor Magenta
    Write-Host ""
}

function Write-QA-Result([string]$verdict, [string[]]$reasons, [string]$artifactDir) {
    Write-Host ""
    Write-Host "=======================================================" -ForegroundColor Magenta
    if ($verdict -eq "PASS") {
        Write-Host "  RESULT: PASS" -ForegroundColor Green
    } else {
        Write-Host "  RESULT: FAIL" -ForegroundColor Red
        $reasons | ForEach-Object { Write-Host "    > $_" -ForegroundColor Red }
    }
    Write-Host "  Artifacts: $artifactDir" -ForegroundColor Gray
    Write-Host "=======================================================" -ForegroundColor Magenta
    Write-Host ""
}

# ============================================================================
# TEXT NORMALIZATION (null-safe, array-safe, multiline-safe)
# ============================================================================
function Normalize-QATextOutput($value) {
    if ($null -eq $value) { return "" }
    if ($value -is [System.Array]) { return ($value -join "`n") }
    return [string]$value
}

# ============================================================================
# ADB COMMAND WRAPPER (result normalization)
# ============================================================================
# Classification:
#   COMMAND_SUCCESS  - exit code 0, operation completed
#   COMMAND_WARNING  - exit code 0 but stderr has content (informational)
#   COMMAND_FAILURE  - non-zero exit code or exception
# ============================================================================

function Invoke-QA-Adb {
    param(
        [string]$Serial,
        [string]$Arguments,
        [switch]$Silent
    )

    $cmd = "adb"
    if ($Serial) { $cmd = "adb -s $Serial" }
    $fullCmd = "$cmd $Arguments"

    $result = @{
        ExitCode = 0
        Stdout = ""
        Stderr = ""
        Status = "COMMAND_SUCCESS"
        Success = $true
    }

    try {
        # Temporarily lower error preference so stderr doesn't throw
        $prevPref = $ErrorActionPreference
        $ErrorActionPreference = "Continue"

        # Capture both streams
        $tempOut = [System.IO.Path]::GetTempFileName()
        $tempErr = [System.IO.Path]::GetTempFileName()

        $proc = Start-Process -FilePath "cmd.exe" `
            -ArgumentList "/c $fullCmd 1>$tempOut 2>$tempErr" `
            -NoNewWindow -Wait -PassThru

        $result.ExitCode = $proc.ExitCode
        $rawOut = Get-Content $tempOut -Raw -ErrorAction SilentlyContinue
        $rawErr = Get-Content $tempErr -Raw -ErrorAction SilentlyContinue
        $result.Stdout = Normalize-QATextOutput $rawOut
        $result.Stderr = Normalize-QATextOutput $rawErr
        # Strip trailing newlines
        $result.Stdout = $result.Stdout -replace "[\r\n]+$", ""
        $result.Stderr = $result.Stderr -replace "[\r\n]+$", ""

        Remove-Item $tempOut -Force -ErrorAction SilentlyContinue
        Remove-Item $tempErr -Force -ErrorAction SilentlyContinue

        $ErrorActionPreference = $prevPref

        # Classify result
        if ($result.ExitCode -ne 0) {
            $result.Status = "COMMAND_FAILURE"
            $result.Success = $false
        }
        elseif ($result.Stderr) {
            $result.Status = "COMMAND_WARNING"
            # Still success - stderr from adb is often informational
        }
    }
    catch {
        $result.ExitCode = -1
        $result.Stderr = $_.Exception.Message
        $result.Status = "COMMAND_FAILURE"
        $result.Success = $false
    }

    if (-not $Silent) {
        $ts = Get-Date -Format "HH:mm:ss"
        $color = switch ($result.Status) {
            "COMMAND_SUCCESS" { "DarkGreen" }
            "COMMAND_WARNING" { "DarkYellow" }
            "COMMAND_FAILURE" { "Red" }
        }
        $stdoutPreview = if ($result.Stdout.Length -gt 80) { $result.Stdout.Substring(0,80) + "..." } else { $result.Stdout }
        Write-Host "[$ts] [$($result.Status)] exitCode=$($result.ExitCode) stdout=$stdoutPreview" -ForegroundColor $color
    }

    return $result
}

# ============================================================================
# TIMESTAMP & NAMING
# ============================================================================
function Get-QA-Timestamp {
    return Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
}

function Get-QA-ArtifactName([string]$scenario, [string]$suffix) {
    return "${scenario}_${suffix}"
}

# ============================================================================
# ARTIFACT DIRECTORY
# ============================================================================
function New-QA-ArtifactDir([string]$scenario) {
    $ts = Get-QA-Timestamp
    $qaRoot = Join-Path $PSScriptRoot "..\.." | Resolve-Path -ErrorAction SilentlyContinue
    if (-not $qaRoot) { $qaRoot = Join-Path $PSScriptRoot "..\.." }
    $dir = [System.IO.Path]::GetFullPath((Join-Path $qaRoot "qa\artifacts\${scenario}_${ts}"))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Write-QA-Info "Artifacts: $dir"
    return $dir
}

# ============================================================================
# DEVICE & PACKAGE ASSERTIONS
# ============================================================================
function Assert-AdbAvailable {
    $adb = Get-Command adb -ErrorAction SilentlyContinue
    if (-not $adb) {
        Write-QA-Fail "adb not found in PATH"
        exit 1
    }
    Write-QA-Info "adb: $($adb.Source)"
}

function Get-QA-Device {
    $r = Invoke-QA-Adb -Arguments "devices" -Silent
    $lines = @((Normalize-QATextOutput $r.Stdout) -split "`n" | Select-Object -Skip 1 | Where-Object { $_ -match "\s+device" })
    if ($lines.Count -eq 0) {
        Write-QA-Fail "No connected Android device"
        exit 1
    }
    $firstLine = Normalize-QATextOutput $lines[0]
    $serial = ($firstLine.Trim() -split "\s+")[0]
    Write-QA-Info "Device: $serial"
    return $serial
}

function Assert-PackageInstalled([string]$serial, [string]$pkg) {
    $r = Invoke-QA-Adb -Serial $serial -Arguments "shell pm list packages $pkg" -Silent
    if ($r.Stdout -notmatch $pkg) {
        Write-QA-Fail "$pkg not installed"
        exit 1
    }
    Write-QA-Pass "$pkg installed"
}

function Get-QA-DeviceInfo([string]$serial) {
    $model = (Invoke-QA-Adb -Serial $serial -Arguments "shell getprop ro.product.model" -Silent).Stdout.Trim()
    $sdk = (Invoke-QA-Adb -Serial $serial -Arguments "shell getprop ro.build.version.sdk" -Silent).Stdout.Trim()
    $android = (Invoke-QA-Adb -Serial $serial -Arguments "shell getprop ro.build.version.release" -Silent).Stdout.Trim()
    $mfr = (Invoke-QA-Adb -Serial $serial -Arguments "shell getprop ro.product.manufacturer" -Silent).Stdout.Trim()
    return @{
        Serial       = $serial
        Model        = $model
        SDK          = $sdk
        Android      = $android
        Manufacturer = $mfr
    }
}

function Save-QA-DeviceInfo([string]$serial, [string]$outFile) {
    $info = Get-QA-DeviceInfo $serial
    $lines = @(
        "serial=$($info.Serial)"
        "model=$($info.Model)"
        "sdk=$($info.SDK)"
        "android=$($info.Android)"
        "manufacturer=$($info.Manufacturer)"
        "captured=$(Get-Date -Format o)"
    )
    $lines | Out-File -FilePath $outFile -Encoding utf8
    Write-QA-Info "Device info: $outFile"
    return $info
}

# ============================================================================
# LOGCAT
# ============================================================================
$Script:QA_LogcatProcess = $null

function Start-QA-Logcat([string]$serial, [string]$outFile) {
    # Clear logcat buffer - ignore errors
    $prevPref = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & adb -s $serial logcat -c 2>&1 | Out-Null
    $ErrorActionPreference = $prevPref

    $Script:QA_LogcatProcess = Start-Process -FilePath "adb" `
        -ArgumentList "-s $serial logcat -v threadtime" `
        -RedirectStandardOutput $outFile `
        -NoNewWindow -PassThru
    Write-QA-Info "Logcat started: $outFile"
}

function Stop-QA-Logcat {
    if ($Script:QA_LogcatProcess -and -not $Script:QA_LogcatProcess.HasExited) {
        $Script:QA_LogcatProcess.Kill()
        Start-Sleep -Milliseconds 500
    }
    $Script:QA_LogcatProcess = $null
    Write-QA-Info "Logcat stopped"
}

# ============================================================================
# SCREENSHOTS (file-existence verified)
# ============================================================================
function Save-QA-Screenshot([string]$serial, [string]$outFile) {
    # Capture on device
    Invoke-QA-Adb -Serial $serial -Arguments "shell screencap -p /sdcard/qa_tmp_screen.png" -Silent

    # Pull to local
    $r = Invoke-QA-Adb -Serial $serial -Arguments "pull /sdcard/qa_tmp_screen.png `"$outFile`""

    # Cleanup device
    Invoke-QA-Adb -Serial $serial -Arguments "shell rm -f /sdcard/qa_tmp_screen.png" -Silent

    # Verify by file existence, NOT by adb output
    if (Test-Path $outFile) {
        $size = (Get-Item $outFile).Length
        Write-QA-Info "Screenshot: $outFile (${size} bytes)"
    }
    else {
        Write-QA-Warn "Screenshot file not found after pull: $outFile"
    }
}

# ============================================================================
# DUMPS
# ============================================================================
function Save-QA-NotificationDump([string]$serial, [string]$outFile) {
    $r = Invoke-QA-Adb -Serial $serial -Arguments "shell dumpsys notification" -Silent
    if ($r.Success) {
        $r.Stdout | Out-File $outFile -Encoding utf8
        Write-QA-Info "Notification dump: $outFile"
    }
    else {
        Write-QA-Warn "Notification dump failed: $($r.Stderr)"
    }
}

function Save-QA-ActivityDump([string]$serial, [string]$outFile) {
    $r = Invoke-QA-Adb -Serial $serial -Arguments "shell dumpsys activity activities" -Silent
    if ($r.Success) {
        $r.Stdout | Out-File $outFile -Encoding utf8
        Write-QA-Info "Activity dump: $outFile"
    }
    else {
        Write-QA-Warn "Activity dump failed: $($r.Stderr)"
    }
}

# ============================================================================
# ADB SHELL (simple wrapper for inline commands)
# ============================================================================
function Invoke-QA-AdbShell([string]$serial, [string]$cmd) {
    return Invoke-QA-Adb -Serial $serial -Arguments "shell $cmd" -Silent
}

# ============================================================================
# PASS / FAIL
# ============================================================================
function Save-QA-Verdict([string]$dir, [string]$verdict, [string[]]$reasons, [hashtable]$meta) {
    $lines = @(
        "VERDICT: $verdict"
        "SCENARIO: $($meta.Scenario)"
        "TIMESTAMP: $($meta.Timestamp)"
        "DEVICE: $($meta.Serial)"
        "ANDROID: $($meta.Android)"
        "DURATION: $($meta.Duration)"
        "REASONS: $($reasons -join '; ')"
    )
    $lines | Out-File "$dir\PASS_FAIL.txt" -Encoding utf8
}

# ============================================================================
# SUMMARY MARKDOWN
# ============================================================================
function Save-QA-Summary {
    param(
        [string]$Dir,
        [string]$Scenario,
        [string]$Verdict,
        [string[]]$Reasons,
        [hashtable]$DeviceInfo,
        [string]$StartTime,
        [string]$EndTime,
        [string[]]$Checks,
        [string[]]$Artifacts
    )

    $duration = ""
    try {
        $s = [datetime]::ParseExact($StartTime, "yyyy-MM-dd_HH-mm-ss", $null)
        $e = [datetime]::ParseExact($EndTime, "yyyy-MM-dd_HH-mm-ss", $null)
        $duration = "$([math]::Round(($e - $s).TotalSeconds))s"
    } catch { $duration = "unknown" }

    $artifactList = ($Artifacts | ForEach-Object { "- $_" }) -join "`n"
    $checkRows = ($Checks) -join "`n"
    $reasonList = if ($Reasons.Count -eq 0) { "None" } else { ($Reasons | ForEach-Object { "- $_" }) -join "`n" }

    $md = @(
        "# Smoke Test: $Scenario"
        ""
        "| Field | Value |"
        "|-------|-------|"
        "| Verdict | **$Verdict** |"
        "| Scenario | $Scenario |"
        "| Device | $($DeviceInfo.Model) ($($DeviceInfo.Serial)) |"
        "| Android | $($DeviceInfo.Android) (SDK $($DeviceInfo.SDK)) |"
        "| Start | $StartTime |"
        "| End | $EndTime |"
        "| Duration | $duration |"
        ""
        "## Checks"
        ""
        "| Check | Result |"
        "|-------|--------|"
        $checkRows
        ""
        "## Failure Reasons"
        ""
        $reasonList
        ""
        "## Artifacts"
        ""
        $artifactList
    ) -join "`n"

    $md | Out-File "$Dir\summary.md" -Encoding utf8
    Write-QA-Info "Summary: $Dir\summary.md"
}
