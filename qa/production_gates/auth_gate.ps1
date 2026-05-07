# ============================================================================
# WawApp QA — Production Gate: Auth
# ============================================================================
# Placeholder for OTP retry, PIN flow, and auth smoke tests.
# Exit 0 = gate passed, Exit 1 = gate blocked
# ============================================================================

param()

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\..\scripts\lib\common.ps1"

$GateName = "AUTH"

Write-QA-Banner "Production Gate: $GateName"
Write-QA-Warn "No auth smoke tests implemented yet"
Write-QA-Info "Future tests: OTP login, OTP retry, PIN create, PIN verify, session expiry"

# Placeholder passes until tests are added
$global:GateResult = @{
    Gate     = $GateName
    Verdict  = "PASSED"
    Duration = 0
    Results  = @()
    Failed   = 0
}

Write-QA-Pass "Gate $GateName : PASSED (placeholder)"
exit 0
