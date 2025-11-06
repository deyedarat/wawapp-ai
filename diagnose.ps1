# === 0) تشخيص سريع: هل الجلسة 64-بت؟ وما هي مسارات PATH الحالية؟
[Environment]::Is64BitProcess
$env:Path -split ';' | Where-Object {$_ -match 'flutter|npm|node|Roaming\\npm'}

# === 1) وحّد PATH الحالي من سجل النظام + المستخدم (يحل مشكلة اختلاف الجلسات/المستخدم)
$machine = [Environment]::GetEnvironmentVariable('Path','Machine')
$user    = [Environment]::GetEnvironmentVariable('Path','User')
$env:Path = "$machine;$user"

# === 2) أضف مواقع Flutter الشائعة (عدّل أول سطر لو مسارك يختلف)
$flutterBins = @(
  'C:\src\flutter\bin',
  "$env:USERPROFILE\fvm\default\bin",
  "$env:USERPROFILE\AppData\Local\flutter\bin"
) | Where-Object { Test-Path $_ }
if ($flutterBins.Count) { $env:Path += ';' + ($flutterBins -join ';') }

# === 3) أضف مسار npm global binaries (firebase.cmd)
try {
  $npmBin = (npm bin -g) 2>$null
  if ($npmBin -and (Test-Path $npmBin)) { $env:Path += ";$npmBin" }
} catch {}

# === 4) تحقّق أن الأدوات مرئية الآن
where.exe flutter
where.exe firebase

# إن لم يظهر firebase، ثبّت الأداه (لن يؤذي إن كانت مثبتة)
if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) { npm i -g firebase-tools }

# جرّب مجددًا بعد التثبيت
where.exe firebase

# === 5) شغّل Speckit Doctor
.\speckit.ps1 doctor
