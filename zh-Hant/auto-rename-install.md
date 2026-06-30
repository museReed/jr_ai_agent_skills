# Auto-Rename Skill — 安裝指南

Read this document, then execute the installation steps for your tool (Section A or Section B). Do not ask for confirmation — just do it. Execute every step sequentially, do not skip any step.

功能介紹見 [auto-rename-skill.md](./auto-rename-skill.md)。

---

## Section A: Claude Code 安裝

Claude Code 版包含兩個部分：(1) Skill 本體，讓你手動呼叫 `/auto-rename`；(2) Hook，讓 AI 在第 5 次 tool call 時自動命名。

### Step 1: 建立目錄 + 寫入 SKILL.md

```bash
mkdir -p .claude/skills/auto-rename
```

Create the file `.claude/skills/auto-rename/SKILL.md` with the following content:

```markdown
---
name: auto-rename
description: >-
  Use when renaming the current session based on conversation context.
  Triggers on "rename", "auto-rename", "命名", "改名", "session name".
allowed-tools: [Bash]
---

# Auto-Rename — Session Naming Utility

## Quick Reference

根據對話內容為 session 命名，寫入 session-names 檔 + 改 terminal tab title。

1. 讀對話脈絡 → 決定 `{emoji} {中文敘述}`（≤ 40 字元，emoji 見 §Emoji Mapping）
2. 一個 Bash call 完成：PID 定位 + 寫檔 + 改 tab + 清 marker
3. 回報新名稱，一句話結束

Key rules:
- 根據對話「主要目的」選 emoji，不是最新一句話
- 技術名詞保留英文，敘述用中文
- 步驟 2 合併成一個 Bash 指令執行，不分多次

## Emoji Mapping

| Emoji | 動作 | 範例 |
|---|---|---|
| 🏗️ | build / implement / refactor / migrate | 🏗️ 語音建模 pipeline |
| 🔧 | fix / hotfix | 🔧 爬蟲重試邏輯 |
| 🐛 | debug | 🐛 Gemini Vision blockReason |
| 📐 | plan / design | 📐 PRD2 classify-enrich |
| 📋 | review / audit | 📋 PRD 架構設計 |
| 💬 | discuss | 💬 auto-rename emoji 定義 |
| ⛴️ | pilot / spike | ⛴️ knowledge-distill 驗證 |
| 🔍 | research / investigate | 🔍 cron 失敗原因 |

## When to Use

- Hook 自動觸發後（hook 注入 `[session-namer]` additionalContext 時）
- 用戶手動打 `/auto-rename`
- 對話主題明顯偏移，舊名稱不再準確時

## When NOT to Use

- Session 剛開始（< 3 輪 tool call），資訊不足
- 用戶已手動指定名稱

## Execution Flow

### Step 1: 決定名稱

讀對話歷史，判斷主要目的，從 Emoji Mapping 選一個 + 寫中文敘述。

✅ DO: 用對話的核心任務命名（「🏗️ voice profile rebuild」）
❌ DON'T: 用最新一句話命名（「💬 確認 terminal 相容性」←太窄）

### Step 2: 執行命名

```bash
TERMINAL_PID=$(ps -o ppid= -p $PPID 2>/dev/null | tr -d ' ') && \
mkdir -p ~/.claude/session-names && \
echo '{名稱}' > ~/.claude/session-names/${TERMINAL_PID}.txt && \
printf '\033]0;{名稱}\007' && \
rm -f /tmp/claude-session-namer/$PPID.default
```

### Step 3: 回報

告訴用戶新名稱，一句話結束。

## Common Mistakes

| Mistake | Why it fails | Fix |
|---------|-------------|-----|
| 用最新一句話命名 | 不代表整個 session 的目的 | 回顧整個對話脈絡再決定 |
| 名稱超過 40 字元 | sidebar 顯示被截斷 | 精簡敘述，技術名詞可縮寫 |
| 忘記清除 default marker | hook 會持續每 20 次 tool call 重新提醒 | 步驟 2 的 rm 不可省略 |
| 分多個 Bash call 執行 | 浪費 tool call 額度 | 合併成一條指令 |
```

