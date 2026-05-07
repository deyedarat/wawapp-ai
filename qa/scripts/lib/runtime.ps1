# ============================================================================
# WawApp QA - Runtime Observability Module
# ============================================================================
# Import: . "$PSScriptRoot\lib\runtime.ps1"
# Requires: common.ps1 loaded first
# ============================================================================

# ============================================================================
# PHASE DEFINITIONS
# ============================================================================
$Script:QA_PHASES = @(
    "DEVICE_CHECK"
    "FORCE_STOP"
    "SEND_PAYLOAD"
    "WAIT_FOR_ACTIVITY"
    "WAIT_FOR_NOTIFICATION"
    "SCREENSHOT_CAPTURE"
    "LOGCAT_STOP"
    "SUMMARY_EXPORT"
)

# ============================================================================
# STATE
# ============================================================================
$Script:QA_CurrentPhase = ""
$Script:QA_PhaseStart = $null
$Script:QA_RunStart = $null
$Script:QA_PhaseTimings = @{}
$Script:QA_FinalState = "RUNNING"  # PASS, FAIL, TIMEOUT, HANG
$Script:QA_HangThresholdSec = 60
$Script:QA_LastActivity = $null

# ============================================================================
# PHASE TRACKING
# ============================================================================
function Enter-QA-Phase([string]$phase, [int]$timeoutSec = 0) {
    # Close previous phase
    if ($Script:QA_CurrentPhase) {
        $elapsed = ((Get-Date) - $Script:QA_PhaseStart).TotalSeconds
        $Script:QA_PhaseTimings[$Script:QA_CurrentPhase] = [math]::Round($elapsed, 1)
    }

    $Script:QA_CurrentPhase = $phase
    $Script:QA_PhaseStart = Get-Date
    $Script:QA_LastActivity = Get-Date

    if (-not $Script:QA_RunStart) { $Script:QA_RunStart = Get-Date }

    $ts = Get-Date -Format "HH:mm:ss"
    Write-Host "[$ts] PHASE: $phase" -ForegroundColor DarkCyan

    if ($timeoutSec -gt 0) {
        Write-Host "[$ts]   timeout: ${timeoutSec}s" -ForegroundColor DarkGray
    }
}

function Complete-QA-Phase {
    if ($Script:QA_CurrentPhase) {
        $elapsed = ((Get-Date) - $Script:QA_PhaseStart).TotalSeconds
        $Script:QA_PhaseTimings[$Script:QA_CurrentPhase] = [math]::Round($elapsed, 1)
        $ts = Get-Date -Format "HH:mm:ss"
        Write-Host "[$ts] DONE: $Script:QA_CurrentPhase ($([math]::Round($elapsed,1))s)" -ForegroundColor DarkGreen
    }
}

# ============================================================================
# HEARTBEAT WAIT (replaces Start-Sleep during waits)
# ============================================================================
function Wait-QA-WithHeartbeat {
    param(
        [int]$Seconds,
        [string]$Label = "WAITING",
        [int]$HeartbeatIntervalSec = 3,
        [int]$HangThresholdSec = 0
    )

    if ($HangThresholdSec -gt 0) {
        $Script:QA_HangThresholdSec = $HangThresholdSec
    }

    $waitStart = Get-Date
    $elapsed = 0

    while ($elapsed -lt $Seconds) {
        $remaining = $Seconds - $elapsed
        $sleepFor = [math]::Min($HeartbeatIntervalSec, $remaining)

        Start-Sleep -Seconds $sleepFor
        $elapsed = [math]::Round(((Get-Date) - $waitStart).TotalSeconds)
        $Script:QA_LastActivity = Get-Date

        $ts = Get-Date -Format "HH:mm:ss"
        Write-Host "[$ts] $Label (${elapsed}s/${Seconds}s)" -ForegroundColor DarkGray
    }
}

