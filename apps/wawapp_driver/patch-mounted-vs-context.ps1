$files = @(
  "lib\features\auth\create_pin_screen.dart",
  "lib\features\auth\otp_screen.dart",
  "lib\features\auth\phone_pin_login_screen.dart"
)

foreach ($f in $files) {
  if (-not (Test-Path $f)) { Write-Host "Skip (missing): $f"; continue }

  $txt = Get-Content $f -Raw
  $orig = $txt

  # Pass 1: بعد await → حارس mounted قبل أول استخدام context → بدّله إلى context.mounted
  # يعتمد على نمط DOTALL (?s) ويقبل تعليقات/أسطر فارغة بينهما.
  $pattern1 = '(?is)(await\s[^;]*;\s*)(?:\/\/[^\n]*\n|\s)*if\s*\(\s*!mounted\s*\)\s*return;\s*(?=(?:\/\/[^\n]*\n|\s)*(Navigator\.|ScaffoldMessenger\.|showDialog|Theme\.of|Localizations\.of))'
  $txt = [regex]::Replace($txt, $pattern1, '$1if (!context.mounted) return; ')

  # Pass 1b (بدون await): لو جاء الحارس مباشرة قبل استخدام context بسطرين كحد أقصى
  $pattern1b = '(?im)^[ \t]*if\s*\(\s*!mounted\s*\)\s*return;\s*(?:\/\/[^\n]*\n|[ \t]*\n){0,2}(?=(Navigator\.|ScaffoldMessenger\.|showDialog|Theme\.of|Localizations\.of))'
  $txt = [regex]::Replace($txt, $pattern1b, 'if (!context.mounted) return; ')

  # Pass 2: حماية setState يجب أن تبقى بـ mounted وليس context.mounted
  $pattern2 = '(?is)if\s*\(\s*!context\.mounted\s*\)\s*return;\s*(?=(?:\/\/[^\n]*\n|\s)*setState\s*\()'
  $txt = [regex]::Replace($txt, $pattern2, 'if (!mounted) return; ')

  if ($txt -ne $orig) {
    Copy-Item $f "$f.bak" -Force
    Set-Content $f $txt -NoNewline
    Write-Host "Patched $f"
  } else {
    Write-Host "No changes in $f"
  }
}

Write-Host "== Quick audit =="
# راجع كل الحراس القريبة من context أو setState
foreach ($f in $files) {
  Write-Host "`n--- $f ---"
  Select-String -Path $f -Pattern 'await|if\s*\(\s*!\s*mounted\)|if\s*\(\s*!\s*context\.mounted\)|Navigator\.|ScaffoldMessenger\.|showDialog|Theme\.of|Localizations\.of|setState\s*\(' -SimpleMatch -Context 0,2
}