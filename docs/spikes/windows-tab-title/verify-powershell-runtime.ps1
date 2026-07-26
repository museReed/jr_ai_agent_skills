<#
  verify-powershell-runtime.ps1
  驗 installer 的 PowerShell runtime（ai-tab-sync + 命名 hook）在 Windows 實機能不能跑。
  對照清單：docs/windows-powershell-runtime.md 末尾「待在 Windows VM 驗的事」。

  跑法：在 Windows Terminal 開 PowerShell，cd 到 repo 根目錄，然後
    powershell -NoProfile -ExecutionPolicy Bypass -File docs\spikes\windows-tab-title\verify-powershell-runtime.ps1
  PowerShell 5.1 與 7 各跑一次（powershell.exe / pwsh.exe）。

  T1-T3、T7-T9 會自己判 PASS/FAIL；T4-T6 要你用眼睛看 tab 標題，腳本會問。
#>

$ErrorActionPreference = 'Continue'
# 本檔在 <repo>\docs\spikes\windows-tab-title\ 底下，往上三層才是 repo 根目錄
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$results = [ordered]@{}

function Show-Header($id, $title) {
  Write-Host ""
  Write-Host "======== $id : $title ========" -ForegroundColor Cyan
}
function Set-Result($id, $ok, $note = '') {
  $results[$id] = @{ ok = $ok; note = $note }
  $color = if ($ok) { 'Green' } else { 'Red' }
  Write-Host ("  => {0} {1}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $note) -ForegroundColor $color
}
function Ask-Eye($id, $question) {
  $answer = Read-Host "  $question (y/n)"
  Set-Result $id ($answer -match '^[yY]') '人眼判定'
}

Write-Host "repo      : $repo"
Write-Host "PSVersion : $($PSVersionTable.PSVersion)  ($($PSVersionTable.PSEdition))"
Write-Host "WT_SESSION: $env:WT_SESSION"
Write-Host "OutputEnc : $([Console]::OutputEncoding.WebName)"

$targets = @(
  'installer\bin\ai-tab-sync.ps1'
  'installer\bin\myclaude.ps1'
  'installer\bin\mycodex.ps1'
  'installer\hooks\set-session-name.ps1'
  'installer\hooks\session-auto-namer.ps1'
  'installer\hooks\codex-session-namer.ps1'
) | ForEach-Object { Join-Path $repo $_ }

# ---- T1: 六支腳本語法都 parse 得過 ----
Show-Header T1 '語法 parse'
$badSyntax = @()
foreach ($t in $targets) {
  $errs = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile($t, [ref]$null, [ref]$errs)
  if ($errs) {
    $badSyntax += (Split-Path -Leaf $t)
    Write-Host "  $(Split-Path -Leaf $t):" -ForegroundColor Red
    $errs | ForEach-Object { Write-Host "    $($_.Extent.StartLineNumber): $($_.Message)" }
  }
}
Set-Result T1 ($badSyntax.Count -eq 0) $(if ($badSyntax) { "壞掉：$($badSyntax -join ', ')" } else { '6/6 通過' })

# ---- T2: 每支都有 UTF-8 BOM（5.1 沒 BOM 會把中文讀成亂碼）----
Show-Header T2 'UTF-8 BOM'
$noBom = @()
foreach ($t in $targets) {
  $head = [System.IO.File]::ReadAllBytes($t)[0..2]
  if (-not ($head[0] -eq 0xEF -and $head[1] -eq 0xBB -and $head[2] -eq 0xBF)) { $noBom += (Split-Path -Leaf $t) }
}
Set-Result T2 ($noBom.Count -eq 0) $(if ($noBom) { "缺 BOM：$($noBom -join ', ')" } else { '6/6 有 BOM' })

# ---- T3: 中文字面值在本 PowerShell 版本讀進來沒亂碼 ----
# 直接驗 T2 的後果：把 namer 腳本讀進來找一段中文，比對字元。
Show-Header T3 '中文字面值不亂碼'
$namerText = Get-Content -Raw -Encoding UTF8 (Join-Path $repo 'installer\hooks\session-auto-namer.ps1')
Set-Result T3 ($namerText -match '命名規則') '在 namer 腳本裡找到「命名規則」四個字'

# ---- T4: 程序祖先鏈（回答 hook 的 parent 是不是 claude 本身）----
Show-Header T4 '程序祖先鏈'
$cur = $PID
for ($i = 0; $i -lt 5 -and $cur -gt 0; $i++) {
  $p = Get-CimInstance Win32_Process -Filter "ProcessId=$cur" -ErrorAction SilentlyContinue
  if (-not $p) { break }
  Write-Host ("  [{0}] pid={1,-7} {2}" -f $i, $p.ProcessId, $p.Name)
  $cur = [int]$p.ParentProcessId
}
Write-Host "  ↑ 這是「直接跑腳本」的鏈。真正要看的是 Claude Code spawn hook 時的鏈——"
Write-Host "    等 hook 裝好後看 ~/.claude/session-names/ 裡的檔名 pid 對不對得上 terminal。"
Set-Result T4 $true '僅記錄，無自動判定'

# ---- T5: \\.\CONOUT$ 在 stdout 被導向時還改得到 tab ----
# 這是 hook 路徑的關鍵：hook 的 stdout 是 pipe，OSC 必須繞過它直達 console 裝置。
Show-Header T5 'CONOUT$（stdout 被導向）'
$conoutProbe = Join-Path $env:TEMP 'verify-conout.ps1'
@'
$payload = ([char]27) + "]0;T5-CONOUT-驗證" + ([char]7)
$bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
$fs = [System.IO.File]::Open('\\.\CONOUT$', [System.IO.FileMode]::Open,
                             [System.IO.FileAccess]::Write, [System.IO.FileShare]::ReadWrite)
try { $fs.Write($bytes, 0, $bytes.Length); $fs.Flush() } finally { $fs.Dispose() }
"CONOUT-OPENED-OK"
'@ | Set-Content -LiteralPath $conoutProbe -Encoding UTF8
$probeOut = Join-Path $env:TEMP 'verify-conout.out'
$shell = (Get-Process -Id $PID).ProcessName
# stdout 導到檔案 = 模擬 hook 被 Claude Code 收走 stdout 的情形
Start-Process -FilePath $shell -NoNewWindow -Wait -RedirectStandardOutput $probeOut `
  -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $conoutProbe
$opened = (Get-Content -Raw -ErrorAction SilentlyContinue $probeOut) -match 'CONOUT-OPENED-OK'
Write-Host "  CONOUT$ 開啟成功：$opened"
if (-not $opened) {
  Set-Result T5 $false 'CONOUT$ 開不起來 → hook 路徑要改別的寫法'
} else {
  Ask-Eye T5 'tab 標題有變成「T5-CONOUT-驗證」嗎？'
}
Remove-Item $conoutProbe, $probeOut -Force -ErrorAction SilentlyContinue

# ---- T6: watcher 全鏈（emoji + 中文 + 孤兒自清）----
Show-Header T6 'ai-tab-sync watcher'
$syncFile = Join-Path $env:TEMP 'verify-tabsync.txt'
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($syncFile, '(等待命名)', $utf8)
$watcher = Join-Path $repo 'installer\bin\ai-tab-sync.ps1'
$w = Start-Process -FilePath $shell -PassThru -NoNewWindow -ArgumentList @(
  '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $watcher, $syncFile, "$PID"
)
Start-Sleep -Seconds 2
[System.IO.File]::WriteAllText($syncFile, '🏗️ 改寫 PowerShell', $utf8)
Write-Host '  已寫入「🏗️ 改寫 PowerShell」，盯 tab 看 3 秒...'
Start-Sleep -Seconds 3
Ask-Eye T6 'tab 標題有變成「🏗️ 改寫 PowerShell」（emoji 跟中文都對）嗎？'

# 孤兒自清：假父 pid 指向一個不存在的程序 → watcher 應自己退出
$ghost = Start-Process -FilePath $shell -PassThru -NoNewWindow -ArgumentList @(
  '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $watcher, $syncFile, '999999'
)
Start-Sleep -Seconds 3
$ghostGone = $ghost.HasExited
if (-not $ghostGone) { try { $ghost.Kill() } catch {} }
Set-Result T6b $ghostGone '父程序不存在時 watcher 自己退出'
if ($w -and -not $w.HasExited) { try { $w.Kill() } catch {} }
Remove-Item $syncFile -Force -ErrorAction SilentlyContinue

# ---- T7: set-session-name.ps1 —— emoji 走命令列會不會亂碼 ----
Show-Header T7 'set-session-name.ps1 命令列編碼'
$testName = '🔧 命令列編碼測試'
$env:AI_TAB_SYNC_FILE = Join-Path $env:TEMP 'verify-setname-sync.txt'
& (Join-Path $repo 'installer\hooks\set-session-name.ps1') $testName $PID
$syncBack = ''
try { $syncBack = [System.IO.File]::ReadAllText($env:AI_TAB_SYNC_FILE, [System.Text.Encoding]::UTF8) } catch {}
Write-Host "  同進程呼叫寫回：[$syncBack]"
$inProc = ($syncBack -eq $testName)

# 再走一次「模型實際會用的形式」：另一個 powershell.exe 帶命令列參數
$env:AI_TAB_SYNC_FILE = Join-Path $env:TEMP 'verify-setname-cli.txt'
Start-Process -FilePath 'powershell' -NoNewWindow -Wait -ArgumentList @(
  '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
  (Join-Path $repo 'installer\hooks\set-session-name.ps1'), $testName, "$PID"
)
$cliBack = ''
try { $cliBack = [System.IO.File]::ReadAllText($env:AI_TAB_SYNC_FILE, [System.Text.Encoding]::UTF8) } catch {}
Write-Host "  跨程序命令列寫回：[$cliBack]"
Set-Result T7 ($inProc -and $cliBack -eq $testName) "同進程=$inProc 跨程序=$($cliBack -eq $testName)"
Remove-Item (Join-Path $env:TEMP 'verify-setname-sync.txt'), (Join-Path $env:TEMP 'verify-setname-cli.txt') `
  -Force -ErrorAction SilentlyContinue
$env:AI_TAB_SYNC_FILE = $null

# ---- T8: session-auto-namer.ps1 吐的 JSON 合法且中文完整 ----
Show-Header T8 'session-auto-namer.ps1 JSON 輸出'
$namerOut = Join-Path $env:TEMP 'verify-namer.json'
Start-Process -FilePath $shell -NoNewWindow -Wait -RedirectStandardOutput $namerOut -ArgumentList @(
  '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
  (Join-Path $repo 'installer\hooks\session-auto-namer.ps1'), 'prompt'
)
$raw = ''
try { $raw = [System.IO.File]::ReadAllText($namerOut, [System.Text.Encoding]::UTF8) } catch {}
$ok8 = $false; $note8 = 'stdout 空的'
if ($raw) {
  try {
    $ctx = ($raw | ConvertFrom-Json).hookSpecificOutput.additionalContext
    $ok8 = ($ctx -match '命名規則') -and ($ctx -match 'set-session-name\.ps1') -and ($ctx -match '🏗')
    $note8 = "JSON 合法，中文/emoji/指令齊全=$ok8"
    Write-Host "  additionalContext 前 120 字：$($ctx.Substring(0, [Math]::Min(120, $ctx.Length)))"
  } catch { $note8 = "JSON parse 失敗：$($_.Exception.Message)" }
}
Set-Result T8 $ok8 $note8
Remove-Item $namerOut -Force -ErrorAction SilentlyContinue
# 清掉本次測試留下的計數器，免得干擾真實 session
Remove-Item (Join-Path ([System.IO.Path]::GetTempPath()) 'claude-session-namer') -Recurse -Force -ErrorAction SilentlyContinue

# ---- T9: codex namer 的 Python + SQLite 路徑 ----
Show-Header T9 'codex namer：Python + SQLite'
$py = $null
foreach ($c in 'py', 'python3', 'python') {
  $cmd = Get-Command $c -ErrorAction SilentlyContinue
  if ($cmd) { $py = $cmd.Source; break }
}
Write-Host "  Python：$(if ($py) { $py } else { '找不到' })"
$ok9 = $false; $note9 = '沒有 Python'
if ($py) {
  # 拿一個拋棄式 db 驗 UPDATE 走得通、emoji 進得去
  $tmpDb = Join-Path $env:TEMP 'verify-codex-state.sqlite'
  Remove-Item $tmpDb -Force -ErrorAction SilentlyContinue
  $env:CODEX_DB = $tmpDb
  $env:CODEX_SID = 'verify-sid'
  $env:CODEX_TITLE = '📐 codex 命名測試'
  $setup = @'
import os, sqlite3
con = sqlite3.connect(os.environ["CODEX_DB"])
con.execute("CREATE TABLE threads (id TEXT PRIMARY KEY, title TEXT, preview TEXT)")
con.execute("INSERT INTO threads VALUES ('verify-sid', 'old', 'old')")
con.execute("UPDATE threads SET title=?, preview=? WHERE id=?",
            (os.environ["CODEX_TITLE"], os.environ["CODEX_TITLE"], os.environ["CODEX_SID"]))
con.commit()
print(con.execute("SELECT title FROM threads WHERE id='verify-sid'").fetchone()[0])
con.close()
'@
  $back = ($setup | & $py -) 2>$null
  Write-Host "  SQLite 讀回：[$back]"
  $ok9 = ($back -eq $env:CODEX_TITLE)
  $note9 = "UPDATE + emoji 往返=$ok9"
  Remove-Item $tmpDb -Force -ErrorAction SilentlyContinue
}
Set-Result T9 $ok9 $note9

# ---- 總結 ----
Write-Host ""
Write-Host "======== 總結（貼回 handoff / issue）========" -ForegroundColor Cyan
Write-Host "PSVersion: $($PSVersionTable.PSVersion)"
foreach ($k in $results.Keys) {
  $r = $results[$k]
  Write-Host ("{0,-4} {1,-5} {2}" -f $k, $(if ($r.ok) { 'PASS' } else { 'FAIL' }), $r.note)
}
$failed = @($results.Keys | Where-Object { -not $results[$_].ok })
Write-Host ""
if ($failed.Count -eq 0) {
  Write-Host '全數通過。' -ForegroundColor Green
} else {
  Write-Host "未通過：$($failed -join ', ')" -ForegroundColor Red
}
