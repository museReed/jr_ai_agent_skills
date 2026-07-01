# Handoff Skill — 安装指南

Read this document, then execute the installation steps for your tool (Section A or Section B). Do not ask for confirmation — just do it. Execute every step sequentially, do not skip any step.

功能介绍见 [handoff-skill.md](./handoff-skill.md)。

---

## Section A: Claude Code 安装

Claude Code 版包含两个部分：(1) Skill 本体，让你手动呼叫 `/handoff`；(2) Hook（context-monitor），在 context 快满时自动提醒 AI 写交接文件。

### Step 1: 创建目录 + 写入 SKILL.md

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

# /handoff — Session 交接文件产生器

## Quick Reference

根据当前 session 的工作内容，产出结构化 handoff 文件到 `docs/handoff/{date}-{topic}.md`。

1. 搜集 session 信息（branch / issue / PR / 改动文件）
2. 判断 handoff 类型（continuation / investigation / reference）
3. 产出交接文件，包含：已完成、进行中、下一步、必读文件
4. Commit handoff 文件到当前 branch
5. 改 session name 为 📦 前缀（标记已交接）
6. 回报结尾输出单行起始 prompt（绝对路径），给新 session 直接复制

Key rules:
- 「已完成的工作」≤ 10 行，细节指向「必读文件」
- 无内容的 optional section 直接删除
- 必须有「下一步」— 这是新 session 的启动指令

## When to Use

- Session 要结束时（用户主动 `/handoff` 或 context 告警）
- 跨天开发，今天做到一半要记录进度
- 换人接手，需要结构化的交接信息

## When NOT to Use

- 很短的一次性对话
- 所有工作在单次 session 完成
- 纯闲聊

## Execution Flow

### Step 1: 搜集 Session 信息

自动执行，不需用户提供：

git branch --show-current
git status -s
git log --oneline -20
gh pr list --state open --head "$(git branch --show-current)" --json number,title

### Step 2: 判断 Handoff 类型

| 信号 | → Type |
|---|---|
| 有未完成的 checklist / 进行中的 step | continuation |
| Session 主要在调查、盘点、分析 | investigation |
| Session 主要在配置、设置、一次性建置 | reference |

不确定时问用户。

### Step 3: 产出 Handoff 文件

文件名：`docs/handoff/{YYYY-MM-DD}-{topic}.md`（topic 英文 kebab-case，≤ 40 chars）

文件结构：
- **状态摘要**：做了什么（≤ 10 行）
- **必读文件**：每项附一句话说明为什么要读
- **下一步**：具体动作，新 session 可直接执行
- **已知问题**：如果有的话

路径规则：
- 文件「内部」引用的路径一律用 repo-relative（`docs/handoff/...`），禁止带 `.worktrees/` 前缀（Step 5 回报的起始 prompt 例外，用绝对路径）
- 若文件只存在于特定 branch，标注 `(branch: {name})`

✅ DO: 用具体的 PR 号码、文件路径、指令
❌ DON'T: 写模糊的「继续之前的工作」

### Step 4: Commit

git add docs/handoff/{file}
git commit -m "docs: add session handoff — {topic}"

Commit 到当前 branch，不要切回 develop。

### Step 5: 改 Session Name + 回报

改名为 `📦 {topic}`（topic 转中文叙述，≤ 30 字符）：

TERMINAL_PID=$(ps -o ppid= -p $PPID 2>/dev/null | tr -d ' ')
mkdir -p ~/.claude/session-names
echo '📦 {topic}' > ~/.claude/session-names/${TERMINAL_PID}.txt
printf '\033]0;📦 {topic}\007'

回报格式（最后一行必须是可直接复制的单行起始 prompt，路径用绝对路径）：
Handoff 已产出：{abs_path}
Branch: {current_branch}
下个 session 贴这行继续：读 {abs_path}

其中 {abs_path} 是交接文件的绝对路径（如 `/Users/you/project/docs/handoff/2026-07-01-topic.md`）。
⚠️ 只输出上面三行，不要重述交接文件的内容——状态摘要、必读文件、下一步都已写在文件里，新 session 读档即可。

## Common Mistakes

