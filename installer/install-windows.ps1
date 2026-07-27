#!/usr/bin/env pwsh
<#
  install-windows.ps1 — Windows/PowerShell 版安裝器，對照 install.sh。
  只裝 auto-rename 這條線（watcher + wrapper + 命名 hook + 三個 skill）；
  context-monitor 尚未移植，editor 偵測 Windows 上不適用。

  用法：
    powershell -NoProfile -ExecutionPolicy Bypass -File installer\install-windows.ps1
    powershell ... -File installer\install-windows.ps1 -Target codex
#>

[CmdletBinding()]
param([ValidateSet('claude', 'codex', 'both')][string]$Target = 'both')

$ErrorActionPreference = 'Stop'
$src = $PSScriptRoot
# .ps1 / SKILL.md 要 BOM：PS 5.1 沒 BOM 會用系統 ANSI codepage 讀中文。
# JSON 相反，一定不能有 BOM：Claude Code / Codex 是 Node，JSON.parse 吃到 BOM 直接丟例外。
$utf8Bom = New-Object System.Text.UTF8Encoding $true
$utf8NoBom = New-Object System.Text.UTF8Encoding $false

# ConvertFrom-Json -AsHashtable 是 PS 6+ 才有，PS 5.1 只能拿到 PSCustomObject，
# 而 PSCustomObject 沒辦法像 hashtable 那樣動態塞 key。手動攤平。
function ConvertTo-Hashtable($obj) {
  if ($null -eq $obj) { return $null }
  if ($obj -is [System.Collections.IDictionary]) { return $obj }
  if ($obj -is [System.Collections.IEnumerable] -and $obj -isnot [string]) {
    return , @($obj | ForEach-Object { ConvertTo-Hashtable $_ })
  }
  if ($obj -is [System.Management.Automation.PSCustomObject]) {
    $h = @{}
    foreach ($p in $obj.PSObject.Properties) { $h[$p.Name] = ConvertTo-Hashtable $p.Value }
    return $h
  }
  return $obj
}

function Install-File($from, $to) {
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $to) | Out-Null
  if (Test-Path -LiteralPath $to) { Copy-Item -LiteralPath $to "$to.bak" -Force }
  Copy-Item -LiteralPath $from -Destination $to -Force
  Write-Host "  installed: $to"
}

# hooks.json / settings.json 的 hook 註冊：先清掉我們自己的舊條目再加，
# 免得重跑安裝時同一支 hook 被登記兩次。
function Register-Hook($configPath, $marker, $entries) {
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $configPath) | Out-Null
  $cfg = [ordered]@{}
  if (Test-Path -LiteralPath $configPath) {
    Copy-Item -LiteralPath $configPath "$configPath.bak" -Force
    $raw = [System.IO.File]::ReadAllText($configPath, [System.Text.Encoding]::UTF8)
    if ($raw.Trim()) { $cfg = ConvertTo-Hashtable ($raw | ConvertFrom-Json) }
  }
  if (-not $cfg.hooks) { $cfg.hooks = @{} }
  foreach ($e in $entries) {
    $event = $e.event
    $existing = @()
    if ($cfg.hooks[$event]) {
      $existing = @($cfg.hooks[$event] | ForEach-Object {
        $kept = @($_.hooks | Where-Object { $_.command -notlike "*$marker*" })
        if ($kept.Count) { @{ hooks = $kept } }
      } | Where-Object { $_ })
    }
    $existing += @{ hooks = @(@{ type = 'command'; command = $e.command; timeout = 3 }) }
    $cfg.hooks[$event] = $existing
  }
  [System.IO.File]::WriteAllText($configPath, ($cfg | ConvertTo-Json -Depth 10), $utf8NoBom)
  Write-Host "  registered: $configPath"
}

# --- 1. 共用顯示層 ---
Write-Host '[1/4] 顯示層（wrapper + watcher）→ ~\.local\bin'
Install-File "$src\bin\ai-tab-sync.ps1" "$HOME\.local\bin\ai-tab-sync.ps1"
if ($Target -ne 'codex') { Install-File "$src\bin\myclaude.ps1" "$HOME\.local\bin\myclaude.ps1" }
if ($Target -ne 'claude') { Install-File "$src\bin\mycodex.ps1" "$HOME\.local\bin\mycodex.ps1" }

