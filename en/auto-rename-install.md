# Auto-Rename Skill — Installation Guide

Read this document, then execute the installation steps for your tool (Section A or Section B). Do not ask for confirmation — just do it. Execute every step sequentially, do not skip any step.

See [auto-rename-skill.md](./auto-rename-skill.md) for feature overview.

---

## Section A: Claude Code Installation

The Claude Code version includes two parts: (1) The Skill itself, allowing you to manually call `/auto-rename`; (2) A Hook that automatically names sessions at the 5th tool call.

### Step 1: Create directory + write SKILL.md

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

### Step 2: Install the auto-naming Hook

This hook lets the AI automatically name sessions during conversation, without needing to manually type `/auto-rename`.

#### 2a: Create the hook script

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

#### 2b: Set executable permission

```bash
chmod +x ~/.claude/hooks/session-auto-namer.sh
```

#### 2c: Register Hook in settings.json

**How to**: Read `~/.claude/settings.json`. Based on the file's current state, follow the matching approach below:

**Case A -- File doesn't exist**: Create `~/.claude/settings.json` with this content:

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

**Case B -- File exists but has no `hooks` key**: Add the entire `"hooks"` object at the JSON top level (same as the hooks part in Case A).

**Case C -- File exists and already has `hooks.PostToolUse`**: Append one entry to the end of the `hooks.PostToolUse[0].hooks` array:

```json
{
  "type": "command",
  "command": "bash ~/.claude/hooks/session-auto-namer.sh",
  "timeout": 3
}
```

**Case D -- File exists and has `hooks` but no `PostToolUse`**: Add the `"PostToolUse"` key to the `hooks` object (same as the PostToolUse part in Case A).

**Conflict check**: If `hooks.PostToolUse[*].hooks[*].command` already contains `session-auto-namer.sh`, skip this step (already installed).

### Step 3: Verify

Run the following two checks to confirm successful installation:

```bash
head -5 .claude/skills/auto-rename/SKILL.md
```

Expected: Output starts with `---` and contains `name: auto-rename`.

```bash
test -x ~/.claude/hooks/session-auto-namer.sh && echo "Hook OK" || echo "Hook MISSING"
```

Expected: Output is `Hook OK`.

```bash
python3 -c "import json; d=json.load(open('$HOME/.claude/settings.json')); hooks=[h['command'] for g in d.get('hooks',{}).get('PostToolUse',[]) for h in g.get('hooks',[])]; print('Hook registered' if any('session-auto-namer' in c for c in hooks) else 'Hook NOT registered')"
```

Expected: Output is `Hook registered`.

### Done

Report: "auto-rename skill installed. Includes SKILL.md + auto-naming hook. Trigger: automatic (after the 5th tool call) or manual `/auto-rename`."

---

## Section B: Codex CLI Installation

> **Differences from the Claude Code version**: Codex has no auto-trigger hook; it can only be called manually.
> The naming method writes to a SQLite database instead of a file.

### Step 1: Create directory + write SKILL.md

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

### Step 2: Create shared reference file

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

### Step 3: Install Terminal Tab Sync Wrapper (optional but strongly recommended)

Codex doesn't sync terminal tab titles by default. This wrapper monitors SQLite session title changes in the background and automatically updates the terminal tab name.

#### 3a: Create the wrapper script

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

#### 3b: Create the mycodex launcher

Create the file `~/.local/bin/mycodex` with the following content:

```bash
#!/usr/bin/env bash
set -euo pipefail
exec ~/.local/bin/codex-title-wrapper.sh "$@"
```

#### 3c: Set permissions + alias

```bash
chmod +x ~/.local/bin/codex-title-wrapper.sh ~/.local/bin/mycodex
```

Add the following to the end of `~/.zshrc` (or `~/.bashrc`):

```bash
# Add ~/.local/bin to PATH if not already there
export PATH="$HOME/.local/bin:$PATH"
# Alias: use mycodex instead of codex to enable terminal tab sync
alias mycodex='~/.local/bin/mycodex'
```

After adding, run `source ~/.zshrc` (or reopen terminal) to apply.

> **Usage**: Launch Codex CLI with `mycodex` instead of `codex`, and the terminal tab will automatically sync with the session title.

### Step 4: Verify

```bash
head -5 .codex/skills/auto-rename/SKILL.md
```

Expected: Output starts with `---` and contains `name: auto-rename`.

```bash
head -3 .codex/skills/_shared/codex-session-rename.md
```

Expected: Output is `# Codex Session Rename`.

```bash
test -x ~/.local/bin/mycodex && echo "Wrapper OK" || echo "Wrapper MISSING"
```

Expected: Output is `Wrapper OK`.

### Done

Report: "auto-rename skill installed. Includes SKILL.md + shared reference file + terminal tab sync wrapper. Use `$auto-rename` to name sessions manually, launch Codex with `mycodex` to auto-sync tab titles."

---

## Verification

After installation, use the following tests to confirm the skill works correctly. After running each test, check against the "Expected" result to confirm correct behavior.

### Test 1: Manual trigger

> Tell the AI: "Help me rename this session"
>
> **Expected**: The AI names it based on conversation content using emoji + description (e.g., "📋 auto-rename installation verification") and executes the write command. Claude Code will change the terminal tab title; Codex will update SQLite.

### Test 2: Auto trigger (Claude Code only)

> Use Claude Code normally and observe after the 5th tool call.
>
> **Expected**: After the AI receives the `[session-namer]` hook prompt, it automatically names the session. The terminal tab changes from the branch name to a descriptive name.

