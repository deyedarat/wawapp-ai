<#
.SYNOPSIS
    Run FCM Notification Certification on Firebase Test Lab (Samsung A15, Android 14)

.DESCRIPTION
    Complete pipeline:
    1. Build debug + androidTest APKs
    2. Run instrumentation on Firebase Test Lab physical device
    3. Extract FCM token from logcat
    4. Optionally trigger fcm-certification.ps1 for push injection

.PARAMETER ProjectId
    Firebase project ID for Test Lab

.PARAMETER Build
    Whether to rebuild APKs (default: true)

.PARAMETER SendPush
    Whether to auto-run fcm-certification.ps1 after token extraction

.PARAMETER ServiceAccountJson
    Path to service account JSON (required if -SendPush)

.EXAMPLE
    .\run-testlab-fcm.ps1 -ProjectId "wawapp-prod" -Build $true
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectId,

    [Parameter(Mandatory=$false)]
    [bool]$Build = $true,

    [Parameter(Mandatory=$false)]
    [switch]$SendPush,

    [Parameter(Mandatory=$false)]
    [string]$ServiceAccountJson
)

$ErrorActionPreference = "Stop"
$DRIVER_ROOT = Split-Path -Parent $PSScriptRoot
$ANDROID_ROOT = Join-Path $DRIVER_ROOT "android"
$APK_DIR = Join-Path $ANDROID_ROOT "app\build\outputs\apk"
$DEBUG_APK = Join-Path $APK_DIR "debug\app-debug.apk"
$TEST_APK = Join-Path $APK_DIR "androidTest\debug\app-debug-androidTest.apk"
$LOGCAT_OUTPUT = Join-Path $PSScriptRoot "testlab_logcat.txt"

Write-Host ""
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "  WawApp FCM Test Lab Runner" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "  Project: $ProjectId"
Write-Host "  Device: samsung/a15 (API 34, Android 14)"
Write-Host ""

# --- Step 1: Build APKs ---
if ($Build) {
    Write-Host "  [1/4] Building APKs..." -ForegroundColor Yellow
    Push-Location $ANDROID_ROOT

    & .\gradlew.bat assembleDebug assembleDebugAndroidTest --no-daemon 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR: Gradle build failed" -ForegroundColor Red
        Pop-Location
        exit 1
    }

    Pop-Location
    Write-Host "  [1/4] DONE - APKs built" -ForegroundColor Green
    Write-Host "    app-debug.apk: $(if (Test-Path $DEBUG_APK) { 'EXISTS' } else { 'MISSING' })"
    Write-Host "    app-debug-androidTest.apk: $(if (Test-Path $TEST_APK) { 'EXISTS' } else { 'MISSING' })"
} else {
    Write-Host "  [1/4] Skipping build (using existing APKs)" -ForegroundColor Gray
}

# Verify APKs exist
if (-not (Test-Path $DEBUG_APK) -or -not (Test-Path $TEST_APK)) {
    Write-Host "  ERROR: APKs not found. Run with -Build `$true" -ForegroundColor Red
    exit 1
}

# --- Step 2: Run on Firebase Test Lab ---
Write-Host ""
Write-Host "  [2/4] Running instrumentation on Firebase Test Lab..." -ForegroundColor Yellow
Write-Host "    Device: samsung/a15 (physical, Android 14)" -ForegroundColor Gray
Write-Host "    Test: com.wawapp.driver.NotificationE2ETest" -ForegroundColor Gray
Write-Host "    Timeout: 300s (5 min)" -ForegroundColor Gray
Write-Host ""

$testLabArgs = @(
    "firebase", "test", "android", "run",
    "--type", "instrumentation",
    "--app", $DEBUG_APK,
    "--test", $TEST_APK,
    "--device", "model=a15,version=34,locale=en,orientation=portrait",
    "--timeout", "5m",
    "--results-bucket", "gs://${ProjectId}-testlab",
    "--results-dir", "fcm-cert-$(Get-Date -Format 'yyyyMMdd-HHmmss')",
    "--no-auto-google-login",
    "--project", $ProjectId
)

