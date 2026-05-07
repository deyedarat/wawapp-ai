# ============================================================================
# WawApp QA — Production Gate: Notifications
# ============================================================================
# Runs all notification reliability tests.
# Exit 0 = gate passed, Exit 1 = gate blocked
# ============================================================================

param()

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\scripts\lib\common.ps1"

$GateName = "NOTIFICATIONS"

Write-QA-Banner "Production Gate: $GateName"

$scripts = @(
    "$PSScriptRoot\..\scripts\run_notification_killed_state.ps1"
    "$PSScriptRoot\..\scripts\run_notification_spam.ps1"
)

$results = @()
$gateStart = Get-Date

foreach ($script in $scripts) {
    $name = [System.IO.Path]::GetFileNameWithoutExtension($script) -replace "^run_", ""
    Write-QA-Step "Running: $name"

    $runStart = Get-Date
    $verdict = "PASS"
    $reason = ""

    try {
        & $script
        $code = $LASTEXITCODE
        if ($null -eq $code) { $code = 0 }
        if ($code -ne 0) { $verdict = "FAIL"; $reason = "Exit code: $code" }
    } catch {
        $verdict = "FAIL"; $reason = "$_"
    }

    # Read verdict from latest artifact
    $artifactsRoot = [System.IO.Path]::GetFullPath("$PSScriptRoot\..\..\qa\artifacts")
    $latest = Get-ChildItem -Path $artifactsRoot -Directory -ErrorAction SilentlyContinue |
        Sort-Object CreationTime -Descending | Select-Object -First 1

    if ($latest) {
        $passFile = Join-Path $latest.FullName "PASS_FAIL.txt"
        if (Test-Path $passFile) {
            $content = Get-Content $passFile -Raw
            if ($content -match "VERDICT:\s*(PASS|FAIL)") { $verdict = $Matches[1] }
            if ($content -match "REASONS:\s*(.+)" -and $Matches[1].Trim()) { $reason = $Matches[1].Trim() }
        }
    }

    $duration = [math]::Round(((Get-Date) - $runStart).TotalSeconds, 1)
    $results += @{ Name = $name; Verdict = $verdict; Duration = $duration; Reason = $reason }

    if ($verdict -eq "PASS") { Write-QA-Pass "$name (${duration}s)" }
    else { Write-QA-Fail "$name (${duration}s): $reason" }
}

$gateEnd = Get-Date
$totalDuration = [math]::Round(($gateEnd - $gateStart).TotalSeconds, 1)
$failed = ($results | Where-Object { $_.Verdict -eq "FAIL" }).Count
$gateVerdict = if ($failed -eq 0) { "PASSED" } else { "BLOCKED" }

Write-Host ""
if ($gateVerdict -eq "PASSED") { Write-QA-Pass "Gate $GateName : PASSED (${totalDuration}s)" }
else { Write-QA-Fail "Gate $GateName : BLOCKED (${totalDuration}s)" }

# Return structured result for release_gate
$global:GateResult = @{
    Gate     = $GateName
    Verdict  = $gateVerdict
    Duration = $totalDuration
    Results  = $results
    Failed   = $failed
}

if ($failed -gt 0) { exit 1 } else { exit 0 }
