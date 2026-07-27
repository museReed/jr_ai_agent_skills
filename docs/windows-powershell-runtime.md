# Windows / PowerShell runtime — auto-rename 的 tab 命名

bash runtime 的 PowerShell 對照版。定案脈絡見
`docs/handoff/2026-07-25-workshop-terminal-tabtitle-verified.md`，
可行性證據見 `docs/spikes/windows-tab-title/SPIKE-CHECKLIST.md`。

支援矩陣：**Windows Terminal** × **Windows PowerShell 5.1 或 PowerShell 7**（不強制 7）。
IDE 整合終端不支援，也不打算支援。

## 檔案對照

| bash | PowerShell | 角色 |
|---|---|---|
| `installer/bin/ai-tab-sync.sh` | `installer/bin/ai-tab-sync.ps1` | 背景 watcher：輪詢 sync 檔 → 寫 OSC 改 tab |
| `installer/bin/myclaude` | `installer/bin/myclaude.ps1` | 啟動器：開 sync 檔 + 起 watcher + 跑 claude |
| `installer/bin/mycodex` | `installer/bin/mycodex.ps1` | 同上，跑 codex |
| `installer/hooks/set-session-name.sh` | `installer/hooks/set-session-name.ps1` | 唯一命名寫入口（hook 與 auto-rename skill 共用） |
| `installer/hooks/session-auto-namer.sh` | `installer/hooks/session-auto-namer.ps1` | Claude Code hook：適時要求模型命名 |
| `installer/hooks/codex-session-namer.sh` | `installer/hooks/codex-session-namer.ps1` | Codex hook：relay 檔 + SQLite sidebar 名 |

行為與 bash 版一致（輪詢 1 秒、prompt#1 命名、tool call 第 5 次重評、之後每 10 次補命名）。

## 三個平台差異（會改到寫法的地方）

| 差異 | bash 做法 | Windows 做法 |
|---|---|---|
| 沒有 `/dev/tty` | 背景程序 `printf` OSC 到 tty device | watcher 共用 console → `[Console]::Write` 寫 OSC；hook 的 stdout 被收走，改用 `SetConsoleTitle`（`[Console]::Title`）完全繞過 stdout |
| 沒有 `$PPID` | hook 讀 `$PPID`，parent 就是 claude | **pid 整個不能用**（見下），session 身分改用 stdin JSON 的 `session_id` |
| 背景程序不隨父程序死 | `trap` 裡 `kill` | 同樣在 `finally` 殺，另加 watcher 自檢父 pid 消失就退出，避免孤兒 |
| 沒有保證的 `sqlite3.exe` | `sqlite3` CLI | Python stdlib `sqlite3`；偵測要**實跑 `--version`**，PATH 上有 `python3.exe` 不代表有 Python（見下） |
| `.ps1` 不能直接當 PATH 指令 | `myclaude` 可執行檔 | `$PROFILE` 裡包 function（見下） |
| CJK / emoji 編碼 | 天生 UTF-8 | 明設 `UTF8Encoding($false)` 讀寫檔與 console；hook JSON 直接寫 bytes |

### ⚠️ `.ps1` 檔本身必須存成「UTF-8 with BOM」

Windows PowerShell 5.1 **沒有 BOM 就用系統 ANSI codepage 讀 `.ps1`**，
腳本裡的中文字面值（命名規則、`(等待命名)`）會直接變亂碼餵給模型與 tab。
PowerShell 7 兩種都吃，所以帶 BOM 是唯一同時相容的存法。

六支腳本目前全部帶 BOM。**後續編輯時別讓編輯器把 BOM 拿掉**——
驗證腳本的 T2 就是在守這件事。

### ⚠️ Windows 的 `python3.exe` 可能是 Microsoft Store 假殼