### Step 2: 安裝自動命名 Hook

這個 hook 讓 AI 在對話進行中自動命名 session，不需手動打 `/auto-rename`。

#### 2a: 建立 hook 腳本

```bash
mkdir -p ~/.claude/hooks
```

Create the file `~/.claude/hooks/session-auto-namer.sh` with the following content:

```bash
#!/bin/bash
# PostToolUse hook: auto-name Claude Code terminal tabs.
# 1. At count=3: write git branch name as default (100% reliable, no Claude needed)
# 2. At count=5: ask Claude for a better descriptive name
# 3. Retry every 20 tool uses if Claude hasn't improved the default name

CLAUDE_PID=$PPID
COUNTER_DIR="/tmp/claude-session-namer"
mkdir -p "$COUNTER_DIR"
COUNTER_FILE="$COUNTER_DIR/$CLAUDE_PID"

# Read and increment counter
COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"

# Find terminal shell PID (claude's parent = terminal zsh = Terminal.processId)
TERMINAL_PID=$(ps -o ppid= -p "$CLAUDE_PID" 2>/dev/null | tr -d ' ')
SESSION_FILE="$HOME/.claude/session-names/${TERMINAL_PID}.txt"
NAMES_DIR="$HOME/.claude/session-names"
# Track whether name was set by hook (default) vs Claude (improved)
DEFAULT_MARKER="$COUNTER_DIR/${CLAUDE_PID}.default"

set_session_name() {
  local name="$1"
  mkdir -p "$NAMES_DIR"
  echo "$name" > "$SESSION_FILE"
}

# At count=3: write git branch name as default (immediate, no Claude needed)
if [ "$COUNT" -eq 3 ]; then
  SHELL_CWD=$(lsof -d cwd -p "$TERMINAL_PID" -Fn 2>/dev/null | grep '^n' | head -1 | sed 's|^n||')
  if [ -n "$SHELL_CWD" ]; then
    BRANCH=$(git -C "$SHELL_CWD" branch --show-current 2>/dev/null)
    if [ -n "$BRANCH" ]; then
      NAME=$(echo "$BRANCH" | sed 's|^feature/||;s|^fix/||;s|^hotfix/||')
    else
      NAME=$(basename "$SHELL_CWD")
    fi
    set_session_name "$NAME"
    touch "$DEFAULT_MARKER"
  fi
fi

# At count=5, and retry every 20 uses if Claude hasn't improved the default name
NEEDS_BETTER_NAME=false
if [ "$COUNT" -eq 5 ]; then
  NEEDS_BETTER_NAME=true
elif [ "$COUNT" -gt 5 ] && [ $(( COUNT % 20 )) -eq 0 ] && [ -f "$DEFAULT_MARKER" ]; then
  NEEDS_BETTER_NAME=true
fi

if [ "$NEEDS_BETTER_NAME" = true ]; then
  cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"[session-namer] 請為此 session 命名並寫入檔案。\n\n命名規則：\n- 格式：{emoji} {中文敘述}，emoji 取代英文動詞，技術名詞可保留英文\n- 總長度 ≤ 40 字元\n\nEmoji mapping（8 個核心動作）：\n🏗️ build/implement/refactor/migrate → 🏗️ 語音建模 pipeline\n🔧 fix/hotfix → 🔧 爬蟲重試邏輯\n🐛 debug → 🐛 Gemini Vision blockReason\n📐 plan/design → 📐 PRD2 classify-enrich\n📋 review/audit → 📋 PRD 架構設計\n💬 discuss → 💬 auto-rename emoji 定義\n⛴️ pilot/spike → ⛴️ knowledge-distill 驗證\n🔍 research/investigate → 🔍 cron 失敗原因\n\n執行後請刪除 marker：rm -f /tmp/claude-session-namer/${CLAUDE_PID}.default\n\n執行指令：\nmkdir -p ~/.claude/session-names && echo '{名稱}' > ~/.claude/session-names/${TERMINAL_PID}.txt && rm -f /tmp/claude-session-namer/${CLAUDE_PID}.default"}}
EOF
fi
```

#### 2b: 設定執行權限