# ============================================================================
# HANG DETECTION
# ============================================================================
function Test-QA-Hang {
    if (-not $Script:QA_LastActivity) { return $false }
    $idle = ((Get-Date) - $Script:QA_LastActivity).TotalSeconds
    return ($idle -ge $Script:QA_HangThresholdSec)
}

function Invoke-QA-HangCheck {
    if (Test-QA-Hang) {
        $idle = [math]::Round(((Get-Date) - $Script:QA_LastActivity).TotalSeconds)
        $ts = Get-Date -Format "HH:mm:ss"
        Write-Host "" -ForegroundColor Red
        Write-Host "[$ts] [HANG DETECTED]" -ForegroundColor Red
        Write-Host "[$ts]   Phase: $Script:QA_CurrentPhase" -ForegroundColor Red
        Write-Host "[$ts]   Idle: ${idle}s (threshold: $($Script:QA_HangThresholdSec)s)" -ForegroundColor Red
        Write-Host "[$ts]   Likely causes:" -ForegroundColor Yellow

        switch ($Script:QA_CurrentPhase) {
            "DEVICE_CHECK"          { Write-Host "[$ts]     - ADB server not responding" -ForegroundColor Yellow
                                      Write-Host "[$ts]     - USB cable disconnected" -ForegroundColor Yellow }
            "FORCE_STOP"            { Write-Host "[$ts]     - Device unresponsive (ANR)" -ForegroundColor Yellow
                                      Write-Host "[$ts]     - ADB shell blocked" -ForegroundColor Yellow }
            "SEND_PAYLOAD"          { Write-Host "[$ts]     - ADB broadcast not returning" -ForegroundColor Yellow
                                      Write-Host "[$ts]     - FCM HTTP call hanging" -ForegroundColor Yellow }
            "WAIT_FOR_ACTIVITY"     { Write-Host "[$ts]     - Activity never launched" -ForegroundColor Yellow
                                      Write-Host "[$ts]     - App crashed silently" -ForegroundColor Yellow }
            "WAIT_FOR_NOTIFICATION" { Write-Host "[$ts]     - FCM not delivered" -ForegroundColor Yellow
                                      Write-Host "[$ts]     - Notification channel disabled" -ForegroundColor Yellow }
            "SCREENSHOT_CAPTURE"    { Write-Host "[$ts]     - screencap blocked (device locked?)" -ForegroundColor Yellow
                                      Write-Host "[$ts]     - ADB pull stalled" -ForegroundColor Yellow }
            "LOGCAT_STOP"           { Write-Host "[$ts]     - Logcat process not responding to kill" -ForegroundColor Yellow }
            "SUMMARY_EXPORT"        { Write-Host "[$ts]     - Disk write blocked" -ForegroundColor Yellow }
            default                 { Write-Host "[$ts]     - Unknown phase stall" -ForegroundColor Yellow }
        }
        Write-Host "" -ForegroundColor Red
        return $true
    }
    return $false
}

# ============================================================================
# TIMEOUT-SAFE EXECUTION
# ============================================================================
function Invoke-QA-WithTimeout {
    param(
        [scriptblock]$Action,
        [int]$TimeoutSec = 30,
        [string]$Label = "operation"
    )

    $Script:QA_LastActivity = Get-Date
    $job = Start-Job -ScriptBlock $Action

    $waited = 0
    while ($waited -lt $TimeoutSec) {
        if ($job.State -eq "Completed" -or $job.State -eq "Failed") { break }
        Start-Sleep -Seconds 1
        $waited++
        $Script:QA_LastActivity = Get-Date
    }

    if ($job.State -eq "Running") {
        Stop-Job $job -ErrorAction SilentlyContinue
        Remove-Job $job -Force -ErrorAction SilentlyContinue
        $ts = Get-Date -Format "HH:mm:ss"
        Write-Host "[$ts] TIMEOUT: $Label exceeded ${TimeoutSec}s" -ForegroundColor Red
        return @{ Success = $false; Reason = "TIMEOUT after ${TimeoutSec}s"; Output = $null }
    }

    $output = Receive-Job $job -ErrorAction SilentlyContinue
    $failed = $job.State -eq "Failed"
    Remove-Job $job -Force -ErrorAction SilentlyContinue

    if ($failed) {
        return @{ Success = $false; Reason = "Job failed"; Output = $output }
    }
    return @{ Success = $true; Reason = ""; Output = $output }
}

