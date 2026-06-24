<#
  List model IDs available on NVIDIA NIM (the OpenAI-compatible /v1/models endpoint).
  Helps you pick a model id to put in -Model when installing, or in
  ~/.claude-code-router/config.json (Router.* + Providers[].models).

  Key resolution order: -NvidiaApiKey param, $env:NVIDIA_API_KEY, or the key
  already saved in ~/.claude-code-router/config.json.

  Usage:
    powershell -ExecutionPolicy Bypass -File scripts/list-models.ps1
    powershell -ExecutionPolicy Bypass -File scripts/list-models.ps1 -Filter minimax
#>
param(
  [string]$NvidiaApiKey = "",
  [string]$Filter = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($NvidiaApiKey)) { $NvidiaApiKey = $env:NVIDIA_API_KEY }
if ([string]::IsNullOrWhiteSpace($NvidiaApiKey)) {
  $cfgPath = Join-Path $HOME ".claude-code-router\config.json"
  if (Test-Path $cfgPath) {
    $cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json
    $NvidiaApiKey = $cfg.Providers[0].api_key
  }
}
if ([string]::IsNullOrWhiteSpace($NvidiaApiKey)) { throw "No NVIDIA API key found (param / env / config.json)." }

$resp = Invoke-RestMethod -Uri "https://integrate.api.nvidia.com/v1/models" -Headers @{ Authorization = "Bearer $NvidiaApiKey" }
$ids = $resp.data | ForEach-Object { $_.id } | Sort-Object
if ($Filter) { $ids = $ids | Where-Object { $_ -like "*$Filter*" } }
$ids
Write-Host ""
Write-Host ("{0} model(s) listed." -f @($ids).Count)