乾淨的 Windows 11 在 `%LOCALAPPDATA%\Microsoft\WindowsApps\` 放了 `python3.exe`
與 `python.exe` 兩個轉址殼，跑起來只會印
「Python was not found; run without arguments to install from the Microsoft Store」。
`Get-Command python3` 找得到它，所以**光看 PATH 會誤判成裝了 Python**。

真的從 Store 安裝 Python 時，執行檔在同一個資料夾、同樣的檔名 —— 靠路徑分不出真假，
只能實跑 `--version` 看有沒有印出 `Python 3`。`codex-session-namer.ps1` 就是這樣做的。

Python 只影響 **Codex 的 sidebar 改名**（要寫 `state_*.sqlite`）。
沒有 Python 時 hook 會在 stderr 說一聲然後跳過，**tab 標題照常運作**。
Claude Code 那條完全不需要 Python。

## 安裝（PowerShell installer 尚未寫，先手動）

複製檔案：

```powershell
New-Item -ItemType Directory -Force -Path "$HOME\.local\bin", "$HOME\.claude\hooks", "$HOME\.codex\hooks"
Copy-Item installer\bin\ai-tab-sync.ps1, installer\bin\myclaude.ps1, installer\bin\mycodex.ps1 "$HOME\.local\bin\"
Copy-Item installer\hooks\set-session-name.ps1, installer\hooks\session-auto-namer.ps1 "$HOME\.claude\hooks\"
Copy-Item installer\hooks\codex-session-namer.ps1 "$HOME\.codex\hooks\"
```

`$PROFILE.CurrentUserAllHosts` 加 wrapper function：

```powershell
function myclaude { & "$HOME\.local\bin\myclaude.ps1" @args }
function mycodex  { & "$HOME\.local\bin\mycodex.ps1"  @args }
```

`~/.claude/settings.json` 註冊 hook（`PostToolUse` 與 `UserPromptSubmit` 各一組，`timeout: 3`）：

```
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\<you>\.claude\hooks\session-auto-namer.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\<you>\.claude\hooks\session-auto-namer.ps1" prompt
```

`~/.codex/hooks.json` 同理指向 `codex-session-namer.ps1`。

`-ExecutionPolicy Bypass` 是必要的：預設 RemoteSigned 會擋掉未簽章腳本。

## 待在 Windows VM 驗的事（本批程式碼尚未實機跑過）

跑 `docs\spikes\windows-tab-title\verify-powershell-runtime.ps1`，
在 **Windows Terminal × PS5.1** 與 **× PS7** 各跑一次，把總結表貼回這裡。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs\spikes\windows-tab-title\verify-powershell-runtime.ps1
pwsh       -NoProfile -ExecutionPolicy Bypass -File docs\spikes\windows-tab-title\verify-powershell-runtime.ps1
```

| # | 驗什麼 | 為什麼會怕 |
|---|---|---|
| T1 | 六支腳本語法 parse | 全部沒在任何 PowerShell 上跑過 |
| T2 | 每支都有 UTF-8 BOM | 沒 BOM → 5.1 把中文讀成亂碼 |
| T3 | 中文字面值讀進來沒亂碼 | T2 的實際後果 |
| T4 | 程序祖先鏈（記錄用） | 決定 `Get-ParentPid $PID` 拿到的是不是 claude 本身 |
| T5 | `SetConsoleTitle` 在 stdout 被導向時仍改得到 tab | spike 只驗過共用 console 的程序，沒驗 stdout 被收走的 hook |
| T6 | watcher 全鏈 + 孤兒自清 | emoji/中文顯示、父程序死後不留殘留程序 |
| T7 | emoji 走命令列傳給 `powershell.exe` | 模型實際呼叫 `set-session-name.ps1` 的形式 |
| T8 | namer 吐的 JSON 合法且中文完整 | 5.1 與 7 的 stdout 編碼不同 |
| T9 | `py -` 跑 SQLite UPDATE | Windows 沒有保證的 `sqlite3.exe` |

~~T4 拿錯 pid 的後果有限，只會記到錯的檔名。~~ **這個判斷是錯的**，
真實 session E2E 推翻了它 —— 見下方「第四輪」。

T5 若 FAIL，hook 的無 wrapper 路徑要換寫法（但走 `myclaude` wrapper 的主路徑不受影響）。

### 第一輪 VM 結果（2026-07-27，Windows Terminal × PS 5.1.26100）

