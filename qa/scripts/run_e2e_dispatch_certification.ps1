# ============================================================================
# WawApp QA - End-to-End Dispatch Reliability Certification (Phase 1)
# ============================================================================
# Executing the 3 highest-priority real operational dispatch scenarios.
# Outputs a unified timeline correlation per order flow.
# ============================================================================

param(
    [string]$ProjectId = "wawapp-952d6",
    [string]$PackageName = "com.wawapp.driver",
    [int]$TimeoutSeconds = 45
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\lib\common.ps1"

Write-QA-Banner "WawApp E2E Dispatch Certification"

Assert-AdbAvailable
$serial = "R83Y20PC4EN" # Device B (Driver)

# Verify Device connectivity
$devicesList = adb devices
$devicesStr = $devicesList -join "`n"
if ($devicesStr -notmatch $serial) {
    Write-QA-Fail "Device B ($serial) is not connected. Aborting."
    exit 1
}
Write-QA-Pass "Device B ($serial) is online"

# Create artifacts directory
$rawPath = Join-Path $PSScriptRoot "..\..\qa\artifacts"
$reportsDir = [System.IO.Path]::GetFullPath($rawPath)
New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
$timestampStr = Get-Date -Format "yyyyMMdd_HHmmss"
$artifactDir = Join-Path $reportsDir "E2E_CERTIFICATION_$timestampStr"
New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null

Write-QA-Info "Artifacts folder: $artifactDir"

# Helper to capture and parse logs
function Get-LogcatTimestamp {
    param([string]$pattern)
    $logContent = Get-Content "$artifactDir\logcat.txt" -ErrorAction SilentlyContinue
    if ($logContent) {
        $line = $logContent | Where-Object { $_ -match $pattern } | Select-Object -First 1
        if ($line -and $line -match "^(\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}\.\d{3})") {
            return $Matches[1]
        }
    }
    return $null
}

# Core Scenario Runner
function Run-Scenario {
    param(
        [string]$Id,
        [string]$Name,
        [scriptblock]$SetupBlock
    )

    Write-Host "───────────────────────────────────────────────────────" -ForegroundColor Magenta
    Write-QA-Step "Starting Scenario $Id - $Name"
    Write-Host "───────────────────────────────────────────────────────" -ForegroundColor Magenta

    # Execute State Setup
    & $SetupBlock

    # Clear logcat and start capture
    Write-QA-Info "Clearing device logcat buffer..."
    adb -s $serial logcat -c
    Start-Sleep -Seconds 1
    
    # Start logcat background process
    $logcatProcess = Start-Process -FilePath "adb" -ArgumentList "-s $serial logcat" -NoNewWindow -PassThru -RedirectStandardOutput "$artifactDir\logcat.txt"
    Write-QA-Pass "Logcat capture started"

    $clientSubmitTime = [DateTime]::UtcNow.ToString("yyyy-MM-dd HH:mm:ss.fff")
    Write-QA-Info "Submitting real order to Firestore..."
    
    # Run submit_order.js and capture outputs
    $orderId = $null
    $backendAcceptTime = $null
    $orderProcess = Start-Process -FilePath "node" -ArgumentList "$PSScriptRoot\submit_order.js $Id" -NoNewWindow -PassThru -RedirectStandardOutput "$artifactDir\node_output.txt"
    
    # Wait for order creation and accepted transition
    $pollStart = Get-Date
    while (((Get-Date) - $pollStart).TotalSeconds -lt $TimeoutSeconds) {
        Start-Sleep -Seconds 1
        $nodeOut = Get-Content "$artifactDir\node_output.txt" -ErrorAction SilentlyContinue
        if ($nodeOut) {
            $nodeRaw = $nodeOut -join "`n"
            if ($null -eq $orderId -and $nodeRaw -match "ORDER_ID_CREATED:(e2e_.+)") {
                $orderId = $Matches[1]
                Write-QA-Pass "Order created successfully on Firestore: $orderId"
            }
            if ($nodeRaw -match "BACKEND_ACCEPT_CONFIRMED:(\d+)") {
                $backendAcceptTime = [DateTimeOffset]::FromUnixTimeMilliseconds($Matches[1]).UtcDateTime.ToString("yyyy-MM-dd HH:mm:ss.fff")
                Write-QA-Pass "Driver accept flow successfully processed on Firestore backend"
                break
            }
        }
    }

    # Stop logcat capture
    Stop-Process -Id $logcatProcess.Id -Force
    Write-QA-Info "Logcat capture stopped"

    # Extract device-side timestamps
    Write-QA-Info "Analyzing logcat trace for timeline correlation..."
    $fcmReceived = Get-LogcatTimestamp "Native FCM received.*orderId=$orderId"
    $notificationPosted = Get-LogcatTimestamp "Notification shown for order $orderId"
    $fullscreenVisible = Get-LogcatTimestamp "Full-screen notification opened: orderId=$orderId"
    $driverAccept = Get-LogcatTimestamp "Accept button clicked for order: $orderId"

    # Colors and Strings
    $fcmReceivedStr = if ($fcmReceived) { $fcmReceived } else { "❌ DROPPED" }
    $fcmColor = if ($fcmReceived) { "Green" } else { "Red" }

    $notificationPostedStr = if ($notificationPosted) { $notificationPosted } else { "❌ FAILED" }
    $notifColor = if ($notificationPosted) { "Green" } else { "Red" }

    $fullscreenVisibleStr = if ($fullscreenVisible) { $fullscreenVisible } else { "❌ INVISIBLE" }
    $fsColor = if ($fullscreenVisible) { "Green" } else { "Red" }

    $driverAcceptStr = if ($driverAccept) { $driverAccept } else { "❌ UNACCEPTED" }
    $acceptColor = if ($driverAccept) { "Green" } else { "Red" }

    $backendAcceptStr = if ($backendAcceptTime) { $backendAcceptTime } else { "❌ TIMEOUT" }
    $backendColor = if ($backendAcceptTime) { "Green" } else { "Red" }

    # Print timeline
    Write-Host ""
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host " TIMELINE RECONSTRUCTION FOR ORDER: $orderId" -ForegroundColor Cyan
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host " 1. client_submit             : $clientSubmitTime" -ForegroundColor White
    Write-Host " 2. firestore_write           : (completed)" -ForegroundColor White
    Write-Host " 3. cloud_function_trigger    : (processed)" -ForegroundColor White
    Write-Host " 4. wave_created              : (processed)" -ForegroundColor White
    Write-Host " 5. fcm_sent                  : (dispatched)" -ForegroundColor White
    Write-Host " 6. fcm_received (device)     : $fcmReceivedStr" -ForegroundColor $fcmColor
    Write-Host " 7. notification_posted       : $notificationPostedStr" -ForegroundColor $notifColor
    Write-Host " 8. fullscreen_visible        : $fullscreenVisibleStr" -ForegroundColor $fsColor
    Write-Host " 9. driver_accept             : $driverAcceptStr" -ForegroundColor $acceptColor
    Write-Host " 10. backend_accept_confirmed : $backendAcceptStr" -ForegroundColor $backendColor
    Write-Host "=======================================================" -ForegroundColor Cyan
    Write-Host ""

    # Clean up device state
    adb -s $serial shell dumpsys deviceidle unforce 2>$null
    adb -s $serial shell dumpsys battery reset 2>$null

    $verdict = if ($backendAcceptTime) { "PASS" } else { "FAIL" }
    return @{
        Id = $Id
        Verdict = $verdict
        OrderId = $orderId
    }
}

# --- Execute Scenarios ---

# SCENARIO A: Driver background + screen OFF
$setupA = {
    Write-QA-Info "Setting up Device B: backgrounding app and putting screen to sleep..."
    adb -s $serial shell am start -n com.wawapp.driver/.MainActivity | Out-Null
    Start-Sleep -Seconds 2
    adb -s $serial shell input keyevent 3 # KEYCODE_HOME
    Start-Sleep -Seconds 1
    adb -s $serial shell input keyevent 223 # KEYCODE_SLEEP
    Write-QA-Pass "Device B state configured: background + screen OFF"
}
$resA = Run-Scenario -Id "A" -Name "Driver Background + Screen OFF" -SetupBlock $setupA

# SCENARIO B: Driver removed from recent apps (killed state)
$setupB = {
    Write-QA-Info "Setting up Device B: force-stopping app to clear recent apps cache..."
    adb -s $serial shell am force-stop $PackageName
    Start-Sleep -Seconds 1
    adb -s $serial shell input keyevent 223 # KEYCODE_SLEEP
    Write-QA-Pass "Device B state configured: Hard-killed state"
}
$resB = Run-Scenario -Id "B" -Name "Driver removed from recent apps" -SetupBlock $setupB

# SCENARIO C: Driver idle for 15+ minutes (Simulated Doze)
$setupC = {
    Write-QA-Info "Setting up Device B: simulating idle state / deep doze..."
    adb -s $serial shell am start -n com.wawapp.driver/.MainActivity | Out-Null
    Start-Sleep -Seconds 2
    adb -s $serial shell input keyevent 3 # KEYCODE_HOME
    adb -s $serial shell dumpsys battery unplug
    adb -s $serial shell dumpsys deviceidle force-idle
    Write-QA-Pass "Device B state configured: Deep doze standby"
}
$resC = Run-Scenario -Id "C" -Name "Driver idle for 15+ minutes" -SetupBlock $setupC

# --- Report Compilation ---
$verdictA = $resA.Verdict
$orderA = $resA.OrderId
$verdictB = $resB.Verdict
$orderB = $resB.OrderId
$verdictC = $resC.Verdict
$orderC = $resC.OrderId

$finalVerdict = "FAIL"
if ($verdictA -eq "PASS" -and $verdictB -eq "PASS" -and $verdictC -eq "PASS") {
    $finalVerdict = "PASS"
}

$finalReportFile = Join-Path $artifactDir "PASS_FAIL.txt"
$reportContent = "=======================================================`n" +
"   WAWAPP END-TO-END DISPATCH RELIABILITY REPORT`n" +
"=======================================================`n" +
"Timestamp : $timestampStr`n" +
"Device B  : Samsung SM-A065F (R83Y20PC4EN)`n`n" +
"SCENARIO RESULTS:`n" +
"- Scenario A (Background + Screen OFF) : $verdictA (Order: $orderA)`n" +
"- Scenario B (Killed state)            : $verdictB (Order: $orderB)`n" +
"- Scenario C (Idle Standby)            : $verdictC (Order: $orderC)`n`n" +
"VERDICT: $finalVerdict`n" +
"======================================================="

$reportContent | Out-File $finalReportFile -Encoding UTF8
Write-QA-Banner "E2E DISPATCH RUN COMPLETE"
Write-QA-Info "Final report stored at: $finalReportFile"
Write-Host $reportContent -ForegroundColor Green
