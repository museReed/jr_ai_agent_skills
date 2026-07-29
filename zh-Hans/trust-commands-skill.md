# Trust Commands — 把常用命令加进白名单，AI 不再每次都问

**适用工具**: Claude Code / Codex CLI
**安装指南**: [trust-commands-install.md](./trust-commands-install.md)
**性质**: 可选额外 skill（不在核心三件套的自动安装内，想要再单独装）

---

## 这个 Skill 解决什么问题？

你开了 **Accept Edits**（Codex 的 **Auto**）之后，改文件不再一直被打断了。但只要 AI 要跑 shell 命令，还是每次都跳出来问你「要执行 `git status` 吗？」——同一批命令一天被问几十次。

**白名单**就是解法：告诉 AI「这几个命令我永远信任，别再问」。但一条条手动加很烦，而且要自己记得格式、自己判断哪些安全。

这个 skill 做三件事：

1. **读你最近的命令记录**，统计最常用的前 10–15 个。
2. **帮你分类**：哪些安全可加、哪些会写文件要你自己决定、哪些危险绝不能加。
3. **列清单让你逐条确认**后，才写进设置——绝不偷偷加。

---

## Before / After 对比

**Before — 同一个命令一直被问：**

```
AI：要执行 `git status` 吗？        你：（按同意）
AI：要执行 `git diff` 吗？          你：（按同意）
AI：要执行 `npm run test` 吗？      你：（又按同意）
...（一天下来按了几十次一模一样的同意）
```

**After — 常用又安全的命令一次放行：**

```
你：/trust-commands
AI：我看了你最近的命令，最常用又安全的有这些，要加进白名单吗？
    ✅ git status（42 次）✅ git diff（31 次）✅ npm run test（18 次）
    ✏️ git commit（15 次，会写 commit，要加吗？）
    ⛔ rm -rf（6 次，危险，不建议加）
你：前三个加、git commit 也加
AI：已写进 ~/.claude/settings.json，之后这几个不会再问你。
```

---

## 安全分类（skill 怎么判断）

| 类别 | 例子 | 动作 |
|---|---|---|
| ✅ 安全（只读／日常） | `git status`、`git diff`、`ls`、`grep`、`npm run *`、`pytest` | 默认建议加入 |
| ✏️ 会写文件 | `git add`、`git commit`、`mkdir`、`touch` | 列出、标注，让你自己勾 |
| ⛔ 危险 | `rm`、`sudo`、`curl … \| sh`、`git push --force` | 绝不主动加；坚持要加会先警告风险 |

---

## 一个重要提醒：复合命令还是会问

就算 `git status` 已加白名单，AI 一跑 `git status && npm test`，只要 `npm test` 没加，**整串还是会问你**。因为白名单是「逐个子命令」比对——一串里任何一个没信任就停。

想少被问，两条路：

- **让 AI 一条命令做一件事**（最推荐，也最容易看懂它每步在干嘛）
- 或把串里每个子命令都加进白名单

---

## Claude Code vs Codex 差异

| | Claude Code | Codex CLI |
|---|---|---|
| 白名单机制 | 有——`~/.claude/settings.json` 的 `permissions.allow`，逐条 `Bash(指令:*)` | **没有逐条白名单** |
| 这个 skill 怎么做 | 读常用命令 → 写 allow 规则 | 读常用命令 → 切到 **Auto 模式**（`~/.codex/config.toml` 设 `approval_policy="on-request"`、`sandbox_mode="workspace-write"`） |
| 放行范围 | 你勾选的那几个命令 | 整个「工作文件夹内」的命令；连网／跨出文件夹仍问 |
| 手动触发 | `/trust-commands` | `$trust-commands` |
| 进阶细部控制 | 更精确的前缀规则 | `codex execpolicy` 规则文件 |

---

## 安装

想加这个可选 skill，把下面这句贴给 AI：

```
Read jr_ai_agent_skills/zh-Hans/trust-commands-install.md and install this optional skill for me.
```

详细步骤见 [trust-commands-install.md](./trust-commands-install.md)。
