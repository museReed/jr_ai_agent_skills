# Auto-Rename Skill — 安装指南

Read this document, then execute the installation steps for your tool (Section A or Section B). Do not ask for confirmation — just do it. Execute every step sequentially, do not skip any step.

功能介绍见 [auto-rename-skill.md](./auto-rename-skill.md)。

---

## Section A: Claude Code 安装

Claude Code 版包含两个部分：(1) Skill 本体，让你手动呼叫 `/auto-rename`；(2) Hook，让 AI 在第 5 次 tool call 时自动命名。

### Step 1: 创建目录 + 写入 SKILL.md

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

根据对话内容为 session 命名，写入 session-names 文件 + 改 terminal tab title。

1. 读对话脉络 → 决定 `{emoji} {中文叙述}`（≤ 40 字符，emoji 见 §Emoji Mapping）
2. 一个 Bash call 完成：PID 定位 + 写文件 + 改 tab + 清 marker
3. 回报新名称，一句话结束

Key rules:
- 根据对话「主要目的」选 emoji，不是最新一句话
- 技术名词保留英文，叙述用中文
- 步骤 2 合并成一个 Bash 指令执行，不分多次

## Emoji Mapping

| Emoji | 动作 | 示例 |
|---|---|---|
| 🏗️ | build / implement / refactor / migrate | 🏗️ 语音建模 pipeline |
| 🔧 | fix / hotfix | 🔧 爬虫重试逻辑 |
| 🐛 | debug | 🐛 Gemini Vision blockReason |
| 📐 | plan / design | 📐 PRD2 classify-enrich |
| 📋 | review / audit | 📋 PRD 架构设计 |
| 💬 | discuss | 💬 auto-rename emoji 定义 |
| ⛴️ | pilot / spike | ⛴️ knowledge-distill 验证 |
| 🔍 | research / investigate | 🔍 cron 失败原因 |

## When to Use

- Hook 自动触发后（hook 注入 `[session-namer]` additionalContext 时）
- 用户手动打 `/auto-rename`
- 对话主题明显偏移，旧名称不再准确时

## When NOT to Use

- Session 刚开始（< 3 轮 tool call），信息不足
- 用户已手动指定名称

## Execution Flow

### Step 1: 决定名称

读对话历史，判断主要目的，从 Emoji Mapping 选一个 + 写中文叙述。

✅ DO: 用对话的核心任务命名（「🏗️ voice profile rebuild」）
❌ DON'T: 用最新一句话命名（「💬 确认 terminal 兼容性」←太窄）

### Step 2: 执行命名

```bash
TERMINAL_PID=$(ps -o ppid= -p $PPID 2>/dev/null | tr -d ' ') && \
mkdir -p ~/.claude/session-names && \
echo '{名称}' > ~/.claude/session-names/${TERMINAL_PID}.txt && \
printf '\033]0;{名称}\007' && \
rm -f /tmp/claude-session-namer/$PPID.default
```

### Step 3: 回报

告诉用户新名称，一句话结束。

## Common Mistakes

| Mistake | Why it fails | Fix |
|---------|-------------|-----|
| 用最新一句话命名 | 不代表整个 session 的目的 | 回顾整个对话脉络再决定 |
| 名称超过 40 字符 | sidebar 显示被截断 | 精简叙述，技术名词可缩写 |
| 忘记清除 default marker | hook 会持续每 20 次 tool call 重新提醒 | 步骤 2 的 rm 不可省略 |
| 分多个 Bash call 执行 | 浪费 tool call 额度 | 合并成一条指令 |
```

### Step 2: 安装自动命名 Hook

这个 hook 让 AI 在对话进行中自动命名 session，不需手动打 `/auto-rename`。

#### 2a: 创建 hook 脚本

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
{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"[session-namer] 请为此 session 命名并写入文件。\n\n命名规则：\n- 格式：{emoji} {中文叙述}，emoji 取代英文动词，技术名词可保留英文\n- 总长度 ≤ 40 字符\n\nEmoji mapping（8 个核心动作）：\n🏗️ build/implement/refactor/migrate → 🏗️ 语音建模 pipeline\n🔧 fix/hotfix → 🔧 爬虫重试逻辑\n🐛 debug → 🐛 Gemini Vision blockReason\n📐 plan/design → 📐 PRD2 classify-enrich\n📋 review/audit → 📋 PRD 架构设计\n💬 discuss → 💬 auto-rename emoji 定义\n⛴️ pilot/spike → ⛴️ knowledge-distill 验证\n🔍 research/investigate → 🔍 cron 失败原因\n\n执行后请删除 marker：rm -f /tmp/claude-session-namer/${CLAUDE_PID}.default\n\n执行指令：\nmkdir -p ~/.claude/session-names && echo '{名称}' > ~/.claude/session-names/${TERMINAL_PID}.txt && rm -f /tmp/claude-session-namer/${CLAUDE_PID}.default"}}
EOF
fi
```

