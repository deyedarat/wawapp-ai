# ============================================================================
# WawApp QA - Notification Spam / Dedup Stress Test
# ============================================================================
# Usage:
#   .\qa\scripts\run_notification_spam.ps1
#   .\qa\scripts\run_notification_spam.ps1 -Count 10 -IntervalMs 200
#   .\qa\scripts\run_notification_spam.ps1 -Mode duplicate -Count 8
#   .\qa\scripts\run_notification_spam.ps1 -RebootBetweenBursts
# ============================================================================

param(
    [int]$Count = 5,
    [int]$IntervalMs = 500,
    [ValidateSet("duplicate","unique")]
    [string]$Mode = "duplicate",
    [switch]$RebootBetweenBursts,
    [string]$PackageName = "com.wawapp.driver",
    [string]$FullScreenActivity = "FullScreenNotificationActivity",
    [int]$MaxExpectedNotifications = 1,
    [int]$HangThresholdSec = 60
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\lib\common.ps1"
. "$PSScriptRoot\lib\runtime.ps1"

$ScenarioId = "SPAM"
$ScenarioName = "Notification Spam / Dedup Stress"
$Script:QA_HangThresholdSec = $HangThresholdSec

# ============================================================================
# SETUP
# ============================================================================
Write-QA-Banner "WawApp QA - $ScenarioId : $ScenarioName"
Write-QA-Info "Mode: $Mode | Count: $Count | Interval: ${IntervalMs}ms"

Enter-QA-Phase "DEVICE_CHECK" -timeoutSec 15
Assert-AdbAvailable
$serial = Get-QA-Device
Assert-PackageInstalled $serial $PackageName
Complete-QA-Phase

$startTime = Get-QA-Timestamp
$artifactDir = New-QA-ArtifactDir $ScenarioId
$deviceInfo = Save-QA-DeviceInfo $serial "$artifactDir\device_info.txt"

# ============================================================================
# PRE-BURST STATE
# ============================================================================
Enter-QA-Phase "SCREENSHOT_CAPTURE" -timeoutSec 10
Save-QA-NotificationDump $serial "$artifactDir\$(Get-QA-ArtifactName $ScenarioId 'pre_notification_dump.txt')"
Save-QA-Screenshot $serial "$artifactDir\$(Get-QA-ArtifactName $ScenarioId 'pre_burst.png')"
Complete-QA-Phase

# Clear existing notifications for clean baseline
Invoke-QA-AdbShell $serial "service call notification 1" | Out-Null

# Start logcat
Start-QA-Logcat $serial "$artifactDir\$(Get-QA-ArtifactName $ScenarioId 'logcat.txt')"

# ============================================================================
# BURST EXECUTION
# ============================================================================
Enter-QA-Phase "SEND_PAYLOAD" -timeoutSec ($Count * 2 + 30)

$modeLabel = $Mode
Write-QA-Step "Sending $Count notifications ($modeLabel mode, ${IntervalMs}ms interval)"

$baseOrderId = "stress_$(Get-Date -Format 'HHmmss')"
$sentPayloads = @()

for ($i = 1; $i -le $Count; $i++) {
    if ($Mode -eq "duplicate") {
        $orderId = "${baseOrderId}_dup"
        $price = "500"
    }
    else {
        $orderId = "${baseOrderId}_$i"
        $price = "$( 400 + $i * 50 )"
    }

    $broadcastCmd = "am broadcast -a com.wawapp.driver.TEST_NOTIFICATION --es type new_order --es orderId $orderId --es pickupLat 18.0735 --es pickupLng -15.9582 --es dropoffLat 18.0800 --es dropoffLng -15.9500 --es price $price --es clientName QA_Stress_$i"
    Invoke-QA-AdbShell $serial $broadcastCmd | Out-Null

    $sentPayloads += @{ Index = $i; OrderId = $orderId; Price = $price; Timestamp = (Get-Date -Format "HH:mm:ss.fff") }
    Write-Host "  [$i/$Count] sent orderId=$orderId" -ForegroundColor DarkGray

    if ($i -lt $Count) {
        Start-Sleep -Milliseconds $IntervalMs
    }

    # Optional reboot between bursts
    if ($RebootBetweenBursts -and $i -lt $Count -and ($i % 3 -eq 0)) {
        Write-QA-Warn "Rebooting device after burst $i"
        Invoke-QA-Adb -Serial $serial -Arguments "reboot" -Silent | Out-Null
        Start-Sleep -Seconds 30
        $retries = 0
        while ($retries -lt 10) {
            $check = Invoke-QA-AdbShell $serial "echo ok"
            if ($check.Stdout.Trim() -eq "ok") { break }
            Start-Sleep -Seconds 5
            $retries++
        }
        if ($retries -ge 10) {
            Write-QA-Fail "Device did not recover after reboot"
            Set-QA-FinalState "TIMEOUT"
            Invoke-QA-EmergencyCleanup $artifactDir "Device reboot recovery timeout"
            exit 1
        }
        Write-QA-Info "Device back online"
    }
}

Write-QA-Pass "All $Count notifications sent"
Complete-QA-Phase

# --- Settle with heartbeat ---
Enter-QA-Phase "WAIT_FOR_NOTIFICATION" -timeoutSec 10
Wait-QA-WithHeartbeat -Seconds 5 -Label "SETTLING" -HeartbeatIntervalSec 2
Complete-QA-Phase

# ============================================================================
# POST-BURST COLLECTION
# ============================================================================
Enter-QA-Phase "SCREENSHOT_CAPTURE" -timeoutSec 15
Save-QA-Screenshot $serial "$artifactDir\$(Get-QA-ArtifactName $ScenarioId 'post_burst.png')"
Save-QA-NotificationDump $serial "$artifactDir\$(Get-QA-ArtifactName $ScenarioId 'post_notification_dump.txt')"
Save-QA-ActivityDump $serial "$artifactDir\$(Get-QA-ArtifactName $ScenarioId 'activity_dump.txt')"
Complete-QA-Phase

Enter-QA-Phase "LOGCAT_STOP" -timeoutSec 10
Stop-QA-Logcat
Complete-QA-Phase

# ============================================================================
# VERDICT EVALUATION
# ============================================================================
$verdict = "PASS"
$reasons = @()
$checks = @()

# --- Check 1: App not crashed ---
$postPidResult = Invoke-QA-AdbShell $serial "pidof $PackageName"
$postPid = $postPidResult.Stdout.Trim()
if ($postPid) {
    Write-QA-Pass "App alive (PID: $postPid)"
    $checks += "| App not crashed | PASS PID:$postPid |"
}
else {
    $verdict = "FAIL"
    $reasons += "App crashed during burst"
    Write-QA-Fail "App crashed"
    $checks += "| App not crashed | FAIL |"
}

# --- Check 2: No duplicate full-screen activities ---
$actDump = Get-Content "$artifactDir\$(Get-QA-ArtifactName $ScenarioId 'activity_dump.txt')" -Raw -ErrorAction SilentlyContinue
$fsMatches = [regex]::Matches($actDump, $FullScreenActivity)
$fsCount = $fsMatches.Count

if ($fsCount -le 1) {
    Write-QA-Pass "Full-screen activity count: $fsCount (no duplicates)"
    $checks += "| No duplicate full-screen | PASS count=$fsCount |"
}
else {
    $verdict = "FAIL"
    $reasons += "Multiple full-screen activities: $fsCount"
    Write-QA-Fail "Duplicate full-screen activities: $fsCount"
    $checks += "| No duplicate full-screen | FAIL count=$fsCount |"
}

# --- Check 3: Notification tray not flooded ---
$notifDump = Get-Content "$artifactDir\$(Get-QA-ArtifactName $ScenarioId 'post_notification_dump.txt')" -Raw -ErrorAction SilentlyContinue
$notifMatches = [regex]::Matches($notifDump, "pkg=$PackageName")
$notifCount = $notifMatches.Count

if ($Mode -eq "duplicate") {
    if ($notifCount -le $MaxExpectedNotifications) {
        Write-QA-Pass "Dedup working: $notifCount notification(s) for $Count sends"
        $checks += "| Dedup (tray count) | PASS $notifCount/$Count |"
    }
    else {
        $verdict = "FAIL"
        $reasons += "Dedup failed: $notifCount notifications for $Count duplicate sends"
        Write-QA-Fail "Tray flooded: $notifCount notifications"
        $checks += "| Dedup (tray count) | FAIL $notifCount/$Count |"
    }
}
else {
    if ($notifCount -le $Count) {
        Write-QA-Pass "Notification count reasonable: $notifCount"
        $checks += "| Tray not flooded | PASS $notifCount/$Count |"
    }
    else {
        $verdict = "FAIL"
        $reasons += "More notifications than sent: $notifCount > $Count"
        Write-QA-Fail "Unexpected notification count: $notifCount"
        $checks += "| Tray not flooded | FAIL $notifCount/$Count |"
    }
}

# --- Check 4: Dedup log evidence ---
$logcat = Get-Content "$artifactDir\$(Get-QA-ArtifactName $ScenarioId 'logcat.txt')" -Raw -ErrorAction SilentlyContinue
$dupIdPattern = "duplicate.*notification|already.*displayed|dedup"
$dupHits = [regex]::Matches($logcat, $dupIdPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

if ($Mode -eq "duplicate" -and $dupHits.Count -gt 0) {
    Write-QA-Pass "Dedup log entries found ($($dupHits.Count) hits)"
    $checks += "| Dedup log evidence | PASS $($dupHits.Count) entries |"
}
elseif ($Mode -eq "duplicate") {
    Write-QA-Warn "No dedup log entries (dedup may be silent)"
    $checks += "| Dedup log evidence | WARN none found |"
}
else {
    $checks += "| Dedup log evidence | N/A (unique mode) |"
}

# --- Check 5: No crash traces in logcat ---
$crashPattern = "FATAL EXCEPTION|ANR in $PackageName|Process.*has died"
$crashes = [regex]::Matches($logcat, $crashPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
if ($crashes.Count -eq 0) {
    Write-QA-Pass "No crash traces in logcat"
    $checks += "| No crash in logcat | PASS |"
}
else {
    $verdict = "FAIL"
    $reasons += "Crash detected in logcat ($($crashes.Count) traces)"
    Write-QA-Fail "Crash traces found: $($crashes.Count)"
    $checks += "| No crash in logcat | FAIL $($crashes.Count) traces |"
}

# ============================================================================
# SAVE RESULTS
# ============================================================================
Enter-QA-Phase "SUMMARY_EXPORT" -timeoutSec 10

if ($verdict -eq "PASS") { Set-QA-FinalState "PASS" }
else { Set-QA-FinalState "FAIL" }

$endTime = Get-QA-Timestamp

Save-QA-Verdict $artifactDir $verdict $reasons @{
    Scenario  = "$ScenarioId - $ScenarioName"
    Timestamp = $startTime
    Serial    = $serial
    Android   = $deviceInfo.Android
    Duration  = "$(((Get-Date) - [datetime]::ParseExact($startTime,'yyyy-MM-dd_HH-mm-ss',$null)).TotalSeconds)s"
}

# --- Burst statistics ---
$burstLines = @("", "## Burst Configuration", "", "| Parameter | Value |", "|-----------|-------|")
$burstLines += "| Mode | $Mode |"
$burstLines += "| Count | $Count |"
$burstLines += "| Interval | ${IntervalMs}ms |"
$burstLines += "| Reboot between | $RebootBetweenBursts |"
$burstLines += "| Max expected notifications | $MaxExpectedNotifications |"
$burstLines += ""
$burstLines += "## Burst Log"
$burstLines += ""
$burstLines += "| # | OrderId | Price | Sent At |"
$burstLines += "|---|---------|-------|---------|"
foreach ($p in $sentPayloads) {
    $burstLines += "| $($p.Index) | $($p.OrderId) | $($p.Price) | $($p.Timestamp) |"
}
$burstLines += ""
$burstLines += "## Post-Burst Metrics"
$burstLines += ""
$burstLines += "| Metric | Value |"
$burstLines += "|--------|-------|"
$burstLines += "| Notifications in tray | $notifCount |"
$burstLines += "| Full-screen activities | $fsCount |"
$burstLines += "| Crash traces | $($crashes.Count) |"
$burstLines += "| Dedup log hits | $($dupHits.Count) |"

$allArtifacts = @(
    "device_info.txt"
    "SPAM_pre_notification_dump.txt"
    "SPAM_pre_burst.png"
    "SPAM_logcat.txt"
    "SPAM_post_burst.png"
    "SPAM_post_notification_dump.txt"
    "SPAM_activity_dump.txt"
)

Save-QA-Summary -Dir $artifactDir -Scenario "$ScenarioId - $ScenarioName" `
    -Verdict $verdict -Reasons $reasons -DeviceInfo $deviceInfo `
    -StartTime $startTime -EndTime $endTime `
    -Checks $checks -Artifacts $allArtifacts

# Append burst stats + runtime observability
($burstLines -join "`n") | Add-Content "$artifactDir\summary.md"
Append-QA-RuntimeSummary $artifactDir "" ""

Complete-QA-Phase

Write-QA-Result $verdict $reasons $artifactDir
