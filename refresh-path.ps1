# تحديث PATH في الجلسة الحالية
$machine = [Environment]::GetEnvironmentVariable('Path','Machine')
$user    = [Environment]::GetEnvironmentVariable('Path','User')
$env:Path = "$machine;$user"

Write-Host "PATH refreshed. Now run: .\speckit.ps1 doctor"
