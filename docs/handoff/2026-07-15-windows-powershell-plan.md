# Handoff — Windows / PowerShell 正式支援規劃

## 狀態摘要

- 類型：continuation / investigation。
- 使用者要求規劃 `jr_ai_agent_skills` 的 Windows／PowerShell 正式支援。
- 已確認現況只正式支援 macOS；Linux 理論相容；Windows 原生明確未支援。
- 主要 Unix 耦合：Bash installer/hooks、`/dev/tty` OSC watcher、`ps/kill/trap`、shell rc、Unix temp/path 與 E2E 指令。
- `structured-questions`、大部分 skill 內容與 JSON hook 設定可望共用；installer、wrapper、hook runtime 與 verify 需要 Windows variant。
- 兩個 discovery agents 已回報：repo Windows audit 與 Microsoft/PowerShell/Windows Terminal 官方 API；下個 session 需依下列摘要補完 Claude/Codex 官方 Windows contract。
- PR #9 已合併到 `main`（merge commit `32fd886`）；本機仍在 `external-skills-and-demo`，工作樹在本 handoff 前為乾淨。

## 必讀檔案

- `installer/install.sh`：目前單一 Unix installer，包含 hooks、skills、wrapper 與 JSON 註冊流程。
- `installer/bin/ai-tab-sync.sh`、`myclaude`、`mycodex`：TTY/OSC 與程序生命週期的 Unix 實作，是 Windows ConPTY 設計的主要替換面。
- `installer/hooks/`：auto-rename 與 context-monitor 的 Bash runtime；需判斷哪些邏輯抽成共用 Python、哪些改寫 PowerShell。
- `installer/detect-environment.py`、`configure-editor.py`：已有平台分支與可測試 helper pattern，可擴充 Windows 路徑與 terminal 偵測。
- `installer/verify.sh`、`VERIFICATION.md`：目前自動檢查及人工 E2E 都是 Unix 指令，需建立 PowerShell 對等介面。
- `README.md`、`installer/README.md`：目前明示 Windows 未支援，正式支援後需三語同步更新矩陣與入口。

## 下一步

1. 重新完成 Phase 0 文件探索：Microsoft PowerShell profile/functions、Windows Terminal/ConPTY OSC、Windows temp/AppData、程序生命週期、atomic replace、junction/symlink；Claude Code 與 Codex 官方 Windows hooks/config/state 支援。
2. 整合兩個 discovery report，建立「Allowed APIs / 禁用假設」清單；所有技術主張只採官方文件或實際 CLI 行為。
3. 在 Plan mode 用 `request_user_input` 鎖定：Windows Native 是否包含 WSL、首版需完整 feature parity 或分階段、最低 Windows/PowerShell 版本、Windows Terminal/Cursor/VS Code 支援矩陣。
4. 將方案定為 PowerShell-native installer + Windows runtime variants，保留 macOS/Linux 行為不變；決定共用 Python core 與平台薄殼的邊界。
5. 規劃 Windows VM 測試矩陣：乾淨 Windows、Claude-only、Codex-only、兩者、PowerShell 7、Windows Terminal、Cursor/VS Code、重裝/回復與三個 skill E2E。
6. 產出 decision-complete `<proposed_plan>`，包含公開命令介面、安裝/移除/備份、錯誤處理、測試與 rollout。

## Phase 0 已確認的官方 API

- PowerShell profile：使用 `$PROFILE.CurrentUserAllHosts`，用 function 包裝參數化 CLI；不可 hard-code Documents 或用 `Set-Alias` 取代 wrapper。
- 使用者資料路徑：`[Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)`；暫存目錄用 `[System.IO.Path]::GetTempPath()`。
- 安全覆寫：先在同目錄寫 temp，再用 `[System.IO.File]::Replace(temp, destination, backup)`；新檔則 move，需實測 Windows PowerShell 5.1 與 PowerShell 7。
- Terminal title：官方支援 OSC `ESC ] 0/2 ; title ST`；Windows Terminal 必須允許 application title，VS Code 設定使用 `"terminal.integrated.tabs.title": "${sequence}"`。
- 程序啟動：`Start-Process -FilePath ... -ArgumentList ... -PassThru` 回傳 Process；不可只用 PID 作 session identity，需 session id 或 PID + start time。
- Link：`New-Item -ItemType SymbolicLink/Junction` 有權限與 PowerShell 版本差異；正式方案應以 copy 為預設，link 僅選配。
- SQLite：Windows 不保證有 `sqlite3.exe`；既然專案已有 Python prerequisite，優先用 Python stdlib `sqlite3`。
- 主要官方來源：Microsoft Learn `about_Profiles`、`.NET Path.GetTempPath`、`Environment.GetFolderPath`、`File.Replace`、console virtual terminal sequences、Windows Terminal CLI/settings、PowerShell `New-Item`/`Start-Process`、VS Code terminal appearance/profiles。

## 已知問題

- Windows 原生沒有 `/dev/tty`；不可把 Git Bash/WSL 當成 PowerShell 正式支援的替代品。
- ConPTY 本身不是可直接寫入的 tty device；tab title 必須驗證 OSC 經 stdout/console 或 Windows Terminal/IDE API 的實際可行路徑。
- Claude Code/Codex 的 Windows hook shell、設定檔與 state DB 位置尚未由官方文件確認，不可沿用 Unix 路徑猜測。
- 本 handoff commit 會位於已合併後的 feature branch；新 session 應先決定後續 Windows 規劃的 branch/PR 策略，不要直接寫入 `main`。