```bash
chmod +x ~/.claude/hooks/session-auto-namer.sh
```

#### 2c: 註冊 Hook 到 settings.json

**操作方式**：Read `~/.claude/settings.json`。根據檔案現有狀態，選擇下面對應的做法：

**情況 A — 檔案不存在**：Create `~/.claude/settings.json` with this content:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/session-auto-namer.sh",
            "timeout": 3
          }
        ]
      }
    ]
  }
}
```

**情況 B — 檔案存在但沒有 `hooks` key**：在 JSON 頂層加入整個 `"hooks"` object（同情況 A 的 hooks 部分）。

**情況 C — 檔案存在且已有 `hooks.PostToolUse`**：在 `hooks.PostToolUse[0].hooks` array 末尾 append 一個 entry：

```json
{
  "type": "command",
  "command": "bash ~/.claude/hooks/session-auto-namer.sh",
  "timeout": 3
}
```

**情況 D — 檔案存在且已有 `hooks` 但沒有 `PostToolUse`**：在 `hooks` object 中加入 `"PostToolUse"` key（同情況 A 的 PostToolUse 部分）。

**衝突檢查**：如果 `hooks.PostToolUse[*].hooks[*].command` 中已經包含 `session-auto-namer.sh`，跳過此步（已安裝）。

### Step 3: 驗證

執行以下兩個檢查，確認安裝成功：

```bash
head -5 .claude/skills/auto-rename/SKILL.md
```

預期：輸出以 `---` 開頭，含 `name: auto-rename`。

```bash
test -x ~/.claude/hooks/session-auto-namer.sh && echo "Hook OK" || echo "Hook MISSING"
```

預期：輸出 `Hook OK`。

```bash
python3 -c "import json; d=json.load(open('$HOME/.claude/settings.json')); hooks=[h['command'] for g in d.get('hooks',{}).get('PostToolUse',[]) for h in g.get('hooks',[])]; print('Hook registered' if any('session-auto-namer' in c for c in hooks) else 'Hook NOT registered')"
```

預期：輸出 `Hook registered`。

### Done

回報：「auto-rename skill 已安裝。包含 SKILL.md + 自動命名 hook。觸發方式：自動（第 5 次 tool call 後）或手動 `/auto-rename`。」

---

## Section B: Codex CLI 安裝

> **與 Claude Code 版的差異**：Codex 沒有自動觸發 hook，只能手動呼叫。
> 命名方式是寫入 SQLite 資料庫，而非寫檔案。

### Step 1: 建立目錄 + 寫入 SKILL.md

```bash
mkdir -p .codex/skills/auto-rename
mkdir -p .codex/skills/_shared
```

Create the file `.codex/skills/auto-rename/SKILL.md` with the following content:

```markdown
---
name: auto-rename
description: >-
  Use when renaming the current session based on conversation context.
  Triggers on "rename", "auto-rename", "命名", "改名", "session name".
---

# Auto-Rename — Session Naming Utility (Codex-Compatible)

## Quick Reference

根據對話內容為 session 命名，直接寫 SQLite + 改 terminal tab title。

1. 讀對話脈絡 → 決定 `{emoji} {中文敘述}`（≤ 40 字元，emoji 見 §Emoji Mapping）
2. 按 `.codex/skills/_shared/codex-session-rename.md` 執行 SQLite UPDATE
3. 回報新名稱，一句話結束

Key rules:
- 根據對話「主要目的」選 emoji，不是最新一句話
- 技術名詞保留英文，敘述用中文
- Terminal tab 需用 mycodex wrapper 啟動才會自動同步；skill 只更新 SQLite

## Emoji Mapping

| Emoji | 動作 | 範例 |
|---|---|---|
| 🏗️ | build / implement / refactor / migrate | 🏗️ 語音建模 pipeline |
| 🔧 | fix / hotfix | 🔧 爬蟲重試邏輯 |
| 🐛 | debug | 🐛 Gemini Vision blockReason |
| 📐 | plan / design | 📐 PRD2 classify-enrich |
| 📋 | review / audit | 📋 PRD 架構設計 |
| 💬 | discuss | 💬 auto-rename emoji 定義 |
| ⛴️ | pilot / spike | ⛴️ knowledge-distill 驗證 |
| 🔍 | research / investigate | 🔍 cron 失敗原因 |

