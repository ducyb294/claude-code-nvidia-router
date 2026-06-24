<#
  Install / configure claude-code-router (CCR) so CCS + Claude Code can use
  any NVIDIA NIM model through the Anthropic Messages API.

  Usage (from the repo root):
    powershell -ExecutionPolicy Bypass -File scripts/install.ps1
    powershell -ExecutionPolicy Bypass -File scripts/install.ps1 -NvidiaApiKey "nvapi-XXXX"
    powershell -ExecutionPolicy Bypass -File scripts/install.ps1 -Model "qwen/qwen3-235b-a22b"

  -Model   The NVIDIA model id to route to. Default: minimaxai/minimax-m2.7 (just
           an example — NVIDIA hosts many; run scripts/list-models.ps1 to browse).
  The NVIDIA key is read from (in order): -NvidiaApiKey param, $env:NVIDIA_API_KEY,
  or an interactive prompt. The key is written ONLY to ~/.claude-code-router/config.json
  (gitignored, outside this repo).
#>
param(
  [string]$NvidiaApiKey = "",
  [string]$Model = "minimaxai/minimax-m2.7"
)

$ErrorActionPreference = "Stop"
$repoRoot   = Split-Path -Parent $PSScriptRoot
$ccrDir     = Join-Path $HOME ".claude-code-router"
$ccsDir     = Join-Path $HOME ".ccs"

Write-Host "==> Target NVIDIA model: $Model"

Write-Host "==> Checking prerequisites (node, npm)..."
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { throw "node not found. Install Node.js first." }
if (-not (Get-Command npm  -ErrorAction SilentlyContinue)) { throw "npm not found. Install Node.js first." }

Write-Host "==> Installing @musistudio/claude-code-router (global)..."
npm install -g "@musistudio/claude-code-router"

Write-Host "==> Resolving NVIDIA API key..."
if ([string]::IsNullOrWhiteSpace($NvidiaApiKey)) { $NvidiaApiKey = $env:NVIDIA_API_KEY }
if ([string]::IsNullOrWhiteSpace($NvidiaApiKey)) {
  $secure = Read-Host -AsSecureString "Enter your NVIDIA API key (nvapi-...)"
  $bstr   = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  $NvidiaApiKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
}
if ([string]::IsNullOrWhiteSpace($NvidiaApiKey)) { throw "No NVIDIA API key provided." }

Write-Host "==> Creating $ccrDir ..."
New-Item -ItemType Directory -Force -Path $ccrDir | Out-Null

Write-Host "==> Installing strip-reasoning transformer..."
$stripSrc  = Join-Path $repoRoot "transformer\strip-reasoning.js"
$stripDest = Join-Path $ccrDir   "strip-reasoning.js"
Copy-Item -Path $stripSrc -Destination $stripDest -Force

Write-Host "==> Writing config.json (key + model + absolute transformer path)..."
$tpl = Get-Content (Join-Path $repoRoot "config\config.template.json") -Raw
$tpl = $tpl.Replace("__NVIDIA_API_KEY__", $NvidiaApiKey)
$tpl = $tpl.Replace("__NVIDIA_MODEL__", $Model)
$tpl = $tpl.Replace("__STRIP_REASONING_PATH__", ($stripDest -replace '\\','/'))
Set-Content -Path (Join-Path $ccrDir "config.json") -Value $tpl -Encoding utf8

Write-Host "==> Installing CCS settings (~/.ccs/duck.settings.json)..."
New-Item -ItemType Directory -Force -Path $ccsDir | Out-Null
$ccsTpl = Get-Content (Join-Path $repoRoot "ccs\duck.settings.template.json") -Raw
$ccsTpl = $ccsTpl.Replace("__NVIDIA_MODEL__", $Model)
Set-Content -Path (Join-Path $ccsDir "duck.settings.json") -Value $ccsTpl -Encoding utf8

Write-Host "==> Starting router..."
ccr restart

Start-Sleep -Seconds 2
Write-Host "==> Smoke test (thinking-enabled request through the router)..."
$body = @{
  model      = $Model
  max_tokens = 256
  thinking   = @{ type = "enabled"; budget_tokens = 128 }
  messages   = @(@{ role = "user"; content = "What is 17 + 25? Reply with just the number." })
} | ConvertTo-Json -Depth 6

try {
  $resp = Invoke-RestMethod -Uri "http://127.0.0.1:3456/v1/messages" -Method Post -Body $body -Headers @{
    "x-api-key"         = "local-ccr-secret"
    "anthropic-version" = "2023-06-01"
    "content-type"      = "application/json"
  }
  $text = ($resp.content | Where-Object { $_.type -eq "text" } | ForEach-Object { $_.text }) -join " "
  Write-Host ""
  Write-Host "SMOKE TEST OK -> model replied: '$($text.Trim())'" -ForegroundColor Green
} catch {
  Write-Host "SMOKE TEST FAILED: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host "Check the router log: enable `"LOG`": true in $ccrDir\config.json then 'ccr restart'."
  exit 1
}

Write-Host ""
Write-Host "Done. The router is running on http://127.0.0.1:3456"
Write-Host "Now launch CCS as usual, or run 'ccr code' for Claude Code directly."
Write-Host "After a reboot, run 'ccr start' before using either."
