#!/usr/bin/env pwsh
# ai-tab-sync.ps1 — Windows counterpart of ai-tab-sync.sh.
# Polls a sync file and writes OSC title escapes to the shared console.
#
# Windows has no /dev/tty, so this cannot write to a tty device. The spike
# (docs/spikes/windows-tab-title) confirmed that a separate process attached to
# the same Windows Terminal console CAN retitle the foreground tab, so the
# macOS watcher architecture carries over — only the write target changes:
# the inherited console handle instead of /dev/tty.
#
# Usage: ai-tab-sync.ps1 <sync-file> [<parent-pid>]

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$SyncFile,
  [int]$ParentPid = 0
)

# Best-effort throughout, like the bash version's `2>/dev/null || true`:
# a watcher that dies takes the tab title with it.
$ErrorActionPreference = 'Continue'

# Titles carry CJK + emoji; without this the console renders mojibake.
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false } catch {}

$ESC = [char]27
$BEL = [char]7
$lastTitle = ''

while ($true) {
  # Start-Process children outlive their parent on Windows (no EXIT trap like
  # bash), so stop polling once the launcher we serve is gone.
  if ($ParentPid -gt 0 -and -not (Get-Process -Id $ParentPid -ErrorAction SilentlyContinue)) { break }

  if (Test-Path -LiteralPath $SyncFile) {
    $title = ''
    try { $title = [System.IO.File]::ReadAllText($SyncFile, [System.Text.Encoding]::UTF8).Trim() } catch {}
    if ($title -and $title -ne $lastTitle) {
      try { [Console]::Write("$ESC]0;$title$BEL") } catch {}
      try { [Console]::Write("$ESC]1;$title$BEL") } catch {}
      try { [Console]::Write("$ESC]2;$title$BEL") } catch {}
      $lastTitle = $title
    }
  }
  Start-Sleep -Seconds 1
}
