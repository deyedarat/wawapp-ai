# tools\spec-kit\doctor.ps1
param(
  [switch]$Light,
  [switch]$VerboseLog
)

$ErrorActionPreference = 'SilentlyContinue'
Set-StrictMode -Version 2.0

# إضافة مسارات شائعة إلى PATH مؤقتاً
$extraPaths = @('C:\flutter\bin', 'C:\src\flutter\bin')
foreach($p in $extraPaths){ if((Test-Path $p) -and ($env:Path -notlike "*$p*")){ $env:Path = "$p;$env:Path" } }

function Resolve-Exe {
  param([string]$BaseName, [string[]]$ExtraCandidates = @())
  $cands = @("$BaseName.cmd", "$BaseName.bat", $BaseName) + $ExtraCandidates
  foreach ($c in $cands) {
    $g = Get-Command $c -ErrorAction SilentlyContinue
    if ($g) {
      $ext = [IO.Path]::GetExtension($g.Source)
      if ($ext -and $ext.ToLowerInvariant() -eq ".ps1") { continue } # تجاهل سكربتات ps1
      return $g.Source
    }
  }
  return $null
}

function Run-Tool {
  param(
    [Parameter(Mandatory=$true)][string]$Name,
    [string]$Args='--version',
    [string[]]$AlsoTry=@()
  )

  # كلمات/عبارات نعدّها فشل صريح
  $errorTokens = @(
    'is not recognized', 'command not found', 'could not be found',
    'not found', 'no such file', 'unable to find git', 'Error:'
  )

  try {
    # نحاول إيجاد مسار فعلي، مع تفضيل .cmd/.bat
    $resolved = $null
    foreach($cand in @("$Name.cmd","$Name.bat",$Name) + $AlsoTry){
      $cmd = Get-Command $cand -ErrorAction SilentlyContinue
      if($cmd){
        $ext = [IO.Path]::GetExtension($cmd.Source)
        if ($ext -and $ext.ToLowerInvariant() -eq '.ps1') { continue } # تجاهل ps1
        $resolved = $cmd.Source; break
      }
    }

    # نختار آلية التنفيذ حسب نوع الملف
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    if ($resolved -and ([IO.Path]::GetExtension($resolved).ToLowerInvariant() -eq '.exe')) {
      $psi.FileName  = $resolved
      $psi.Arguments = $Args
    } else {
      $toRun = if ($resolved) { "`"$resolved`" $Args" } else { "$Name $Args" }
      $psi.FileName  = 'cmd.exe'
      $psi.Arguments = "/c $toRun"
    }

    # نمرر PATH الحالي صراحةً
    $psi.EnvironmentVariables['PATH'] = $env:Path
    $psi.WorkingDirectory       = (Get-Location).Path
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute        = $false
    $psi.CreateNoWindow         = $true

    $p = [System.Diagnostics.Process]::Start($psi)
    $out = $p.StandardOutput.ReadToEnd()
    $err = $p.StandardError.ReadToEnd()
    $p.WaitForExit()

    $txt = (($out + $err) -as [string]).Trim()

    # نجاح فقط إذا ExitCode=0 ولا توجد عبارات خطأ
    $looksError = $false
    foreach($t in $errorTokens){ if($txt.ToLower().Contains($t)){ $looksError = $true; break } }
    $ok = ($p.ExitCode -eq 0) -and (-not $looksError)

    return @{ ok=$ok; msg=$txt }
  } catch {
    return @{ ok=$false; msg=$_.Exception.Message }
  }
}

function Test-File { param([string]$Path) return @{ path=$Path; exists=(Test-Path $Path) } }

# project root = two levels up from doctor.ps1 location
$scriptDir = Split-Path -Parent $PSCommandPath
$project   = Split-Path -Parent (Split-Path -Parent $scriptDir)

# --- candidates & paths ---
# Android dirs in monorepo
$androidDirs = @(
  (Join-Path $project 'android'),
  (Join-Path $project 'apps\wawapp_client\android'),
  (Join-Path $project 'apps\wawapp_driver\android')
) | Where-Object { Test-Path $_ }

# pick first gradlew.bat that exists
$gradlew = $null
foreach($d in $androidDirs){
  $gw = Join-Path $d 'gradlew.bat'
  if(Test-Path $gw){ $gradlew = $gw; break }
}

# extra candidates for tools (common Windows locations)
$flutterExtra  = @('flutter.bat','C:\flutter\bin\flutter.bat','C:\src\flutter\bin\flutter.bat')
$nodeExtra     = @('C:\Program Files\nodejs\node.exe','C:\nvm4w\nodejs\node.exe','C:\Program Files\nodejs\node')
$npmExtra      = @('npm.cmd', (Join-Path $env:APPDATA 'npm\npm.cmd'))
$firebaseExtra = @('firebase.cmd', (Join-Path $env:APPDATA 'npm\firebase.cmd'))
$javaHome      = $env:JAVA_HOME
$javaExtra     = @()
if($javaHome){ $javaExtra += (Join-Path $javaHome 'bin\java.exe') }

# --- tools check ---
$tools = [ordered]@{
  flutter  = Run-Tool -Name 'flutter'  -Args '--version' -AlsoTry $flutterExtra
  node     = Run-Tool -Name 'node'     -Args '--version' -AlsoTry $nodeExtra
  npm      = Run-Tool -Name 'npm'      -Args '--version' -AlsoTry $npmExtra
  java     = Run-Tool -Name 'java'     -Args '-version'  -AlsoTry $javaExtra
  gradle   = if($gradlew){ Run-Tool -Name $gradlew -Args '--version' } else { @{ ok=$false; msg='gradlew.bat not found' } }
  firebase = Run-Tool -Name 'firebase' -Args '--version' -AlsoTry $firebaseExtra
}

Write-Host "Environment Report:"
foreach ($k in $tools.Keys) {
  $line = if ($tools[$k].ok) { "OK" } else { "MISSING" }
  if ($tools[$k].msg -and $tools[$k].ok) {
    $first = ($tools[$k].msg -split "`r?`n")[0]
    Write-Host ("{0,-8}: {1}  ({2})" -f $k, $line, $first)
  } else {
    Write-Host ("{0,-8}: {1}" -f $k, $line)
  }
  if ($VerboseLog -and $tools[$k].msg) { Write-Host $tools[$k].msg }
}

Write-Host ""
Write-Host "Files:"
# check important files for BOTH apps
$filesList = @(
  (Join-Path $project '.specify\config.yaml'),
  (Join-Path $project 'apps\wawapp_client\pubspec.yaml'),
  (Join-Path $project 'apps\wawapp_driver\pubspec.yaml'),
  (Join-Path $project 'apps\wawapp_client\android\app\google-services.json'),
  (Join-Path $project 'apps\wawapp_driver\android\app\google-services.json'),
  (Join-Path $project 'apps\wawapp_client\android\app\src\main\res\values\api_keys.xml'),
  (Join-Path $project 'apps\wawapp_driver\android\app\src\main\res\values\api_keys.xml')
)
foreach ($p in $filesList){
  $status = if (Test-Path $p) { 'OK' } else { 'MISSING' }
  Write-Host ("{0} : {1}" -f $p, $status)
}

# exit code (require core tools + at least one gradle wrapper)
$must = 'flutter','java','node','npm'
$missing = @($must | Where-Object { -not $tools[$_].ok })
if (($missing.Count -gt 0) -or -not $gradlew) { exit 2 } else { exit 0 }
