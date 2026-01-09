# run_driver_with_log.ps1
# يشغل wawapp_driver ويحفظ اللوغ في logs/latest_driver.log

$ErrorActionPreference = "Stop"

Set-Location "$PSScriptRoot\apps\wawapp_driver"

$logsDir = Join-Path $PSScriptRoot "logs"
New-Item -ItemType Directory -Force -Path $logsDir | Out-Null

$logFile = Join-Path $logsDir "latest_driver.log"

flutter run -d R8YW40AW58L -v 2>&1 | Tee-Object -FilePath $logFile
