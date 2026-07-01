# Handoff Skill — Installation Guide

Read this document, then execute the installation steps for your tool (Section A or Section B). Do not ask for confirmation — just do it. Execute every step sequentially, do not skip any step.

See [handoff-skill.md](./handoff-skill.md) for feature overview.

---

## Section A: Claude Code Installation

The Claude Code version includes two parts: (1) The Skill itself, allowing you to manually call `/handoff`; (2) A Hook (context-monitor) that automatically prompts the AI to write a handoff document when context is running low.

### Step 1: Create directory + write SKILL.md

```bash
mkdir -p .claude/skills/handoff
```

Create the file `.claude/skills/handoff/SKILL.md` with the following content:

```markdown
---
name: handoff
description: >-
  Use when ending a session, context running low, or user requests a handoff document.
  Produces a structured handoff file for the next session to continue seamlessly.
  Triggers on "handoff", "交接", "寫 handoff", "session 結束".
user-invocable: true
---

# /handoff — Session 交接文件產生器

## Quick Reference

根據當前 session 的工作內容，產出結構化 handoff 文件到 `docs/handoff/{date}-{topic}.md`。

1. 蒐集 session 資訊（branch / issue / PR / 改動檔案）
2. 判斷 handoff 類型（continuation / investigation / reference）
3. 產出交接文件，包含：已完成、進行中、下一步、必讀檔案
4. Commit handoff 文件到當前 branch
5. 改 session name 為 📦 前綴（標記已交接）
6. 回報結尾輸出單行起始 prompt（絕對路徑），給新 session 直接複製

Key rules:
- 「已完成的工作」≤ 10 行，細節指向「必讀檔案」
- 無內容的 optional section 直接刪除
- 必須有「下一步」— 這是新 session 的啟動指令

## When to Use

- Session 要結束時（用戶主動 `/handoff` 或 context 告警）
- 跨天開發，今天做到一半要記錄進度
- 換人接手，需要結構化的交接資訊

## When NOT to Use

- 很短的一次性對話
- 所有工作在單次 session 完成
- 純閒聊

## Execution Flow

### Step 1: 蒐集 Session 資訊

自動執行，不需用戶提供：

git branch --show-current
git status -s
git log --oneline -20
gh pr list --state open --head "$(git branch --show-current)" --json number,title

### Step 2: 判斷 Handoff 類型

| 信號 | → Type |
|---|---|
| 有未完成的 checklist / 進行中的 step | continuation |
| Session 主要在調查、盤點、分析 | investigation |
| Session 主要在配置、設定、一次性建置 | reference |

不確定時問用戶。

### Step 3: 產出 Handoff 文件

檔名：`docs/handoff/{YYYY-MM-DD}-{topic}.md`（topic 英文 kebab-case，≤ 40 chars）

文件結構：
- **狀態摘要**：做了什麼（≤ 10 行）
- **必讀檔案**：每項附一句話說明為什麼要讀
- **下一步**：具體動作，新 session 可直接執行
- **已知問題**：如果有的話

路徑規則：
- 文件「內部」引用的路徑一律用 repo-relative（`docs/handoff/...`），禁止帶 `.worktrees/` 前綴（Step 5 回報的起始 prompt 例外，用絕對路徑）
- 若檔案只存在於特定 branch，標注 `(branch: {name})`

✅ DO: 用具體的 PR 號碼、檔案路徑、指令
❌ DON'T: 寫模糊的「繼續之前的工作」

### Step 4: Commit

git add docs/handoff/{file}
git commit -m "docs: add session handoff — {topic}"

Commit 到當前 branch，不要切回 develop。

### Step 5: 改 Session Name + 回報

改名為 `📦 {topic}`（topic 轉中文敘述，≤ 30 字元）：

TERMINAL_PID=$(ps -o ppid= -p $PPID 2>/dev/null | tr -d ' ')
mkdir -p ~/.claude/session-names
echo '📦 {topic}' > ~/.claude/session-names/${TERMINAL_PID}.txt
TTY_DEV=$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')
[ -w "/dev/$TTY_DEV" ] && printf '\033]0;📦 {topic}\007' > "/dev/$TTY_DEV"

回報格式（最後一行必須是可直接複製的單行起始 prompt，路徑用絕對路徑）：
Handoff 已產出：{abs_path}
Branch: {current_branch}
下個 session 貼這行繼續：讀 {abs_path}

其中 {abs_path} 是交接文件的絕對路徑（如 `/Users/you/project/docs/handoff/2026-07-01-topic.md`）。
⚠️ 只輸出上面三行，不要重述交接文件的內容——狀態摘要、必讀檔案、下一步都已寫在文件裡，新 session 讀檔即可。

## Common Mistakes

| Mistake | Why it fails | Fix |
|---------|-------------|-----|
| 已完成的工作寫成長篇報告 | 新 session 花大量 context 讀 | ≤ 10 行，detail 指向必讀檔案 |
| 缺「下一步」 | 新 session 不知道做什麼 | 必填，寫具體動作 |
| 必讀檔案只列路徑 | 新 session 不知道為什麼要讀 | 每項附原因 |
| 忘記改 terminal name | 無法辨識哪個 session 已交接 | Step 5 必做，📦 前綴 |
| 路徑帶 .worktrees/ 前綴 | 新 session 不在同一個 worktree 就 404 | 一律 repo-relative |
| 起始 prompt 重述整份交接內容 | 浪費輸出，新 session 讀檔就有 | 只給 `讀 {絕對路徑}` 一行 |
| 起始 prompt 用相對路徑 | 新 session cwd 不同會 404 | 一律絕對路徑 |
```