| Mistake | Why it fails | Fix |
|---------|-------------|-----|
| 已完成的工作写成长篇报告 | 新 session 花大量 context 读 | ≤ 10 行，detail 指向必读文件 |
| 缺「下一步」 | 新 session 不知道做什么 | 必填，写具体动作 |
| 必读文件只列路径 | 新 session 不知道为什么要读 | 每项附原因 |
| 忘记改 terminal name | 无法辨识哪个 session 已交接 | Step 5 必做，📦 前缀 |
| 路径带 .worktrees/ 前缀 | 新 session 不在同一个 worktree 就 404 | 一律 repo-relative |
| 起始 prompt 重述整份交接内容 | 浪费输出，新 session 读档就有 | 只给 `读 {绝对路径}` 一行 |
| 起始 prompt 用相对路径 | 新 session cwd 不同会 404 | 一律绝对路径 |
```

### Step 2: 安装 Context Monitor Hook

这个 hook 在 context 用量超过 70% 时自动提醒 AI 写交接文件。

#### 2a: 创建 hook 脚本

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
  MSG="⚠️ Context 已用 ~${TOTAL} tokens (${PCT}%)。请立即：(1) 写 docs/handoff/$(date +%F)-{topic}.md (2) 提示用户开新 session 继续工作。"
  printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}' "$MSG"
fi
```

#### 2b: 设置执行权限

```bash
chmod +x ~/.claude/hooks/context-monitor.sh
```

#### 2c: 注册 Hook 到 settings.json

**操作方式**：Read `~/.claude/settings.json`。根据文件现有状态，选择下面对应的做法：

**情况 A — 文件不存在**：Create `~/.claude/settings.json` with this content:

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

**情况 B — 文件存在但没有 `hooks` key**：在 JSON 顶层加入整个 `"hooks"` object（同情况 A 的 hooks 部分）。

**情况 C — 文件存在且已有 `hooks`**：需要加入两个 hook entry：

1. **SessionStart hook**（context monitor 的 session 起点标记）：
   - 如果 `hooks.SessionStart` 不存在 → 加入整个 `"SessionStart"` key（同情况 A）
   - 如果已存在 → 在 `hooks.SessionStart[0].hooks` array 末尾 append：
     ```json
     { "type": "command", "command": "touch /tmp/.claude-context-monitor-start", "timeout": 2 }
     ```
   - **冲突检查**：如果 command 中已包含 `claude-context-monitor-start`，跳过

2. **PostToolUse hook**（context monitor 本体）：
   - 如果 `hooks.PostToolUse` 不存在 → 加入整个 `"PostToolUse"` key（同情况 A）
   - 如果已存在 → 在 `hooks.PostToolUse[0].hooks` array 末尾 append：
     ```json
     { "type": "command", "command": "bash ~/.claude/hooks/context-monitor.sh", "timeout": 5 }
     ```
   - **冲突检查**：如果 command 中已包含 `context-monitor.sh`，跳过

### Step 3: 验证

执行以下检查，确认安装成功：

```bash
head -5 .claude/skills/handoff/SKILL.md
```

预期：输出以 `---` 开头，含 `name: handoff`。

```bash
test -x ~/.claude/hooks/context-monitor.sh && echo "Hook OK" || echo "Hook MISSING"
```

预期：输出 `Hook OK`。

```bash
python3 -c "import json; d=json.load(open('$HOME/.claude/settings.json')); hooks=[h['command'] for g in d.get('hooks',{}).get('PostToolUse',[]) for h in g.get('hooks',[])]; print('Hook registered' if any('context-monitor' in c for c in hooks) else 'Hook NOT registered')"
```

预期：输出 `Hook registered`。

### Done

回报：「handoff skill 已安装。包含 SKILL.md + context-monitor hook。触发方式：手动 `/handoff`，或 context 用量 > 70% 时 hook 自动提醒。」

---

## Section B: Codex CLI 安装

> **与 Claude Code 版的差异**：Codex 没有 context-monitor hook，只能手动呼叫。
> Session 封存改名走 SQLite 路径。

### Step 1: 创建目录 + 写入 SKILL.md

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

# /handoff — Session 交接文件产生器（Codex-Compatible）

## Quick Reference

根据当前 session 的工作内容，产出结构化 handoff 文件到 `docs/handoff/{date}-{topic}.md`。

1. 搜集 session 信息（branch / issue / PR / 改动文件）
2. 判断 handoff 类型（continuation / investigation / reference）
3. 产出交接文件，包含：已完成、进行中、下一步、必读文件
4. Commit handoff 文件到当前 branch
5. 改 terminal name 为 `📦 {topic}` 标记已交接

Key rules:
- 「已完成的工作」≤ 10 行，细节指向「必读文件」
- 无内容的 optional section 直接删除
- 必须有「下一步」— 这是新 session 的启动指令

## When to Use

- Session 要结束时
- 跨天开发，今天做到一半要记录进度
- 换人接手

## When NOT to Use

- 很短的一次性对话
- 所有工作在单次 session 完成

## Execution Flow

