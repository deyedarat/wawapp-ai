param([switch]$DryRun)

Write-Host "[clean] Searching for Bloc usage..." -ForegroundColor Cyan

$results = @(rg -n --glob "apps/**/lib/**.dart" "(flutter_bloc|BlocProvider|BlocListener|BlocBuilder|Cubit|bloc_test)")

if ($results.Count -eq 0) {
  Write-Host "✓ No Bloc usage found" -ForegroundColor Green
  exit 0
}

Write-Host "✗ Found Bloc usage in $($results.Count) locations:" -ForegroundColor Red
$results | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }

if ($DryRun) {
  Write-Host "`n[clean] Dry run complete. Use migrate_to_riverpod.ps1 to fix" -ForegroundColor Cyan
} else {
  Write-Host "`n[clean] Run migration scripts to convert to Riverpod" -ForegroundColor Cyan
  Write-Host "  .\tools\migrate_to_riverpod.ps1 -Feature auth" -ForegroundColor Yellow
}