### Test 3: Should NOT trigger

> In the first two rounds of a session, say: "Rename this variable to foo"
>
> **Expected**: The AI renames the variable, without triggering session renaming. "Rename" in a code context should not trigger the auto-rename skill.

### Test 4: Name quality

> Open a session, do three things: (1) read a file (2) fix a bug (3) run tests. Then type `/auto-rename`.
>
> **Expected**: The name reflects the main task (e.g., "🔧 Fix API response format"), not the last action (e.g., "🔍 Run tests").

### Test 5: Codex-specific -- SQLite write

> In Codex, type `$auto-rename`
>
> **Expected**: The AI uses `sqlite3` to update the `title` and `preview` fields in the `threads` table. You can verify with:
> ```bash
> CODEX_DB=$(ls -t ~/.codex/state_*.sqlite 2>/dev/null | head -1)
> sqlite3 "$CODEX_DB" "SELECT id, title FROM threads ORDER BY updated_at_ms DESC LIMIT 1;"
> ```

### Test 6: Codex-specific -- mycodex wrapper tab sync

> Launch Codex using `mycodex` (not `codex`), start a conversation, then type `$auto-rename`.
>
> **Expected**: After the AI executes the SQLite UPDATE, the terminal tab title automatically changes from the default name to the session name (e.g., "🔧 Fix retry logic"). If launched with `codex` instead, the tab won't sync -- this is expected behavior.

### Verification Result Guide

| Result | Action |
|---|---|
| All tests pass | Installation successful |
| Test 1 didn't trigger | Check if the SKILL.md `description` contains trigger keywords (rename) |
| Test 2 hook didn't trigger | Check if `~/.claude/settings.json` has the hook registered correctly, and the script has execute permission |
| Test 3 false trigger | Normal -- keywords overlap. If it happens frequently, add "variable renaming in code" to the When NOT to Use section in SKILL.md |
| Test 4 name too narrow | Check if Step 1 in SKILL.md emphasizes "name based on the core task of the conversation" |
| Test 5 SQLite not updated | Check if the `$CODEX_THREAD_ID` environment variable exists and the DB path is correct |

---

## Section C: Cursor / VS Code Terminal Tab Sync Setup

Auto-rename uses OSC escape sequences (`\033]0;title\007`) to change terminal tab names. Cursor and VS Code both use xterm.js under the hood, which supports OSC, but the default tab title format overrides OSC output.

### Step 1: Modify Settings

Open Cursor / VS Code Settings (JSON) and add:

```json
"terminal.integrated.tabs.title": "${sequence}"
```

- `${sequence}` = use the OSC escape sent by the terminal as the tab title — this is what the auto-rename hook needs
- The default value `${task}${separator}${local}${separator}${cwdFolder}` overrides OSC and must be changed

### Step 2: Verify OSC Support

Run this in the Cursor / VS Code terminal:

```bash
printf '\033]0;Test Rename\007'
```

**Expected**: The terminal tab name changes to "Test Rename". If nothing happens, go back to Step 1 and confirm the setting was saved.

### Known Scenarios

| Scenario | Result |
|---|---|
| Cursor / VS Code integrated terminal | Works after setting `${sequence}` |
| SSH remote session | Usually passes through, but some SSH configs strip OSC |
| macOS Terminal / iTerm2 | Native OSC support, no extra setup needed |

---

## Section D: Migration to Another Computer

### Files Needed for Claude Code

| # | File / Directory | Purpose |
|---|---|---|
| 1 | `~/.claude/skills/auto-rename/SKILL.md` | Skill definition (naming rules, emoji mapping) |
| 2 | `~/.claude/hooks/session-auto-namer.sh` | PostToolUse hook (counter + trigger rename + emit OSC) |
| 3 | `~/.claude/settings.json` | Hook registration (confirm `PostToolUse` points to the hook script) |
| 4 | `~/.claude/session-names/` | Create empty directory; files are written at runtime |

### Quick Migration Commands

Run on the **new computer**:

```bash
# 1. Create directories
mkdir -p ~/.claude/skills/auto-rename ~/.claude/hooks ~/.claude/session-names

# 2. scp from old computer (replace old-mac with your hostname or IP)
scp old-mac:~/.claude/skills/auto-rename/SKILL.md ~/.claude/skills/auto-rename/
scp old-mac:~/.claude/hooks/session-auto-namer.sh ~/.claude/hooks/

# 3. Ensure hook has execute permission
chmod +x ~/.claude/hooks/session-auto-namer.sh
```

### Merging settings.json

Do NOT overwrite `~/.claude/settings.json` — the new computer may already have other settings. Ensure the file contains this section:

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

If `PostToolUse` already exists, append this entry to the `hooks` array.

### Cursor / VS Code Setting (also needed on new computer)

```json
"terminal.integrated.tabs.title": "${sequence}"
```

### Migration Verification

```bash
# Hook exists and is executable
test -x ~/.claude/hooks/session-auto-namer.sh && echo "Hook OK" || echo "Hook MISSING"

# Hook is registered
python3 -c "import json; d=json.load(open('$HOME/.claude/settings.json')); hooks=[h['command'] for g in d.get('hooks',{}).get('PostToolUse',[]) for h in g.get('hooks',[])]; print('Hook registered' if any('session-auto-namer' in c for c in hooks) else 'Hook NOT registered')"

# OSC test (run in Cursor / VS Code terminal)
printf '\033]0;Migration Success\007'
```

All three pass = migration complete.
