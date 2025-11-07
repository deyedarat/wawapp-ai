param()

# يبحث عن نماط مفاتيح مثل Google API: AIza...
# يستثني ملفات Firebase المعروفة التي تحتوي مفاتيح عامة مسموح بها عادة.
$pattern   = [regex]'AIza[0-9A-Za-z\-_]+'
$whitelist = @(
  'google-services.json',
  'GoogleService-Info.plist',
  'firebase_options.dart'
)

# استخدم git لسرد الملفات المتتبعة وغير المتتبعة (المستثناة حسب .gitignore)
$files = (& git ls-files -co --exclude-standard) -split "`n" | Where-Object { $_ -and -not ($_ -like '.git/*') }

$hits = @()
foreach ($f in $files) {
  if ($whitelist | Where-Object { $f -like "*$_" }) { continue }
  try {
    $text = Get-Content -Path $f -Raw -ErrorAction Stop
    if ($pattern.IsMatch($text)) { $hits += $f }
  } catch { }
}

if ($hits.Count -gt 0) {
  Write-Error "Secret-like patterns found (e.g., 'AIza...') in:`n  - " + ($hits -join "`n  - ")
  Write-Host ">> ذا كانت هذه مفاتيح صحيحة وقف الكومت ودورها فورا."
  exit 2
}

Write-Host "OK: no secret-like patterns found."
exit 0
