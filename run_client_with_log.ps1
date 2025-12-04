# run_client_with_log.ps1
# يشغل wawapp_client ويحفظ اللوغ في ملف logs/latest_client.log

$ErrorActionPreference = "Stop"

# 1) تأكد أننا داخل مجلد تطبيق العميل
# عدّل هذا المسار حسب مكان التطبيق عندك
Set-Location "$PSScriptRoot\apps\wawapp_client"

# 2) تحضير مجلد اللوغات
$logsDir = Join-Path $PSScriptRoot "logs"
New-Item -ItemType Directory -Force -Path $logsDir | Out-Null

# 3) اسم ملف اللوغ الأساسي الذي سيقرأه Amazon Q
$logFile = Join-Path $logsDir "latest_client.log"

# 4) تشغيل Flutter مع حفظ كل شيء في الملف + عرضه في الشاشة
flutter run -v 2>&1 | Tee-Object -FilePath $logFile