#### 2b: 设置执行权限

```bash
chmod +x ~/.claude/hooks/session-auto-namer.sh
```

#### 2c: 注册 Hook 到 settings.json

**操作方式**：Read `~/.claude/settings.json`。根据文件现有状态，选择下面对应的做法：

**情况 A — 文件不存在**：Create `~/.claude/settings.json` with this content:

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

**情况 B — 文件存在但没有 `hooks` key**：在 JSON 顶层加入整个 `"hooks"` object（同情况 A 的 hooks 部分）。

**情况 C — 文件存在且已有 `hooks.PostToolUse`**：在 `hooks.PostToolUse[0].hooks` array 末尾 append 一个 entry：

```json
{
  "type": "command",
  "command": "bash ~/.claude/hooks/session-auto-namer.sh",
  "timeout": 3
}
```

**情况 D — 文件存在且已有 `hooks` 但没有 `PostToolUse`**：在 `hooks` object 中加入 `"PostToolUse"` key（同情况 A 的 PostToolUse 部分）。

**冲突检查**：如果 `hooks.PostToolUse[*].hooks[*].command` 中已经包含 `session-auto-namer.sh`，跳过此步（已安装）。

### Step 3: 验证

执行以下两个检查，确认安装成功：

```bash
head -5 .claude/skills/auto-rename/SKILL.md
```

预期：输出以 `---` 开头，含 `name: auto-rename`。

```bash
test -x ~/.claude/hooks/session-auto-namer.sh && echo "Hook OK" || echo "Hook MISSING"
```

预期：输出 `Hook OK`。

```bash
python3 -c "import json; d=json.load(open('$HOME/.claude/settings.json')); hooks=[h['command'] for g in d.get('hooks',{}).get('PostToolUse',[]) for h in g.get('hooks',[])]; print('Hook registered' if any('session-auto-namer' in c for c in hooks) else 'Hook NOT registered')"
```

预期：输出 `Hook registered`。

### Done

回报：「auto-rename skill 已安装。包含 SKILL.md + 自动命名 hook。触发方式：自动（第 5 次 tool call 后）或手动 `/auto-rename`。」

---

## Section B: Codex CLI 安装

> **与 Claude Code 版的差异**：Codex 没有自动触发 hook，只能手动呼叫。
> 命名方式是写入 SQLite 数据库，而非写文件。

### Step 1: 创建目录 + 写入 SKILL.md

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

根据对话内容为 session 命名，直接写 SQLite + 改 terminal tab title。

1. 读对话脉络 → 决定 `{emoji} {中文叙述}`（≤ 40 字符，emoji 见 §Emoji Mapping）
2. 按 `.codex/skills/_shared/codex-session-rename.md` 执行 SQLite UPDATE
3. 回报新名称，一句话结束

Key rules:
- 根据对话「主要目的」选 emoji，不是最新一句话
- 技术名词保留英文，叙述用中文
- Terminal tab 需用 mycodex wrapper 启动才会自动同步；skill 只更新 SQLite

## Emoji Mapping