# --- 2. Claude Code ---
if ($Target -ne 'codex') {
  Write-Host '[2/4] Claude Code：hooks + skills'
  Install-File "$src\hooks\set-session-name.ps1" "$HOME\.claude\hooks\set-session-name.ps1"
  Install-File "$src\hooks\session-auto-namer.ps1" "$HOME\.claude\hooks\session-auto-namer.ps1"

  foreach ($skill in 'auto-rename', 'handoff', 'structured-questions') {
    $dst = "$HOME\.claude\skills\$skill"
    New-Item -ItemType Directory -Force -Path $dst | Out-Null
    Copy-Item -Path "$src\skills\claude\$skill\*" -Destination $dst -Recurse -Force
    Write-Host "  installed: $dst\"
  }

  # /auto-rename 的手動指令是 bash 寫法（$HOME 路徑 + $PPID），Windows 上兩者都不成立。
  # 換成同進程呼叫 .ps1：路徑寫絕對值（allowlist 不展開 $HOME），且同進程執行時
  # 腳本看到的 $PID 就是模型 shell 本身，往上一層正好是 claude——與 hook 自動命名同層。
  $skillMd = "$HOME\.claude\skills\auto-rename\SKILL.md"
  $setName = "$HOME\.claude\hooks\set-session-name.ps1"
  $md = [System.IO.File]::ReadAllText($skillMd, [System.Text.Encoding]::UTF8)
  $psBlock = '```powershell' + "`n& `"$setName`" '{名稱}'`n" + '```'
  $md = $md -replace '(?s)```bash\r?\n\$HOME/\.claude/hooks/set-session-name\.sh.*?```', $psBlock
  $md = $md -replace '(?s)`\$PPID` 當第二個參數.*?行為一致）。',
       '同進程呼叫，腳本自己往上找 parent 解析出 claude 與 terminal PID，與 hook 自動命名走同一支腳本、行為一致。'
  [System.IO.File]::WriteAllText($skillMd, $md, $utf8Bom)
  Write-Host '  patched: auto-rename SKILL.md → PowerShell 指令'

  $namer = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$HOME\.claude\hooks\session-auto-namer.ps1`""
  Register-Hook "$HOME\.claude\settings.json" 'session-auto-namer.ps1' @(
    @{ event = 'PostToolUse'; command = $namer }
    @{ event = 'UserPromptSubmit'; command = "$namer prompt" }
  )
}

# --- 3. Codex ---
if ($Target -ne 'claude') {
  Write-Host '[3/4] Codex：hooks'
  Install-File "$src\hooks\codex-session-namer.ps1" "$HOME\.codex\hooks\codex-session-namer.ps1"
  $cnamer = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$HOME\.codex\hooks\codex-session-namer.ps1`""
  Register-Hook "$HOME\.codex\hooks.json" 'codex-session-namer.ps1' @(
    @{ event = 'PostToolUse'; command = $cnamer }
    @{ event = 'UserPromptSubmit'; command = "$cnamer prompt" }
  )
}

# --- 4. Profile wrapper functions ---
Write-Host '[4/4] $PROFILE wrapper functions'
$profilePath = $PROFILE.CurrentUserAllHosts
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $profilePath) | Out-Null
$profileText = ''
if (Test-Path -LiteralPath $profilePath) {
  $profileText = [System.IO.File]::ReadAllText($profilePath, [System.Text.Encoding]::UTF8)
}
# .ps1 不在 PATHEXT 裡，所以不能直接當指令用，要用 function 包一層
$block = @"
# >>> jr_ai_agent_skills >>>
function myclaude { & "`$HOME\.local\bin\myclaude.ps1" @args }
function mycodex  { & "`$HOME\.local\bin\mycodex.ps1"  @args }
# <<< jr_ai_agent_skills <<<
"@
if ($profileText -notmatch '>>> jr_ai_agent_skills >>>') {
  [System.IO.File]::WriteAllText($profilePath, ($profileText.TrimEnd() + "`n`n" + $block + "`n"), $utf8Bom)
  Write-Host "  appended: $profilePath"
} else {
  Write-Host "  already present: $profilePath"
}

Write-Host ''
Write-Host '完成。開一個新的 Windows Terminal 分頁，然後用 myclaude 啟動。' -ForegroundColor Green
