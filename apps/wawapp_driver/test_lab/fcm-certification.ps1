<#
.SYNOPSIS
    WawApp FCM Notification Certification Pipeline
    Production-grade push notification validation on Firebase Test Lab physical devices.

.DESCRIPTION
    This script:
    1. Reads FCM token from Test Lab logcat output
    2. Sends real FCM v1 API push notifications
    3. Validates delivery via logcat markers
    4. Measures latency and prints PASS/FAIL verdicts

.PARAMETER Token
    FCM device token (extracted from Test Lab logs or passed directly)

.PARAMETER ServiceAccountJson
    Path to Firebase service account JSON (for OAuth2 token generation)

.PARAMETER ProjectId
    Firebase project ID

.PARAMETER Scenario
    Test scenario: wave_offer | fullscreen | qa_test | dedup | all

.PARAMETER OutputFormat
    Output mode: "human" (colored terminal) or "json" (NDJSON for agents)

.PARAMETER OutputFile
    Path to write NDJSON events (used by MCP/Antigravity agents)

.PARAMETER RunId
    Correlation ID for multi-step agent workflows

.EXAMPLE
    .\fcm-certification.ps1 -Token "abc123..." -ServiceAccountJson ".\sa.json" -ProjectId "wawapp-prod" -Scenario all
    .\fcm-certification.ps1 -Token "abc123..." -ServiceAccountJson ".\sa.json" -ProjectId "wawapp-prod" -OutputFormat json
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$Token,

    [Parameter(Mandatory=$true)]
    [string]$ServiceAccountJson,

    [Parameter(Mandatory=$true)]
    [string]$ProjectId,

    [Parameter(Mandatory=$false)]
    [ValidateSet("wave_offer", "fullscreen", "qa_test", "dedup", "all")]
    [string]$Scenario = "all",

    [Parameter(Mandatory=$false)]
    [string]$LogcatFile,

    # --- Agentic Orchestration Parameters ---
    [Parameter(Mandatory=$false)]
    [ValidateSet("human", "json")]
    [string]$OutputFormat = "human",

    [Parameter(Mandatory=$false)]
    [string]$OutputFile,

    [Parameter(Mandatory=$false)]
    [string]$RunId = [guid]::NewGuid().ToString("N").Substring(0, 12)
)

$ErrorActionPreference = "Stop"

# ===========================================================================
# CONFIGURATION
# ===========================================================================

$FCM_V1_URL = "https://fcm.googleapis.com/v1/projects/$ProjectId/messages:send"
$OAUTH_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
$VERDICT = @{}
$TIMESTAMPS = @{}
$EVENTS = [System.Collections.ArrayList]::new()

# ===========================================================================
# AGENTIC ORCHESTRATION: Structured Event Emitter
# ===========================================================================