| Emoji | 动作 | 示例 |
|---|---|---|
| 🏗️ | build / implement / refactor / migrate | 🏗️ 语音建模 pipeline |
| 🔧 | fix / hotfix | 🔧 爬虫重试逻辑 |
| 🐛 | debug | 🐛 Gemini Vision blockReason |
| 📐 | plan / design | 📐 PRD2 classify-enrich |
| 📋 | review / audit | 📋 PRD 架构设计 |
| 💬 | discuss | 💬 auto-rename emoji 定义 |
| ⛴️ | pilot / spike | ⛴️ knowledge-distill 验证 |
| 🔍 | research / investigate | 🔍 cron 失败原因 |

## Runtime Detection

改名方法（含 SQLite 指令、环境检测、注意事项）→ Read `.codex/skills/_shared/codex-session-rename.md`

## When to Use

- 用户手动打 `$auto-rename`
- 对话主题明显偏移，旧名称不再准确时

## When NOT to Use

- Session 刚开始（< 3 轮 tool call），信息不足
- 用户已手动指定名称

## Execution Flow

### Step 1: 决定名称

读对话历史，判断主要目的，从 Emoji Mapping 选一个 + 写中文叙述。

✅ DO: 用对话的核心任务命名
❌ DON'T: 用最新一句话命名

### Step 2: 执行命名

按 `.codex/skills/_shared/codex-session-rename.md` 的指令执行（SQLite UPDATE + terminal tab）。

### Step 3: 回报

告诉用户新名称，一句话结束。

## Common Mistakes

| Mistake | Why it fails | Fix |
|---------|-------------|-----|
| 用最新一句话命名 | 不代表整个 session 的目的 | 回顾整个对话脉络再决定 |
| 名称超过 40 字符 | 显示被截断 | 精简叙述 |
| 名称含单引号 | SQL 语法错误 | 用双引号包 SQL value，或转义单引号 |
| 用 ORDER BY updated_at_ms 找 session | 多 session 同时开会改错 | 用 $CODEX_THREAD_ID 定位 |
```

### Step 2: 创建共用参考文件

Create the file `.codex/skills/_shared/codex-session-rename.md` with the following content:

```markdown
# Codex Session Rename — 共用参考文件

> 任何需要手动改 Codex session 名称的 skill，引用此文件取得方法。
> 不要各自重写 — 改版时只改这一份。

---

## 原理

Codex 把 session 数据存在 SQLite（`~/.codex/state_*.sqlite`），每个 session 是 `threads` 表的一笔 row。
`/title` 指令背后就是 UPDATE `threads.title` — 我们直接用 `sqlite3` 做一样的事。

## 改名指令

# 1. 取得 Codex thread ID
SESSION_ID="${CODEX_THREAD_ID}"

# 2. 找到 SQLite DB（支持版号变更）
CODEX_DB=$(ls -t ~/.codex/state_*.sqlite 2>/dev/null | head -1)

# 3. 先确认 target row 是这次对话
sqlite3 -header -column "$CODEX_DB" \
  "SELECT id, title, first_user_message FROM threads WHERE id='${SESSION_ID}';"

# 4. 改名
sqlite3 "$CODEX_DB" "UPDATE threads SET title='新名称', preview='新名称' WHERE id='${SESSION_ID}';"

## 注意事项

