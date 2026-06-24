# CCS + Claude Code → NVIDIA NIM (minimax) via claude-code-router

Lets **CCS / Claude Code** use models hosted on **NVIDIA NIM**
(`minimaxai/minimax-m2.7`, `minimaxai/minimax-m3`) — which only expose an
OpenAI-compatible endpoint — by putting a protocol-translating proxy in between.

## The problem

| Endpoint | Protocol | Used by |
|---|---|---|
| `https://integrate.api.nvidia.com/v1/chat/completions` | **OpenAI** | opencode (works) |
| `…/v1/messages` | **Anthropic** | Claude Code / CCS |

NVIDIA NIM does **not** speak the Anthropic Messages API, so pointing
`ANTHROPIC_BASE_URL` straight at NVIDIA fails with `model … may not exist`
(really a 404 on `/v1/messages`). On top of that, Claude Code sends a
`reasoning` parameter when thinking is enabled, which NVIDIA rejects with
`400 Unsupported parameter(s): reasoning`.

## The solution

[claude-code-router](https://github.com/musistudio/claude-code-router) (CCR)
runs locally, accepts the Anthropic Messages API, and translates it to OpenAI
for NVIDIA. A small transformer (`strip-reasoning`) removes the unsupported
`reasoning` parameter.

```
CCS / Claude Code  --(Anthropic API)-->  CCR :3456  --(OpenAI API)-->  NVIDIA NIM
                                          └─ strip-reasoning transformer
```

## Requirements

- Node.js + npm
- An NVIDIA API key (`nvapi-...`) — get one at https://build.nvidia.com
- CCS installed (reads `~/.ccs/*.settings.json`)

## Install (Windows)

```powershell
git clone <repo-url> claude-code-nvidia-router
cd claude-code-nvidia-router
powershell -ExecutionPolicy Bypass -File scripts/install.ps1
# or pass the key directly:
# powershell -ExecutionPolicy Bypass -File scripts/install.ps1 -NvidiaApiKey "nvapi-XXXX"
```

The script: installs CCR globally → copies the transformer and generates
`~/.claude-code-router/config.json` (with your key injected) → copies
`~/.ccs/duck.settings.json` → starts the router → runs a smoke test.

> The API key is written **only** to `~/.claude-code-router/config.json`
> (outside this repo). `config/config.json` and `*.local.json` are gitignored,
> so the key is never committed.

## Usage

Launch CCS as usual. Requests now flow through the router to minimax.

- **After a reboot**: the router does not auto-start → run `ccr start`.
- Change the default model: edit `Router.default` in
  `~/.claude-code-router/config.json`, then `ccr restart`.
- Check status: `ccr status`.
- Debug: set `"LOG": true` in the config → `ccr restart` → see logs under
  `~/.claude-code-router/`.

## Using Claude Code directly (without CCS)

CCS is just an opt-in launcher (it reads `duck.settings.json`, sets the env, then
runs Claude Code). If you don't use CCS, CCR ships its own launcher — **no extra
config files needed**:

```powershell
ccr code                       # interactive session through the router -> minimax
ccr code "Write a hello world" # one-shot prompt
```

`ccr code` points `claude` at the local router for that session only. Running
plain `claude` elsewhere keeps using your normal Anthropic models. (Requires the
`claude` CLI on PATH; `ccr code` auto-starts the router if it isn't running.)

> Avoid putting `ANTHROPIC_BASE_URL` in the global `~/.claude/settings.json` —
> that would route **every** Claude Code session (including Opus/Sonnet) through
> NVIDIA, which is usually not what you want. Prefer `ccr code` or CCS for opt-in.

## Auto-start on Windows login (optional)

Create a scheduled task that runs `ccr start` at logon:

```powershell
$action  = New-ScheduledTaskAction -Execute "ccr" -Argument "start"
$trigger = New-ScheduledTaskTrigger -AtLogOn
Register-ScheduledTask -TaskName "ccr-autostart" -Action $action -Trigger $trigger
```

## Uninstall

```powershell
powershell -ExecutionPolicy Bypass -File scripts/uninstall.ps1            # keep the npm package
powershell -ExecutionPolicy Bypass -File scripts/uninstall.ps1 -RemovePackage
```

## Repo layout

```
config/config.template.json    # CCR config template (key = placeholder)
transformer/strip-reasoning.js # drops the `reasoning` param for NVIDIA
ccs/duck.settings.json         # CCS settings pointing at the router
scripts/install.ps1            # install + configure + smoke test
scripts/uninstall.ps1          # tear down
.gitignore                     # prevents committing a config that holds the key
```
