Param(
    [string]$Device = "R83Y20PC4EN"
)

Write-Host "`n🚀 STARTING ULTIMATE VISUAL RESURRECTION FORENSICS"

# Ensure clean
adb -s $Device shell am force-stop com.wawapp.driver
node qa/scripts/reproduce_resurrection.js cleanup | Out-Null

# Start screenrecord in background
Write-Host "[TEST] 🎥 Starting Screen Recording to catch transient pixels..."
$RecordProcess = Start-Process adb -ArgumentList "-s $Device shell screenrecord /sdcard/visual_trap.mp4" -PassThru -NoNewWindow

Start-Sleep -Seconds 2

# Inject
Write-Host "[TEST] Injecting unique offer..."
node qa/scripts/reproduce_resurrection.js inject

# Open App, let it cache
adb -s $Device shell monkey -p com.wawapp.driver -c android.intent.category.LAUNCHER 1 | Out-Null
Start-Sleep -Seconds 10
# Go to nearby
adb -s $Device shell input tap 532 650
Start-Sleep -Seconds 5
Write-Host "[TEST] Offer established in UI."

# Force Stop (Cache commits)
Write-Host "[TEST] 💥 KILLING APP WHILE CACHED..."
adb -s $Device shell am force-stop com.wawapp.driver
Start-Sleep -Seconds 2

# Terminate
Write-Host "[TEST] 💀 TERMINATING ON BACKEND..."
node qa/scripts/reproduce_resurrection.js terminate | Out-Null
Start-Sleep -Seconds 2

# Relaunch
Write-Host "[TEST] 🔄 RELAUNCHING FOR TRAP..."
adb -s $Device shell monkey -p com.wawapp.driver -c android.intent.category.LAUNCHER 1 | Out-Null
Start-Sleep -Seconds 10

# Navigate to nearby IMMEDIATELY
Write-Host "[TEST] PUSHING TO NEARBY TO WITNESS CACHE..."
adb -s $Device shell input tap 532 650
Start-Sleep -Seconds 6

Write-Host "[TEST] 🎬 STOPPING RECORDING..."
# Kill the recording process gracefully
Stop-Process -Id $RecordProcess.Id -Force
adb -s $Device shell pkill -2 screenrecord # Send SIGINT to properly finalize the mp4 file header
Start-Sleep -Seconds 3

Write-Host "[TEST] 💾 PULLING VIDEO FILE..."
adb -s $Device pull /sdcard/visual_trap.mp4 qa_forensics/visual_trap.mp4

Write-Host "`n🏁 VIDEO CAPTURED: qa_forensics/visual_trap.mp4"
Write-Host "[TEST] Extracting key frames for visual review..."
# Use ffmpeg to dump frames at 10fps to a folder for inspection
if (Test-Path "qa_forensics/frames") { Remove-Item "qa_forensics/frames" -Recurse -Force }
New-Item -ItemType Directory -Path "qa_forensics/frames" | Out-Null
ffmpeg -i qa_forensics/visual_trap.mp4 -r 10 qa_forensics/frames/frame_%04d.png -loglevel quiet

Write-Host "[ANALYSIS] Generated frames. Analyzing for resurrection artifacts..."
node -e "const fs = require('fs'); console.log('[REPORT] Visual artifacts ready for review in qa_forensics/frames.'); process.exit(0);"