| 项目 | 说明 |
|---|---|
| **Session 定位** | 用 `$CODEX_THREAD_ID` 环境变量定位，不用 `ORDER BY updated_at_ms DESC LIMIT 1` |
| **SQLite locking** | 短暂 UPDATE 不会跟 Codex 冲突 |
| **版号变更** | DB 文件名可能从 `state_5.sqlite` 变成 `state_6`，用 `ls -t state_*.sqlite | head -1` 适配 |
| **单引号转义** | 名称含 `'` 时用 `''` 跳脱 |
| **preview 字段** | 必须跟 title 一起改，否则 sidebar 显示旧文字 |
| **Claude Code 环境** | 检测 `$HOME/.claude/session-names` 存在 → 走 Claude Code 路径（写文件），不走 SQLite |
```

### Step 3: 安装 Terminal Tab 同步 Wrapper（可选但强烈建议）

Codex 预设不会同步 terminal tab title。这个 wrapper 会在后台监听 SQLite 的 session title 变化，自动更新 terminal tab 名称。

#### 3a: 创建 wrapper 脚本

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

#### 3b: 创建 mycodex 启动器

Create the file `~/.local/bin/mycodex` with the following content:

```bash
#!/usr/bin/env bash
set -euo pipefail
exec ~/.local/bin/codex-title-wrapper.sh "$@"
```

#### 3c: 设置执行权限 + alias

```bash
chmod +x ~/.local/bin/codex-title-wrapper.sh ~/.local/bin/mycodex
```

在 `~/.zshrc`（或 `~/.bashrc`）末尾加入：

```bash
# 如果 ~/.local/bin 不在 PATH 中，加入它
export PATH="$HOME/.local/bin:$PATH"
# alias：用 mycodex 取代 codex 以启用 terminal tab 同步
alias mycodex='~/.local/bin/mycodex'
```

加完后执行 `source ~/.zshrc`（或重开 terminal）使其生效。

> **使用方式**：之后用 `mycodex` 取代 `codex` 启动 Codex CLI，terminal tab 就会自动同步 session title。

### Step 4: 验证

```bash
head -5 .codex/skills/auto-rename/SKILL.md
```

预期：输出以 `---` 开头，含 `name: auto-rename`。

```bash
head -3 .codex/skills/_shared/codex-session-rename.md
```

预期：输出 `# Codex Session Rename`。

```bash
test -x ~/.local/bin/mycodex && echo "Wrapper OK" || echo "Wrapper MISSING"
```

预期：输出 `Wrapper OK`。

### Done

回报：「auto-rename skill 已安装。包含 SKILL.md + 共用参考文件 + terminal tab 同步 wrapper。手动输入 `$auto-rename` 命名，用 `mycodex` 启动 Codex 可自动同步 tab title。」

---

## 验证

安装完成后，用以下测试确认 skill 正常运作。每个 test 执行后，对照「预期」确认行为正确。

### Test 1: 手动触发

> 对 AI 说：「帮我把这个 session 改个名字」
>
> **预期**：AI 根据对话内容，用 emoji + 中文命名（如「📋 auto-rename 安装验证」），并执行写入指令。Claude Code 会改 terminal tab title；Codex 会更新 SQLite。

### Test 2: 自动触发（仅 Claude Code）

> 正常使用 Claude Code，在第 5 次 tool call 后观察。
>
> **预期**：AI 收到 `[session-namer]` 的 hook 提示后，自动执行命名。Terminal tab 从 branch 名变成描述性名称。

### Test 3: 不该触发的情况

> 在 session 的前两轮对话中说：「这个变量要 rename 成 foo」
>
> **预期**：AI 执行变量重新命名，不触发 session 改名。「rename」在代码脉络中不应触发 auto-rename skill。

### Test 4: 名称品质

> 开一个 session，做三件事：(1) 读一个文件 (2) 修一个 bug (3) 跑测试。然后打 `/auto-rename`。
>
> **预期**：名称反映主要任务（如「🔧 修 API 回传格式」），不是最后一个动作（如「🔍 跑测试」）。

### Test 5: Codex 专用 — SQLite 写入

> 在 Codex 中打 `$auto-rename`
>
> **预期**：AI 用 `sqlite3` 更新 `threads` 表的 `title` 和 `preview` 字段。可用以下指令验证：
> ```bash
> CODEX_DB=$(ls -t ~/.codex/state_*.sqlite 2>/dev/null | head -1)
> sqlite3 "$CODEX_DB" "SELECT id, title FROM threads ORDER BY updated_at_ms DESC LIMIT 1;"
> ```

### Test 6: Codex 专用 — mycodex wrapper Tab 同步

> 用 `mycodex` 启动 Codex（不是 `codex`），开始一段对话后打 `$auto-rename`。
>
> **预期**：AI 执行 SQLite UPDATE 后，terminal tab title 自动从预设名称变成 session 名称（如「🔧 爬虫重试逻辑」）。如果用 `codex` 启动则 tab 不会同步——这是预期行为。

### 验证结果判读

