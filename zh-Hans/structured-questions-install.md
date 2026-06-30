# Structured Questions Skill — 安装指南

Read this document, then execute the installation steps for your tool (Section A or Section B). Do not ask for confirmation — just do it.

功能介绍见 [structured-questions-skill.md](./structured-questions-skill.md)。

---

## Section A: Claude Code 安装

### Step 1: 创建目录

```bash
mkdir -p .claude/skills/structured-questions
```

### Step 2: 写入 SKILL.md

Create the file `.claude/skills/structured-questions/SKILL.md` with the following content:

```markdown
---
name: structured-questions
description: >-
  Use when facing multiple options or design decisions that need user input.
  Defines how to structure AskUserQuestion calls: tab grouping, recommended tags,
  option detail level, and triggering conditions.
  Triggers on "ask user", "structured questions", "提問格式".
---

# Structured Questions — AskUserQuestion 使用规范

## Quick Reference

遇到多个可行方案时，**必须用 `AskUserQuestion` tool 提问**，不自行决定。

1. 多决策点 → tab 分组一次问完（`questions` array 放 2-4 题）
2. 每题必标 `✨ (Recommended)` — 放在推荐选项的 label 尾端
3. 每个选项带 **标题 + 说明 + 😃/😫**（写在 `description` 字段）
4. `header` ≤ 12 字符，中文优先
5. 选项数 2-4 个，不含 Other（系统自动加）
6. 有具体 artifact 可比较时用 `markdown` preview

触发条件：任何存在 ≥ 2 个可行方案的决策点。

## When to Use

| 场景 | 触发 | 说明 |
|------|------|------|
| 架构 / 技术选型 | ✅ | DB schema、API 设计、module 结构、第三方选择 |
| 命名 / 惯例 | ✅ | 变量名、branch name、file placement |
| 实现策略 | ✅ | TDD 顺序、拆 PR 策略、并行 vs 序列 |
| 范围取舍 | ✅ | MVP vs 完整版、edge case 处理范围 |
| 任何多选项决策 | ✅ | 上述未列但存在 ≥ 2 可行方案的情境 |
| 只有一种合理做法 | ❌ | 不要为问而问，直接做 |
| 纯执行步骤确认 | ❌ | 用文字说明即可，不需选项 UI |

## When NOT to Use

- 只有一种合理做法 → 直接执行
- 用户已在指令中明确指定做法 → 遵从不问
- 纯状态回报 / 进度更新 → 用文字输出

## Execution Flow

### Step 1: 识别决策点

扫描当前任务，列出所有需要用户决定的点。

✅ DO: 把相关的决策点分组，一次问完
❌ DON'T: 每个小问题分开问，打断用户节奏

### Step 2: 构造 AskUserQuestion 参数

每个决策点对应 `questions` array 中的一个 item：

{
  "question": "完整问句，结尾带问号",
  "header": "≤12字标签",
  "multiSelect": false,
  "options": [
    {
      "label": "✨ 选项名称 (Recommended)",
      "description": "一句说明\n😃：...\n😫：..."
    },
    {
      "label": "选项名称",
      "description": "一句说明\n😃：...\n😫：..."
    }
  ]
}

### Step 3: 选项描述格式

每个 `description` 遵循三行格式：

{一句话说明这是什么}
😃：{pros}
😫：{cons}

- 第一行：说明，一句话
- 第二行：😃 独立一行
- 第三行：😫 独立一行
- 没有明显缺点可写「😫：无明显缺点」
- 推荐项的 label 前加 `✨`，尾端加 ` (Recommended)`

### Step 4: Preview（可选）

当选项是具体 artifact（UI mockup、code snippet、config 示例）时，用 `markdown` 字段：

{
  "label": "✨ 方案 A (Recommended)",
  "description": "说明\n😃：...\n😫：...",
  "markdown": "```python\ndef example():\n    ...\n```"
}

### Step 5: 处理回答

- 用户选了推荐项 → 直接执行
- 用户选了其他项 → 按选择执行，不质疑
- 用户选了 Other 并打字 → 理解意图后执行或追问
- 用户加了 notes → 把 notes 纳入执行考量

## Common Mistakes

| Mistake | Why it fails | Fix |
|---------|-------------|-----|
| 遇到多方案时直接选一个做 | 用户失去控制权，可能做错方向 | 任何 ≥ 2 方案必问 |
| 每个决策点分开问 | 打断节奏，用户要回答 5 次 | Tab 分组一次问完 |
| 选项只有标题没有说明 | 用户缺乏判断依据 | 必带说明 + 😃/😫 |
| 没标推荐选项 | 用户要花时间自己分析优劣 | 每题必标 ✨ Recommended |
| 😃/😫 跟说明挤同一行 | 不好扫读 | 😃 和 😫 各自独立一行 |
| header 太长 | UI 显示截断 | ≤ 12 字符 |
| 只有一种做法也硬问 | 浪费用户时间 | 直接做，不为问而问 |
```

