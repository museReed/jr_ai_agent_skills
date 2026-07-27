#!/usr/bin/env pwsh
# set-session-name.ps1 — Windows counterpart of set-session-name.sh.
# Single entry point for session naming, called by both:
#   - session-auto-namer.ps1 (hook-injected WRITE_CMD)
#   - auto-rename skill (manual /auto-rename)
#
# Usage: set-session-name.ps1 '{emoji} {name}' <agent-pid>
#
# PID semantics: the caller passes the AGENT process id (the claude process),
# because this script sits one process layer deeper than the hook that computed
# it. The pid only keys the ~/.claude/session-names record file — the tab title
# itself goes to the console device and does not depend on it, so a wrong pid
# misfiles the record but never breaks the rename.

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Name,
  [int]$AgentPid = 0
)

$ErrorActionPreference = 'Continue'
$utf8 = New-Object System.Text.UTF8Encoding $false

function Get-ParentPid([int]$ProcessId) {
  if ($ProcessId -le 0) { return 0 }
  try {
    $p = Get-CimInstance Win32_Process -Filter "ProcessId=$ProcessId" -ErrorAction Stop
    return [int]$p.ParentProcessId
  } catch { return 0 }
}

function Write-ConsoleTitle([string]$Text) {
  # SetConsoleTitle, not OSC. A hook's stdout is a pipe Claude Code captures, so
  # OSC written there never reaches the terminal — and VM verification (T5)
  # showed OSC written to the \\.\CONOUT$ device opens fine but retitles nothing.
  # [Console]::Title goes through SetConsoleTitle instead, which bypasses stdout
  # entirely and works cross-process (spike TEST 1/4).
  try { [Console]::Title = $Text; return } catch {}
  # Fallback for hosts without a console title (stdout must be the console).
  try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false } catch {}
  try { [Console]::Write(([char]27) + "]0;$Text" + ([char]7)) } catch {}
}

if ($AgentPid -le 0) { $AgentPid = Get-ParentPid $PID }
$terminalPid = Get-ParentPid $AgentPid

$namesDir = Join-Path $HOME '.claude\session-names'
New-Item -ItemType Directory -Force -Path $namesDir | Out-Null
[System.IO.File]::WriteAllText((Join-Path $namesDir "$terminalPid.txt"), $Name, $utf8)

if ($env:AI_TAB_SYNC_FILE) {
  # myclaude wrapper: watcher owns the tab, just write the sync file
  try { [System.IO.File]::WriteAllText($env:AI_TAB_SYNC_FILE, $Name, $utf8) } catch {}
} else {
  # no wrapper: write OSC title straight to the console device
  Write-ConsoleTitle $Name
}

$marker = Join-Path ([System.IO.Path]::GetTempPath()) "claude-session-namer\$AgentPid.default"
Remove-Item -LiteralPath $marker -Force -ErrorAction SilentlyContinue
