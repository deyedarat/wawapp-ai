#!/usr/bin/env pwsh
# Setup implementation plan for a feature

[CmdletBinding()]
param(
    [switch]$Json,
    [switch]$Help,
    [switch]$NoOverwrite,  # لا تكتب فوق plan.md إذا موجود
    [switch]$Backup        # أنشئ نسخة احتياطية قبل الاستبدال
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Show help if requested
if ($Help) {
    Write-Output "Usage: ./setup-plan.ps1 [-Json] [-Help] [-NoOverwrite] [-Backup]"
    Write-Output "  -Json         Output results in JSON format"
    Write-Output "  -Help         Show this help message"
    Write-Output "  -NoOverwrite  Skip copying template if plan.md already exists"
    Write-Output "  -Backup       Create a timestamped backup if overwriting plan.md"
    exit 0
}

# Load common functions
try { . "$PSScriptRoot/common.ps1" } catch {
    $msg = "Failed to load common.ps1: $($_.Exception.Message)"
    if ($Json) {
        [pscustomobject]@{ success=$false; error=$msg } | ConvertTo-Json -Compress
    } else { Write-Error $msg }
    exit 1
}

# Get all paths and variables from common functions
$paths = Get-FeaturePathsEnv

# Check if we're on a proper feature branch (only for git repos)
if (-not (Test-FeatureBranch -Branch $paths.CURRENT_BRANCH -HasGit $paths.HAS_GIT)) { 
    exit 1 
}

# Ensure the feature directory exists
New-Item -ItemType Directory -Path $paths.FEATURE_DIR -Force | Out-Null

# Decide copy strategy
$template = Join-Path $paths.REPO_ROOT '.specify/templates/plan-template.md'
$planExists = Test-Path $paths.IMPL_PLAN
$action = 'none'
$backupPath = $null

try {
    if ($planExists -and $NoOverwrite) {
        $action = 'skip_existing'
        Write-Output "plan.md already exists → SKIP (NoOverwrite)"
    }
    elseif (Test-Path $template) {
        if ($planExists -and $Backup) {
            $ts = Get-Date -Format 'yyyyMMdd_HHmmss'
            $backupPath = "$($paths.IMPL_PLAN).$ts.bak"
            Copy-Item $paths.IMPL_PLAN $backupPath -Force
            Write-Output "Backup created: $backupPath"
        }
        Copy-Item $template $paths.IMPL_PLAN -Force
        $action = if ($planExists) { 'overwrite_from_template' } else { 'create_from_template' }
        Write-Output "Copied plan template to $($paths.IMPL_PLAN)"
    }
    else {
        if (-not $planExists) {
            @"
# Implementation Plan

> Fill the concrete steps below. Tech: Dart/Flutter. Auth: phone + 4-digit PIN.

## Goals
- 

## Tasks
- 

## Risks / Open Questions
- 
"@ | Set-Content -Encoding UTF8 -Path $paths.IMPL_PLAN
            $action = 'create_minimal'
            Write-Warning "Plan template not found at $template — created minimal plan.md"
        } else {
            $action = 'keep_existing_no_template'
            Write-Warning "Plan template not found at $template — keeping existing plan.md"
        }
    }
}
catch {
    $msg = "Failed while preparing plan.md: $($_.Exception.Message)"
    if ($Json) {
        [pscustomobject]@{
            success   = $false
            error     = $msg
            action    = $action
            FEATURE_SPEC = $paths.FEATURE_SPEC
            IMPL_PLAN    = $paths.IMPL_PLAN
            SPECS_DIR    = $paths.FEATURE_DIR
            BRANCH       = $paths.CURRENT_BRANCH
            HAS_GIT      = $paths.HAS_GIT
        } | ConvertTo-Json -Compress
    } else {
        Write-Error $msg
    }
    exit 1
}

# Output results
if ($Json) {
    [pscustomobject]@{
        success      = $true
        action       = $action
        backupPath   = $backupPath
        FEATURE_SPEC = $paths.FEATURE_SPEC
        IMPL_PLAN    = $paths.IMPL_PLAN
        SPECS_DIR    = $paths.FEATURE_DIR
        BRANCH       = $paths.CURRENT_BRANCH
        HAS_GIT      = $paths.HAS_GIT
    } | ConvertTo-Json -Compress
} else {
    Write-Output "FEATURE_SPEC: $($paths.FEATURE_SPEC)"
    Write-Output "IMPL_PLAN: $($paths.IMPL_PLAN)"
    Write-Output "SPECS_DIR: $($paths.FEATURE_DIR)"
    Write-Output "BRANCH: $($paths.CURRENT_BRANCH)"
    Write-Output "HAS_GIT: $($paths.HAS_GIT)"
    Write-Output "ACTION: $action"
    if ($backupPath) { Write-Output "BACKUP: $backupPath" }
}
exit 0

