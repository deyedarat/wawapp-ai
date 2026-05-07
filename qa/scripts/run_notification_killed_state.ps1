# ============================================================================
# WawApp QA - Killed-State Notification Smoke Test (N3)
# ============================================================================
# Usage: .\qa\scripts\run_notification_killed_state.ps1
#        .\qa\scripts\run_notification_killed_state.ps1 -TimeoutSeconds 30
#        .\qa\scripts\run_notification_killed_state.ps1 -FcmToken "token" -ProjectId "id"
# ============================================================================

param(
    [int]$TimeoutSeconds = 20,
    [string]$FcmToken = "",
    [string]$ProjectId = "",
    [string]$PackageName = "com.wawapp.driver",
    [string]$FullScreenActivity = "FullScreenNotificationActivity",
    [int]$HangThresholdSec = 60
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\lib\common.ps1"
. "$PSScriptRoot\lib\runtime.ps1"

$ScenarioId = "N3"
$ScenarioName = "Killed-State Notification"
$Script:QA_HangThresholdSec = $HangThresholdSec

# ============================================================================
# SETUP
# ============================================================================
Write-QA-Banner "WawApp QA - $ScenarioId : $ScenarioName"

Enter-QA-Phase "DEVICE_CHECK" -timeoutSec 15

Assert-AdbAvailable
$serial = Get-QA-Device
Assert-PackageInstalled $serial $PackageName

Complete-QA-Phase

$startTime = Get-QA-Timestamp
$artifactDir = New-QA-ArtifactDir $ScenarioId
$deviceInfo = Save-QA-DeviceInfo $serial "$artifactDir\device_info.txt"

# ============================================================================
# EXECUTE
# ============================================================================
Enter-QA-Phase "FORCE_STOP" -timeoutSec 10

Start-QA-Logcat $serial "$artifactDir\$(Get-QA-ArtifactName $ScenarioId 'logcat.txt')"
Invoke-QA-AdbShell $serial "am force-stop $PackageName"
Start-Sleep -Seconds 1

$pidResult = Invoke-QA-AdbShell $serial "pidof $PackageName"
if ($pidResult.Stdout.Trim()) { Write-QA-Warn "App still running (PID: $($pidResult.Stdout.Trim()))" }
else { Write-QA-Pass "App killed" }

Complete-QA-Phase

# --- Pre-FCM screenshot ---
Enter-QA-Phase "SCREENSHOT_CAPTURE" -timeoutSec 10
Save-QA-Screenshot $serial "$artifactDir\$(Get-QA-ArtifactName $ScenarioId 'pre_fcm.png')"
Complete-QA-Phase

# --- Send FCM ---
Enter-QA-Phase "SEND_PAYLOAD" -timeoutSec 15

if (-not $FcmToken) {
    Write-QA-Info "No FCM token - using ADB broadcast (local only)"
    Invoke-QA-AdbShell $serial "am broadcast -a com.wawapp.driver.TEST_NOTIFICATION --es type new_order --es orderId test_n3_$startTime --es pickupLat 18.0735 --es pickupLng -15.9582 --es dropoffLat 18.0800 --es dropoffLng -15.9500 --es price 500 --es clientName QA_Test"
}
else {
    if (-not $ProjectId) {
        Write-QA-Fail "-ProjectId required with -FcmToken"
        Set-QA-FinalState "FAIL"
        Invoke-QA-EmergencyCleanup $artifactDir "Missing ProjectId"
        exit 1
    }
    $body = @{
        message = @{
            token = $FcmToken
            data = @{
                type = "new_order"; orderId = "test_n3_$startTime"
                pickupLat = "18.0735"; pickupLng = "-15.9582"
                dropoffLat = "18.0800"; dropoffLng = "-15.9500"
                price = "500"; clientName = "QA_Test"
            }
        }
    } | ConvertTo-Json -Depth 4

    $token = gcloud auth print-access-token 2>$null
    if (-not $token) {
        Write-QA-Fail "gcloud auth failed"
        Set-QA-FinalState "FAIL"
        Invoke-QA-EmergencyCleanup $artifactDir "gcloud auth failed"
        exit 1
    }

    $url = "https://fcm.googleapis.com/v1/projects/$ProjectId/messages:send"
    try {
        Invoke-RestMethod -Uri $url -Method POST -Headers @{
            "Authorization" = "Bearer $token"; "Content-Type" = "application/json"
        } -Body $body
        Write-QA-Pass "FCM sent"
    } catch {
        Write-QA-Fail "FCM failed: $_"
        Set-QA-FinalState "FAIL"
        Invoke-QA-EmergencyCleanup $artifactDir "FCM send failed"
        exit 1
    }
}

Complete-QA-Phase

# --- Wait with heartbeat ---
Enter-QA-Phase "WAIT_FOR_ACTIVITY" -timeoutSec $TimeoutSeconds
Wait-QA-WithHeartbeat -Seconds $TimeoutSeconds -Label "WAITING_FOR_FULLSCREEN" -HeartbeatIntervalSec 3
Complete-QA-Phase

# ============================================================================
# COLLECT
# ============================================================================
Enter-QA-Phase "SCREENSHOT_CAPTURE" -timeoutSec 15
Save-QA-Screenshot $serial "$artifactDir\$(Get-QA-ArtifactName $ScenarioId 'post_fcm.png')"
Complete-QA-Phase

Enter-QA-Phase "WAIT_FOR_NOTIFICATION" -timeoutSec 10
Save-QA-NotificationDump $serial "$artifactDir\$(Get-QA-ArtifactName $ScenarioId 'notification_dump.txt')"
Save-QA-ActivityDump $serial "$artifactDir\$(Get-QA-ArtifactName $ScenarioId 'activity_dump.txt')"
Complete-QA-Phase

Enter-QA-Phase "LOGCAT_STOP" -timeoutSec 10
Stop-QA-Logcat
Complete-QA-Phase

# ============================================================================
# VERDICT
# ============================================================================
$verdict = "PASS"
$reasons = @()
$checks = @()

# Check 1: Full-screen activity
$actDump = Get-Content "$artifactDir\$(Get-QA-ArtifactName $ScenarioId 'activity_dump.txt')" -Raw -ErrorAction SilentlyContinue
if ($actDump -match $FullScreenActivity) {
    Write-QA-Pass "Full-screen activity visible"
    $checks += "| Full-screen activity | PASS |"
}
else {
    $verdict = "FAIL"
    $reasons += "Full-screen activity not visible"
    Write-QA-Fail "Full-screen activity NOT visible"
    $checks += "| Full-screen activity | FAIL |"
}

# Check 2: Notification in tray
$notifDump = Get-Content "$artifactDir\$(Get-QA-ArtifactName $ScenarioId 'notification_dump.txt')" -Raw -ErrorAction SilentlyContinue
if ($notifDump -match $PackageName) {
    Write-QA-Pass "Notification present"
    $checks += "| Notification in tray | PASS |"
}
else {
    $checks += "| Notification in tray | WARN (OK if full-screen fired) |"
    Write-QA-Info "No tray notification (OK if full-screen fired)"
}

# Check 3: App process alive
$postPidResult = Invoke-QA-AdbShell $serial "pidof $PackageName"
$postPid = $postPidResult.Stdout.Trim()
if ($postPid) {
    Write-QA-Pass "App alive (PID: $postPid)"
    $checks += "| App process woken | PASS PID:$postPid |"
}
else {
    $verdict = "FAIL"
    $reasons += "App not started after FCM"
    Write-QA-Fail "App NOT running"
    $checks += "| App process woken | FAIL |"
}

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
    Duration = "${TimeoutSeconds}s+"
}

$allArtifacts = @("device_info.txt","N3_logcat.txt","N3_pre_fcm.png","N3_post_fcm.png","N3_notification_dump.txt","N3_activity_dump.txt")

Save-QA-Summary -Dir $artifactDir -Scenario "$ScenarioId - $ScenarioName" `
    -Verdict $verdict -Reasons $reasons -DeviceInfo $deviceInfo `
    -StartTime $startTime -EndTime $endTime `
    -Checks $checks -Artifacts $allArtifacts

Append-QA-RuntimeSummary $artifactDir "" ""

Complete-QA-Phase

Write-QA-Result $verdict $reasons $artifactDir
