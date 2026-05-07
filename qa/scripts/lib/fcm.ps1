# ============================================================================
# WawApp QA - FCM Delivery Module
# ============================================================================
# Import: . "$PSScriptRoot\lib\fcm.ps1"
# Requires: common.ps1 loaded first
#
# Provides:
#   Send-QA-FcmMessage       - Send real FCM high-priority data message
#   Get-QA-FcmToken          - Retrieve device FCM token from Firestore/file
#   Get-QA-GcloudAccessToken - Get OAuth2 token via gcloud
#
# Classifications:
#   REAL_FCM_DELIVERED   - FCM API accepted the message
#   REAL_FCM_REJECTED    - FCM API rejected (bad token, quota, etc)
#   REAL_FCM_AUTH_FAIL   - gcloud auth failed
#   REAL_FCM_TIMEOUT     - FCM API did not respond in time
# ============================================================================

# ============================================================================
# GCLOUD AUTH
# ============================================================================
function Get-QA-GcloudAccessToken {
    try {
        $token = & gcloud auth print-access-token 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $token) {
            return @{ Success = $false; Token = ""; Error = "gcloud auth print-access-token failed" }
        }
        $token = $token.Trim()
        return @{ Success = $true; Token = $token; Error = "" }
    } catch {
        return @{ Success = $false; Token = ""; Error = "$_" }
    }
}

# ============================================================================
# FCM TOKEN RETRIEVAL
# ============================================================================
function Get-QA-FcmToken {
    param(
        [string]$TokenFile = "",
        [string]$Token = ""
    )

    # Direct token takes priority
    if ($Token) {
        return @{ Success = $true; Token = $Token; Source = "parameter" }
    }

    # Try token file
    if ($TokenFile -and (Test-Path $TokenFile)) {
        $content = (Get-Content $TokenFile -Raw).Trim()
        if ($content) {
            return @{ Success = $true; Token = $content; Source = "file:$TokenFile" }
        }
    }

    # Try default location
    $defaultFile = Join-Path $PSScriptRoot "..\..\fcm_token.txt"
    if (Test-Path $defaultFile) {
        $content = (Get-Content $defaultFile -Raw).Trim()
        if ($content) {
            return @{ Success = $true; Token = $content; Source = "file:$defaultFile" }
        }
    }

    return @{ Success = $false; Token = ""; Source = "none" }
}

# ============================================================================
# SEND FCM MESSAGE
# ============================================================================
function Send-QA-FcmMessage {
    param(
        [Parameter(Mandatory)][string]$ProjectId,
        [Parameter(Mandatory)][string]$FcmToken,
        [Parameter(Mandatory)][string]$AccessToken,
        [Parameter(Mandatory)][hashtable]$DataPayload,
        [int]$TimeoutSec = 10
    )

    $result = @{
        Success       = $false
        Status        = "UNKNOWN"
        MessageId     = ""
        SendTimestamp = $null
        AckTimestamp  = $null
        LatencyMs     = 0
        Error         = ""
        HttpStatus    = 0
    }

    $body = @{
        message = @{
            token = $FcmToken
            android = @{
                priority = "high"
            }
            data = $DataPayload
        }
    } | ConvertTo-Json -Depth 5

    $url = "https://fcm.googleapis.com/v1/projects/$ProjectId/messages:send"
    $headers = @{
        "Authorization" = "Bearer $AccessToken"
        "Content-Type"  = "application/json"
    }

    $result.SendTimestamp = Get-Date

    try {
        $response = Invoke-RestMethod -Uri $url -Method POST -Headers $headers -Body $body -TimeoutSec $TimeoutSec
        $result.AckTimestamp = Get-Date
        $result.LatencyMs = [math]::Round(($result.AckTimestamp - $result.SendTimestamp).TotalMilliseconds)
        $result.Success = $true
        $result.Status = "REAL_FCM_DELIVERED"
        if ($response.name) { $result.MessageId = $response.name }
    } catch {
        $result.AckTimestamp = Get-Date
        $result.LatencyMs = [math]::Round(($result.AckTimestamp - $result.SendTimestamp).TotalMilliseconds)
        $result.Error = "$_"

        if ($_.Exception.Message -match "timeout|timed out") {
            $result.Status = "REAL_FCM_TIMEOUT"
        } else {
            $result.Status = "REAL_FCM_REJECTED"
            # Try to extract HTTP status
            if ($_.Exception.Response) {
                $result.HttpStatus = [int]$_.Exception.Response.StatusCode
            }
        }
    }

    return $result
}

# ============================================================================
# QA TEST PAYLOAD (production-safe, clearly marked)
# ============================================================================
function New-QA-FcmTestPayload {
    param(
        [string]$ScenarioId = "QA",
        [string]$Timestamp = ""
    )

    if (-not $Timestamp) { $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss" }

    return @{
        type        = "new_order"
        orderId     = "QA_ONLY_${ScenarioId}_$Timestamp"
        pickupLat   = "18.0735"
        pickupLng   = "-15.9582"
        dropoffLat  = "18.0800"
        dropoffLng  = "-15.9500"
        price       = "500"
        clientName  = "QA_CERTIFICATION"
        qa_test     = "true"
        qa_scenario = $ScenarioId
    }
}
