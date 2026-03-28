# === WawApp Environment Setup ===
function EG-Ok($m){Write-Host "[OK]  $m" -ForegroundColor Green}
function EG-Miss($m){Write-Host "[MISS] $m" -ForegroundColor Yellow}

function EG-PrependPath([string]$dir){
  if (-not (Test-Path $dir)) { return }
  $items = ($env:Path -split ';') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
  $norm = $dir.TrimEnd('\').ToLower()
  foreach($x in $items){ if($x.TrimEnd('\').ToLower() -eq $norm){ return } }
  $env:Path = "$dir;$env:Path"
}

function EG-TestCmd([string]$cmd){
  try {
    $null = Get-Command $cmd -ErrorAction Stop
    return $true
  } catch {
    return $false
  }
}

function EG-Verify {
  Write-Host "`n=== Environment Verification ===" -ForegroundColor Cyan
  if(EG-TestCmd "flutter"){ EG-Ok "Flutter (installed)" } else { EG-Miss "Flutter (missing)" }
  if(EG-TestCmd "dart"){ EG-Ok "Dart (installed)" } else { EG-Miss "Dart (missing)" }
  if(EG-TestCmd "java"){ EG-Ok "Java (installed)" } else { EG-Miss "Java (missing)" }
  
  $gwLocations = @(
    ".\apps\wawapp_client\android\gradlew.bat",
    ".\apps\wawapp_driver\android\gradlew.bat"
  )
  $foundGw = $gwLocations | Where-Object { Test-Path $_ } | Select-Object -First 1
  if($foundGw){ EG-Ok "Gradle (wrapper: $foundGw)" } else { EG-Miss "Gradle wrapper (not found)" }
  
  if(EG-TestCmd "node"){ EG-Ok "Node (installed)" } else { EG-Miss "Node (missing)" }
  if(EG-TestCmd "npm"){ EG-Ok "npm (installed)" } else { EG-Miss "npm (missing)" }
  if(EG-TestCmd "firebase"){ EG-Ok "Firebase CLI (installed)" } else { EG-Miss "Firebase CLI (missing)" }
  Write-Host ""
}

Write-Host "`n=== Fixing Environment ===" -ForegroundColor Cyan

# إضافة المسارات
@(
  "C:\Program Files\Git\cmd",
  "C:\Program Files\Git\bin",
  "C:\flutter\bin",
  "C:\Program Files\nodejs"
) | ForEach-Object { EG-PrependPath $_ }

# Java
$jdk = "C:\Program Files\Eclipse Adoptium\jdk-17.0.6.10-hotspot"
if(Test-Path $jdk){
  $env:JAVA_HOME = $jdk
  EG-PrependPath (Join-Path $jdk 'bin')
}

# Android SDK
if($env:ANDROID_HOME){ EG-PrependPath (Join-Path $env:ANDROID_HOME 'platform-tools') }
if($env:ANDROID_SDK_ROOT){ EG-PrependPath (Join-Path $env:ANDROID_SDK_ROOT 'platform-tools') }

Write-Host "Environment fixed for current session`n" -ForegroundColor Green
EG-Verify
Write-Host "Ready to work! `n" -ForegroundColor Green
