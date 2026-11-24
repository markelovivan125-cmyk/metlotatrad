# Публикация радара на GitHub: powershell -File push-github.ps1 https://github.com/USER/radar-rf.git
param(
  [Parameter(Mandatory = $true)][string]$Url
)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
if (-not (git remote | Where-Object { $_ -eq 'origin' })) {
  git remote add origin $Url
} else {
  git remote set-url origin $Url
}
git push -u origin main
Write-Host ''
Write-Host 'Готово. Репозиторий: ' + $Url
if ($Url -match 'github\.com[:/](.+?)(\.git)?$') {
  Write-Host ('Страница: https://github.com/' + $Matches[1])
  Write-Host ('GitHub Pages (по желанию): Settings -> Pages -> Branch: main, root.')
}
