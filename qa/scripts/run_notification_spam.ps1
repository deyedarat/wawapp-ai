# ============================================================================
# WawApp QA - Notification Spam / Dedup Stress Test
# ============================================================================
# This is a DEDUP/STACKING stress test, NOT a killed-state wake test.
# The app is warm-started before the burst to isolate dedup behavior.
#
# Usage:
#   .\qa\scripts\run_notification_spam.ps1
#   .\qa\scripts\run_notification_spam.ps1 -Count 10 -IntervalMs 200
#   .\qa\scripts\run_notification_spam.ps1 -Mode duplicate -Count 8
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
$intervalLabel = "${IntervalMs}ms"
Write-QA-Info "Mode: $Mode | Count: $Count | Interval: $intervalLabel"

Enter-QA-Phase "DEVICE_CHECK" -timeoutSec 15
Assert-AdbAvailable
$serial = Get-QA-Device
Assert-PackageInstalled $serial $PackageName
Complete-QA-Phase

$startTime = Get-QA-Timestamp
$artifactDir = New-QA-ArtifactDir $ScenarioId
$deviceInfo = Save-QA-DeviceInfo $serial "$artifactDir\device_info.txt"

# ============================================================================
# PRECONDITION: WARM-START APP
# ============================================================================
Enter-QA-Phase "APP_WARM" -timeoutSec 15

Invoke-QA-AdbShell $serial "am start -n $PackageName/.MainActivity --activity-no-animation" | Out-Null
Start-Sleep -Seconds 2

$warmPidResult = Invoke-QA-AdbShell $serial "pidof $PackageName"
$warmPid = $warmPidResult.Stdout.Trim()
$appWarmed = [bool]$warmPid

if ($appWarmed) {
    Write-QA-Pass "App warmed PID:$warmPid"
} else {
    Write-QA-Warn "App did not start - retrying with monkey"
    Invoke-QA-AdbShell $serial "monkey -p $PackageName -c android.intent.category.LAUNCHER 1" | Out-Null
    Start-Sleep -Seconds 3
    $warmPidResult = Invoke-QA-AdbShell $serial "pidof $PackageName"
    $warmPid = $warmPidResult.Stdout.Trim()
    $appWarmed = [bool]$warmPid
    if ($appWarmed) { Write-QA-Pass "App warmed via monkey PID:$warmPid" }
    else { Write-QA-Fail "App could not be started" }
}

Invoke-QA-AdbShell $serial "input keyevent KEYCODE_HOME" | Out-Null
Start-Sleep -Milliseconds 500

Complete-QA-Phase

# ============================================================================
# PRE-BURST STATE
# ============================================================================
Enter-QA-Phase "SCREENSHOT_CAPTURE" -timeoutSec 10
$preNotifFile = Join-Path $artifactDir (Get-QA-ArtifactName $ScenarioId 'pre_notification_dump.txt')
$preBurstFile = Join-Path $artifactDir (Get-QA-ArtifactName $ScenarioId 'pre_burst.png')
Save-QA-NotificationDump $serial $preNotifFile
Save-QA-Screenshot $serial $preBurstFile
Complete-QA-Phase

Invoke-QA-AdbShell $serial "service call notification 1" | Out-Null

$logcatFile = Join-Path $artifactDir (Get-QA-ArtifactName $ScenarioId 'logcat.txt')
Start-QA-Logcat $serial $logcatFile

# ============================================================================
# BURST EXECUTION
# ============================================================================
Enter-QA-Phase "SEND_PAYLOAD" -timeoutSec ($Count * 2 + 30)

Write-QA-Step "Sending $Count notifications - $Mode mode, $intervalLabel interval"

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

Enter-QA-Phase "WAIT_FOR_NOTIFICATION" -timeoutSec 10
Wait-QA-WithHeartbeat -Seconds 5 -Label "SETTLING" -HeartbeatIntervalSec 2
Complete-QA-Phase

# ============================================================================
# POST-BURST COLLECTION
# ============================================================================
Enter-QA-Phase "SCREENSHOT_CAPTURE" -timeoutSec 15
$postBurstFile = Join-Path $artifactDir (Get-QA-ArtifactName $ScenarioId 'post_burst.png')
$postNotifFile = Join-Path $artifactDir (Get-QA-ArtifactName $ScenarioId 'post_notification_dump.txt')
$actDumpFile = Join-Path $artifactDir (Get-QA-ArtifactName $ScenarioId 'activity_dump.txt')
Save-QA-Screenshot $serial $postBurstFile
Save-QA-NotificationDump $serial $postNotifFile
Save-QA-ActivityDump $serial $actDumpFile
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

# --- Precondition: App warmed ---
if ($appWarmed) {
    $checks += "| App warmed | PASS PID:$warmPid |"
} else {
    $verdict = "FAIL"
    $reasons += "App could not be warm-started before burst"
    $checks += "| App warmed | FAIL |"
}

# --- Check 1: Crash detection via logcat ---
$logcat = Get-Content $logcatFile -Raw -ErrorAction SilentlyContinue
$crashPattern = "FATAL EXCEPTION|ANR in $PackageName|Process.*$PackageName.*has died"
$crashes = @()
if ($logcat) {
    $crashes = @([regex]::Matches($logcat, $crashPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase))
}

if ($crashes.Count -eq 0) {
    Write-QA-Pass "No crash traces in logcat"
    $checks += "| Crash detection | PASS |"
} else {
    $verdict = "FAIL"
    $crashCount = $crashes.Count
    $reasons += "App crashed during burst - $crashCount crash traces in logcat"
    Write-QA-Fail "Crash traces found: $crashCount"
    $checks += "| Crash detection | FAIL $crashCount traces |"
}

