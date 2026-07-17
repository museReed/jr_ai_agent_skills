# Auto-Rename Skill — 安裝指南

Read this document and guide the user through the single installation flow below. Detect first, ask only when a real choice remains, and execute every step sequentially. **Installation is NOT complete until the user has opened a new session and completed all three skills' E2E checks.**

功能介紹見 [auto-rename-skill.md](./auto-rename-skill.md)。

> 適用：Claude Code / Codex CLI（macOS / Linux）
> 需求：bash、python3；Codex sidebar 改名另需 sqlite3

---

## 這個 skill 做什麼

AI 自動幫每個 session 取名字並同步到 terminal tab（和 Codex sidebar），tab 不再全叫 "New chat"。

命名節奏（三段接力）：

| 時間點 | 誰做的 | tab 顯示 |
|---|---|---|
| 開 session 那一刻 | wrapper 寫佔位字 | `(等待命名)` |
| **你的第一句話之後** | hook 請 AI 依任務意圖命名 | `🔍 cron 失敗原因`（例） |
| 第 5 次 tool call | hook 請 AI 根據前面討論重新評估（名字仍準確就不改） | 可能升級成更貼切的名字 |
| 每 10 次 tool call | 兜底：只在還沒命名成功時重試 | — |

架構一句話：`claude`/`codex` 經 wrapper 啟動 → wrapper 開背景 watcher 盯一個 sync 檔 → hook 在命名時寫 sync 檔 → watcher 把名字寫進 terminal tab（OSC）。Codex 側模型先寫 `/tmp` relay 檔、hook 代寫 SQLite（sidebar）+ sync 檔（sandbox 限制）。

## 單一 AI 引導式安裝流程

### 1. 先偵測，不修改任何設定

```bash
cd jr_ai_agent_skills/installer
python3 detect-environment.py
```

讀取 JSON 中的 `cli`、`recommended_install_target`、`terminal` 與 `editors`。父程序是強證據，`TERM_PROGRAM` 次之；設定檔存在只代表該 IDE 安裝或用過，不能代表目前 terminal。

### 2. 決定安裝目標

| 偵測結果 | AI 行為 |
|---|---|
| 只有 Claude CLI | 告知「偵測到 Claude Code，將安裝 Claude 版本」，不提問 |
| 只有 Codex CLI | 告知「偵測到 Codex CLI，將安裝 Codex 版本」，不提問 |
| 兩者都有 | 用結構化問題詢問「兩者（Recommended）／Claude／Codex」 |
| 兩者都沒有 | 停止；請使用者先安裝至少一個 CLI |

安裝前不能假設 `structured-questions` skill 已存在，因此直接遵守以下內建流程：

- Claude Code：使用 `AskUserQuestion` 互動選單。
- Codex Plan mode：使用 `request_user_input`；每次最多 3 題、每題 2–3 個選項，推薦項置首並加 `(Recommended)`，每個 description 用一行說明取捨。
- Codex Default mode：輸出「你目前不在 Plan mode。若要互動式選單，請輸入 `/plan 繼續安裝 jr_ai_agent_skills`；若不要切換，請回覆『不切換』，我會改用文字選項。」然後停止，不先列選項。
- 使用者回覆「要／切換」時，引導輸入 `/plan 繼續安裝 jr_ai_agent_skills` 後停止；直接輸入該指令並切換成功後，用 `request_user_input` 繼續。
- 只有明確回覆「不要／不切換」才在同一輪列出完整文字選項；模糊回答必須再問「切換」或「不切換」，不得自行 fallback。

### 3. 一律確認目前 terminal／IDE

偵測結果只是推薦，AI 必須用同一套結構化問題讓學生確認。明確偵測時先問「使用偵測結果（Recommended）／其他 VS Code 系 IDE／Terminal、iTerm 或其他」；選其他 VS Code 系 IDE 時，再問「Cursor／Antigravity／VS Code」。偵測不明時先問「VS Code 系 IDE／Terminal、iTerm 或其他」，選前者後再問是哪一個 IDE。

只設定學生最後確認的 IDE：

```bash
python3 configure-editor.py cursor       # 或 antigravity / vscode
python3 configure-editor.py native       # Terminal.app、iTerm 或其他：明確不修改設定
```

若既有 `settings.json` 含 JSONC 註解而解析失敗，原檔不會被寫入；請學生在已確認的那個 IDE 內用 "Open User Settings (JSON)" 手動加入 `"terminal.integrated.tabs.title": "${sequence}"`。不可因其他 IDE 的設定檔存在而修改它。

### 4. 執行非互動 installer 並寫 alias

```bash
./install.sh claude --editor=<confirmed-editor>   # 只安裝 Claude Code
./install.sh codex --editor=<confirmed-editor>    # 只安裝 Codex CLI
./install.sh --editor=<confirmed-editor>          # 兩者都安裝
```