Write-Host "  Command:" -ForegroundColor Gray
Write-Host "    gcloud $($testLabArgs -join ' ')" -ForegroundColor DarkGray
Write-Host ""

$output = & gcloud @testLabArgs 2>&1
$exitCode = $LASTEXITCODE

# Save full output
$output | Out-File -FilePath $LOGCAT_OUTPUT -Encoding utf8
Write-Host "  [2/4] Test Lab output saved to: $LOGCAT_OUTPUT" -ForegroundColor Gray

if ($exitCode -ne 0) {
    Write-Host "  [2/4] WARNING: Test Lab returned exit code $exitCode" -ForegroundColor Yellow
    Write-Host "    (This may be OK - test waits for push that may not arrive)" -ForegroundColor Gray
}

Write-Host "  [2/4] DONE - Test Lab execution complete" -ForegroundColor Green

# --- Step 3: Extract FCM Token ---
Write-Host ""
Write-Host "  [3/4] Extracting FCM token from logs..." -ForegroundColor Yellow

$logContent = Get-Content $LOGCAT_OUTPUT -Raw -ErrorAction SilentlyContinue
$tokenMatch = [regex]::Match($logContent, "FCM_TOKEN=([A-Za-z0-9:_\-]+)")

if ($tokenMatch.Success) {
    $extractedToken = $tokenMatch.Groups[1].Value
    Write-Host "  [3/4] DONE - FCM Token extracted:" -ForegroundColor Green
    Write-Host "    $($extractedToken.Substring(0, [Math]::Min(40, $extractedToken.Length)))..." -ForegroundColor White

    # Save token to file
    $tokenFile = Join-Path $PSScriptRoot "extracted_fcm_token.txt"
    $extractedToken | Out-File -FilePath $tokenFile -Encoding utf8 -NoNewline
    Write-Host "    Saved to: $tokenFile" -ForegroundColor Gray
} else {
    Write-Host "  [3/4] WARNING: Could not extract FCM token from logs" -ForegroundColor Yellow
    Write-Host "    Check $LOGCAT_OUTPUT for WAWAPP_TEST markers" -ForegroundColor Gray
    $extractedToken = $null
}

# --- Step 4: Send Push (optional) ---
if ($SendPush -and $extractedToken -and $ServiceAccountJson) {
    Write-Host ""
    Write-Host "  [4/4] Sending FCM push notifications..." -ForegroundColor Yellow

    $certScript = Join-Path $PSScriptRoot "fcm-certification.ps1"
    & $certScript -Token $extractedToken -ServiceAccountJson $ServiceAccountJson -ProjectId $ProjectId -Scenario all
} else {
    Write-Host ""
    Write-Host "  [4/4] Push injection skipped" -ForegroundColor Gray
    if ($extractedToken) {
        Write-Host "    To send pushes manually:" -ForegroundColor Yellow
        Write-Host "    .\fcm-certification.ps1 -Token '$extractedToken' -ServiceAccountJson '<path>' -ProjectId '$ProjectId' -Scenario all" -ForegroundColor White
    }
}

# --- Summary ---
Write-Host ""
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "  EXECUTION SUMMARY" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "  APKs: $(if (Test-Path $DEBUG_APK) { 'OK' } else { 'MISSING' }) debug, $(if (Test-Path $TEST_APK) { 'OK' } else { 'MISSING' }) androidTest"
Write-Host "  Test Lab: $(if ($exitCode -eq 0) { 'PASS' } else { "Exit $exitCode" })"
Write-Host "  FCM Token: $(if ($extractedToken) { 'Extracted' } else { 'Not found' })"
Write-Host "  Push Sent: $(if ($SendPush -and $extractedToken) { 'Yes' } else { 'Skipped' })"
Write-Host ""