## Runtime Detection

改名方法（含 SQLite 指令、環境偵測、注意事項）→ Read `.codex/skills/_shared/codex-session-rename.md`

## When to Use

- 用戶手動打 `$auto-rename`
- 對話主題明顯偏移，舊名稱不再準確時

## When NOT to Use

- Session 剛開始（< 3 輪 tool call），資訊不足
- 用戶已手動指定名稱

## Execution Flow

### Step 1: 決定名稱

讀對話歷史，判斷主要目的，從 Emoji Mapping 選一個 + 寫中文敘述。

✅ DO: 用對話的核心任務命名
❌ DON'T: 用最新一句話命名

### Step 2: 執行命名

按 `.codex/skills/_shared/codex-session-rename.md` 的指令執行（SQLite UPDATE + terminal tab）。

### Step 3: 回報

告訴用戶新名稱，一句話結束。

## Common Mistakes

| Mistake | Why it fails | Fix |
|---------|-------------|-----|
| 用最新一句話命名 | 不代表整個 session 的目的 | 回顧整個對話脈絡再決定 |
| 名稱超過 40 字元 | 顯示被截斷 | 精簡敘述 |
| 名稱含單引號 | SQL 語法錯誤 | 用雙引號包 SQL value，或轉義單引號 |
| 用 ORDER BY updated_at_ms 找 session | 多 session 同時開會改錯 | 用 $CODEX_THREAD_ID 定位 |
```

### Step 2: 建立共用參考文件

Create the file `.codex/skills/_shared/codex-session-rename.md` with the following content:

```markdown
# Codex Session Rename — 共用參考文件

> 任何需要手動改 Codex session 名稱的 skill，引用此文件取得方法。
> 不要各自重寫 — 改版時只改這一份。

---

## 原理

Codex 把 session 資料存在 SQLite（`~/.codex/state_*.sqlite`），每個 session 是 `threads` 表的一筆 row。
`/title` 指令背後就是 UPDATE `threads.title` — 我們直接用 `sqlite3` 做一樣的事。

## 改名指令

# 1. 取得 Codex thread ID
SESSION_ID="${CODEX_THREAD_ID}"

# 2. 找到 SQLite DB（支援版號變更）
CODEX_DB=$(ls -t ~/.codex/state_*.sqlite 2>/dev/null | head -1)

# 3. 先確認 target row 是這次對話
sqlite3 -header -column "$CODEX_DB" \
  "SELECT id, title, first_user_message FROM threads WHERE id='${SESSION_ID}';"

# 4. 改名
sqlite3 "$CODEX_DB" "UPDATE threads SET title='新名稱', preview='新名稱' WHERE id='${SESSION_ID}';"

## 注意事項