一個指令會安裝該目標的 auto-rename、handoff、structured-questions 三個 skills 與相關 hooks，不需逐個 skill 安裝。AI 接著把對應 alias 寫進 shell rc（冪等，兩者都裝就執行兩段）：

```bash
RC="$HOME/.zshrc"; case "$SHELL" in *bash*) RC="$HOME/.bashrc";; esac
TARGET="<claude|codex|all>"
case "$TARGET" in claude|all) grep -q "alias claude=.*myclaude" "$RC" 2>/dev/null || echo "alias claude='\$HOME/.local/bin/myclaude'" >> "$RC";; esac
case "$TARGET" in codex|all) grep -q "alias codex=.*mycodex" "$RC" 2>/dev/null || echo "alias codex='\$HOME/.local/bin/mycodex'" >> "$RC";; esac
```

只寫入實際安裝目標的 alias。installer 可安全重跑；Codex skill 備份放在 `~/.agents/skill-backups/{timestamp}/`，其他檔案使用 `*.bak.{timestamp}`。

### 5. 必須停下並要求新環境

installer 完成後，AI 必須明確要求學生**開新的 terminal，再啟動新的 AI session**，並把 installer 印出的 target-aware continuation prompt 貼進新 session，然後停止目前流程。舊 session 不會重新載入剛安裝的 skills，不得在舊 session 宣稱安裝或 E2E 已完成。

## E2E 驗證（AI agent 必須主動引導用戶完成，不可跳過）

> 完整逐步引導劇本（四輪 × 檢查點編號）→ Read `installer/VERIFICATION.md`，照它帶用戶跑。

### 第 1 步：自動檢查

```bash
cd jr_ai_agent_skills/installer
./verify.sh claude --editor=<confirmed-editor>  # 換成 cursor / antigravity / vscode / native
# 或改用 codex；兩者都裝時省略 claude/codex
```

全部 PASS 才往下；有 FAIL 先照訊息修（改完重跑 `install.sh` 再 verify）。

### 第 2 步：真實行為驗證（引導用戶做這三件事）

1. 請用戶**開一個新的 terminal**（舊 terminal 還在舊環境，測了不算）
2. 請用戶跑 `claude`（或 `codex`），打一句有任務內容的話，例如「列出這個資料夾的檔案」
3. 預期結果：**第一個回合內** terminal tab 變成 `{emoji} 任務描述`
4. Codex 額外驗證 sidebar：

```bash
sqlite3 "$(ls -t ~/.codex/state_*.sqlite | head -1)" \
  "SELECT title FROM threads ORDER BY updated_at_ms DESC LIMIT 1;"
```

### 失敗時（AI agent 的責任，不要只說「裝完了」就結束）

1. Read `installer/TROUBLESHOOTING.md`，按症狀對照表排查；修好後重跑 `install.sh` 再 `verify.sh`
2. 修不掉 → 跑一個指令回報（自動跑 verify --report、收集現場證據、開 issue，不用手工整理）：

```bash
cd jr_ai_agent_skills/installer
./diagnose.sh "{工具} {一句話症狀}"     # 例：./diagnose.sh "codex tab 不改名 @ Cursor"
```

有 `gh` CLI 且已登入會直接開好 issue；沒有則內容進剪貼簿 + 打開預填的 new-issue 頁，請用戶貼上送出。

## 機制細節（debug 時參考）

| 元件 | 位置 | 作用 |
|---|---|---|
| `myclaude` / `mycodex` | `~/.local/bin/` | 建 sync 檔 + 起 watcher + 啟動本體 |
| `ai-tab-sync.sh` | `~/.local/bin/` | watcher：輪詢 sync 檔 → OSC 寫 tty |
| sync 檔 | `~/.ai-session-names/{pid}.txt` | tab 名字的唯一事實來源 |
| `session-auto-namer.sh` | `~/.claude/hooks/` | UserPromptSubmit（第一句話命名）+ PostToolUse（#5 重評、每 10 次兜底） |
| `set-session-name.sh` | `~/.claude/hooks/` | 命名寫入包裝腳本（hook 自動命名與 `/auto-rename` 共用；把寫檔/OSC/清 marker 收進單一腳本，免 `&&` 串接、一條白名單放行） |
| `codex-session-namer.sh` | `~/.codex/hooks/` | 同上 + 消化 relay 檔、代寫 SQLite |
| relay 檔（Codex） | `/tmp/codex-session-namer/{pid}.pending` | 模型在 sandbox 裡唯一能寫的交棒點 |
| skill | `~/.claude/skills/auto-rename/`、`~/.agents/skills/auto-rename/` | 手動 `/auto-rename` 時的規則 |

## 搬遷到其他電腦

新電腦上 clone 本 repo → 讓 AI 跑偵測與確認 → `install.sh` + alias + 已確認的編輯器設定 + `verify.sh` 即可，
不需要從舊電腦複製任何檔案。