### Step 2: Install Context Monitor Hook

This hook automatically prompts the AI to write a handoff document when context usage exceeds 70%.

#### 2a: Create the hook script

```bash
mkdir -p ~/.claude/hooks
```

Create the file `~/.claude/hooks/context-monitor.sh` with the following content:

```bash
#!/bin/bash
# Context Monitor Hook — reads session JSONL to get real token usage
# Triggered on PostToolUse to warn when context exceeds threshold

CLAUDE_PROJECTS_DIR="${HOME}/.claude/projects"
THRESHOLD=140000  # 70% of 200k context window
MAX_CONTEXT=200000

# Map CWD to Claude's project directory format: /a/b/c → -a-b-c
PROJECT_KEY=$(echo "${CWD:-$PWD}" | tr '/' '-')
PROJECT_DIR="${CLAUDE_PROJECTS_DIR}/${PROJECT_KEY}"

[ -d "$PROJECT_DIR" ] || exit 0

# Find most recently modified .jsonl (current session)
JSONL=$(find "$PROJECT_DIR" -maxdepth 1 -name "*.jsonl" -newer /tmp/.claude-context-monitor-start 2>/dev/null | head -1)
if [ -z "$JSONL" ]; then
  JSONL=$(ls -t "$PROJECT_DIR"/*.jsonl 2>/dev/null | head -1)
fi

[ -z "$JSONL" ] && exit 0

# Read last 30 lines for performance
TOTAL=$(tail -30 "$JSONL" | python3 -c "
import json, sys
best = 0
for line in sys.stdin:
    try:
        d = json.loads(line)
        if d.get('type') == 'assistant':
            u = d.get('message', {}).get('usage', {})
            t = u.get('input_tokens', 0) + u.get('cache_creation_input_tokens', 0) + u.get('cache_read_input_tokens', 0)
            if t > best:
                best = t
    except (json.JSONDecodeError, KeyError):
        pass
print(best)
" 2>/dev/null)

[ -z "$TOTAL" ] && exit 0
[ "$TOTAL" -eq 0 ] 2>/dev/null && exit 0

PCT=$((TOTAL * 100 / MAX_CONTEXT))

if [ "$TOTAL" -gt "$THRESHOLD" ]; then
  MSG="⚠️ Context 已用 ~${TOTAL} tokens (${PCT}%)。請立即：(1) 寫 docs/handoff/$(date +%F)-{topic}.md (2) 提示用戶開新 session 繼續工作。"
  printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}' "$MSG"
fi
```

#### 2b: Set executable permission

```bash
chmod +x ~/.claude/hooks/context-monitor.sh
```

#### 2c: Register Hook in settings.json

