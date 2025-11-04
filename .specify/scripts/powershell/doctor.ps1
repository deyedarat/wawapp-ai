$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..\")).Path

Write-Host "[Speckit] == Speckit Doctor =="
Write-Host "Project Root : $projectRoot"
Write-Host "Environment Report:"

# Check gradle wrappers
$wrapperPaths = @(
    "android\gradlew.bat",
    "apps\wawapp_client\android\gradlew.bat", 
    "apps\wawapp_driver\android\gradlew.bat"
)

$foundWrappers = @()
foreach ($wrapper in $wrapperPaths) {
    $fullPath = Join-Path $projectRoot $wrapper
    if (Test-Path $fullPath) {
        $foundWrappers += $fullPath
        Write-Host "gradle  : OK ($wrapper)"
    } else {
        Write-Host "gradle  : MISSING ($wrapper)"
    }
}

if ($foundWrappers.Count -eq 0) {
    Write-Host "`nNo gradle wrappers found. Running flutter commands to materialize them..."
    
    $appPaths = @("apps\wawapp_client", "apps\wawapp_driver")
    foreach ($appPath in $appPaths) {
        $fullAppPath = Join-Path $projectRoot $appPath
        if (Test-Path $fullAppPath) {
            Write-Host "Processing $appPath..."
            Set-Location $fullAppPath
            & flutter pub get
            & flutter build apk --debug
        }
    }
    Set-Location $projectRoot
}