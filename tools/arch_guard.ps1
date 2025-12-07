param([switch]$Fix)

Write-Host "[arch-guard] Checking architecture rules..."

# 1) منع وجود bloc
$bad = @(rg -n --glob "apps/**/lib/**.dart" "(flutter_bloc|bloc_test|BlocBuilder|BlocProvider|BlocListener|Cubit)")
if ($bad.Count -gt 0) {
  Write-Host "[arch-guard] Found Bloc usage:" -ForegroundColor Red
  $bad | ForEach-Object { Write-Host "  $_" }
  if (-not $Fix) { exit 1 }
}

# 2) منع تعديلات خارج scopes
$changed = git diff --cached --name-only | Where-Object { $_ -like "*.dart" }
$protected = $changed | Where-Object {
  $_ -like "apps/*/lib/core/*" -or
  $_ -like "apps/*/lib/router/*" -or
  $_ -like "apps/*/lib/l10n/*" -or
  $_ -like "apps/*/lib/data/*" -or
  $_ -like "apps/*/lib/theme/*"
}
if ($protected.Count -gt 0) {
  Write-Host "[arch-guard] Protected areas modified:" -ForegroundColor Red
  $protected | ForEach-Object { Write-Host "  $_" }
  exit 1
}

Write-Host "[arch-guard] OK"
