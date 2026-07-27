#!/usr/bin/env pwsh
<#
  install-windows.ps1 — Windows/PowerShell 版安裝器，對照 install.sh。
  裝 watcher + wrapper + 命名 hook + context-monitor + 三個 skill；
  editor 偵測 Windows 上不適用，不含。

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
  Install-File "$src\hooks\context-monitor.ps1" "$HOME\.claude\hooks\context-monitor.ps1"
  # context-monitor 靠這份快取查每個 model 的真實 context window，避免把 1M 模型當 200k。
  # 只在缺檔時種下，不覆蓋本機已 populated 的版本。
  if (-not (Test-Path -LiteralPath "$HOME\.claude\model-context-windows-cache.json")) {
    Install-File "$src\model-context-windows-cache.json" "$HOME\.claude\model-context-windows-cache.json"
  }

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

  # handoff 的 Step 5 把整套命名邏輯用 bash 內聯了一遍（ps -o ppid、/dev/tty、
  # /tmp marker）。Windows 上沒有一個成立 —— 而 set-session-name.ps1 本來就做完
  # 同樣的事，所以直接呼叫它，不要再維護第二份。
  $handoffMd = "$HOME\.claude\skills\handoff\SKILL.md"
  if (Test-Path -LiteralPath $handoffMd) {
    $hm = [System.IO.File]::ReadAllText($handoffMd, [System.Text.Encoding]::UTF8)
    $hmBlock = '```powershell' + "`n& `"$setName`" '📦 {topic}'`n" + '```'
    $hm = $hm -replace '(?s)```bash\r?\nTERMINAL_PID=.*?```', $hmBlock
    $hm = $hm -replace '(?s)⚠️ 不要把 OSC 印到 stdout.*?直寫 tty device。',
         '改名一律呼叫 set-session-name.ps1：它自己判斷要寫 tab-sync 檔（有 wrapper）還是 SetConsoleTitle（無 wrapper），並清掉 default marker。'
    [System.IO.File]::WriteAllText($handoffMd, $hm, $utf8Bom)
    Write-Host '  patched: handoff SKILL.md → PowerShell 指令'
  }

  $namer = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$HOME\.claude\hooks\session-auto-namer.ps1`""
  Register-Hook "$HOME\.claude\settings.json" 'session-auto-namer.ps1' @(
    @{ event = 'PostToolUse'; command = $namer }
    @{ event = 'UserPromptSubmit'; command = "$namer prompt" }
  )
  $monitor = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$HOME\.claude\hooks\context-monitor.ps1`""
  Register-Hook "$HOME\.claude\settings.json" '\context-monitor.ps1' @(
    @{ event = 'PostToolUse'; command = $monitor }
  )
}

# --- 3. Codex ---
if ($Target -ne 'claude') {
  Write-Host '[3/4] Codex：hooks + skills'
  Install-File "$src\hooks\codex-session-namer.ps1" "$HOME\.codex\hooks\codex-session-namer.ps1"
  Install-File "$src\hooks\codex-context-monitor.ps1" "$HOME\.codex\hooks\codex-context-monitor.ps1"

  # Codex 讀 ~/.agents/skills（不是 ~/.claude/skills），且三個 skill 共用 _shared
  foreach ($skill in 'auto-rename', 'handoff', 'structured-questions', '_shared') {
    $dst = "$HOME\.agents\skills\$skill"
    New-Item -ItemType Directory -Force -Path $dst | Out-Null
    Copy-Item -Path "$src\skills\codex\$skill\*" -Destination $dst -Recurse -Force
    Write-Host "  installed: $dst\"
  }

  # 手動命名的指令寫的是 bash：mkdir -p /tmp/... 加 ${PPID}。Windows 上兩者都不成立，
  # 而且 relay 檔現在以 session_id 命名、模型自己算不出來——所以改成「沿用 hook
  # 先前訊息裡給的那個路徑」，那是唯一可靠的來源。
  $psRelay = @'
```powershell
# 沿用 hook 先前訊息裡給的 .pending 路徑（模型無法自行推導 session_id）
Set-Content -LiteralPath '<hook 給的路徑>' -Value '{emoji} {名稱}' -Encoding utf8
```
'@
  foreach ($md in "$HOME\.agents\skills\auto-rename\SKILL.md",
                  "$HOME\.agents\skills\handoff\SKILL.md",
                  "$HOME\.agents\skills\_shared\codex-session-rename.md") {
    if (-not (Test-Path -LiteralPath $md)) { continue }
    $text = [System.IO.File]::ReadAllText($md, [System.Text.Encoding]::UTF8)
    $text = $text -replace '(?s)```bash\r?\n[^`]*?mkdir -p /tmp/codex-session-namer[^`]*?```', $psRelay
    $text = $text -replace '\$\{PPID\}\.pending', 'hook 給的 .pending 路徑'
    [System.IO.File]::WriteAllText($md, $text, $utf8Bom)
    Write-Host "  patched: $md"
  }

  $cnamer = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$HOME\.codex\hooks\codex-session-namer.ps1`""
  Register-Hook "$HOME\.codex\hooks.json" 'codex-session-namer.ps1' @(
    @{ event = 'PostToolUse'; command = $cnamer }
    @{ event = 'UserPromptSubmit'; command = "$cnamer prompt" }
  )
  $cmonitor = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$HOME\.codex\hooks\codex-context-monitor.ps1`""
  Register-Hook "$HOME\.codex\hooks.json" 'codex-context-monitor.ps1' @(
    @{ event = 'PostToolUse'; command = $cmonitor }
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
# .ps1 不在 PATHEXT 裡，所以不能直接當指令用，要用 function 包一層。
# claude / codex 直接被同名 function 遮蔽（PowerShell 解析順序 function 先於
# application），學生照常打 claude 就會走 wrapper，不必記 myclaude。
# wrapper 內部要過濾掉 function 才不會解析到這裡而無限遞迴，且必須連
# ExternalScript 一起收——npm 把 claude 裝成 claude.ps1，不是 .exe。
$block = @"
# >>> jr_ai_agent_skills >>>
function myclaude { & "`$HOME\.local\bin\myclaude.ps1" @args }
function mycodex  { & "`$HOME\.local\bin\mycodex.ps1"  @args }
function claude   { & "`$HOME\.local\bin\myclaude.ps1" @args }
function codex    { & "`$HOME\.local\bin\mycodex.ps1"  @args }
# 要繞過 wrapper 跑原生指令：
#   & (Get-Command claude -All | Where-Object { `$_.CommandType -in 'Application','ExternalScript' } | Select-Object -First 1).Source
# <<< jr_ai_agent_skills <<<
"@
# 整段換掉而不是「已存在就跳過」——舊安裝留下的舊 function 定義不會自己更新。
$marker = '(?s)# >>> jr_ai_agent_skills >>>.*?# <<< jr_ai_agent_skills <<<'
if ($profileText -match $marker) {
  $profileText = [regex]::Replace($profileText, $marker, $block.Replace('$', '$$'))
  Write-Host "  updated: $profilePath"
} else {
  $profileText = $profileText.TrimEnd() + "`n`n" + $block + "`n"
  Write-Host "  appended: $profilePath"
}
[System.IO.File]::WriteAllText($profilePath, $profileText, $utf8Bom)

Write-Host ''
Write-Host '完成。開一個新的 Windows Terminal 分頁，直接打 claude 或 codex 即可（已由 wrapper 接手）。' -ForegroundColor Green