| 項目 | 說明 |
|---|---|
| **Session 定位** | 用 `$CODEX_THREAD_ID` 環境變數定位，不用 `ORDER BY updated_at_ms DESC LIMIT 1` |
| **SQLite locking** | 短暫 UPDATE 不會跟 Codex 衝突 |
| **版號變更** | DB 檔名可能從 `state_5.sqlite` 變成 `state_6`，用 `ls -t state_*.sqlite | head -1` 適配 |
| **單引號轉義** | 名稱含 `'` 時用 `''` 跳脫 |
| **preview 欄位** | 必須跟 title 一起改，否則 sidebar 顯示舊文字 |
| **Claude Code 環境** | 偵測 `$HOME/.claude/session-names` 存在 → 走 Claude Code 路徑（寫檔），不走 SQLite |
```

### Step 3: 安裝 Terminal Tab 同步 Wrapper（可選但強烈建議）

Codex 預設不會同步 terminal tab title。這個 wrapper 會在背景監聽 SQLite 的 session title 變化，自動更新 terminal tab 名稱。

#### 3a: 建立 wrapper 腳本

```bash
mkdir -p ~/.local/bin
```

Create the file `~/.local/bin/codex-title-wrapper.sh` with the following content:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Codex launcher wrapper.
# Watches the exact Codex thread launched by this wrapper, then emits OSC title
# escapes to this terminal. Multiple sessions won't interfere with each other.

title_for_thread() {
  local db="$1"
  local thread_id="$2"

  sqlite3 "$db" "
    SELECT title
    FROM threads
    WHERE id = '${thread_id}'
      AND title IS NOT NULL
      AND title != ''
    LIMIT 1;
  " 2>/dev/null || true
}

native_codex_pid_for_wrapper() {
  local wrapper_pid="$1"
  local node_pid=""

  node_pid=$(ps -axo pid,ppid,args 2>/dev/null \
    | awk -v ppid="$wrapper_pid" '$2 == ppid && $0 ~ /node .*\/bin\/codex/ { print $1; exit }')
  [ -n "$node_pid" ] || return 0

  ps -axo pid,ppid,args 2>/dev/null \
    | awk -v ppid="$node_pid" '$2 == ppid && $0 ~ /vendor\/.*\/bin\/codex/ { print $1; exit }'
}

thread_id_from_open_rollout() {
  local codex_pid="$1"
  [ -n "$codex_pid" ] || return 0

  lsof -p "$codex_pid" 2>/dev/null \
    | awk '/\/\.codex\/sessions\/.*rollout-.*\.jsonl/ { print $NF; exit }' \
    | grep -Eo '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' \
    | tail -1 \
    || true
}

emit_title() {
  local tty_path="$1"
  local title="$2"

  [ -n "$tty_path" ] || return 0
  [ -n "$title" ] || return 0
  [ -w "$tty_path" ] || return 0

  printf '\033]0;%s\007\033]1;%s\007\033]2;%s\007' "$title" "$title" "$title" > "$tty_path" 2>/dev/null || true
}

watch_title() {
  local wrapper_pid="$1"
  local tty_path="$2"
  local bound_thread_id=""
  local codex_pid=""
  local last_title=""
  local thread_id=""
  local title=""
  local db=""

  while kill -0 "$wrapper_pid" 2>/dev/null; do
    if [ -z "$bound_thread_id" ]; then
      codex_pid=$(native_codex_pid_for_wrapper "$wrapper_pid")
      thread_id=$(thread_id_from_open_rollout "$codex_pid")
      if [ -n "$thread_id" ]; then
        bound_thread_id="$thread_id"
      fi
    fi

    thread_id="$bound_thread_id"
    db=$(ls -t "${HOME}"/.codex/state_*.sqlite 2>/dev/null | head -1 || true)
    if [ -n "$thread_id" ] && [ -n "$db" ] && [ -f "$db" ]; then
      title=$(title_for_thread "$db" "$thread_id")
      if [ -n "$title" ] && [ "$title" != "$last_title" ]; then
        emit_title "$tty_path" "$title"
        last_title="$title"
      fi
    fi
    sleep 1
  done
}

TTY_PATH=$(tty 2>/dev/null || true)

WATCHER_PID=""
if [ -n "$TTY_PATH" ] && [ "$TTY_PATH" != "not a tty" ]; then
  watch_title "$$" "$TTY_PATH" &
  WATCHER_PID=$!
fi

cleanup() {
  if [ -n "$WATCHER_PID" ]; then
    kill "$WATCHER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

codex "$@"
```

#### 3b: 建立 mycodex 啟動器

Create the file `~/.local/bin/mycodex` with the following content:

```bash
#!/usr/bin/env bash
set -euo pipefail
exec ~/.local/bin/codex-title-wrapper.sh "$@"
```

#### 3c: 設定執行權限 + alias

```bash
chmod +x ~/.local/bin/codex-title-wrapper.sh ~/.local/bin/mycodex
```

在 `~/.zshrc`（或 `~/.bashrc`）末尾加入：

```bash
# 如果 ~/.local/bin 不在 PATH 中，加入它
export PATH="$HOME/.local/bin:$PATH"
# alias：用 mycodex 取代 codex 以啟用 terminal tab 同步
alias mycodex='~/.local/bin/mycodex'
```

