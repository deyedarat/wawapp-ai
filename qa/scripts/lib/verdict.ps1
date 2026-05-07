# ============================================================================
# WawApp QA - Verdict Classification Module
# ============================================================================
# Import: . "$PSScriptRoot\lib\verdict.ps1"
# Requires: common.ps1 loaded first
#
# Classifications:
#   RUNTIME_PASS  - Script executed without crash/exception
#   RUNTIME_FAIL  - Script crashed, threw, or timed out
#   TEST_PASS     - PASS_FAIL.txt contains VERDICT: PASS
#   TEST_FAIL     - PASS_FAIL.txt contains VERDICT: FAIL
#   GATE_BLOCKED  - Gate cannot approve release (TEST_FAIL or unreadable verdict)
# ============================================================================

# ============================================================================
# READ VERDICT FROM ARTIFACT DIRECTORY
# ============================================================================
function Read-QA-TestVerdict {
    param(
        [Parameter(Mandatory)][string]$ArtifactDir
    )

    $result = @{
        TestVerdict   = "UNKNOWN"
        Reasons       = @()
        Source        = ""
        Raw           = ""
        IsValid       = $false
    }

    $passFile = Join-Path $ArtifactDir "PASS_FAIL.txt"

    # --- Missing file ---
    if (-not (Test-Path $passFile)) {
        $result.TestVerdict = "TEST_FAIL"
        $result.Reasons = @("PASS_FAIL.txt not found in $ArtifactDir")
        return $result
    }

    $result.Source = $passFile

    # --- Read content ---
    try {
        $content = Get-Content $passFile -Raw -ErrorAction Stop
        $result.Raw = $content
    } catch {
        $result.TestVerdict = "TEST_FAIL"
        $result.Reasons = @("Cannot read PASS_FAIL.txt: $_")
        return $result
    }

    # --- Empty file ---
    if ([string]::IsNullOrWhiteSpace($content)) {
        $result.TestVerdict = "TEST_FAIL"
        $result.Reasons = @("PASS_FAIL.txt is empty")
        return $result
    }

    # --- Parse verdict line ---
    if ($content -match "VERDICT:\s*(PASS|FAIL|TIMEOUT|HANG)") {
        $raw = $Matches[1]
        if ($raw -eq "PASS") {
            $result.TestVerdict = "TEST_PASS"
            $result.IsValid = $true
        } else {
            $result.TestVerdict = "TEST_FAIL"
        }
    } else {
        # Malformed - no recognizable VERDICT line
        $result.TestVerdict = "TEST_FAIL"
        $result.Reasons = @("Malformed PASS_FAIL.txt: no valid VERDICT line")
        return $result
    }

    # --- Extract reasons ---
    if ($content -match "REASONS?:\s*(.+)") {
        $reasonStr = $Matches[1].Trim()
        if ($reasonStr -and $reasonStr -ne "None" -and $reasonStr -ne "") {
            $result.Reasons = @($reasonStr -split ";\s*" | Where-Object { $_ })
        }
    }

    return $result
}

# ============================================================================
# FIND LATEST ARTIFACT DIR FOR A SCENARIO
# ============================================================================
function Find-QA-LatestArtifactDir {
    param(
        [Parameter(Mandatory)][string]$ArtifactsRoot,
        [Parameter(Mandatory)][string]$ScenarioPrefix
    )

    if (-not (Test-Path $ArtifactsRoot)) { return $null }

    $dirs = Get-ChildItem -Path $ArtifactsRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match "^${ScenarioPrefix}_\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}$" } |
        Sort-Object Name -Descending

    if ($dirs.Count -eq 0) { return $null }
    return $dirs[0].FullName
}

# ============================================================================
# CLASSIFY A SINGLE TEST RUN
# ============================================================================
function Get-QA-RunClassification {
    param(
        [Parameter(Mandatory)][string]$ScriptName,
        [Parameter(Mandatory)][string]$ArtifactsRoot,
        [Parameter(Mandatory)][string]$ScenarioPrefix,
        [bool]$RuntimeSuccess = $true,
        [string]$RuntimeError = ""
    )

    $classification = @{
        Script          = $ScriptName
        RuntimeStatus   = if ($RuntimeSuccess) { "RUNTIME_PASS" } else { "RUNTIME_FAIL" }
        RuntimeError    = $RuntimeError
        TestVerdict     = "UNKNOWN"
        TestReasons     = @()
        GateDecision    = "GATE_BLOCKED"
        ArtifactDir     = ""
        VerdictSource   = ""
    }

    # Find the artifact directory created by this run
    $artifactDir = Find-QA-LatestArtifactDir -ArtifactsRoot $ArtifactsRoot -ScenarioPrefix $ScenarioPrefix
    $classification.ArtifactDir = if ($artifactDir) { $artifactDir } else { "" }

    # If runtime failed AND no artifacts, blocked
    if (-not $RuntimeSuccess -and -not $artifactDir) {
        $classification.TestVerdict = "TEST_FAIL"
        $classification.TestReasons = @("Runtime failure with no artifacts: $RuntimeError")
        return $classification
    }

    # If no artifact dir found at all
    if (-not $artifactDir) {
        $classification.TestVerdict = "TEST_FAIL"
        $classification.TestReasons = @("No artifact directory found for prefix '$ScenarioPrefix'")
        return $classification
    }

    # Read the actual test verdict from PASS_FAIL.txt
    $verdictResult = Read-QA-TestVerdict -ArtifactDir $artifactDir
    $classification.TestVerdict = $verdictResult.TestVerdict
    $classification.TestReasons = $verdictResult.Reasons
    $classification.VerdictSource = $verdictResult.Source

    # Gate decision: ONLY passes if TestVerdict is TEST_PASS
    if ($classification.TestVerdict -eq "TEST_PASS") {
        $classification.GateDecision = "GATE_PASS"
    }

    return $classification
}

# ============================================================================
# FORMAT CLASSIFICATION FOR DISPLAY
# ============================================================================
function Write-QA-Classification {
    param([hashtable]$Classification)

    $c = $Classification
    $ts = Get-Date -Format "HH:mm:ss"

    # Runtime status
    if ($c.RuntimeStatus -eq "RUNTIME_PASS") {
        Write-Host "[$ts]   Runtime: RUNTIME_PASS" -ForegroundColor DarkGreen
    } else {
        Write-Host "[$ts]   Runtime: RUNTIME_FAIL ($($c.RuntimeError))" -ForegroundColor Red
    }

    # Test verdict
    if ($c.TestVerdict -eq "TEST_PASS") {
        Write-Host "[$ts]   Test:    TEST_PASS" -ForegroundColor Green
    } else {
        Write-Host "[$ts]   Test:    $($c.TestVerdict)" -ForegroundColor Red
        $c.TestReasons | ForEach-Object { Write-Host "[$ts]            > $_" -ForegroundColor Red }
    }

    # Gate decision
    if ($c.GateDecision -eq "GATE_PASS") {
        Write-Host "[$ts]   Gate:    GATE_PASS" -ForegroundColor Green
    } else {
        Write-Host "[$ts]   Gate:    GATE_BLOCKED" -ForegroundColor Red
    }
}
