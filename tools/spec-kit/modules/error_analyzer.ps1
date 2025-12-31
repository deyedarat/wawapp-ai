# Error Analyzer Module for WawApp
# Analyzes build errors, runtime errors, and provides actionable solutions

function Get-ErrorCategory {
    param([string]$ErrorText)
    
    $categories = @{
        'Gradle' = @('gradle', 'build.gradle', 'settings.gradle', 'AGP', 'Android Gradle Plugin')
        'Flutter' = @('flutter', 'pub get', 'pubspec.yaml', 'dart')
        'Firebase' = @('firebase', 'google-services', 'FirebaseApp', 'FCM')
        'Dependency' = @('dependency', 'package', 'version conflict', 'resolution failed')
        'Permission' = @('permission denied', 'access denied', 'already exists')
        'Path' = @('path', 'directory', 'file not found', 'subdirectory')
        'Network' = @('network', 'timeout', 'connection', 'download failed')
        'Android' = @('AndroidManifest', 'minSdkVersion', 'targetSdkVersion', 'compileSdkVersion')
    }
    
    foreach ($category in $categories.Keys) {
        foreach ($keyword in $categories[$category]) {
            if ($ErrorText -match [regex]::Escape($keyword)) {
                return $category
            }
        }
    }
    
    return 'Unknown'
}

function Get-ErrorSolution {
    param(
        [string]$ErrorText,
        [string]$Category
    )
    
    $solutions = @()
    
    # Path/Permission errors
    if ($ErrorText -match 'already exists' -or $ErrorText -match 'subdirectory or file.*already exists') {
        $solutions += @{
            Issue = 'Directory or file already exists'
            Cause = 'Previous build artifacts or incomplete cleanup'
            Solution = @(
                '.\spec.ps1 flutter:refresh',
                'Manually delete the conflicting directory if refresh fails',
                'Check for file locks or running processes'
            )
            Priority = 'High'
        }
    }
    
    # Gradle errors
    if ($Category -eq 'Gradle') {
        $solutions += @{
            Issue = 'Gradle build configuration issue'
            Cause = 'Version mismatch or cache corruption'
            Solution = @(
                '.\spec.ps1 flutter:refresh',
                'Delete .gradle folders in android directories',
                '.\spec.ps1 env:verify to check Gradle version'
            )
            Priority = 'High'
        }
    }
    
    # Dependency errors
    if ($Category -eq 'Dependency' -or $ErrorText -match 'version conflict') {
        $solutions += @{
            Issue = 'Dependency version conflict'
            Cause = 'Incompatible package versions'
            Solution = @(
                'Check pubspec.yaml for version constraints',
                '.\spec.ps1 flutter:refresh',
                'Run flutter pub outdated to check versions'
            )
            Priority = 'Medium'
        }
    }
    
    # Firebase errors
    if ($Category -eq 'Firebase') {
        $solutions += @{
            Issue = 'Firebase configuration issue'
            Cause = 'Missing or invalid Firebase configuration files'
            Solution = @(
                '.\spec.ps1 env:verify-Firebase',
                '.\spec.ps1 fcm:verify',
                'Verify google-services.json files exist and are valid'
            )
            Priority = 'High'
        }
    }
    
    # Network errors
    if ($Category -eq 'Network') {
        $solutions += @{
            Issue = 'Network connectivity issue'
            Cause = 'Unable to download dependencies or connect to services'
            Solution = @(
                'Check internet connection',
                'Verify proxy settings if behind corporate firewall',
                'Try again after a few minutes'
            )
            Priority = 'Medium'
        }
    }
    
    # Android SDK errors
    if ($Category -eq 'Android') {
        $solutions += @{
            Issue = 'Android SDK configuration issue'
            Cause = 'Missing SDK components or version mismatch'
            Solution = @(
                '.\spec.ps1 env:verify',
                'Check Android SDK installation',
                'Verify ANDROID_HOME environment variable'
            )
            Priority = 'High'
        }
    }
    
    # Generic fallback
    if ($solutions.Count -eq 0) {
        $solutions += @{
            Issue = 'Unclassified error'
            Cause = 'Error pattern not recognized'
            Solution = @(
                '.\spec.ps1 doctor for full diagnostics',
                '.\spec.ps1 flutter:refresh to clean and rebuild',
                'Check error logs for more details'
            )
            Priority = 'Low'
        }
    }
    
    return $solutions
}

function Format-ErrorReport {
    param(
        [string]$ErrorText,
        [string]$Category,
        [array]$Solutions
    )
    
    $report = @"

╔════════════════════════════════════════════════════════════════╗
║                    ERROR ANALYSIS REPORT                       ║
╚════════════════════════════════════════════════════════════════╝

📋 ERROR CATEGORY: $Category

📝 ERROR EXCERPT:
$($ErrorText.Substring(0, [Math]::Min(200, $ErrorText.Length)))...

"@

    $solutionNum = 1
    foreach ($solution in $Solutions) {
        $report += @"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 SOLUTION $solutionNum (Priority: $($solution.Priority))
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠️  Issue: $($solution.Issue)
💡 Cause: $($solution.Cause)

🔧 Recommended Actions:

"@
        $actionNum = 1
        foreach ($action in $solution.Solution) {
            $report += "   $actionNum. $action`n"
            $actionNum++
        }
        $solutionNum++
    }
    
    $report += @"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📚 ADDITIONAL RESOURCES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

• Run .\spec.ps1 help for all available commands
• Run .\spec.ps1 doctor for comprehensive diagnostics
• Check .specify/config.yaml for project configuration

"@
    
    return $report
}

function Invoke-ErrorAnalysis {
    param(
        [Parameter(Mandatory=$false)]
        [string]$ErrorText,
        
        [Parameter(Mandatory=$false)]
        [string]$LogFile
    )
    
    # Read error from file if provided
    if ($LogFile -and (Test-Path $LogFile)) {
        $ErrorText = Get-Content $LogFile -Raw
    }
    
    # Read from stdin if no error text provided
    if (-not $ErrorText) {
        Write-Host "📥 Paste error text (press Ctrl+Z then Enter when done):"
        $ErrorText = $input | Out-String
    }
    
    if (-not $ErrorText -or $ErrorText.Trim().Length -eq 0) {
        Write-Warning "No error text provided"
        return $false
    }
    
    # Analyze error
    $category = Get-ErrorCategory -ErrorText $ErrorText
    $solutions = Get-ErrorSolution -ErrorText $ErrorText -Category $category
    
    # Generate and display report
    $report = Format-ErrorReport -ErrorText $ErrorText -Category $category -Solutions $solutions
    Write-Host $report
    
    # Save report to file
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $reportPath = Join-Path $PSScriptRoot "..\..\..\tools\reports\error_analysis_$timestamp.txt"
    $reportDir = Split-Path $reportPath -Parent
    if (-not (Test-Path $reportDir)) {
        New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    }
    $report | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Host "💾 Report saved to: $reportPath`n"
    
    return $true
}

# Export functions
Export-ModuleMember -Function Invoke-ErrorAnalysis, Get-ErrorCategory, Get-ErrorSolution