| 结果 | 处理方式 |
|---|---|
| 全部 test 通过 | 安装成功 |
| Test 1 没触发 | 检查 SKILL.md 的 `description` 是否包含 trigger keywords（rename、改名） |
| Test 2 hook 没触发 | 检查 `~/.claude/settings.json` 是否正确注册 hook，且脚本有执行权限 |
| Test 3 误触发 | 正常现象——keyword 有重叠。如果频繁误触，在 SKILL.md 的 When NOT to Use 加上「代码 rename 变量」 |
| Test 4 名称太窄 | 检查 SKILL.md 的 Step 1 是否强调「用对话核心任务命名」 |
| Test 5 SQLite 没更新 | 检查 `$CODEX_THREAD_ID` 环境变量是否存在，以及 DB 路径是否正确 |

---

## Section C: Cursor / VS Code Terminal Tab 同步设定

Auto-rename 靠 OSC escape sequence（`\033]0;title\007`）改 terminal tab 名。Cursor 和 VS Code 底层都用 xterm.js，支持 OSC，但默认的 tab title 格式会盖掉 OSC 输出。

### Step 1: 修改 Settings

打开 Cursor / VS Code 的 Settings (JSON)，加入：

```json
"terminal.integrated.tabs.title": "${sequence}"
```

- `${sequence}` = 用 terminal 自己发的 OSC escape 当标题——这是 auto-rename hook 需要的值
- 默认值 `${task}${separator}${local}${separator}${cwdFolder}` 会覆盖 OSC，必须改掉

### Step 2: 验证 OSC 支持

在 Cursor / VS Code 的 terminal 里跑：

```bash
printf '\033]0;测试改名\007'
```

**预期**：terminal tab 名称变成「测试改名」。没反应 → 回 Step 1 确认设定有保存。

### 已知情境

| 情境 | 结果 |
|---|---|
| Cursor / VS Code integrated terminal | 设定 `${sequence}` 后正常运作 |
| SSH remote session | 通常可穿透，但部分 SSH config 会 strip OSC |
| macOS Terminal / iTerm2 | 原生支持 OSC，不需额外设定 |

---

## Section D: 迁移到其他电脑

### Claude Code 版需要的文件

| # | 文件 / 目录 | 用途 |
|---|---|---|
| 1 | `~/.claude/skills/auto-rename/SKILL.md` | skill 定义（命名规则、emoji mapping） |
| 2 | `~/.claude/hooks/session-auto-namer.sh` | PostToolUse hook（计数 + 触发改名 + 发 OSC） |
| 3 | `~/.claude/settings.json` | 注册 hook（确认 `PostToolUse` 有指向 hook 脚本） |
| 4 | `~/.claude/session-names/` | 创建空目录即可，runtime 自动写文件 |

### 快速迁移指令

在**新电脑**上执行：

```bash
# 1. 建目录
mkdir -p ~/.claude/skills/auto-rename ~/.claude/hooks ~/.claude/session-names

# 2. 从旧电脑 scp（替换 old-mac 为你的 hostname 或 IP）
scp old-mac:~/.claude/skills/auto-rename/SKILL.md ~/.claude/skills/auto-rename/
scp old-mac:~/.claude/hooks/session-auto-namer.sh ~/.claude/hooks/

# 3. 确保 hook 有执行权限
chmod +x ~/.claude/hooks/session-auto-namer.sh
```

### settings.json 合并

不要直接覆盖 `~/.claude/settings.json`，新电脑可能已有其他设定。确认文件中包含以下区段：

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

如果已有 `PostToolUse`，在 `hooks` array 末尾 append 这个 entry 即可。

### Cursor / VS Code 设定（新电脑也要做）

```json
"terminal.integrated.tabs.title": "${sequence}"
```

### 迁移验证

```bash
# hook 存在且可执行
test -x ~/.claude/hooks/session-auto-namer.sh && echo "Hook OK" || echo "Hook MISSING"

# hook 已注册
python3 -c "import json; d=json.load(open('$HOME/.claude/settings.json')); hooks=[h['command'] for g in d.get('hooks',{}).get('PostToolUse',[]) for h in g.get('hooks',[])]; print('Hook registered' if any('session-auto-namer' in c for c in hooks) else 'Hook NOT registered')"

# OSC 测试（在 Cursor / VS Code terminal 中执行）
printf '\033]0;迁移成功\007'
```

三项都通过 = 迁移完成。
