# Structured Questions Skill — 安装指南

Read this document, then execute the installation steps for your tool (Section A or Section B). Do not ask for confirmation — just do it. **Installation is NOT complete until you have walked the user through the "验证" section.**

功能介绍见 [structured-questions-skill.md](./structured-questions-skill.md)。

> 适用：Claude Code / Codex CLI（macOS / Linux）
> 需求：bash、python3

---

## 这个 skill 做什么

遇到「有 ≥ 2 个可行方案」的决策时，AI 不自己拍板，而是把选项用结构化格式列给你选——每个选项附推荐与取舍。Claude Code 用交互式 `AskUserQuestion` 菜单；Codex 在 Plan mode 用 `request_user_input`，Default mode 会先停下来询问是否切换，只有明确拒绝后才退回纯文本选项。

> 这是纯 skill（一份 `SKILL.md`），没有 hook、没有 alias、不需编辑器设置。`install.sh` 会连同 auto-rename、handoff 一起把它复制到位。

## Section A: Claude Code 安装

所有 skill 都在本 repo 的 `installer/`，一个指令装完（含 structured-questions）：

```bash
cd jr_ai_agent_skills/installer
./install.sh claude
```

装到 `~/.claude/skills/structured-questions/SKILL.md`。触发方式：自动（遇到多选项决策）或手动输入 `/structured-questions`。

## Section B: Codex CLI 安装

```bash
cd jr_ai_agent_skills/installer
./install.sh codex
```

装到 `~/.agents/skills/structured-questions/SKILL.md`。触发方式：自动或手动输入 `$structured-questions`。**Plan mode 使用 `request_user_input`；Default mode 先等待切换确认，拒绝后才使用文本选项。**

> 两个工具都用 → `./install.sh`（不带参数）。
> installer 是幂等的：重跑安全；Codex skill 备份放在 `~/.agents/skill-backups/{timestamp}/`，其他文件使用 `*.bak.{timestamp}`。

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
> **预期**：出现交互式选项 UI（`request_user_input` 工具）
>
> **5b — Default mode**：在 Default mode 说「帮我选数据库」
> **预期 1**：只出现切换提示，然后停下；此时不得出现数据库文本选项
>
> 接着回复“不切换”
> **预期 2**：同一轮继续原问题，改用 `Q1: A/B/C` 纯文本格式列选项

### 验证结果判读

| 结果 | 处理方式 |
|---|---|
| 全部 test 通过 | 安装成功，可以正常使用 |
| Test 1-2 没触发 | 检查 SKILL.md 的 `description` 是否包含 trigger keywords |
| Test 3 没触发 | 检查 frontmatter `name` 是否拼对（`structured-questions`） |
| Test 4 误触发 | 检查 SKILL.md 的「When NOT to Use」段落是否清楚 |
| Test 5b 未先停顿，或拒绝后没有 fallback | 检查 Codex 版 SKILL.md 的 Mode Detection 段落 |
