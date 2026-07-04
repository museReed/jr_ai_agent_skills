# VERIFICATION — 引導式 E2E 驗證流程（給安裝方 AI agent）

> 這份文件是給「執行安裝的 AI agent」的劇本：照順序帶用戶跑完四輪，回報檢查點結果。
> 安裝沒跑完這份 = 沒裝完。本流程 2026-07-04 在 macOS（Terminal + Cursor + Antigravity × Claude Code + Codex）全數實測通過。
>
> 你（AI agent）的角色：下指令前先告訴用戶「現在測什麼、預期看到什麼」；每個檢查點
> 明確判定 PASS/FAIL；FAIL 不要硬修，走文末「失敗處理」。

---

## 事前準備（AI agent 自己做）

1. 跑自動檢查，全 PASS 才開始人工輪：

```bash
cd <本 repo>/installer && ./verify.sh
```

2. 建一個用完即丟的測試 repo（handoff 測試會產生 commit，別弄髒用戶的真 repo）：

```bash
mkdir -p ~/e2e-skill-test && cd ~/e2e-skill-test && git init -q && \
  echo "# e2e skill test" > README.md && git add -A && git commit -qm init
```

3. 提醒用戶：**每一輪都要開全新的 terminal**（舊 terminal 還在舊環境，測了不算）。

---

## 第 A 輪 — 系統 terminal（Terminal.app / iTerm）× Claude Code 完整功能

請用戶開新 terminal 貼：

```bash
cd ~/e2e-skill-test && CONTEXT_MONITOR_TEST_WINDOW=30000 claude
```

| 檢查點 | 動作 | 預期 |
|---|---|---|
| **A1** | 啟動瞬間看 tab | 顯示 `(等待命名)`（wrapper + watcher 活著） |
| **A2** | 打第一句話：「列出這個資料夾的檔案，然後把 README 讀給我」 | **第一個回合內** tab 變成 `{emoji} 任務描述` |
| **A3** | 它動手後 | 回應出現 `⚠️ Context 已用 …（測試模式）`（context-monitor） |
| **A4** | 打：「照警告的指示寫 handoff」 | 產出 `docs/handoff/*.md` + commit |
| **A5** | handoff 完成後看 tab | 變成 `📦 …` 開頭（封存改名） |

測完直接關掉 session。

## 第 B 輪 — 同一個 terminal app 新 tab × Codex 完整功能

```bash
cd ~/e2e-skill-test && CODEX_TEST_MAX_CONTEXT_WINDOW=10000 codex
```

| 檢查點 | 動作 | 預期 |
|---|---|---|
| **B1** | 打第一句話（同 A2） | 第一回合內 tab 變任務名 |
| **B2** | ⚠️ **先下第二個指令**（例如「再列一次」） | **第二個指令的回合起**出現 `[context-monitor] 測試模式…`（token 帳本在回合結束才寫入，hook 有一回合時差——第一回合沒警告是正常的，見 TROUBLESHOOTING #10） |
| **B3** | 打：「照指示寫 handoff，全部步驟做完」 | handoff 檔 + commit |
| **B4** | 看 tab | 變 `📦 …` |
| **B5** | 它 `touch …/{pid}.handoff` 後 | 警告**停止重複** |
| **B6** | 讓它跑：`sqlite3 "$(ls -t ~/.codex/state_*.sqlite \| head -1)" "SELECT title FROM threads ORDER BY updated_at_ms DESC LIMIT 1;"` | 回 `📦 …`（sidebar 同步） |

## 第 C 輪 — Cursor integrated terminal × 顯示層

hook 邏輯 A/B 已驗過，這輪只驗「這個編輯器的 tab 會不會顯示」。

1. Cursor 開**新的** integrated terminal（⌃`）
2. `cd ~/e2e-skill-test && claude`（正常模式，不帶測試變數）
3. **C1**：打一句任務 → 第一回合內 Cursor terminal tab 變任務名，**中文無亂碼**
4. 關掉，開新 terminal 換 `codex` 重複 → **C2**

前置：Cursor `settings.json` 需有 `"terminal.integrated.tabs.title": "${sequence}"`（verify.sh 會查）。

## 第 D 輪 — Antigravity integrated terminal × 顯示層

同 C 輪，在 Antigravity 開新 terminal 測一個工具即可 → **D1**（可加測另一工具 → **D2**）。

---

## 判定與收尾

- **A1-A5、B1-B6、C1-C2、D1 全 PASS** → 回報用戶「全鏈路驗證通過」，然後清理：
  ```bash
  rm -rf ~/e2e-skill-test
  ```
  測試 session 直接關閉即可；正常 session 不帶測試變數、行為完全不變。

## 失敗處理（AI agent 的責任，不要只回報「失敗」就結束）

1. 對照 `TROUBLESHOOTING.md` 症狀表逐條檢查（tab 不變 → #1/#2；亂碼 → #3；B2 沒警告 → #10…）
2. 修不掉：跑一個指令回報（自動收證據 + 開 issue）——症狀寫「檢查點編號 + 預期 vs 實際」：

```bash
./diagnose.sh "B2 FAIL：預期第二回合出現警告，實際沒有"
```