# --- Check 2: Process liveness ---
$postPidResult = Invoke-QA-AdbShell $serial "pidof $PackageName"
$postPid = $postPidResult.Stdout.Trim()

if ($postPid) {
    Write-QA-Pass "App alive after burst PID:$postPid"
    $checks += "| Process liveness | PASS PID:$postPid |"
} else {
    if ($crashes.Count -gt 0) {
        Write-QA-Fail "App process dead - crash confirmed"
        $checks += "| Process liveness | FAIL crash confirmed |"
    } elseif (-not $appWarmed) {
        Write-QA-Warn "App not running - was never warmed"
        $checks += "| Process liveness | SKIP precondition failed |"
    } else {
        Write-QA-Warn "App process gone after burst - no crash in logcat, likely system kill"
        $checks += "| Process liveness | WARN system kill |"
    }
}

# --- Check 3: No duplicate full-screen activities ---
$actDump = Get-Content $actDumpFile -Raw -ErrorAction SilentlyContinue
$fsMatches = @()
if ($actDump) { $fsMatches = @([regex]::Matches($actDump, $FullScreenActivity)) }
$fsCount = $fsMatches.Count

if ($fsCount -le 1) {
    Write-QA-Pass "Full-screen activity count: $fsCount"
    $checks += "| Fullscreen stacking | PASS count=$fsCount |"
} else {
    $verdict = "FAIL"
    $reasons += "Multiple full-screen activities: $fsCount"
    Write-QA-Fail "Duplicate full-screen activities: $fsCount"
    $checks += "| Fullscreen stacking | FAIL count=$fsCount |"
}

# --- Check 4: Notification dedup ---
$notifDump = Get-Content $postNotifFile -Raw -ErrorAction SilentlyContinue
$notifMatches = @()
if ($notifDump) { $notifMatches = @([regex]::Matches($notifDump, "pkg=$PackageName")) }
$notifCount = $notifMatches.Count

if ($Mode -eq "duplicate") {
    if ($notifCount -le $MaxExpectedNotifications) {
        Write-QA-Pass "Dedup working: $notifCount notification for $Count sends"
        $checks += "| Notification dedup | PASS $notifCount/$Count |"
    } else {
        $verdict = "FAIL"
        $reasons += "Dedup failed: $notifCount notifications for $Count duplicate sends"
        Write-QA-Fail "Tray flooded: $notifCount notifications"
        $checks += "| Notification dedup | FAIL $notifCount/$Count |"
    }
} else {
    if ($notifCount -le $Count) {
        Write-QA-Pass "Notification count reasonable: $notifCount"
        $checks += "| Notification dedup | PASS $notifCount/$Count |"
    } else {
        $verdict = "FAIL"
        $reasons += "More notifications than sent: $notifCount > $Count"
        Write-QA-Fail "Unexpected notification count: $notifCount"
        $checks += "| Notification dedup | FAIL $notifCount/$Count |"
    }
}

# --- Check 5: Dedup log evidence ---
$dupIdPattern = 'duplicate.*notification|already.*displayed|dedup'
$dupHits = @()
if ($logcat) {
    $dupHits = @([regex]::Matches($logcat, $dupIdPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase))
}

$dupCount = $dupHits.Count
if ($Mode -eq "duplicate" -and $dupCount -gt 0) {
    Write-QA-Pass "Dedup log entries found: $dupCount hits"
    $checks += "| Dedup log evidence | PASS $dupCount entries |"
} elseif ($Mode -eq "duplicate") {
    Write-QA-Warn "No dedup log entries found"
    $checks += "| Dedup log evidence | WARN none found |"
} else {
    $checks += "| Dedup log evidence | N/A unique mode |"
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
    Duration  = "$([math]::Round(((Get-Date) - [datetime]::ParseExact($startTime,'yyyy-MM-dd_HH-mm-ss',$null)).TotalSeconds))s"
}

$burstLines = @("", "## Burst Configuration", "", "| Parameter | Value |", "|-----------|-------|")
$burstLines += "| Mode | $Mode |"
$burstLines += "| Count | $Count |"
$burstLines += "| Interval | $intervalLabel |"
$burstLines += "| Reboot between | $RebootBetweenBursts |"
$burstLines += "| Max expected notifications | $MaxExpectedNotifications |"
$burstLines += ""
$burstLines += "## Burst Log"
$burstLines += ""
$burstLines += "| # | OrderId | Price | Sent At |"
$burstLines += "|---|---------|-------|---------|"
foreach ($p in $sentPayloads) {
    $idx = $p.Index; $oid = $p.OrderId; $pr = $p.Price; $ts = $p.Timestamp
    $burstLines += "| $idx | $oid | $pr | $ts |"
}
$burstLines += ""
$burstLines += "## Post-Burst Metrics"
$burstLines += ""
$burstLines += "| Metric | Value |"
$burstLines += "|--------|-------|"
$burstLines += "| App warmed | $appWarmed PID:$warmPid |"
$aliveLabel = if ($postPid) { "YES PID:$postPid" } else { "NO" }
$burstLines += "| App alive after burst | $aliveLabel |"
$cCount = $crashes.Count
$burstLines += "| Crash traces in logcat | $cCount |"
$burstLines += "| Notifications in tray | $notifCount |"
$burstLines += "| Full-screen activities | $fsCount |"
$burstLines += "| Dedup log hits | $dupCount |"

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

($burstLines -join "`n") | Add-Content "$artifactDir\summary.md"
Append-QA-RuntimeSummary $artifactDir "" ""

Complete-QA-Phase

Write-QA-Result $verdict $reasons $artifactDir
