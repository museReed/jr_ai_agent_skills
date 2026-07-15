# Auto-Rename Skill — 安裝指南

Read this document, then execute the installation steps for your tool (Section A or Section B). Do not ask for confirmation — just do it. Execute every step sequentially, do not skip any step. **Installation is NOT complete until you have walked the user through the "E2E 驗證" section.**

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

## Section A: Claude Code 安裝

所有 script 都在本 repo 的 `installer/`，一個指令裝完（hooks + skills + 註冊）：

```bash
cd jr_ai_agent_skills/installer
./install.sh claude
```

然後把 alias 寫進 shell rc（**AI 直接執行寫入，不要只印給用戶看**；冪等，已存在就不重複加）：

```bash
RC="$HOME/.zshrc"; case "$SHELL" in *bash*) RC="$HOME/.bashrc";; esac
grep -q "alias claude=.*myclaude" "$RC" 2>/dev/null \
  || echo "alias claude='\$HOME/.local/bin/myclaude'" >> "$RC"
echo "已寫入 $RC — 請重開 terminal 或 source 它，alias 沒生效＝功能沒生效"
```

裝完跳到「編輯器設定」。

## Section B: Codex CLI 安裝

```bash
cd jr_ai_agent_skills/installer
./install.sh codex
```

alias（**AI 直接執行寫入**，冪等）：

```bash
RC="$HOME/.zshrc"; case "$SHELL" in *bash*) RC="$HOME/.bashrc";; esac
grep -q "alias codex=.*mycodex" "$RC" 2>/dev/null \
  || echo "alias codex='\$HOME/.local/bin/mycodex'" >> "$RC"
echo "已寫入 $RC — 請重開 terminal 或 source 它"
```

> 兩個工具都用 → `./install.sh`（不帶參數），兩個 alias 都加。
> installer 是冪等的：重跑安全；Codex skill 備份放在 `~/.agents/skill-backups/{timestamp}/`，其他檔案使用 `*.bak.{timestamp}`。

## 編輯器設定（VS Code 系必做，iTerm / Terminal.app 跳過）

Cursor、Antigravity、VS Code 的 terminal tab **預設不顯示** OSC 標題，必須在該編輯器的
`settings.json` 加 `"terminal.integrated.tabs.title": "${sequence}"`。

**AI 直接執行（不要叫用戶走 Cmd+Shift+P）**：判斷用戶用哪個編輯器（存在哪個路徑就設哪個），
用下面的 python 把 key **merge 進去（保留既有設定）**，檔案不存在就建。macOS 路徑：

| 編輯器 | settings.json 路徑 |
|---|---|
| Cursor | `~/Library/Application Support/Cursor/User/settings.json` |
| Antigravity | `~/Library/Application Support/Antigravity/User/settings.json` |
| VS Code | `~/Library/Application Support/Code/User/settings.json` |

```bash
python3 - "<上表對應路徑>" <<'PY'
import json, os, sys
p = os.path.expanduser(sys.argv[1])
os.makedirs(os.path.dirname(p), exist_ok=True)
cfg = {}
if os.path.exists(p):
    with open(p) as f:
        cfg = json.load(f)          # 若含 // 註解會 raise → 走下方 fallback
cfg["terminal.integrated.tabs.title"] = "${sequence}"
with open(p, "w") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
print("set terminal.integrated.tabs.title in", p)
PY
```

- **只對存檔後新開的 terminal 生效** → 設完請用戶新開一個 terminal
- 用哪個編輯器就設哪個（各有各的 settings.json）
- Fallback：上述路徑都找不到、或 python 因 JSONC 註解報錯 → 請用戶
  Cmd+Shift+P → "Open User Settings (JSON)" 手動加那一行。**報錯時原檔不會被動到**
  （json.load 在讀取階段就失敗、還沒寫入），放心走手動

## E2E 驗證（AI agent 必須主動引導用戶完成，不可跳過）

> 完整逐步引導劇本（四輪 × 檢查點編號）→ Read `installer/VERIFICATION.md`，照它帶用戶跑。

### 第 1 步：自動檢查

```bash
cd jr_ai_agent_skills/installer
./verify.sh          # 或 ./verify.sh claude / ./verify.sh codex
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
| `codex-session-namer.sh` | `~/.codex/hooks/` | 同上 + 消化 relay 檔、代寫 SQLite |
| relay 檔（Codex） | `/tmp/codex-session-namer/{pid}.pending` | 模型在 sandbox 裡唯一能寫的交棒點 |
| skill | `~/.claude/skills/auto-rename/`、`~/.agents/skills/auto-rename/` | 手動 `/auto-rename` 時的規則 |

## 搬遷到其他電腦

新電腦上 clone 本 repo → 跑同樣的 `install.sh` + alias + 編輯器設定 + `verify.sh` 即可，
不需要從舊電腦複製任何檔案。
