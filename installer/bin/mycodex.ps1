#!/usr/bin/env pwsh
# mycodex.ps1 — Windows counterpart of the `mycodex` bash launcher.
# 1. Creates a per-session sync file and sets $env:AI_TAB_SYNC_FILE
# 2. Starts a background watcher (poll sync file → OSC to the shared console)
# 3. Launches codex (inherits $env:AI_TAB_SYNC_FILE; the session-namer hook writes it)
#
# PowerShell does not run bare `.ps1` files off PATH (`.PS1` is not in PATHEXT),
# so the profile wraps this in a function:
#   function mycodex { & "$HOME\.local\bin\mycodex.ps1" @args }
#
# Usage: mycodex.ps1 [any codex args]

[CmdletBinding()]
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$CodexArgs)

$ErrorActionPreference = 'Stop'

# -CommandType Application is load-bearing: the profile defines a `codex`
# function that shadows the real binary, and a bare Get-Command would resolve to
# that function and recurse forever. Only ever launch a real executable here.
$codexCmd = Get-Command codex -CommandType Application -ErrorAction SilentlyContinue |
            Select-Object -First 1
if (-not $codexCmd) {
  Write-Error 'codex 執行檔不在 PATH 上，無法啟動。'
  exit 127
}
$codexBin = $codexCmd.Source

$watcher = Join-Path $HOME '.local\bin\ai-tab-sync.ps1'
$syncDir = Join-Path $HOME '.ai-session-names'

# No console to retitle (piped / non-interactive host) or no watcher installed
# → run codex straight through, same as the bash `exec` fallback.
$hasConsole = $true
try { [void][Console]::WindowWidth } catch { $hasConsole = $false }
if (-not $hasConsole -or -not (Test-Path -LiteralPath $watcher)) {
  & $codexBin @CodexArgs
  exit $LASTEXITCODE
}

New-Item -ItemType Directory -Force -Path $syncDir | Out-Null
$syncFile = Join-Path $syncDir "$PID.txt"
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($syncFile, '(等待命名)', $utf8)
$env:AI_TAB_SYNC_FILE = $syncFile

# -NoNewWindow keeps the watcher attached to this console, which is what lets it
# write OSC to the foreground tab (spike TEST 5).
$watcherProc = Start-Process -FilePath 'powershell' -PassThru -NoNewWindow -ArgumentList @(
  '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $watcher, $syncFile, "$PID"
)

try {
  & $codexBin @CodexArgs
} finally {
  if ($watcherProc -and -not $watcherProc.HasExited) {
    try { $watcherProc.Kill() } catch {}
  }
  Remove-Item -LiteralPath $syncFile -Force -ErrorAction SilentlyContinue
}
