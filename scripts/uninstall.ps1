<#
  Stop the router and remove the config it generated.
  Does NOT uninstall the npm package by default (pass -RemovePackage to do so).
#>
param([switch]$RemovePackage)

$ccrDir = Join-Path $HOME ".claude-code-router"

Write-Host "==> Stopping router..."
try { ccr stop } catch { Write-Host "router not running" }

Write-Host "==> Removing $ccrDir ..."
if (Test-Path $ccrDir) { Remove-Item -Recurse -Force $ccrDir }

if ($RemovePackage) {
  Write-Host "==> Removing global npm package..."
  npm uninstall -g "@musistudio/claude-code-router"
}

Write-Host "Done. (Your ~/.ccs/duck.settings.json was left in place — remove it manually if you want.)"