**How to**: Read `~/.claude/settings.json`. Based on the file's current state, follow the matching approach below:

**Case A -- File doesn't exist**: Create `~/.claude/settings.json` with this content:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "touch /tmp/.claude-context-monitor-start",
            "timeout": 2
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/context-monitor.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

**Case B -- File exists but has no `hooks` key**: Add the entire `"hooks"` object at the JSON top level (same as the hooks part in Case A).

**Case C -- File exists and already has `hooks`**: Two hook entries need to be added:

1. **SessionStart hook** (session start marker for context monitor):
   - If `hooks.SessionStart` doesn't exist -> add the entire `"SessionStart"` key (same as Case A)
   - If it already exists -> append to the end of the `hooks.SessionStart[0].hooks` array:
     ```json
     { "type": "command", "command": "touch /tmp/.claude-context-monitor-start", "timeout": 2 }
     ```
   - **Conflict check**: If the command already contains `claude-context-monitor-start`, skip

2. **PostToolUse hook** (context monitor itself):
   - If `hooks.PostToolUse` doesn't exist -> add the entire `"PostToolUse"` key (same as Case A)
   - If it already exists -> append to the end of the `hooks.PostToolUse[0].hooks` array:
     ```json
     { "type": "command", "command": "bash ~/.claude/hooks/context-monitor.sh", "timeout": 5 }
     ```
   - **Conflict check**: If the command already contains `context-monitor.sh`, skip

### Step 3: Verify

Run the following checks to confirm successful installation:

```bash
head -5 .claude/skills/handoff/SKILL.md
```

Expected: Output starts with `---` and contains `name: handoff`.

```bash
test -x ~/.claude/hooks/context-monitor.sh && echo "Hook OK" || echo "Hook MISSING"
```

Expected: Output is `Hook OK`.

```bash
python3 -c "import json; d=json.load(open('$HOME/.claude/settings.json')); hooks=[h['command'] for g in d.get('hooks',{}).get('PostToolUse',[]) for h in g.get('hooks',[])]; print('Hook registered' if any('context-monitor' in c for c in hooks) else 'Hook NOT registered')"
```

Expected: Output is `Hook registered`.

### Done

Report: "handoff skill installed. Includes SKILL.md + context-monitor hook. Trigger: manual `/handoff`, or hook auto-prompts when context usage > 70%."

---

## Section B: Codex CLI Installation

> **Differences from the Claude Code version**: Codex has no context-monitor hook; it can only be called manually.
> Session archive renaming uses the SQLite path.

### Step 1: Create directory + write SKILL.md

```bash
mkdir -p .codex/skills/handoff
mkdir -p .codex/skills/_shared
```

Create the file `.codex/skills/handoff/SKILL.md` with the following content:

