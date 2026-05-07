# ============================================================================
# WawApp QA - Killed-State Notification: Real FCM Certification
# ============================================================================
# Sends a REAL Firebase high-priority data message to a force-stopped app.
# Measures: delivery latency, wake latency, fullscreen launch latency.
#
# Modes:
#   LOCAL_SIMULATION - ADB broadcast only (no network, deterministic)
#   REAL_FCM         - Actual FCM delivery through Google servers
#
# Usage:
#   .\qa\scripts\run_notification_killed_state_real_fcm.ps1 -ProjectId "wawapp-xxx" -FcmToken "token..."
#   .\qa\scripts\run_notification_killed_state_real_fcm.ps1 -ProjectId "wawapp-xxx" -TokenFile ".\fcm_token.txt"
#   .\qa\scripts\run_notification_killed_state_real_fcm.ps1 -LocalOnly
#
# Prerequisites:
#   - gcloud CLI authenticated (for REAL_FCM)
#   - Device FCM token (from app logs or Firestore)
#   - Firebase project ID
# ============================================================================

param(
    [string]$ProjectId = "",
    [string]$FcmToken = "",
    [string]$TokenFile = "",
    [switch]$LocalOnly,
    [int]$TimeoutSeconds = 25,
    [int]$PollIntervalMs = 500,
    [string]$PackageName = "com.wawapp.driver",
    [string]$FullScreenActivity = "FullScreenNotificationActivity",
    [int]$HangThresholdSec = 60
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\lib\common.ps1"
. "$PSScriptRoot\lib\runtime.ps1"
. "$PSScriptRoot\lib\fcm.ps1"

$ScenarioId = "N3_FCM"
$ScenarioName = "Killed-State Real FCM Certification"
$Script:QA_HangThresholdSec = $HangThresholdSec

# ============================================================================
# DETERMINE MODE
# ============================================================================
if ($LocalOnly) {
    $execMode = "LOCAL_SIMULATION"
} else {
    $execMode = "REAL_FCM"
}

# ============================================================================
# SETUP
# ============================================================================
Write-QA-Banner "WawApp QA - $ScenarioId : $ScenarioName"
Write-QA-Info "Mode: $execMode | Timeout: ${TimeoutSeconds}s"

Enter-QA-Phase "DEVICE_CHECK" -timeoutSec 15
Assert-AdbAvailable
$serial = Get-QA-Device
Assert-PackageInstalled $serial $PackageName
Complete-QA-Phase

$startTime = Get-QA-Timestamp
$artifactDir = New-QA-ArtifactDir $ScenarioId
$deviceInfo = Save-QA-DeviceInfo $serial "$artifactDir\device_info.txt"

# ============================================================================
# VALIDATE FCM PREREQUISITES (REAL_FCM mode)
# ============================================================================
$fcmReady = $false
$accessToken = ""
$resolvedFcmToken = ""

if ($execMode -eq "REAL_FCM") {
    Enter-QA-Phase "FCM_AUTH" -timeoutSec 15

    # Resolve FCM token
    $tokenResult = Get-QA-FcmToken -Token $FcmToken -TokenFile $TokenFile
    if (-not $tokenResult.Success) {
        Write-QA-Fail "No FCM token available. Use -FcmToken or -TokenFile or place in qa/fcm_token.txt"
        Set-QA-FinalState "FAIL"
        Invoke-QA-EmergencyCleanup $artifactDir "No FCM token"
        exit 1
    }
    $resolvedFcmToken = $tokenResult.Token
    Write-QA-Info "FCM token source: $($tokenResult.Source)"

    # Validate ProjectId
    if (-not $ProjectId) {
        Write-QA-Fail "-ProjectId required for REAL_FCM mode"
        Set-QA-FinalState "FAIL"
        Invoke-QA-EmergencyCleanup $artifactDir "Missing ProjectId"
        exit 1
    }

    # Get gcloud access token
    $authResult = Get-QA-GcloudAccessToken
    if (-not $authResult.Success) {
        Write-QA-Fail "gcloud auth failed: $($authResult.Error)"
        Set-QA-FinalState "FAIL"
        Invoke-QA-EmergencyCleanup $artifactDir "gcloud auth failed"
        exit 1
    }
    $accessToken = $authResult.Token
    $fcmReady = $true
    Write-QA-Pass "FCM auth ready"

    Complete-QA-Phase
}

# ============================================================================
# FORCE-STOP APP
# ============================================================================
Enter-QA-Phase "FORCE_STOP" -timeoutSec 10

$logcatFile = Join-Path $artifactDir (Get-QA-ArtifactName $ScenarioId 'logcat.txt')
Start-QA-Logcat $serial $logcatFile
Invoke-QA-AdbShell $serial "am force-stop $PackageName"
Start-Sleep -Seconds 1

$pidResult = Invoke-QA-AdbShell $serial "pidof $PackageName"
$appKilled = -not [bool]$pidResult.Stdout.Trim()
if ($appKilled) { Write-QA-Pass "App force-stopped" }
else { Write-QA-Warn "App still running after force-stop" }

Complete-QA-Phase

# --- Pre-FCM screenshot ---
Enter-QA-Phase "SCREENSHOT_CAPTURE" -timeoutSec 10
$preFcmFile = Join-Path $artifactDir (Get-QA-ArtifactName $ScenarioId 'pre_fcm.png')
Save-QA-Screenshot $serial $preFcmFile
Complete-QA-Phase

# ============================================================================
# SEND NOTIFICATION
# ============================================================================
Enter-QA-Phase "SEND_PAYLOAD" -timeoutSec 15

$sendTimestamp = Get-Date
$fcmResult = $null

if ($execMode -eq "REAL_FCM") {
    Write-QA-Step "Sending REAL FCM high-priority data message"
    $payload = New-QA-FcmTestPayload -ScenarioId $ScenarioId -Timestamp $startTime

    $fcmResult = Send-QA-FcmMessage `
        -ProjectId $ProjectId `
        -FcmToken $resolvedFcmToken `
        -AccessToken $accessToken `
        -DataPayload $payload

    if ($fcmResult.Success) {
        Write-QA-Pass "FCM delivered - messageId: $($fcmResult.MessageId) latency: $($fcmResult.LatencyMs)ms"
    } else {
        Write-QA-Fail "FCM send failed: $($fcmResult.Status) - $($fcmResult.Error)"
        Set-QA-FinalState "FAIL"
        Invoke-QA-EmergencyCleanup $artifactDir "FCM send failed: $($fcmResult.Status)"
        exit 1
    }
} else {
    Write-QA-Info "LOCAL_SIMULATION - using ADB broadcast"
    $orderId = "QA_ONLY_${ScenarioId}_$startTime"
    $broadcastCmd = "am broadcast -a com.wawapp.driver.TEST_NOTIFICATION --es type new_order --es orderId $orderId --es pickupLat 18.0735 --es pickupLng -15.9582 --es dropoffLat 18.0800 --es dropoffLng -15.9500 --es price 500 --es clientName QA_CERTIFICATION --es qa_test true"
    Invoke-QA-AdbShell $serial $broadcastCmd | Out-Null
    Write-QA-Pass "ADB broadcast sent"
}

Complete-QA-Phase

# ============================================================================
# POLL FOR WAKE + FULLSCREEN (with timing)
# ============================================================================
Enter-QA-Phase "WAIT_FOR_ACTIVITY" -timeoutSec $TimeoutSeconds

$wakeTimestamp = $null
$fullscreenTimestamp = $null
$pollStart = Get-Date
$wakeDetected = $false
$fullscreenDetected = $false
$pollCount = 0

while (((Get-Date) - $pollStart).TotalSeconds -lt $TimeoutSeconds) {
    $pollCount++

    # Check if app process woke
    if (-not $wakeDetected) {
        $pidCheck = Invoke-QA-AdbShell $serial "pidof $PackageName"
        if ($pidCheck.Stdout.Trim()) {
            $wakeTimestamp = Get-Date
            $wakeDetected = $true
            $wakePid = $pidCheck.Stdout.Trim()
            Write-QA-Info "App woke at poll $pollCount PID:$wakePid"
        }
    }

    # Check if fullscreen activity launched
    if (-not $fullscreenDetected) {
        $actCheck = Invoke-QA-AdbShell $serial "dumpsys activity activities" -Silent
        if ($actCheck.Stdout -match $FullScreenActivity) {
            $fullscreenTimestamp = Get-Date
            $fullscreenDetected = $true
            Write-QA-Info "Fullscreen detected at poll $pollCount"
        }
    }

    # Both detected - stop polling
    if ($wakeDetected -and $fullscreenDetected) { break }

    Start-Sleep -Milliseconds $PollIntervalMs
}

Complete-QA-Phase

# ============================================================================
# COLLECT ARTIFACTS
# ============================================================================
Enter-QA-Phase "SCREENSHOT_CAPTURE" -timeoutSec 15
$postFcmFile = Join-Path $artifactDir (Get-QA-ArtifactName $ScenarioId 'post_fcm.png')
Save-QA-Screenshot $serial $postFcmFile
Complete-QA-Phase

Enter-QA-Phase "WAIT_FOR_NOTIFICATION" -timeoutSec 10
$notifDumpFile = Join-Path $artifactDir (Get-QA-ArtifactName $ScenarioId 'notification_dump.txt')
$actDumpFile = Join-Path $artifactDir (Get-QA-ArtifactName $ScenarioId 'activity_dump.txt')
Save-QA-NotificationDump $serial $notifDumpFile
Save-QA-ActivityDump $serial $actDumpFile
Complete-QA-Phase

Enter-QA-Phase "LOGCAT_STOP" -timeoutSec 10
Stop-QA-Logcat
Complete-QA-Phase

# ============================================================================
# COMPUTE LATENCIES
# ============================================================================
$deliveryLatencyMs = 0
$wakeLatencyMs = 0
$fullscreenLatencyMs = 0

if ($fcmResult -and $fcmResult.Success) {
    $deliveryLatencyMs = $fcmResult.LatencyMs
}
if ($wakeTimestamp) {
    $wakeLatencyMs = [math]::Round(($wakeTimestamp - $sendTimestamp).TotalMilliseconds)
}
if ($fullscreenTimestamp) {
    $fullscreenLatencyMs = [math]::Round(($fullscreenTimestamp - $sendTimestamp).TotalMilliseconds)
}

# ============================================================================
# VERDICT
# ============================================================================
$verdict = "PASS"
$reasons = @()
$checks = @()
$classification = ""

# Check 1: App woke
if ($wakeDetected) {
    Write-QA-Pass "App woke from killed state PID:$wakePid"
    $checks += "| App wake | PASS PID:$wakePid ${wakeLatencyMs}ms |"
} else {
    $verdict = "FAIL"
    $reasons += "App did not wake from killed state within ${TimeoutSeconds}s"
    Write-QA-Fail "App did NOT wake"
    $checks += "| App wake | FAIL timeout ${TimeoutSeconds}s |"
}

# Check 2: Fullscreen activity
if ($fullscreenDetected) {
    Write-QA-Pass "Fullscreen activity launched ${fullscreenLatencyMs}ms"
    $checks += "| Fullscreen launch | PASS ${fullscreenLatencyMs}ms |"
} else {
    $verdict = "FAIL"
    $reasons += "Fullscreen activity not launched within ${TimeoutSeconds}s"
    Write-QA-Fail "Fullscreen NOT launched"
    $checks += "| Fullscreen launch | FAIL |"
}

# Check 3: Notification in tray
$notifDump = Get-Content $notifDumpFile -Raw -ErrorAction SilentlyContinue
if ($notifDump -match $PackageName) {
    Write-QA-Pass "Notification present in tray"
    $checks += "| Notification tray | PASS |"
} else {
    $checks += "| Notification tray | WARN |"
    Write-QA-Info "No tray notification - OK if fullscreen fired"
}

# Check 4: No crash in logcat
$logcat = Get-Content $logcatFile -Raw -ErrorAction SilentlyContinue
$crashPattern = "FATAL EXCEPTION|ANR in $PackageName|Process.*$PackageName.*has died"
$crashes = @()
if ($logcat) {
    $crashes = @([regex]::Matches($logcat, $crashPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase))
}
if ($crashes.Count -eq 0) {
    $checks += "| Crash detection | PASS |"
} else {
    $verdict = "FAIL"
    $cCount = $crashes.Count
    $reasons += "Crash detected: $cCount traces"
    $checks += "| Crash detection | FAIL $cCount traces |"
}

# --- Determine classification ---
if ($execMode -eq "LOCAL_SIMULATION") {
    if ($verdict -eq "PASS") { $classification = "LOCAL_SIMULATION_PASS" }
    else { $classification = "LOCAL_SIMULATION_FAIL" }
} else {
    if ($verdict -eq "PASS") {
        # Check for delayed delivery (wake > 5s)
        if ($wakeLatencyMs -gt 5000) {
            $classification = "REAL_FCM_DELAYED"
        } else {
            $classification = "REAL_FCM_PASS"
        }
    } else {
        if (-not $wakeDetected) {
            $classification = "REAL_FCM_WAKE_FAIL"
        } else {
            $classification = "REAL_FCM_PARTIAL"
        }
    }
}

$checks += "| Classification | $classification |"
Write-QA-Info "Classification: $classification"

# ============================================================================
# SAVE
# ============================================================================
Enter-QA-Phase "SUMMARY_EXPORT" -timeoutSec 10

if ($verdict -eq "PASS") { Set-QA-FinalState "PASS" }
else { Set-QA-FinalState "FAIL" }

$endTime = Get-QA-Timestamp

Save-QA-Verdict $artifactDir $verdict $reasons @{
    Scenario = "$ScenarioId - $ScenarioName"
    Timestamp = $startTime
    Serial = $serial
    Android = $deviceInfo.Android
    Duration = "$([math]::Round(((Get-Date) - [datetime]::ParseExact($startTime,'yyyy-MM-dd_HH-mm-ss',$null)).TotalSeconds))s"
}

# --- Certification metrics ---
$certLines = @("")
$certLines += "## FCM Certification Metrics"
$certLines += ""
$certLines += "| Metric | Value |"
$certLines += "|--------|-------|"
$certLines += "| Execution mode | $execMode |"
$certLines += "| Classification | **$classification** |"
$certLines += "| Delivery latency | ${deliveryLatencyMs}ms |"
$certLines += "| Wake latency | ${wakeLatencyMs}ms |"
$certLines += "| Fullscreen latency | ${fullscreenLatencyMs}ms |"
$certLines += "| Poll count | $pollCount |"
$certLines += "| Poll interval | ${PollIntervalMs}ms |"
$certLines += "| Timeout | ${TimeoutSeconds}s |"
if ($fcmResult) {
    $certLines += "| FCM message ID | $($fcmResult.MessageId) |"
    $certLines += "| FCM status | $($fcmResult.Status) |"
}
$certLines += ""
$certLines += "## Latency Thresholds"
$certLines += ""
$certLines += "| Threshold | Value | Status |"
$certLines += "|-----------|-------|--------|"
$wakeStatus = if ($wakeLatencyMs -eq 0) { "N/A" } elseif ($wakeLatencyMs -le 3000) { "EXCELLENT" } elseif ($wakeLatencyMs -le 5000) { "GOOD" } elseif ($wakeLatencyMs -le 10000) { "ACCEPTABLE" } else { "SLOW" }
$fsStatus = if ($fullscreenLatencyMs -eq 0) { "N/A" } elseif ($fullscreenLatencyMs -le 4000) { "EXCELLENT" } elseif ($fullscreenLatencyMs -le 7000) { "GOOD" } elseif ($fullscreenLatencyMs -le 12000) { "ACCEPTABLE" } else { "SLOW" }
$certLines += "| Wake < 3s | ${wakeLatencyMs}ms | $wakeStatus |"
$certLines += "| Fullscreen < 4s | ${fullscreenLatencyMs}ms | $fsStatus |"

$allArtifacts = @(
    "device_info.txt"
    "${ScenarioId}_logcat.txt"
    "${ScenarioId}_pre_fcm.png"
    "${ScenarioId}_post_fcm.png"
    "${ScenarioId}_notification_dump.txt"
    "${ScenarioId}_activity_dump.txt"
)

Save-QA-Summary -Dir $artifactDir -Scenario "$ScenarioId - $ScenarioName" `
    -Verdict $verdict -Reasons $reasons -DeviceInfo $deviceInfo `
    -StartTime $startTime -EndTime $endTime `
    -Checks $checks -Artifacts $allArtifacts

($certLines -join "`n") | Add-Content "$artifactDir\summary.md"
Append-QA-RuntimeSummary $artifactDir "" ""

Complete-QA-Phase

Write-QA-Result $verdict $reasons $artifactDir