### Step 1: 搜集 Session 信息

自动执行：

git branch --show-current
git status -s
git log --oneline -20

### Step 2: 判断 Handoff 类型

| 信号 | → Type |
|---|---|
| 有未完成的 checklist | continuation |
| Session 主要在调查 | investigation |
| Session 主要在配置 | reference |

### Step 3: 产出 Handoff 文件

文件名：`docs/handoff/{YYYY-MM-DD}-{topic}.md`

✅ DO: 用具体的文件路径、指令
❌ DON'T: 写模糊的「继续之前的工作」

### Step 4: Commit

git add docs/handoff/{file}
git commit -m "docs: add session handoff — {topic}"

### Step 5: Terminal 改名 + 回报

改名方法 → Read `.codex/skills/_shared/codex-session-rename.md`

名称格式：`📦 {topic}`（topic 转中文叙述，≤ 30 字符）。

回报格式：
Handoff 已产出：docs/handoff/{file}
Branch: {current_branch}

## Common Mistakes

| Mistake | Why it fails | Fix |
|---------|-------------|-----|
| 已完成的工作写成长篇报告 | 新 session 花大量 context 读 | ≤ 10 行 |
| 缺「下一步」 | 新 session 不知道做什么 | 必填 |
| 必读文件只列路径 | 不知道为什么要读 | 附原因 |
| 忘记改 terminal name | 无法辨识已交接 | Step 5 必做 |
| 用 ORDER BY 找 session | 多 session 改错 | 用 $CODEX_THREAD_ID |
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

### Step 3: 验证

```bash
head -5 .codex/skills/handoff/SKILL.md
```

预期：输出以 `---` 开头，含 `name: handoff`。

```bash
head -3 .codex/skills/_shared/codex-session-rename.md
```

预期：输出 `# Codex Session Rename`。

### Done

回报：「handoff skill 已安装。Codex 无自动触发 hook，手动输入 `$handoff` 使用。」

---

## 验证

安装完成后，用以下测试确认 skill 正常运作。每个 test 执行后，对照「预期」确认行为正确。

### Test 1: 手动触发

> 输入 `/handoff`（Claude Code）或 `$handoff`（Codex），在一个已经做了一些工作的 session 中。
>
> **预期**：AI 自动搜集 git 信息，产出 `docs/handoff/{date}-{topic}.md`，commit 到当前 branch，并改 terminal name 为 `📦 {topic}`。

### Test 2: 自动触发（仅 Claude Code）

> 在一个 context 用量接近 70% 的长 session 中，继续使用 tool。
>
> **预期**：context-monitor hook 输出 `⚠️ Context 已用` 警告，AI 收到后主动开始写交接文件。

### Test 3: 不该触发的情况

> 对 AI 说：「帮我把这个函数的参数交接给另一个函数」
>
> **预期**：AI 执行代码修改，不触发 handoff skill。「交接」在代码脉络中不应触发。

### Test 4: 交接文件品质

> 在一个做了多件事的 session 中触发 `/handoff`。
>
> **预期**：
> - 「已完成」≤ 10 行
> - 有「下一步」section，内容是具体可执行的动作
> - 「必读文件」每项有说明
> - 路径全部是 repo-relative（不含 `.worktrees/`）

### Test 5: 封存改名

> 触发 `/handoff` 后，检查 terminal tab / sidebar 名称。
>
> **预期**：
> - Claude Code：terminal tab 变成 `📦 {中文 topic}`
> - Codex：sidebar 显示 `📦 {中文 topic}`（需用 `mycodex` 启动才会即时同步 tab）

### Test 6: 新 Session 接续

> 开一个新 session，读取刚刚产出的 handoff 文件。
>
> **预期**：新 session 能直接从「下一步」开始工作，不需要额外解释背景。

### 验证结果判读

| 结果 | 处理方式 |
|---|---|
| 全部 test 通过 | 安装成功 |
| Test 1 没触发 | 检查 SKILL.md 的 `description` 是否包含 trigger keywords（handoff、交接） |
| Test 2 hook 没触发 | 检查 `~/.claude/settings.json` 的 hook 注册和脚本权限 |
| Test 3 误触发 | 在 SKILL.md 的 When NOT to Use 加上「代码层面的参数传递」 |
| Test 4 品质不达标 | 检查 SKILL.md 的 Step 3 是否有 ≤ 10 行和必读文件规则 |
| Test 5 名称没改 | Claude Code：检查 Step 5 的 PID 取法。Codex：确认用 mycodex 启动 |
| Test 6 新 session 卡住 | 检查交接文件的「下一步」是否够具体 |