```markdown
---
name: handoff
description: >-
  Use when ending a session, context running low, or user requests a handoff document.
  Produces a structured handoff file for the next session to continue seamlessly.
  Triggers on "handoff", "交接", "寫 handoff", "session 結束".
---

# /handoff — Session 交接文件產生器（Codex-Compatible）

## Quick Reference

根據當前 session 的工作內容，產出結構化 handoff 文件到 `docs/handoff/{date}-{topic}.md`。

1. 蒐集 session 資訊（branch / issue / PR / 改動檔案）
2. 判斷 handoff 類型（continuation / investigation / reference）
3. 產出交接文件，包含：已完成、進行中、下一步、必讀檔案
4. Commit handoff 文件到當前 branch
5. 改 terminal name 為 `📦 {topic}` 標記已交接

Key rules:
- 「已完成的工作」≤ 10 行，細節指向「必讀檔案」
- 無內容的 optional section 直接刪除
- 必須有「下一步」— 這是新 session 的啟動指令

## When to Use

- Session 要結束時
- 跨天開發，今天做到一半要記錄進度
- 換人接手

## When NOT to Use

- 很短的一次性對話
- 所有工作在單次 session 完成

## Execution Flow

### Step 1: 蒐集 Session 資訊

自動執行：

git branch --show-current
git status -s
git log --oneline -20

### Step 2: 判斷 Handoff 類型

| 信號 | → Type |
|---|---|
| 有未完成的 checklist | continuation |
| Session 主要在調查 | investigation |
| Session 主要在配置 | reference |

### Step 3: 產出 Handoff 文件

檔名：`docs/handoff/{YYYY-MM-DD}-{topic}.md`

✅ DO: 用具體的檔案路徑、指令
❌ DON'T: 寫模糊的「繼續之前的工作」

### Step 4: Commit

git add docs/handoff/{file}
git commit -m "docs: add session handoff — {topic}"

### Step 5: Terminal 改名 + 回報

改名方法 → Read `.codex/skills/_shared/codex-session-rename.md`

名稱格式：`📦 {topic}`（topic 轉中文敘述，≤ 30 字元）。

回報格式：
Handoff 已產出：docs/handoff/{file}
Branch: {current_branch}

## Common Mistakes

| Mistake | Why it fails | Fix |
|---------|-------------|-----|
| 已完成的工作寫成長篇報告 | 新 session 花大量 context 讀 | ≤ 10 行 |
| 缺「下一步」 | 新 session 不知道做什麼 | 必填 |
| 必讀檔案只列路徑 | 不知道為什麼要讀 | 附原因 |
| 忘記改 terminal name | 無法辨識已交接 | Step 5 必做 |
| 用 ORDER BY 找 session | 多 session 改錯 | 用 $CODEX_THREAD_ID |
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

### Step 3: Verify

```bash
head -5 .codex/skills/handoff/SKILL.md
```

Expected: Output starts with `---` and contains `name: handoff`.

```bash
head -3 .codex/skills/_shared/codex-session-rename.md
```

Expected: Output is `# Codex Session Rename`.

### Done

Report: "handoff skill installed. Codex has no auto-trigger hook; use `$handoff` manually."

---

## Verification

After installation, use the following tests to confirm the skill works correctly. After running each test, check against the "Expected" result to confirm correct behavior.

### Test 1: Manual trigger

> Type `/handoff` (Claude Code) or `$handoff` (Codex) in a session where some work has already been done.
>
> **Expected**: The AI automatically gathers git info, produces `docs/handoff/{date}-{topic}.md`, commits it to the current branch, and renames the terminal to `📦 {topic}`.

### Test 2: Auto trigger (Claude Code only)

> In a long session where context usage is approaching 70%, continue using tools.
>
> **Expected**: The context-monitor hook outputs a `⚠️ Context is at` warning, and the AI proactively starts writing the handoff document after receiving it.

### Test 3: Should NOT trigger

> Tell the AI: "Help me hand off this function's parameters to another function"
>
> **Expected**: The AI performs the code modification without triggering the handoff skill. "Hand off" in a code context should not trigger it.

### Test 4: Handoff document quality

> Trigger `/handoff` in a session where multiple things were done.
>
> **Expected**:
> - "Completed" is <= 10 lines
> - Has a "Next steps" section with specific actionable items
> - "Must read files" has an explanation for each item
> - All paths are repo-relative (no `.worktrees/` prefix)

### Test 5: Archive rename

> After triggering `/handoff`, check the terminal tab / sidebar name.
>
> **Expected**:
> - Claude Code: Terminal tab changes to `📦 {topic}`
> - Codex: Sidebar shows `📦 {topic}` (requires launching with `mycodex` for real-time tab sync)

### Test 6: New session continuation

> Open a new session and read the handoff document that was just produced.
>
> **Expected**: The new session can start working directly from the "Next steps" without needing additional background explanation.

### Verification Result Guide

| Result | Action |
|---|---|
| All tests pass | Installation successful |
| Test 1 didn't trigger | Check if the SKILL.md `description` contains trigger keywords (handoff) |
| Test 2 hook didn't trigger | Check `~/.claude/settings.json` hook registration and script permissions |
| Test 3 false trigger | Add "parameter passing in code" to the When NOT to Use section in SKILL.md |
| Test 4 quality not up to standard | Check if Step 3 in SKILL.md has the <= 10 lines and must-read files rules |
| Test 5 name not changed | Claude Code: Check the PID retrieval method in Step 5. Codex: Confirm launched with mycodex |
| Test 6 new session stuck | Check if the "Next steps" in the handoff document are specific enough |
