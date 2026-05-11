Param(
    [string]$Device = "R83Y20PC4EN",
    [int]$DurationSeconds = 45
)

$StartTime = Get-Date
$EndTime = $StartTime.AddSeconds($DurationSeconds)
$LogDir = "qa_forensics"
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

Write-Host "[FORENSICS] Starting Continuous Activity & Notification Monitor..."

$counter = 0
while ((Get-Date) -lt $EndTime) {
    $timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
    
    # 1. Capture top activity
    $topActivity = adb -s $Device shell dumpsys activity top | Select-String -Pattern "TASK|ACTIVITY|View Root"
    $topActivity | Out-File -FilePath "$LogDir/activity_top_$counter.txt"

    # 2. Capture screenshot
    adb -s $Device shell screencap -p /sdcard/forensic_$counter.png
    adb -s $Device pull /sdcard/forensic_$counter.png "$LogDir/forensic_$counter.png" | Out-Null

    # 3. Extract notification active state
    $notifCount = adb -s $Device shell dumpsys notification --summary | Select-String -Pattern "com.wawapp.driver"
    $notifCount | Out-File -FilePath "$LogDir/notif_summary_$counter.txt"

    Write-Host "[T+$(($counter*5))s] Activity: $($topActivity | Select-String -Pattern "ACTIVITY" | Select-Object -First 1)"
    
    Start-Sleep -Seconds 5
    $counter++
}

Write-Host "[FORENSICS] Monitor finished. Final forensics stored in $LogDir."
