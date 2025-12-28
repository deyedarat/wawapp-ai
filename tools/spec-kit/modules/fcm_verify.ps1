function Invoke-FcmVerify {
    param([string]$AppPath)
    
    Write-Host "[FCM-VERIFY] Checking $AppPath..."
    
    $googleServicesPath = Join-Path $AppPath "android\app\google-services.json"
    $buildGradlePath = Join-Path $AppPath "android\app\build.gradle.kts"
    
    if (-not (Test-Path $googleServicesPath)) {
        Write-Warning "google-services.json not found"
        return $false
    }
    
    if (-not (Test-Path $buildGradlePath)) {
        Write-Warning "build.gradle.kts not found"
        return $false
    }
    
    $googleServices = Get-Content $googleServicesPath -Raw | ConvertFrom-Json
    $packageName = $googleServices.client[0].client_info.android_client_info.package_name
    
    $buildGradle = Get-Content $buildGradlePath -Raw
    if ($buildGradle -match 'applicationId\s*=\s*"([^"]+)"') {
        $applicationId = $matches[1]
        
        if ($packageName -eq $applicationId) {
            Write-Host "[FCM-VERIFY] OK: $packageName matches applicationId"
            return $true
        } else {
            Write-Warning "Mismatch: google-services.json=$packageName vs applicationId=$applicationId"
            return $false
        }
    } else {
        Write-Warning "Could not find applicationId in build.gradle.kts"
        return $false
    }
}
