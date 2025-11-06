param(
  [Parameter(Mandatory=$true)]
  [ValidateSet('auth', 'nearby', 'wallet')]
  [string]$Feature
)

Write-Host "[migrate] Starting $Feature migration to Riverpod..."

$steps = @(
  "1. Create ${Feature}_controller.dart with StateNotifier",
  "2. Replace BlocBuilder with Consumer",
  "3. Replace BlocListener with ref.listen",
  "4. Update screens to use ref.watch/ref.read",
  "5. Run: dart format . --set-exit-if-changed",
  "6. Run: flutter analyze",
  "7. Run: .\tools\arch_guard.ps1"
)

Write-Host "`nMigration steps for $Feature:" -ForegroundColor Cyan
$steps | ForEach-Object { Write-Host "  $_" }

Write-Host "`nTemplates available in tools/templates/" -ForegroundColor Green
Write-Host "  - riverpod_controller_template.dart"
Write-Host "  - riverpod_ui_template.dart"