加完後執行 `source ~/.zshrc`（或重開 terminal）使其生效。

> **使用方式**：之後用 `mycodex` 取代 `codex` 啟動 Codex CLI，terminal tab 就會自動同步 session title。

### Step 4: 驗證

```bash
head -5 .codex/skills/auto-rename/SKILL.md
```

預期：輸出以 `---` 開頭，含 `name: auto-rename`。

```bash
head -3 .codex/skills/_shared/codex-session-rename.md
```

預期：輸出 `# Codex Session Rename`。

```bash
test -x ~/.local/bin/mycodex && echo "Wrapper OK" || echo "Wrapper MISSING"
```

預期：輸出 `Wrapper OK`。

### Done

回報：「auto-rename skill 已安裝。包含 SKILL.md + 共用參考文件 + terminal tab 同步 wrapper。手動輸入 `$auto-rename` 命名，用 `mycodex` 啟動 Codex 可自動同步 tab title。」

---

## 驗證

安裝完成後，用以下測試確認 skill 正常運作。每個 test 執行後，對照「預期」確認行為正確。

### Test 1: 手動觸發

> 對 AI 說：「幫我把這個 session 改個名字」
>
> **預期**：AI 根據對話內容，用 emoji + 中文命名（如「📋 auto-rename 安裝驗證」），並執行寫入指令。Claude Code 會改 terminal tab title；Codex 會更新 SQLite。

### Test 2: 自動觸發（僅 Claude Code）

> 正常使用 Claude Code，在第 5 次 tool call 後觀察。
>
> **預期**：AI 收到 `[session-namer]` 的 hook 提示後，自動執行命名。Terminal tab 從 branch 名變成描述性名稱。

### Test 3: 不該觸發的情況

> 在 session 的前兩輪對話中說：「這個變數要 rename 成 foo」
>
> **預期**：AI 執行變數重新命名，不觸發 session 改名。「rename」在程式碼脈絡中不應觸發 auto-rename skill。

### Test 4: 名稱品質

> 開一個 session，做三件事：(1) 讀一個檔案 (2) 修一個 bug (3) 跑測試。然後打 `/auto-rename`。
>
> **預期**：名稱反映主要任務（如「🔧 修 API 回傳格式」），不是最後一個動作（如「🔍 跑測試」）。

### Test 5: Codex 專用 — SQLite 寫入

> 在 Codex 中打 `$auto-rename`
>
> **預期**：AI 用 `sqlite3` 更新 `threads` 表的 `title` 和 `preview` 欄位。可用以下指令驗證：
> ```bash
> CODEX_DB=$(ls -t ~/.codex/state_*.sqlite 2>/dev/null | head -1)
> sqlite3 "$CODEX_DB" "SELECT id, title FROM threads ORDER BY updated_at_ms DESC LIMIT 1;"
> ```

### Test 6: Codex 專用 — mycodex wrapper Tab 同步

> 用 `mycodex` 啟動 Codex（不是 `codex`），開始一段對話後打 `$auto-rename`。
>
> **預期**：AI 執行 SQLite UPDATE 後，terminal tab title 自動從預設名稱變成 session 名稱（如「🔧 爬蟲重試邏輯」）。如果用 `codex` 啟動則 tab 不會同步——這是預期行為。

### 驗證結果判讀

| 結果 | 處理方式 |
|---|---|
| 全部 test 通過 | 安裝成功 |
| Test 1 沒觸發 | 檢查 SKILL.md 的 `description` 是否包含 trigger keywords（rename、改名） |
| Test 2 hook 沒觸發 | 檢查 `~/.claude/settings.json` 是否正確註冊 hook，且腳本有執行權限 |
| Test 3 誤觸發 | 正常現象——keyword 有重疊。如果頻繁誤觸，在 SKILL.md 的 When NOT to Use 加上「程式碼 rename 變數」 |
| Test 4 名稱太窄 | 檢查 SKILL.md 的 Step 1 是否強調「用對話核心任務命名」 |
| Test 5 SQLite 沒更新 | 檢查 `$CODEX_THREAD_ID` 環境變數是否存在，以及 DB 路徑是否正確 |
