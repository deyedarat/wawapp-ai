<#
.SYNOPSIS
رشادات + وظائف مساعدة لتدوير مفاتيح Google Maps ومنع تسريب السرار.

USAGE:
  pwsh -File tools/secure/rotate_keys.ps1
#>

function Ensure-LineInFile {
  param([string]$Path, [string]$Line)
  if (-not (Test-Path $Path)) { New-Item -ItemType File -Force -Path $Path | Out-Null }
  $content = Get-Content -Path $Path -ErrorAction SilentlyContinue
  if ($content -notcontains $Line) { Add-Content -Path $Path -Value $Line }
}

Write-Host "== Ensure .gitignore sane defaults =="
Ensure-LineInFile ".gitignore" ".env"
Ensure-LineInFile ".gitignore" ".env.*"
Ensure-LineInFile ".gitignore" "*.runtimeconfig.*"
Ensure-LineInFile ".gitignore" "*.keystore"
Ensure-LineInFile ".gitignore" "*.jks"

# نشاء .env.example ن لم يوجد
$envClient = "apps/wawapp_client/.env.example"
$envDriver = "apps/wawapp_driver/.env.example"
if (-not (Test-Path $envClient)) {
  @"
# Example env for Client
MAPS_API_KEY=YOUR_MAPS_BROWSER_KEY
SENTRY_DSN=
"@ | Set-Content -Encoding UTF8 $envClient
}
if (-not (Test-Path $envDriver)) {
  @"
# Example env for Driver
MAPS_API_KEY=YOUR_MAPS_BROWSER_KEY
SENTRY_DSN=
"@ | Set-Content -Encoding UTF8 $envDriver
}

Write-Host "== Scan current working tree for 'AIza...' =="
powershell -NoProfile -ExecutionPolicy Bypass -File "tools/guards/guard-secrets.ps1"
if ($LASTEXITCODE -ne 0) {
  Write-Host "⚠️  اكتشفت نماط سرار. عالجها ولا."
} else {
  Write-Host "✅ لا توجد نماط سرار مبدئيا."
}

@"
=== خطوات تدوير مفتاح Google Maps (يدويا من GCP) ===
1) افتح: Google Cloud Console → APIs & Services → Credentials.
2) نشئ API key جديد.
3) قيود المفتاح:
   - Application restrictions:
       * Android: ضف Package Name + SHA-1 (مثلا com.wawapp.client)
       * iOS   : Bundle ID (ن وجد)
       * Web   : (اختياري) لو عندك صفحات ويب
   - API restrictions: فعل فقط (Maps SDK for Android/iOS, Maps Static, Geocoding…) حسب حاجتك.
4) انسخ المفتاح الجديد لى ملفات .env (محليا فقط لا ترفعه).
5) فعل المفتاح الجديد واختبر البناء والتشغيل.
6) عطل المفتاح القديم ثم احذفه.
7) نظف تاريخ Git من ي تسريب سابق (اختياري قوي):
   - ثبت git-filter-repo ثم شغل:
     git filter-repo --invert-paths --path-glob "*AIza*"
   - و: git filter-repo --replace-text replace.txt (مع قواعد الاستبدال)
   - ادفع التغييرات بقوة: git push --force-with-lease
8) اطلب من كل الجهزة عادة الاستنساخ و تنفيذ fetch+reset.
"@ | Write-Host
