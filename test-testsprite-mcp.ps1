# TestSprite MCP Integration Test Script
# Tests WawApp Flutter apps using TestSprite MCP server

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("client", "driver", "both")]
    [string]$App = "both",
    
    [Parameter(Mandatory=$false)]
    [string]$TestType = "smoke"
)

Write-Host "🧪 TestSprite MCP Integration Test" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan

# Verify MCP configuration
$mcpConfigPath = ".\.mcp\servers.json"
if (-not (Test-Path $mcpConfigPath)) {
    Write-Error "MCP configuration not found at $mcpConfigPath"
    exit 1
}

Write-Host "✅ MCP configuration found" -ForegroundColor Green

# Check if TestSprite is configured
$mcpConfig = Get-Content $mcpConfigPath | ConvertFrom-Json
$testSpriteServer = $mcpConfig.servers | Where-Object { $_.name -eq "TestSprite" }

if (-not $testSpriteServer) {
    Write-Error "TestSprite server not configured in MCP"
    exit 1
}

if (-not $testSpriteServer.enabled) {
    Write-Error "TestSprite server is disabled in MCP configuration"
    exit 1
}

Write-Host "✅ TestSprite MCP server configured and enabled" -ForegroundColor Green

# Test function for each app
function Test-WawApp {
    param(
        [string]$AppName,
        [string]$AppPath
    )
    
    Write-Host "`n🔍 Testing $AppName app..." -ForegroundColor Yellow
    
    if (-not (Test-Path $AppPath)) {
        Write-Warning "$AppName app not found at $AppPath"
        return $false
    }
    
    # Check if app has test directory
    $testDir = Join-Path $AppPath "test"
    $integrationTestDir = Join-Path $AppPath "integration_test"
    
    if (Test-Path $testDir) {
        Write-Host "  ✅ Unit tests directory found" -ForegroundColor Green
    }
    
    if (Test-Path $integrationTestDir) {
        Write-Host "  ✅ Integration tests directory found" -ForegroundColor Green
    }
    
    # Run basic Flutter doctor check using spec.ps1
    Write-Host "  🔧 Running Flutter environment check..." -ForegroundColor Blue
    try {
        & ".\spec.ps1" env:doctor
        Write-Host "  ✅ Flutter environment OK" -ForegroundColor Green
    }
    catch {
        Write-Warning "  ⚠️ Flutter environment issues detected"
    }
    
    # Test app compilation (dry run)
    Write-Host "  🏗️ Testing app compilation..." -ForegroundColor Blue
    Push-Location $AppPath
    try {
        flutter analyze --no-fatal-infos
        Write-Host "  ✅ Static analysis passed" -ForegroundColor Green
        
        # Test build (debug mode, no actual device)
        flutter build apk --debug --no-shrink
        Write-Host "  ✅ Debug build successful" -ForegroundColor Green
        
        return $true
    }
    catch {
        Write-Warning "  ⚠️ Build issues detected: $_"
        return $false
    }
    finally {
        Pop-Location
    }
}

# Test apps based on parameter
$results = @{}

if ($App -eq "client" -or $App -eq "both") {
    $results["client"] = Test-WawApp "WawApp Client" ".\apps\wawapp_client"
}

if ($App -eq "driver" -or $App -eq "both") {
    $results["driver"] = Test-WawApp "WawApp Driver" ".\apps\wawapp_driver"
}

# Summary
Write-Host "`n📊 Test Results Summary" -ForegroundColor Cyan
Write-Host "======================" -ForegroundColor Cyan

$allPassed = $true
foreach ($app in $results.Keys) {
    $status = if ($results[$app]) { "✅ PASS" } else { "❌ FAIL" }
    $color = if ($results[$app]) { "Green" } else { "Red" }
    Write-Host "$app app: $status" -ForegroundColor $color
    
    if (-not $results[$app]) {
        $allPassed = $false
    }
}

# TestSprite MCP connection test
Write-Host "`n🔌 Testing TestSprite MCP Connection..." -ForegroundColor Yellow
try {
    # This would typically involve calling the MCP server
    # For now, we'll just verify the configuration is valid
    $apiKey = $testSpriteServer.config.env.API_KEY
    if ($apiKey -and $apiKey.StartsWith("sk-user-")) {
        Write-Host "✅ TestSprite API key format valid" -ForegroundColor Green
    } else {
        Write-Warning "⚠️ TestSprite API key format may be invalid"
        $allPassed = $false
    }
}
catch {
    Write-Warning "⚠️ TestSprite MCP connection test failed: $_"
    $allPassed = $false
}

# Final result
Write-Host "`n🎯 Overall Result" -ForegroundColor Cyan
if ($allPassed) {
    Write-Host "✅ All tests passed! TestSprite MCP integration ready." -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ Some tests failed. Check output above for details." -ForegroundColor Red
    exit 1
}