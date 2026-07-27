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
# $ok = $null 代表 SKIP：環境沒裝東西，不是程式碼壞了。不併進 PASS，
# 否則就是拿綠燈蓋掉「這題根本沒驗到」。
function Set-Result($id, $ok, $note = '') {
  $results[$id] = @{ ok = $ok; note = $note }
  $label = if ($null -eq $ok) { 'SKIP' } elseif ($ok) { 'PASS' } else { 'FAIL' }
  $color = if ($null -eq $ok) { 'Yellow' } elseif ($ok) { 'Green' } else { 'Red' }
  Write-Host ("  => {0} {1}" -f $label, $note) -ForegroundColor $color
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

# T0：檔案不在就直接停。檔案讀不到時後面每一題都會倒，而且倒的理由是假的
# （T2 甚至會因為例外打斷迴圈而報綠燈）——寧可在這裡吵，不要跑完一輪騙人的表。
$missing = @($targets | Where-Object { -not (Test-Path -LiteralPath $_) })
if ($missing) {
  Write-Host ""
  Write-Host "腳本找不到，先確認 repo 根目錄算對了：" -ForegroundColor Red
  Write-Host "  推算的 repo 根目錄：$repo"
  $missing | ForEach-Object { Write-Host "  缺：$_" }
  Write-Host "  （若路徑裡多了一層 docs\，代表你跑的是舊版腳本，git pull 後重跑）" -ForegroundColor Yellow
  exit 1
}

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
  # try 包住：讀不到時若讓例外逸出，整個迴圈會斷在第一支，$noBom 停在空的 → 假 PASS
  $head = $null
  try { $head = [System.IO.File]::ReadAllBytes($t)[0..2] } catch {}
  if (-not ($head -and $head[0] -eq 0xEF -and $head[1] -eq 0xBB -and $head[2] -eq 0xBF)) {
    $noBom += (Split-Path -Leaf $t)
  }
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

# ---- T5: stdout 被導向時還改不改得到 tab ----
# 這是 hook 路徑的關鍵：hook 的 stdout 被 Claude Code 收走，改 tab 不能經過它。
# 第一輪驗證證實寫 OSC 進 \\.\CONOUT$ 開得起來但沒作用，改用 SetConsoleTitle
# （[Console]::Title）。這裡兩條都測，順便留下 CONOUT$ 的紀錄。
Show-Header T5 'SetConsoleTitle（stdout 被導向）'
$shell = (Get-Process -Id $PID).ProcessName
$titleProbe = Join-Path $env:TEMP 'verify-title.ps1'
@'
$ok = 'NONE'
try { [Console]::Title = 'T5-SETTITLE-驗證'; $ok = 'SETTITLE-OK' } catch { $ok = "SETTITLE-FAIL $_" }
"$ok"
'@ | Set-Content -LiteralPath $titleProbe -Encoding UTF8
$probeOut = Join-Path $env:TEMP 'verify-title.out'
# stdout 導到檔案 = 模擬 hook 被 Claude Code 收走 stdout 的情形
Start-Process -FilePath $shell -NoNewWindow -Wait -RedirectStandardOutput $probeOut `
  -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $titleProbe
$probeMsg = (Get-Content -Raw -ErrorAction SilentlyContinue $probeOut)
Write-Host "  子程序回報：$($probeMsg -replace '\s+$', '')"
if ($probeMsg -notmatch 'SETTITLE-OK') {
  Set-Result T5 $false 'SetConsoleTitle 就丟例外 → hook 路徑要再想'
} else {
  Ask-Eye T5 'tab 標題有變成「T5-SETTITLE-驗證」嗎？'
}
Remove-Item $titleProbe, $probeOut -Force -ErrorAction SilentlyContinue

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
# 引號要自己加：PS 5.1 的 Start-Process 不會替含空白的陣列元素補引號，
# 名字會被拆成兩個參數（第二段還會綁進 [int]$AgentPid 而失敗）。
Start-Process -FilePath 'powershell' -NoNewWindow -Wait -ArgumentList @(
  '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
  "`"$(Join-Path $repo 'installer\hooks\set-session-name.ps1')`"", "`"$testName`"", "$PID"
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
if (-not $ok8) {
  # 光看「parse 失敗」猜不出前面混進了什麼，把原始 bytes 攤開來看
  Write-Host '  --- stdout 原始內容（前 200 字元 + 前 32 bytes）---' -ForegroundColor Yellow
  Write-Host "  [$($raw.Substring(0, [Math]::Min(200, $raw.Length)))]"
  $rawBytes = @()
  try { $rawBytes = [System.IO.File]::ReadAllBytes($namerOut) } catch {}
  Write-Host "  hex: $(($rawBytes | Select-Object -First 32 | ForEach-Object { '{0:X2}' -f $_ }) -join ' ')"
}
Set-Result T8 $ok8 $note8
Remove-Item $namerOut -Force -ErrorAction SilentlyContinue
# 清掉本次測試留下的計數器，免得干擾真實 session
Remove-Item (Join-Path ([System.IO.Path]::GetTempPath()) 'claude-session-namer') -Recurse -Force -ErrorAction SilentlyContinue

# ---- T9: codex namer 的 Python + SQLite 路徑 ----
Show-Header T9 'codex namer：Python + SQLite'
# 與 codex-session-namer.ps1 同一套偵測：PATH 上有 python3.exe 不代表有 Python，
# Windows 的 Store 假殼同名同資料夾，只有真的跑一次 --version 才分得出來。
$py = $null
foreach ($c in 'py', 'python3', 'python') {
  $cmd = Get-Command $c -ErrorAction SilentlyContinue
  if (-not $cmd) { continue }
  $ver = ''
  try { $ver = (& $cmd.Source '--version' 2>&1) -join ' ' } catch {}
  Write-Host "  試 $c → $($cmd.Source)：$($ver -replace '\s+$', '')"
  if ($ver -match 'Python 3') { $py = $cmd.Source; break }
}
Write-Host "  採用：$(if ($py) { $py } else { '沒有可用的 Python' })"
$ok9 = $null; $note9 = '本機沒有可用的 Python → codex sidebar 改名這條沒驗到（tab 標題不受影響）'
if ($py) {
  # 拿一個拋棄式 db 驗 UPDATE 走得通、emoji 進得去
  $tmpDb = Join-Path $env:TEMP 'verify-codex-state.sqlite'
  Remove-Item $tmpDb -Force -ErrorAction SilentlyContinue
  $env:CODEX_DB = $tmpDb
  $env:CODEX_SID = 'verify-sid'
  $env:CODEX_TITLE = '📐 codex 命名測試'
  # 比對在 Python 裡做完只印 ASCII：stdout 是 pipe 時 Python 用系統 locale 編碼
  # （zh-TW 是 cp950），直接 print emoji 會 UnicodeEncodeError，測到的是 Python
  # 的輸出編碼而不是 SQLite 往返。
  $setup = @'
import os, sqlite3
con = sqlite3.connect(os.environ["CODEX_DB"])
con.execute("CREATE TABLE threads (id TEXT PRIMARY KEY, title TEXT, preview TEXT)")
con.execute("INSERT INTO threads VALUES ('verify-sid', 'old', 'old')")
con.execute("UPDATE threads SET title=?, preview=? WHERE id=?",
            (os.environ["CODEX_TITLE"], os.environ["CODEX_TITLE"], os.environ["CODEX_SID"]))
con.commit()
got = con.execute("SELECT title FROM threads WHERE id='verify-sid'").fetchone()[0]
print("ROUNDTRIP-OK" if got == os.environ["CODEX_TITLE"] else "MISMATCH")
con.close()
'@
  $back = ($setup | & $py - 2>&1) -join ''
  Write-Host "  Python 回報：[$back]"
  $ok9 = ($back -match 'ROUNDTRIP-OK')
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
  $label = if ($null -eq $r.ok) { 'SKIP' } elseif ($r.ok) { 'PASS' } else { 'FAIL' }
  Write-Host ("{0,-4} {1,-5} {2}" -f $k, $label, $r.note)
}
$failed = @($results.Keys | Where-Object { $null -ne $results[$_].ok -and -not $results[$_].ok })
$skipped = @($results.Keys | Where-Object { $null -eq $results[$_].ok })
Write-Host ""
if ($failed.Count -eq 0) {
  Write-Host '沒有 FAIL。' -ForegroundColor Green
} else {
  Write-Host "未通過：$($failed -join ', ')" -ForegroundColor Red
}
if ($skipped.Count -gt 0) {
  Write-Host "略過（環境沒裝，非程式碼問題）：$($skipped -join ', ')" -ForegroundColor Yellow
}
