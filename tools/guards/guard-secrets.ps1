# guard-secrets.ps1 - Prevent API key leaks in commits
# Purpose: Scan codebase for exposed secrets before CI builds

param(
    [string]$Path = ".",
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

Write-Host "🔍 Scanning for exposed secrets..." -ForegroundColor Cyan

# Patterns to detect
$patterns = @(
    @{ Name = "Google API Key"; Pattern = 'AIza[0-9A-Za-z\-_]{35}' },
    @{ Name = "Firebase API Key"; Pattern = 'AAAA[0-9A-Za-z\-_:]{100,}' },
    @{ Name = "Generic Secret"; Pattern = '(api[_-]?key|apikey|secret[_-]?key)\s*[:=]\s*[''"]?[A-Za-z0-9\-_]{20,}' }
)

# Files to exclude
$excludePatterns = @(
    '*.lock',
    '*.log',
    '.git/*',
    'build/*',
    '.dart_tool/*',
    'node_modules/*',
    '*.example',
    'guard-secrets.ps1',
    'rotate_keys.ps1'
)

$findings = @()
$scannedFiles = 0

# Get all text files
$files = Get-ChildItem -Path $Path -Recurse -File | Where-Object {
    $file = $_
    $include = $true
    
    # Check exclusions
    foreach ($exclude in $excludePatterns) {
        if ($file.FullName -like "*$exclude*") {
            $include = $false
            break
        }
    }
    
    # Only text files
    if ($include -and $file.Extension -match '\.(dart|yaml|yml|json|xml|gradle|properties|sh|ps1|md|txt|env)$') {
        $include = $true
    } elseif ($include) {
        $include = $false
    }
    
    $include
}

foreach ($file in $files) {
    $scannedFiles++
    
    if ($Verbose) {
        Write-Host "  Scanning: $($file.FullName)" -ForegroundColor Gray
    }
    
    try {
        $content = Get-Content -Path $file.FullName -Raw -ErrorAction SilentlyContinue
        
        if ($content) {
            foreach ($pattern in $patterns) {
                if ($content -match $pattern.Pattern) {
                    $matches = [regex]::Matches($content, $pattern.Pattern)
                    
                    foreach ($match in $matches) {
                        # Get line number
                        $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
                        
                        $findings += [PSCustomObject]@{
                            File = $file.FullName.Replace($PWD.Path, ".")
                            Line = $lineNumber
                            Type = $pattern.Name
                            Match = $match.Value.Substring(0, [Math]::Min(50, $match.Value.Length)) + "..."
                        }
                    }
                }
            }
        }
    } catch {
        if ($Verbose) {
            Write-Host "  ⚠️  Could not read: $($file.FullName)" -ForegroundColor Yellow
        }
    }
}

Write-Host "✅ Scanned $scannedFiles files`n" -ForegroundColor Green

if ($findings.Count -gt 0) {
    Write-Host "❌ SECURITY ALERT: Found $($findings.Count) potential secret(s)!`n" -ForegroundColor Red
    
    $findings | Format-Table -AutoSize
    
    Write-Host "`n🔒 Action Required:" -ForegroundColor Yellow
    Write-Host "1. Remove secrets from code"
    Write-Host "2. Move to .env files (add to .gitignore)"
    Write-Host "3. Rotate exposed keys immediately"
    Write-Host "4. Run: tools/secure/rotate_keys.ps1 -Help"
    
    exit 1
} else {
    Write-Host "✅ No secrets detected. Safe to proceed!" -ForegroundColor Green
    exit 0
}