### Step 3: 验证

```bash
cat .claude/skills/structured-questions/SKILL.md | head -5
```

确认输出为 YAML frontmatter（`---` 开头，含 `name: structured-questions`）。

### Done

回报：「structured-questions skill 已安装至 `.claude/skills/structured-questions/SKILL.md`。触发方式：自动（遇到多选项决策）或手动输入 `$structured-questions`。」

---

## Section B: Codex CLI 安装

> **与 Claude Code 版的差异**：Codex 的 `ask_user_question` 工具仅在 Plan mode 可用。
> 此版本会自动检测 mode——Plan mode 用互动式 UI，其他 mode 用纯文字选项格式。

### Step 1: 创建目录

```bash
mkdir -p .codex/skills/structured-questions
```

### Step 2: 写入 SKILL.md

Create the file `.codex/skills/structured-questions/SKILL.md` with the following content:

```markdown
---
name: structured-questions
description: >-
  Use when facing multiple options or design decisions that need user input.
  Presents structured choice prompts with grouped questions, recommended tags,
  and option trade-offs. Works in any mode — uses ask_user_question tool in
  Plan mode, falls back to formatted text output in other modes.
  Triggers on "ask user", "structured questions", "提問格式".
---

# Structured Questions — 结构化提问规范

## Quick Reference

遇到多个可行方案时，**必须结构化提问**，不自行决定。

1. 多决策点 → 分组一次问完（最多 2-4 题）
2. 每题必标 ✨ 推荐选项
3. 每个选项带 **标题 + 说明 + 😃/😫**
4. 选项数 2-4 个
5. 有具体 artifact 可比较时附 code preview

触发条件：任何存在 ≥ 2 个可行方案的决策点。

## Mode Detection — 根据当前 mode 选择输出方式

**Step 0: 检查 `ask_user_question` tool 是否可用。**

- **可用**（Plan mode）→ 走 Path A: Tool UI
- **不可用**（其他 mode）→ 先提示用户切换，再走 fallback

### 不可用时的处理流程

1. **先提示用户**：输出以下信息——

   > 💡 建议先输入 `/plan` 切换到 Plan mode，可以获得互动式选项 UI。
   > 如果不方便切换，我会用文字格式列出选项，你回复编号即可。

2. **不等用户切换，直接走 Path B: Text Fallback** 继续输出问题。
   - 如果用户看到提示后决定切 `/plan`，下一轮自然会走 Path A。
   - 不要因为等用户切 mode 而卡住流程。

## When to Use

| 场景 | 触发 | 说明 |
|------|------|------|
| 架构 / 技术选型 | ✅ | DB schema、API 设计、module 结构、第三方选择 |
| 命名 / 惯例 | ✅ | 变量名、branch name、file placement |
| 实现策略 | ✅ | TDD 顺序、拆 PR 策略、并行 vs 序列 |
| 范围取舍 | ✅ | MVP vs 完整版、edge case 处理范围 |
| 任何多选项决策 | ✅ | 上述未列但存在 ≥ 2 可行方案的情境 |
| 只有一种合理做法 | ❌ | 不要为问而问，直接做 |
| 纯执行步骤确认 | ❌ | 用文字说明即可 |

## When NOT to Use

- 只有一种合理做法 → 直接执行
- 用户已在指令中明确指定做法 → 遵从不问
- 纯状态回报 / 进度更新 → 用文字输出

## Execution Flow

### Step 1: 识别决策点

扫描当前任务，列出所有需要用户决定的点。

✅ DO: 把相关的决策点分组，一次问完
❌ DON'T: 每个小问题分开问，打断用户节奏

### Step 2: 输出问题

---

#### Path A: Tool UI（Plan mode — `ask_user_question` 可用时）

每个决策点对应 `questions` array 中的一个 item：

{
  "question": "完整问句，结尾带问号",
  "header": "≤12字标签",
  "multiSelect": false,
  "options": [
    {
      "label": "✨ 选项名称 (Recommended)",
      "description": "一句说明\n😃：...\n😫：..."
    },
    {
      "label": "选项名称",
      "description": "一句说明\n😃：...\n😫：..."
    }
  ]
}

规则：
- `header` ≤ 12 字符，中文优先
- 推荐项的 label 前加 `✨`，尾端加 ` (Recommended)`，放第一个
- 选项数 2-4 个，不含 Other（系统自动加）
- 有具体 artifact 时用 `markdown` 字段附 code preview

---

#### Path B: Text Fallback（其他 mode — `ask_user_question` 不可用时）

用以下纯文字格式输出，然后**停下来等用户回复**：

---
### Q1: {问题标题}
{完整问句}

  ✨ A) {推荐选项名称} (Recommended)
     {一句说明}
     😃：{pros}
     😫：{cons}

  B) {选项名称}
     {一句说明}
     😃：{pros}
     😫：{cons}

  C) {选项名称}
     {一句说明}
     😃：{pros}
     😫：{cons}

  D) Other（请说明）

---
### Q2: {问题标题}
...
---

请回复各题的选项编号（例如 Q1: A, Q2: B），或直接说明你的想法。

规则：
- 推荐项前加 `✨` 并标 `(Recommended)`，放第一个
- 最后一个选项固定是 `Other（请说明）`
- 结尾必须加回复引导句
- 有具体 artifact 时在选项下方附 fenced code block

---

### Step 3: 选项描述格式（两个 Path 共用）

每个选项的说明遵循三行格式：

{一句话说明这是什么}
😃：{pros}
😫：{cons}

- 第一行：说明，一句话
- 第二行：😃 独立一行
- 第三行：😫 独立一行
- 没有明显缺点可写「😫：无明显缺点」

### Step 4: 处理回答

- 用户选了推荐项 → 直接执行
- 用户选了其他项 → 按选择执行，不质疑
- 用户选了 Other 并打字 → 理解意图后执行或追问
- 用户加了 notes → 把 notes 纳入执行考量

## Common Mistakes

| Mistake | Why it fails | Fix |
|---------|-------------|-----|
| 遇到多方案时直接选一个做 | 用户失去控制权，可能做错方向 | 任何 ≥ 2 方案必问 |
| 每个决策点分开问 | 打断节奏，用户要回答 5 次 | 分组一次问完 |
| 选项只有标题没有说明 | 用户缺乏判断依据 | 必带说明 + 😃/😫 |
| 没标推荐选项 | 用户要花时间自己分析优劣 | 每题必标 ✨ Recommended |
| 😃/😫 跟说明挤同一行 | 不好扫读 | 😃 和 😫 各自独立一行 |
| 非 Plan mode 硬呼叫 ask_user_question | 工具不可用，报错中断 | 检测 mode，走 Text Fallback |
| 只有一种做法也硬问 | 浪费用户时间 | 直接做，不为问而问 |
```