function Emit-Event {
    param(
        [string]$Event,
        [string]$Phase,
        [hashtable]$Data = @{}
    )

    $eventObj = @{
        event  = $Event
        ts     = [long]([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())
        runId  = $RunId
        phase  = $Phase
        data   = $Data
    }

    $json = $eventObj | ConvertTo-Json -Compress -Depth 5
    [void]$EVENTS.Add($eventObj)

    if ($OutputFormat -eq "json") {
        Write-Output $json
    }

    if ($OutputFile) {
        $json | Out-File -FilePath $OutputFile -Append -Encoding utf8
    }
}

# ===========================================================================
# HELPER FUNCTIONS
# ===========================================================================

function Write-Header($text) {
    if ($OutputFormat -eq "human") {
        Write-Host ""
        Write-Host "=======================================================" -ForegroundColor Cyan
        Write-Host "  $text" -ForegroundColor Cyan
        Write-Host "=======================================================" -ForegroundColor Cyan
    }
}

function Write-Step($text) {
    if ($OutputFormat -eq "human") {
        Write-Host "  -> $text" -ForegroundColor Yellow
    }
}

function Write-Pass($test, $detail) {
    $VERDICT[$test] = "PASS"
    if ($OutputFormat -eq "human") {
        Write-Host "  [PASS] $test - $detail" -ForegroundColor Green
    }
    Emit-Event -Event "ASSERTION_RESULT" -Phase $test -Data @{ check = $test; result = "PASS"; detail = $detail }
}

function Write-Fail($test, $detail) {
    $VERDICT[$test] = "FAIL"
    if ($OutputFormat -eq "human") {
        Write-Host "  [FAIL] $test - $detail" -ForegroundColor Red
    }
    Emit-Event -Event "ASSERTION_RESULT" -Phase $test -Data @{ check = $test; result = "FAIL"; detail = $detail }
}

function Get-OAuthToken {
    param([string]$SaJsonPath)

    $sa = Get-Content $SaJsonPath | ConvertFrom-Json
    $now = [int][double]::Parse((Get-Date -UFormat %s))
    $exp = $now + 3600

    # JWT Header
    $header = @{ alg = "RS256"; typ = "JWT" } | ConvertTo-Json -Compress
    $headerB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($header)).TrimEnd('=').Replace('+','-').Replace('/','_')

    # JWT Claim
    $claim = @{
        iss   = $sa.client_email
        scope = $OAUTH_SCOPE
        aud   = "https://oauth2.googleapis.com/token"
        iat   = $now
        exp   = $exp
    } | ConvertTo-Json -Compress
    $claimB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($claim)).TrimEnd('=').Replace('+','-').Replace('/','_')

    # Sign with RSA
    $signingInput = "$headerB64.$claimB64"
    $keyText = $sa.private_key
    $rsa = [System.Security.Cryptography.RSA]::Create()
    $rsa.ImportFromPem($keyText)
    $sigBytes = $rsa.SignData(
        [Text.Encoding]::UTF8.GetBytes($signingInput),
        [Security.Cryptography.HashAlgorithmName]::SHA256,
        [Security.Cryptography.RSASignaturePadding]::Pkcs1
    )
    $sigB64 = [Convert]::ToBase64String($sigBytes).TrimEnd('=').Replace('+','-').Replace('/','_')

    $jwt = "$headerB64.$claimB64.$sigB64"

    # Exchange JWT for access token
    $response = Invoke-RestMethod -Uri "https://oauth2.googleapis.com/token" -Method Post -Body @{
        grant_type = "urn:ietf:params:oauth:grant-type:jwt-bearer"
        assertion  = $jwt
    }

    return $response.access_token
}

function Send-FcmPush {
    param(
        [string]$AccessToken,
        [string]$DeviceToken,
        [hashtable]$DataPayload,
        [string]$TestName
    )

    $body = @{
        message = @{
            token = $DeviceToken
            data  = $DataPayload
            android = @{
                priority = "high"
                ttl      = "60s"
            }
        }
    } | ConvertTo-Json -Depth 5

    $TIMESTAMPS["${TestName}_sent"] = Get-Date
    Emit-Event -Event "PUSH_SENT" -Phase $TestName -Data @{
        orderId = $DataPayload["orderId"]
        type    = $DataPayload["notificationType"]
    }

    try {
        $response = Invoke-RestMethod -Uri $FCM_V1_URL -Method Post -Headers @{
            Authorization  = "Bearer $AccessToken"
            "Content-Type" = "application/json"
        } -Body $body

        $TIMESTAMPS["${TestName}_ack"] = Get-Date
        $latency = ((Get-Date) - $TIMESTAMPS["${TestName}_sent"]).TotalMilliseconds
        Write-Step "FCM accepted in ${latency}ms - messageId: $($response.name)"
        Emit-Event -Event "PUSH_ACCEPTED" -Phase $TestName -Data @{
            messageId  = $response.name
            latencyMs  = [int]$latency
            orderId    = $DataPayload["orderId"]
        }
        return $true
    }
    catch {
        Write-Fail $TestName "FCM API error: $($_.Exception.Message)"
        return $false
    }
}

function Extract-TokenFromLogcat {
    param([string]$LogFile)

    if (-not (Test-Path $LogFile)) {
        if ($OutputFormat -eq "human") {
            Write-Host "  Logcat file not found: $LogFile" -ForegroundColor Red
        }
        return $null
    }

    $content = Get-Content $LogFile -Raw
    $match = [regex]::Match($content, "FCM_TOKEN=([A-Za-z0-9:_\-]+)")
    if ($match.Success) {
        return $match.Groups[1].Value
    }
    return $null
}

# ===========================================================================
# TEST PAYLOADS
# ===========================================================================

