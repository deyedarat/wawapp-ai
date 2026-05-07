# ============================================================================
# WawApp QA - Production Gate: Notifications
# ============================================================================
# Gate verdict depends ONLY on PASS_FAIL.txt contents from test artifacts.
# A script can execute successfully (RUNTIME_PASS) but still FAIL the test.
#
# Exit 0 = gate passed, Exit 1 = gate blocked
# ============================================================================

param()

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\scripts\lib\common.ps1"
. "$PSScriptRoot\..\scripts\lib\verdict.ps1"

$GateName = "NOTIFICATIONS"

Write-QA-Banner "Production Gate: $GateName"

# ============================================================================
# TEST REGISTRY
# ============================================================================
$tests = @(
    @{ Name = "notification_killed_state"; Script = "$PSScriptRoot\..\scripts\run_notification_killed_state.ps1"; Prefix = "N3" }
    @{ Name = "notification_spam";         Script = "$PSScriptRoot\..\scripts\run_notification_spam.ps1";         Prefix = "SPAM" }
)

$artifactsRoot = [System.IO.Path]::GetFullPath("$PSScriptRoot\..\..\qa\artifacts")

# ============================================================================
# EXECUTE TESTS & CLASSIFY
# ============================================================================
$classifications = @()
$gateStart = Get-Date

foreach ($test in $tests) {
    Write-QA-Step "Running: $($test.Name)"

    $runStart = Get-Date
    $runtimeSuccess = $true
    $runtimeError = ""

    try {
        & $test.Script
        $code = $LASTEXITCODE
        if ($null -eq $code) { $code = 0 }
        if ($code -ne 0) {
            $runtimeSuccess = $false
            $runtimeError = "Exit code: $code"
        }
    } catch {
        $runtimeSuccess = $false
        $runtimeError = "$_"
    }

    # Classify: runtime status + test verdict from PASS_FAIL.txt
    $classification = Get-QA-RunClassification `
        -ScriptName $test.Name `
        -ArtifactsRoot $artifactsRoot `
        -ScenarioPrefix $test.Prefix `
        -RuntimeSuccess $runtimeSuccess `
        -RuntimeError $runtimeError

    $duration = [math]::Round(((Get-Date) - $runStart).TotalSeconds, 1)
    $classification.Duration = $duration

    Write-QA-Classification $classification
    $classifications += $classification

    Write-Host ""
}

# ============================================================================
# GATE VERDICT (depends ONLY on test verdicts, NOT runtime exit codes)
# ============================================================================
$gateEnd = Get-Date
$totalDuration = [math]::Round(($gateEnd - $gateStart).TotalSeconds, 1)

$blocked = @($classifications | Where-Object { $_.GateDecision -eq "GATE_BLOCKED" })
$passed  = @($classifications | Where-Object { $_.GateDecision -eq "GATE_PASS" })

$gateVerdict = if ($blocked.Count -eq 0) { "PASSED" } else { "BLOCKED" }

# ============================================================================
# SUMMARY
# ============================================================================
Write-Host ""
Write-Host "-------------------------------------------------------" -ForegroundColor DarkYellow
Write-Host "  Gate: $GateName" -ForegroundColor DarkYellow
Write-Host "-------------------------------------------------------" -ForegroundColor DarkYellow

foreach ($c in $classifications) {
    $icon = if ($c.GateDecision -eq "GATE_PASS") { "[PASS]" } else { "[BLOCK]" }
    $rt = $c.RuntimeStatus
    $tv = $c.TestVerdict
    $dur = $c.Duration
    $color = if ($c.GateDecision -eq "GATE_PASS") { "Green" } else { "Red" }
    Write-Host "  $icon $($c.Script)  [$rt | $tv]  ${dur}s" -ForegroundColor $color
    if ($c.TestReasons.Count -gt 0) {
        $c.TestReasons | ForEach-Object { Write-Host "       > $_" -ForegroundColor DarkRed }
    }
}

Write-Host "-------------------------------------------------------" -ForegroundColor DarkYellow

$durationLabel = "${totalDuration}s"
if ($gateVerdict -eq "PASSED") {
    Write-QA-Pass "Gate $GateName : PASSED $durationLabel"
} else {
    $blockedCount = $blocked.Count
    Write-QA-Fail "Gate $GateName : BLOCKED $durationLabel - $blockedCount tests failed"
}

# ============================================================================
# STRUCTURED RESULT
# ============================================================================
$global:GateResult = @{
    Gate            = $GateName
    Verdict         = $gateVerdict
    Duration        = $totalDuration
    Classifications = $classifications
    Passed          = $passed.Count
    Blocked         = $blocked.Count
}

if ($blocked.Count -gt 0) { exit 1 } else { exit 0 }