# ============================================================================
# FINAL STATE
# ============================================================================
function Set-QA-FinalState([string]$state) {
    $Script:QA_FinalState = $state
}

function Get-QA-FinalState {
    return $Script:QA_FinalState
}

# ============================================================================
# GRACEFUL CLEANUP ON TIMEOUT/HANG
# ============================================================================
function Invoke-QA-EmergencyCleanup([string]$artifactDir, [string]$reason) {
    $ts = Get-Date -Format "HH:mm:ss"
    Write-Host "[$ts] EMERGENCY CLEANUP: $reason" -ForegroundColor Red

    # Stop logcat
    try { Stop-QA-Logcat } catch {}

    # Write partial PASS_FAIL
    $lines = @(
        "VERDICT: $Script:QA_FinalState"
        "PHASE_AT_FAILURE: $Script:QA_CurrentPhase"
        "REASON: $reason"
        "TIMESTAMP: $(Get-Date -Format o)"
    )
    if ($artifactDir -and (Test-Path $artifactDir)) {
        $lines | Out-File "$artifactDir\PASS_FAIL.txt" -Encoding utf8 -ErrorAction SilentlyContinue
    }

    Write-Host "[$ts] Partial artifacts saved" -ForegroundColor Yellow
}

# ============================================================================
# PHASE TIMINGS REPORT
# ============================================================================
function Get-QA-PhaseTimingsTable {
    # Close current phase if still open
    if ($Script:QA_CurrentPhase -and $Script:QA_PhaseStart) {
        $elapsed = ((Get-Date) - $Script:QA_PhaseStart).TotalSeconds
        $Script:QA_PhaseTimings[$Script:QA_CurrentPhase] = [math]::Round($elapsed, 1)
    }

    $totalDuration = 0
    if ($Script:QA_RunStart) {
        $totalDuration = [math]::Round(((Get-Date) - $Script:QA_RunStart).TotalSeconds, 1)
    }

    $rows = @()
    foreach ($phase in $Script:QA_PHASES) {
        $t = $Script:QA_PhaseTimings[$phase]
        if ($null -ne $t) {
            $rows += "| $phase | ${t}s |"
        }
    }
    # Include any custom phases not in the standard list
    foreach ($key in $Script:QA_PhaseTimings.Keys) {
        if ($key -notin $Script:QA_PHASES) {
            $rows += "| $key | $($Script:QA_PhaseTimings[$key])s |"
        }
    }
    $rows += "| **TOTAL** | **${totalDuration}s** |"
    return $rows
}

function Get-QA-PhaseTimingsMarkdown {
    $rows = Get-QA-PhaseTimingsTable
    $header = @("", "## Phase Timings", "", "| Phase | Duration |", "|-------|----------|")
    return ($header + $rows) -join "`n"
}

# ============================================================================
# ENHANCED SUMMARY (appends phase timings + state to summary.md)
# ============================================================================
function Append-QA-RuntimeSummary([string]$dir, [string]$timeoutReason, [string]$hangReason) {
    if (-not (Test-Path "$dir\summary.md")) { return }

    $extra = @("")
    $extra += "## Runtime Observability"
    $extra += ""
    $extra += "| Field | Value |"
    $extra += "|-------|-------|"
    $extra += "| Final State | **$Script:QA_FinalState** |"
    $extra += "| Last Phase | $Script:QA_CurrentPhase |"
    if ($timeoutReason) { $extra += "| Timeout Reason | $timeoutReason |" }
    if ($hangReason) { $extra += "| Hang Reason | $hangReason |" }

    $extra += (Get-QA-PhaseTimingsMarkdown)

    ($extra -join "`n") | Add-Content "$dir\summary.md" -Encoding utf8
}
