param()

$bad = @()

# 2.1 منع flutter_bloc في الاعتماديات
$pubspecs = (& git ls-files 'pubspec.yaml','pubspec.lock') -split "`n" | Where-Object { $_ }
foreach ($p in $pubspecs) {
  try {
    $t = Get-Content -Path $p -Raw -ErrorAction Stop
    if ($t -match '(?ms)^\s*flutter_bloc\s*:') { $bad += $p }
  } catch { }
}

# 2.2 منع الاستيراد من flutter_bloc في دارت
$dartFiles = (& git ls-files '*.dart') -split "`n" | Where-Object { $_ }
foreach ($f in $dartFiles) {
  try {
    $t = Get-Content -Path $f -Raw -ErrorAction Stop
    if ($t -match 'package:flutter_bloc/' -or $t -match 'bloc/bloc\.dart') { $bad += $f }
  } catch { }
}

if ($bad.Count -gt 0) {
  Write-Error "Bloc usage detected (deps or imports) in:`n  - " + ($bad | Select-Object -Unique -Join "`n  - ")
  Write-Host ">> المطلوب: استخدام Riverpod فقط (StateNotifier/AsyncNotifier)."
  exit 3
}

Write-Host "OK: no flutter_bloc usage detected."
exit 0