### Step 3: 验证

```bash
cat .codex/skills/structured-questions/SKILL.md | head -5
```

确认输出为 YAML frontmatter（`---` 开头，含 `name: structured-questions`）。

### Done

回报：「structured-questions skill 已安装至 `.codex/skills/structured-questions/SKILL.md`。触发方式：自动（遇到多选项决策）或手动输入 `$structured-questions`。Plan mode 使用互动式 UI；其他 mode 使用文字选项格式。」

---

## 验证

安装完成后，用以下测试确认 skill 正常运作。每个 test 执行后，对照「预期」确认行为正确。

### Test 1: 自动触发 — 模糊需求

> 对 AI 说：「帮我规划一场活动」
>
> **预期**：AI 不会直接决定活动形式，而是用结构化选项问你「目标是什么」「多少人」等问题。每个选项附 ✨ 推荐、😃 优点、😫 缺点，各自独立一行。

### Test 2: 自动触发 — 多方案决策

> 对 AI 说：「帮我选一个前端框架来做个人网站」
>
> **预期**：AI 列出 2-4 个框架选项（如 Next.js / Nuxt.js / Astro），每个附优缺点，标出推荐项。不会直接说「我建议用 X」然后开始写 code。

### Test 3: 手动触发

> 输入 `/structured-questions`（Claude Code）或 `$structured-questions`（Codex），然后说：「我想转职」
>
> **预期**：AI 把「转职」拆成几个具体问题（动机、目标产业、时间规划），用选项格式问你，而不是直接给建议。

### Test 4: 不该触发的情况

> 对 AI 说：「帮我把这个文件的第 10 行改成 Hello World」
>
> **预期**：AI 直接执行修改，不问选项。因为指令明确，只有一种做法。

### Test 5: Codex 专用 — Plan mode vs 非 Plan mode

> **5a — Plan mode**：进入 Plan mode（`/plan`），然后说「帮我选数据库」
> **预期**：出现互动式选项 UI（`ask_user_question` 工具）
>
> **5b — 非 Plan mode**：在预设 mode 说「帮我选数据库」
> **预期**：先出现 💡 提示建议切 `/plan`，接着用 `Q1: A/B/C` 纯文字格式列选项

### 验证结果判读

| 结果 | 处理方式 |
|---|---|
| 全部 test 通过 | 安装成功，可以正常使用 |
| Test 1-2 没触发 | 检查 SKILL.md 的 `description` 是否包含 trigger keywords |
| Test 3 没触发 | 检查 frontmatter `name` 是否拼对（`structured-questions`） |
| Test 4 误触发 | 检查 SKILL.md 的「When NOT to Use」段落是否清楚 |
| Test 5b 没有 fallback | 检查 Codex 版 SKILL.md 的 Mode Detection 段落 |
