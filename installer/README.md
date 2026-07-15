# AI Session Auto-Rename + Terminal Tab Sync — Installer

一鍵讓 **Claude Code** 和 **Codex CLI** 的 session 自動命名，並同步到 terminal tab title。
支援 iTerm2 / Terminal.app / Cursor / Antigravity（VS Code forks）。macOS / Linux。

## 安裝

```bash
git clone https://github.com/museReed/jr_ai_agent_skills.git
cd jr_ai_agent_skills/installer
./install.sh          # 兩個工具都裝
./install.sh claude   # 只裝 Claude Code
./install.sh codex    # 只裝 Codex
```

裝完把印出的 alias 加進 `~/.zshrc`，重開 terminal。之後照常打 `claude` / `codex`，
第 3 次 tool call 自動用 git branch 命名、第 5 次由 AI 取更好的名字（`{emoji} {中文敘述}`）。

## 架構：命名層 / 持久層 / 顯示層

```
命名層  PostToolUse hook 數 tool call：
        count=3 → git branch 當預設名（不用 LLM）
        count=5 → 注入提示叫 model 取名（之後每 20 次 retry）
           │
持久層  Claude Code → ~/.claude/session-names/<pid>.txt（model 直接寫）
        Codex       → model 寫 /tmp relay 檔 → hook 代寫 SQLite sidebar 名
                      （model 的 sandbox 寫不了 ~/.codex/*.sqlite；hook 不受限）
           │ 兩者都同步寫 $AI_TAB_SYNC_FILE（~/.ai-session-names/<wrapper-pid>.txt）
           ▼
顯示層  myclaude / mycodex wrapper：
        背景 watcher poll sync file → OSC 直寫 /dev/ttysXXX
        （繞過 IDE 對 stdout 的過濾，Cursor / Antigravity 都通）
```

關鍵發現（2026-07-03 驗證，六組合全通：{Claude Code, Codex} × {iTerm2, Cursor, Antigravity}）：

- **OSC 走 stdout 不可靠**：Claude Code 會過濾 ESC bytes，IDE terminal 也常擋。
  **從 wrapper 直寫 tty device 全環境都通**。
- **Codex sandbox**：model 在非 trusted cwd 寫 `~/.codex/state_*.sqlite` 會
  silent fail（`attempt to write a readonly database`）。所以 model 只寫 /tmp
  relay 檔，hook（unsandboxed）在下一次 PostToolUse 代寫。
- **Claude Code 內建 title 會蓋掉自訂名**：wrapper 用
  `CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1` 關掉。
- 不需要設定 `terminal.integrated.tabs.title: ${sequence}`——直寫 tty 繞過模板。

## 檔案清單

| 安裝位置 | 作用 |
|---|---|
| `~/.local/bin/ai-tab-sync.sh` | 通用 watcher：poll sync file → OSC 到 tty |
| `~/.local/bin/myclaude` | Claude Code wrapper（sync file + watcher + 關內建 title） |
| `~/.local/bin/mycodex` | Codex wrapper（sync file + watcher） |
| `~/.claude/hooks/session-auto-namer.sh` | Claude Code 自動命名 hook（註冊進 settings.json） |
| `~/.claude/skills/auto-rename/SKILL.md` | `/auto-rename` 手動命名 skill |
| `~/.codex/hooks/codex-session-namer.sh` | Codex 自動命名 hook（註冊進 hooks.json） |
| `~/.agents/skills/auto-rename/SKILL.md` | `$auto-rename` 手動命名 skill |

## 不用 wrapper 也能動（degraded mode）

直接跑原生 `claude`（沒 alias）時，hook 會在每次 tool call 把已存的名稱
OSC 直寫 tty——tab 仍會更新，但要自己設 `CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1`。
Codex 沒 wrapper 時只有 sidebar 名（SQLite），terminal tab 不會動。

## 已知限制

- Windows 未支援（無 `/dev/ttysXXX`，ConPTY 需另行設計）
- Antigravity 直接啟動（非 terminal 內）時，sidebar 命名靠 SQLite 路徑；
  title script 整合見 repo 內 `zh-Hant/auto-rename-install.md` Section C/D
- 名稱請避免單引號

## 驗證

```bash
# 裝完開新 terminal，跑 claude 或 codex，做 3 次以上 tool call：
ls ~/.ai-session-names/          # 應出現 <pid>.txt 且內容是 session 名
cat ~/.claude/session-names/*.txt 2>/dev/null   # Claude Code 命名結果
sqlite3 "$(ls -t ~/.codex/state_*.sqlite | head -1)" \
  "SELECT title FROM threads ORDER BY updated_at_ms DESC LIMIT 3;"  # Codex sidebar
```
