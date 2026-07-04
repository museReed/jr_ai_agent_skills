# Handoff Skill — 安裝指南

Read this document, then execute the installation steps for your tool (Section A or Section B). Do not ask for confirmation — just do it. Execute every step sequentially, do not skip any step. **Installation is NOT complete until you have walked the user through the "E2E 驗證" section.**

功能介紹見 [handoff-skill.md](./handoff-skill.md)。

> 適用：Claude Code / Codex CLI（macOS / Linux）
> 需求：bash、python3、git repo（handoff 文件 commit 到 `docs/handoff/`）
> 建議先裝 [auto-rename](./auto-rename-install.md)——handoff 完成後的 📦 改名依賴它的同步機制。

---

## 這個 skill 做什麼

兩個部件，同一個 installer 裝：

1. **handoff skill**：session 要結束（或 context 快滿）時，AI 產出結構化交接文件到
   `docs/handoff/{date}-{topic}.md`，commit，然後把 session 改名成 `📦 {topic}` 標記已交接。
   新 session 讀一個檔案就能無縫接續。
2. **context-monitor hook**：每次 tool call 後讀 session 的真實 token 用量，
   超過 **70%** 就注入警告叫 AI 立刻寫 handoff——避免 context 爆掉才想起來要交接。

## Section A: Claude Code 安裝

所有 script 都在本 repo 的 `installer/`（auto-rename 裝過的話重跑同個指令即可，冪等）：

```bash
cd jr_ai_agent_skills/installer
./install.sh claude
```

裝了什麼（handoff 相關部分）：

| 檔案 | 位置 | 作用 |
|---|---|---|
| `handoff/SKILL.md` | `~/.claude/skills/handoff/` | 交接文件產生流程 |
| `context-monitor.sh` | `~/.claude/hooks/` | PostToolUse 讀 transcript 的真實 token 數，>70% 警告 |

## Section B: Codex CLI 安裝

```bash
cd jr_ai_agent_skills/installer
./install.sh codex
```

| 檔案 | 位置 | 作用 |
|---|---|---|
| `handoff/SKILL.md` | `~/.codex/skills/handoff/` | 交接文件產生流程（改名走 relay 檔） |
| `_shared/codex-session-rename.md` | `~/.codex/skills/_shared/` | 改名方法的唯一事實來源 |
| `codex-context-monitor.sh` | `~/.codex/hooks/` | 讀 rollout 的 token_count，>70% 警告；讀不到時用 tool call 數估算 |

## E2E 驗證（AI agent 必須主動引導用戶完成，不可跳過）

> 完整逐步引導劇本（四輪 × 檢查點編號）→ Read `installer/VERIFICATION.md`，照它帶用戶跑。

### 第 1 步：自動檢查

```bash
cd jr_ai_agent_skills/installer
./verify.sh
```

verify 會模擬 context-monitor 觸發（假 transcript + 縮小視窗），全 PASS 才往下。

### 第 2 步：真實觸發測試（引導用戶做）

用「縮小視窗」讓警告提早出現，不用真的聊到 70%：

1. 請用戶開**新 terminal**，在一個 git repo 裡啟動測試 session：
   - Claude Code：`CONTEXT_MONITOR_TEST_WINDOW=30000 claude`
   - Codex：`CODEX_TEST_MAX_CONTEXT_WINDOW=20000 codex`
2. 叫它做 1-2 件會動手的事（例如「列出這個資料夾的檔案」），做完**再下第二個指令**（例如「再列一次」）
3. 預期：**第二個指令的回合起**，AI 開始說「⚠️ Context 已用 …（測試模式）請寫交接文件」——**看到警告＝hook 驗證成功**，可以直接關掉，不用真的寫完 handoff
4. （可選）讓它寫完：檢查 `docs/handoff/` 出現文件、有 commit、session 改名成 `📦 …`
5. 提醒用戶：測試 session 關掉即可，正常 session 不設環境變數、行為完全不變

### 第 3 步：手動 handoff 驗證（可選）

任何正常 session 裡打「寫 handoff」→ 應產出文件 + commit + 📦 改名 + 回報單行起始 prompt。

### 失敗時（AI agent 的責任，不要只說「裝完了」就結束）

1. 跑 `./verify.sh --report` 產出診斷報告
2. 開 `installer/TROUBLESHOOTING.md` 按症狀對照表檢查（第 8 條就是 context-monitor 常見問題）
3. 修不掉 → 替用戶準備好 issue 內容，引導用戶貼到：
   <https://github.com/museReed/jr_ai_agent_skills/issues/new?template=install-report.md>

## 機制細節（debug 時參考）

- Claude 側 context-monitor 從 hook stdin 的 `transcript_path` 讀**當前 session** 的 JSONL——
  不用 mtime 猜檔案（多 session 同開會猜錯，這是修過的坑）
- Codex 側優先讀 rollout JSONL 的 `token_count` 事件；讀不到退回「tool call 數 ≈ 用量」估算
- Codex 的 `token_count` 在**回合結束**才寫入，hook 在回合中執行 → 警告有一回合的時差，
  測試時第二個指令才會看到（正常使用無感，70% 不會只差一回合）
- 測試旋鈕：`CONTEXT_MONITOR_TEST_WINDOW`（Claude）/ `CODEX_TEST_MAX_CONTEXT_WINDOW`（Codex），
  只影響帶著變數啟動的那個 session
- Codex 觸發後會**持續催**直到 AI 照指示 `touch /tmp/codex-context-monitor/{pid}.handoff`——
  這是防漏設計，不是 bug
