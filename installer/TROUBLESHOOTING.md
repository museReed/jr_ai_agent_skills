# Troubleshooting — Auto-Rename / Handoff 安裝除錯手冊

> 先跑 `./verify.sh`，它會抓掉八成的問題。這份手冊處理 verify 抓不到的「行為不對」。
> 每一條都是實際踩過的坑。修不掉 → 跑 `./verify.sh --report`，照文末「回報方式」開 issue。

---

## 症狀對照表

| # | 症狀 | 先檢查 | 修法 |
|---|---|---|---|
| 1 | Terminal tab 完全不改名（Cursor / VS Code / Antigravity） | 該編輯器 `settings.json` 有沒有 `"terminal.integrated.tabs.title": "${sequence}"` | 加上這行；**只對存檔後新開的 terminal 生效**。iTerm / Terminal.app 原生支援不用設 |
| 2 | Tab 不改名（任何 terminal） | ① `echo $AI_TAB_SYNC_FILE` 有值嗎 ② `ps aux \| grep ai-tab-sync` watcher 在跑嗎 | 空值＝沒走 wrapper：確認 shell rc 有 `alias claude='$HOME/.local/bin/myclaude'`（codex 同理），然後**開新 terminal** |
| 3 | Tab 名稱中文變亂碼（`æ¸¬è©¦` 這種） | `locale` 輸出是不是 UTF-8 | `export LANG=en_US.UTF-8` 加進 shell rc。若 locale 正常但仍亂碼，是該編輯器對 raw OSC 的解碼 bug，改用英文名或回報 |
| 4 | 從 terminal「複製出來」的中文是亂碼，畫面正常 | 是不是用滑鼠拖曳複製（Cursor 已知 OSC 52 bug） | Cursor 設 `"terminal.integrated.macOptionClickForcesSelection": true` 後用 Option+拖曳複製 |
| 5 | Codex sidebar 名稱沒更新 | ① `~/.codex/hooks.json` 有註冊兩個事件嗎 ② `sqlite3` 裝了嗎 ③ relay 檔寫對 key 了嗎（`/tmp/codex-session-namer/<codex PID>.pending`） | verify.sh 會檢查 ①②；③ 常見錯因是模型用了錯的 PID——relay 檔名必須用 hook 注入訊息裡給的精確路徑 |
| 6 | 第一句話後沒觸發命名 | 這個 session 是不是在安裝「之前」就開著 | Hook 註冊只對**重啟後的新 session** 生效。開新 terminal 再測 |
| 7 | AI 收到命名請求但 tab 還是舊的（Codex） | relay 檔有沒有被消化（檔案還在＝hook 沒跑） | hook 在「下一次 tool call 或訊息」才套用；完全沒消化＝hooks.json 註冊路徑錯 |
| 8 | context-monitor 瘋狂催寫 handoff | ① 是不是設了測試變數（`CONTEXT_MONITOR_TEST_WINDOW` / `CODEX_TEST_MAX_CONTEXT_WINDOW`）② context 是不是真的 >70% | 測試變數只該在測試 session 用；真超標就照指示寫 handoff（Codex 寫完要 `touch` 它給的 marker 路徑才會停） |
| 9 | `install.sh` 中途失敗 | 錯誤訊息是不是 JSON 相關 | `~/.claude/settings.json` / `~/.codex/hooks.json` 可能本來就不是合法 JSON（手改壞的）。先 `python3 -m json.tool <檔案>` 找出壞處修好，再重跑 install.sh |
| 10 | 舊 terminal 的 tab 名字凍結 | 那個 terminal 是不是安裝前開的 | 正常——舊 watcher 握著舊檔案繼續跑，關掉重開就好 |

## Debug 時值得留的證據（開 issue 前收集）

1. `./verify.sh --report` 的完整輸出檔（必附——含環境、版本、逐項檢查結果）
2. 「預期 vs 實際」一句話：例如「打了第一句話，預期 tab 變任務名，實際停在 (等待命名)」
3. 症狀相關的現場數據（對照上表的「先檢查」欄，把指令輸出貼上）：
   - tab 問題：`echo $AI_TAB_SYNC_FILE`、`cat "$AI_TAB_SYNC_FILE"`、`ps aux | grep ai-tab-sync | grep -v grep`
   - Codex 問題：`ls -la /tmp/codex-session-namer/`、`sqlite3 "$(ls -t ~/.codex/state_*.sqlite | head -1)" "SELECT title FROM threads ORDER BY updated_at_ms DESC LIMIT 3;"`
   - 命名不觸發：`python3 -m json.tool ~/.claude/settings.json | grep -A3 session-auto-namer`
4. 用的 terminal / 編輯器名稱和版本（Cursor、Antigravity、iTerm…）

## 回報方式（讓 trouble shooting 紀錄集中留存）

1. 跑 `./verify.sh --report`，會產出 `verify-report-*.md`
2. 到 <https://github.com/museReed/jr_ai_agent_skills/issues/new?template=install-report.md> 開 issue
3. 標題格式：`[install] {工具} {一句話症狀}`（例：`[install] codex tab 不改名 @ Cursor`）
4. 內文貼上報告全文 + 上面第 2、3 點的證據

> 給安裝方 AI agent 的指示：安裝失敗或驗證不過時，**主動**替用戶跑 `--report`、收集上述證據、
> 產出 issue 內文草稿讓用戶貼——不要只說「安裝完成」就結束。