T1/T2/T3/T4/T6/T6b PASS —— 語法、BOM、中文字面值、watcher 全鏈（emoji + 中文）、
孤兒自清全數過關。

**T5 FAIL 改動了設計**：`\\.\CONOUT$` 開得起來，但把 OSC 寫進去**不會改到 tab**。
`/dev/tty` 的類比只成立到「開得起來」為止。改用 `SetConsoleTitle`（`[Console]::Title`），
它不經 stdout，spike TEST 1/4 已證實跨程序有效。

連帶：`session-auto-namer.ps1` **刻意不留 OSC 寫 stdout 的後備**——它的 stdout 是
hook 的 JSON 通道，混進 escape 會把 payload 弄壞。寧可標題沒改，不要 payload 壞掉。

### 第二輪 VM 結果（2026-07-27，同機）

T1–T8 全 PASS，含改用 `SetConsoleTitle` 後的 T5、emoji 走命令列的 T7、
hook JSON 通道的 T8。

**T9 暴露真 bug**：偵測到的 `python3.exe` 是 Store 假殼，`codex-session-namer.ps1`
會挑中它然後靜默失敗。改成實跑 `--version` 驗證，並在沒有 Python 時於 stderr 明講。

**Claude Code 那條路徑（tab 命名主線）在 PS 5.1 上已完整驗證通過。**

### 第三輪：PS 7 全數通過（2026-07-27，同機，已補裝 Python 3.12）

| 題 | WT × PS 5.1 (5.1.26100.8875) | WT × PS 7 (7.6.4) |
|---|---|---|
| T1 語法 parse | PASS | PASS |
| T2 UTF-8 BOM | PASS | PASS |
| T3 中文字面值 | PASS | PASS |
| T4 程序祖先鏈 | 記錄 | 記錄 |
| T5 SetConsoleTitle（stdout 被導向） | PASS | PASS |
| T6 watcher 全鏈（emoji + 中文） | PASS | PASS |
| T6b 孤兒自清 | PASS | PASS |
| T7 emoji 走命令列 | PASS | PASS |
| T8 hook JSON 通道 | PASS | PASS |
| T9 Python + SQLite | PASS（補裝 Python 後重跑） | PASS |

**移植完成**：`ai-tab-sync` watcher + Claude/Codex 兩支命名 hook 在
Windows Terminal × PS 5.1 / PS 7 皆驗證通過。

### 第四輪：真實 session E2E —— pid 在 Windows 上不能當 session 身分

harness 全綠之後，把 hook 實際掛進 Windows 的 Claude Code 跑一輪，
浮出 harness 驗不到的東西。

**現象**：跑滿 10 次 tool call，第 5 次的重評估**從沒觸發**；
`~/.claude/session-names/` 裡出現 `0.txt`，而且所有 session 都寫進同一個檔互相覆蓋。

**根因（兩個現象同一個）**：Windows 的 Claude Code **每次 spawn hook 都開一個
用完即丟的中介程序**。hook 看到的 parent pid 每次都不一樣，而且子腳本查詢時
那個 pid 已經死了（`Get-CimInstance` 查不到 → 回 0）。於是：

- 計數器檔名每次都不同 → 永遠停在 1，到不了 5
- pid 解析失敗 → 全部落到 `0.txt`

bash 版的 `$PPID`（parent 就是 claude）**在 Windows 沒有對應物**。

**修法**：改用 Claude Code 自己的 `session_id`（hook 的 stdin JSON 裡就有，
Codex 那支本來就這樣做）當計數器、marker 與紀錄檔的 key。
手動 `/auto-rename` 沒有 session_id 可傳，退回 pid 鏈，
但**不再允許 key 成 `0`**（改 `unresolved-<pid>`），避免互相覆蓋。

tab 改名本來就不靠 pid（走 `SetConsoleTitle`），所以退化路徑只影響紀錄檔。

**教訓**：元件級 harness 驗不出「宿主怎麼 spawn 你」。T4 當初只印祖先鏈不判定，
就是因為那時看不到真值——真值只有掛進真實 session 才會出現。

未驗：`installer/install-windows.ps1` 本身、以及上述 `session_id` 修正的實機效果。
