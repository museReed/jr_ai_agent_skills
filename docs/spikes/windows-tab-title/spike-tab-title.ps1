<#
  spike-tab-title.ps1
  目的：驗證「在 Windows 上能不能自動改 terminal tab 名」。
  對照 macOS 版做法：背景 watcher 直接 printf OSC 到 /dev/tty。
  Windows 沒有 /dev/tty，所以要測三條替代路徑通不通。

  跑法：在「Windows Terminal」和「VS Code 整合終端」各開一個 PowerShell，
        分別在 PowerShell 7 (pwsh) 和 Windows PowerShell 5.1 各跑一次。
        跑完把畫面 tab 標題變化記到 SPIKE-CHECKLIST.md。
#>

$ESC = [char]27
$BEL = [char]7

function Show-Header($n, $title) {
  Write-Host ""
  Write-Host "======== TEST $n : $title ========" -ForegroundColor Cyan
}

# 環境資訊（貼結果時一起附上）
Write-Host "PSVersion : $($PSVersionTable.PSVersion)"
Write-Host "PSEdition : $($PSVersionTable.PSEdition)"
Write-Host "WT_SESSION: $env:WT_SESSION   (有值=Windows Terminal)"
Write-Host "TERM_PROGRAM: $env:TERM_PROGRAM  (vscode=VS Code 整合終端)"
Write-Host "Host      : $($Host.Name)"

# ---- TEST 1: 原生 API 設 title ----
# PowerShell 內建設 window title 的官方做法。
Show-Header 1 "RawUI.WindowTitle (原生 API)"
$Host.UI.RawUI.WindowTitle = "SPIKE-1-RawUI"
Write-Host "已設 WindowTitle = 'SPIKE-1-RawUI'。看 tab 標題有沒有變？"
Read-Host "看完按 Enter 繼續"

# ---- TEST 2: OSC 0 寫進 stdout ----
# 對應 macOS 的 \033]0;title\007，但寫 stdout 不是 /dev/tty。
Show-Header 2 "OSC 0 -> stdout (ESC ]0; title BEL)"
[Console]::Write("$ESC]0;SPIKE-2-OSC0$BEL")
Write-Host "已送 OSC 0。看 tab 標題有沒有變成 SPIKE-2-OSC0？"
Read-Host "看完按 Enter 繼續"

# ---- TEST 3: OSC 2 寫進 stdout ----
Show-Header 3 "OSC 2 -> stdout (ESC ]2; title BEL)"
[Console]::Write("$ESC]2;SPIKE-3-OSC2$BEL")
Write-Host "已送 OSC 2。tab 標題變 SPIKE-3-OSC2？"
Read-Host "看完按 Enter 繼續"

# ---- TEST 4: 跨程序 —— 背景 job 改同一個 console 的 title ----
# 這是「watcher 模型」的核心：另一個程序能不能改前景 terminal 的 tab？
# macOS 靠寫 /dev/tty 達成；Windows 這裡測背景 job 走 RawUI + OSC。
Show-Header 4 "跨程序：背景 job 改 title（watcher 模型）"
$job = Start-Job -ScriptBlock {
  Start-Sleep -Seconds 2
  $e = [char]27; $b = [char]7
  try { $Host.UI.RawUI.WindowTitle = "SPIKE-4-JOB-RawUI" } catch {}
  [Console]::Write("$e]0;SPIKE-4-JOB-OSC$b")
}
Write-Host "背景 job 已啟動，2 秒後嘗試改 title。盯著 tab 看 2-3 秒..."
Start-Sleep -Seconds 4
Receive-Job $job | Out-Null
Remove-Job $job -Force
Write-Host "tab 有沒有被背景 job 改成 SPIKE-4-JOB-*？（這題最關鍵）"
Read-Host "看完按 Enter 繼續"

# ---- TEST 5: 跨程序 —— 獨立 pwsh 程序寫共用 console ----
# 更貼近真實 watcher：一個獨立進程 attach 到同一 console。
Show-Header 5 "跨程序：獨立 pwsh 進程寫 console"
$shell = (Get-Process -Id $PID).ProcessName  # pwsh 或 powershell
$code = @'
Start-Sleep -Seconds 1
$e=[char]27;$b=[char]7
[Console]::Write("$e]0;SPIKE-5-PROC-OSC$b")
try { $Host.UI.RawUI.WindowTitle = "SPIKE-5-PROC-RawUI" } catch {}
Start-Sleep -Seconds 1
'@
$tmp = Join-Path $env:TEMP "spike5.ps1"
$code | Out-File -FilePath $tmp -Encoding utf8
Write-Host "啟動獨立 $shell 進程（共用本 console，NoNewWindow）..."
Start-Process -FilePath $shell -ArgumentList "-NoProfile","-File",$tmp -NoNewWindow -Wait
Remove-Item $tmp -ErrorAction SilentlyContinue
Write-Host "獨立進程有沒有改到本 tab 的標題？"
Read-Host "看完按 Enter 繼續"

Write-Host ""
Write-Host "全部測完。把每題 tab 標題有沒有變、變成什麼，填回 SPIKE-CHECKLIST.md" -ForegroundColor Green