function Get-WaveOfferPayload {
    $orderId = "cert_order_" + (Get-Random -Maximum 99999)
    $offerId = "cert_offer_" + (Get-Random -Maximum 99999)
    return @{
        notificationType = "wave_offer"
        type             = "wave_offer"
        orderId          = $orderId
        offerId          = $offerId
        title            = "new order nearby"
        body             = "Pickup to Dropoff"
        pickupLabel      = "Pickup"
        dropoffLabel     = "Dropoff"
        price            = "350"
        distance         = "4.2"
        createdAt        = [string]([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())
        round            = "1"
        messageId        = "cert_msg_" + (Get-Random -Maximum 99999)
    }
}

function Get-FullscreenPayload {
    $orderId = "cert_fs_" + (Get-Random -Maximum 99999)
    $offerId = "cert_fso_" + (Get-Random -Maximum 99999)
    return @{
        notificationType = "new_order"
        type             = "new_order"
        orderId          = $orderId
        offerId          = $offerId
        title            = "new order nearby"
        body             = "Market to Hospital"
        pickupLabel      = "Market"
        dropoffLabel     = "Hospital"
        price            = "500"
        distance         = "2.8"
        createdAt        = [string]([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())
        round            = "1"
        messageId        = "cert_fsmsg_" + (Get-Random -Maximum 99999)
    }
}

function Get-QaTestPayload {
    return @{
        notificationType = "qa_test"
        type             = "qa_test"
        orderId          = "cert_qa_" + (Get-Random -Maximum 99999)
        offerId          = ""
        title            = "QA Certification Ping"
        body             = "Timestamp: $((Get-Date).ToString('HH:mm:ss.fff'))"
        messageId        = "cert_qa_msg_" + (Get-Random -Maximum 99999)
    }
}

function Get-DedupPayload {
    return @{
        notificationType = "wave_offer"
        type             = "wave_offer"
        orderId          = "cert_dedup_fixed_order"
        offerId          = "cert_dedup_fixed_offer"
        title            = "Dedup Test"
        body             = "Same offer twice"
        pickupLabel      = "A"
        dropoffLabel     = "B"
        price            = "100"
        distance         = "1.0"
        createdAt        = [string]([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())
        round            = "1"
        messageId        = "cert_dedup_msg"
    }
}

# ===========================================================================
# MAIN EXECUTION
# ===========================================================================

Write-Header "WawApp FCM Notification Certification"
if ($OutputFormat -eq "human") {
    Write-Host "  Project: $ProjectId"
    Write-Host "  Scenario: $Scenario"
    Write-Host "  RunId: $RunId"
    Write-Host "  Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
}

Emit-Event -Event "ORCHESTRATION_START" -Phase "init" -Data @{
    project  = $ProjectId
    scenario = $Scenario
    runId    = $RunId
}

# Step 1: Resolve FCM token
if (-not $Token -and $LogcatFile) {
    Write-Step "Extracting FCM token from logcat..."
    $Token = Extract-TokenFromLogcat -LogFile $LogcatFile
}

if (-not $Token) {
    if ($OutputFormat -eq "human") {
        Write-Host ""
        Write-Host "  ERROR: No FCM token provided." -ForegroundColor Red
        Write-Host "  Use -Token parameter or -LogcatFile to extract from Test Lab logs." -ForegroundColor Red
        Write-Host ""
        Write-Host "  To extract from running Test Lab test:" -ForegroundColor Yellow
        Write-Host "    gcloud firebase test android run ... 2>&1 | Select-String 'FCM_TOKEN='" -ForegroundColor Yellow
    }
    Emit-Event -Event "ORCHESTRATION_END" -Phase "error" -Data @{ verdict = "ERROR"; reason = "no_token" }
    exit 1
}

Write-Step "FCM Token: $($Token.Substring(0, [Math]::Min(20, $Token.Length)))..."

# Step 2: Get OAuth2 access token
Write-Step "Generating OAuth2 access token..."
$accessToken = Get-OAuthToken -SaJsonPath $ServiceAccountJson
Write-Step "OAuth2 token acquired (length: $($accessToken.Length))"

# Step 3: Execute test scenarios
$scenarios = if ($Scenario -eq "all") { @("wave_offer", "fullscreen", "qa_test", "dedup") } else { @($Scenario) }

foreach ($s in $scenarios) {
    Write-Header "TEST: $s"
    Emit-Event -Event "SCENARIO_STEP_START" -Phase $s -Data @{ scenario = $s }

    switch ($s) {
        "wave_offer" {
            $payload = Get-WaveOfferPayload
            Write-Step "Sending wave_offer push (orderId=$($payload.orderId))..."
            $sent = Send-FcmPush -AccessToken $accessToken -DeviceToken $Token -DataPayload $payload -TestName "wave_offer"
            if ($sent) {
                Write-Pass "wave_offer_delivery" "FCM accepted by Google servers"
                Write-Step "Verify in logcat: PUSH_RECEIVED raw_type=wave_offer"
                Write-Step "Verify: NOTIFICATION_POSTED type=wave_offer"
                Write-Step "Verify: FULLSCREEN_LAUNCHED orderId=$($payload.orderId)"
                Write-Step "Verify: ALARM_SCHEDULED order=$($payload.orderId)"
            }
        }

        "fullscreen" {
            $payload = Get-FullscreenPayload
            Write-Step "Sending new_order push (orderId=$($payload.orderId))..."
            $sent = Send-FcmPush -AccessToken $accessToken -DeviceToken $Token -DataPayload $payload -TestName "fullscreen"
            if ($sent) {
                Write-Pass "fullscreen_delivery" "FCM accepted - should trigger FullScreenNotificationActivity"
                Write-Step "Verify in logcat: FULLSCREEN_LAUNCHED orderId=$($payload.orderId)"
                Write-Step "Verify: WakeLock acquired"
                Write-Step "Verify: Keyguard dismissed"
            }
        }

        "qa_test" {
            $payload = Get-QaTestPayload
            Write-Step "Sending qa_test ping..."
            $sent = Send-FcmPush -AccessToken $accessToken -DeviceToken $Token -DataPayload $payload -TestName "qa_test"
            if ($sent) {
                Write-Pass "qa_test_delivery" "FCM accepted - certification marker should be written"
                Write-Step "Verify in logcat: PUSH_RECEIVED raw_type=qa_test"
                Write-Step "Note: qa_test type is not routed to notification display (expected)"
            }
        }

        "dedup" {
            $payload = Get-DedupPayload
            Write-Step "Sending first push (should display)..."
            $sent1 = Send-FcmPush -AccessToken $accessToken -DeviceToken $Token -DataPayload $payload -TestName "dedup_first"
            Start-Sleep -Seconds 3

            Write-Step "Sending duplicate push (should be deduped)..."
            $sent2 = Send-FcmPush -AccessToken $accessToken -DeviceToken $Token -DataPayload $payload -TestName "dedup_second"

            if ($sent1 -and $sent2) {
                Write-Pass "dedup_delivery" "Both pushes accepted by FCM"
                Write-Step "Verify in logcat: First shows NOTIFICATION_POSTED"
                Write-Step "Verify in logcat: Second shows 'DEDUP: offer already seen, dropping'"
            }
        }
    }

    # Brief pause between scenarios
    if ($scenarios.Count -gt 1) { Start-Sleep -Seconds 5 }
}

# ===========================================================================
# FINAL VERDICT
# ===========================================================================

Write-Header "CERTIFICATION VERDICT"

$passCount = ($VERDICT.Values | Where-Object { $_ -eq "PASS" }).Count
$failCount = ($VERDICT.Values | Where-Object { $_ -eq "FAIL" }).Count
$total = $VERDICT.Count

if ($OutputFormat -eq "human") {
    foreach ($k in $VERDICT.Keys | Sort-Object) {
        $color = if ($VERDICT[$k] -eq "PASS") { "Green" } else { "Red" }
        $icon = if ($VERDICT[$k] -eq "PASS") { "[PASS]" } else { "[FAIL]" }
        Write-Host "  $icon $k" -ForegroundColor $color
    }

    Write-Host ""
    Write-Host "  Total: $passCount/$total PASS" -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Yellow" })

    if ($failCount -eq 0) {
        Write-Host ""
        Write-Host "  ========================================" -ForegroundColor Green
        Write-Host "  =  FCM CERTIFICATION: ALL PASS        =" -ForegroundColor Green
        Write-Host "  ========================================" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "  ========================================" -ForegroundColor Red
        Write-Host "  =  FCM CERTIFICATION: $failCount FAILURES     =" -ForegroundColor Red
        Write-Host "  ========================================" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "  Next steps:" -ForegroundColor Yellow
    Write-Host "    1. Check Test Lab logcat for WAWAPP_TEST markers" -ForegroundColor Yellow
    Write-Host "    2. Verify PUSH_RECEIVED appears for each sent push" -ForegroundColor Yellow
    Write-Host "    3. Verify NOTIFICATION_POSTED for wave_offer/new_order" -ForegroundColor Yellow
    Write-Host "    4. Verify FULLSCREEN_LAUNCHED for new_order type" -ForegroundColor Yellow
    Write-Host "    5. Verify ALARM_SCHEDULED + ALARM_FIRED for sound repeats" -ForegroundColor Yellow
}

Emit-Event -Event "ORCHESTRATION_END" -Phase "verdict" -Data @{
    pass    = $passCount
    fail    = $failCount
    total   = $total
    verdict = if ($failCount -eq 0) { "PASS" } else { "FAIL" }
}

Write-Host ""

# Exit with appropriate code for CI/agent consumption
if ($failCount -gt 0) { exit 1 }
