# Auto-Rename — 让每个 AI Session 都有自己的名字

**适用工具**: Claude Code / Codex CLI
**安装指南**: [auto-rename-install.md](./auto-rename-install.md)

---

## 这个 Skill 解决什么问题？

你有没有遇过这种情况——

你开了好几个 AI 对话窗口，每个 tab 都叫同一个名字。你想切回刚刚在做的那个，结果要一个一个点开来确认。开越多越混乱，最后干脆全部关掉重来。

这个 skill 做一件事：

1. **让 AI 自动帮每个 session 取一个看得懂的名字。** 根据你们在聊什么，AI 会自动用 emoji + 中文叙述命名（例如「🏗️ voice profile pipeline」），你从 tab 列表一眼就能找到要的那个。

---

## Before / After 对比

### 价值：Tab 太多，找不到你要的 session

> 不管开几个 session，每个都有名字，一眼就知道哪个在做什么。

---

#### 场景 A：开了好几个 AI 对话，全部叫一样的名字

**Before — 你得一个一个点开确认：**

```
你的 tab 列表：
  [New chat]  [New chat]  [New chat]  [New chat]  [New chat]

你：（哪个是刚刚在讨论食谱的？）
你：（点开第一个——不是，这个在聊旅游）
你：（点开第二个——也不是，这个在问健身）
你：（点开第三个——终于找到了）
```

问题：开 5 个对话就要猜 5 次，开 10 个就放弃了。

**After — 每个对话自动有名字：**

```
你的 tab 列表：
  [🔍 京都五日行程]  [🏗️ 减脂菜单规划]  [💬 健身课表讨论]  [📐 侧边栏 UI]  [🐛 登入错误排查]

你：（一眼找到「京都五日行程」，点开继续）
```

差异：不用猜、不用点开确认，tab 名字就是内容摘要。

---

#### 场景 B：上班时开了多个 AI 助手，分不清哪个在做什么

**Before — sidebar 全部长一样：**

```
Codex sidebar：
  muse-platform  (3 minutes ago)
  muse-platform  (15 minutes ago)
  muse-platform  (1 hour ago)

你：（15 分钟前那个是在写简报还是整理会议纪录？）
你：（只能靠时间猜，猜错就浪费时间）
```

问题：同一个项目开多个 session，sidebar 显示的都是项目名，毫无区别。

**After — 每个 session 自动命名：**

```
Codex sidebar：
  📐 Q3 简报架构  (3 minutes ago)
  📋 周会纪录整理  (15 minutes ago)
  🔍 竞品分析      (1 hour ago)

你：（直接点「周会纪录整理」继续）
```

差异：不用靠时间推测内容，名字就说明了一切。

---

#### 场景 C：开了多个 Claude Code session，terminal tab 全部显示 branch 名

**Before — 4 个 tab 全部显示 `develop`：**

```
Terminal tabs：
  [develop]  [develop]  [develop]  [develop]

你：（哪个在跑 TDD？哪个在 debug？哪个在写 PRD？）
你：（切到第三个——啊不是，这个在做 PR review）
```

问题：branch 名不能告诉你「这个 session 在做什么」。

**After — 每个 tab 自动命名：**

```
Terminal tabs：
  [🏗️ voice profile pipeline]  [🐛 Gemini 429 debug]  [📐 PRD2 设计]  [📋 PR review]

你：（直接切到「Gemini 429 debug」继续排查）
```

差异：tab 名从「你在哪个 branch」变成「你在做什么事」。

---

#### 场景 D：同一个 repo 开 3 个 Codex session，做不同的事

**Before — sidebar 完全无法区分：**

```
Codex sidebar：
  muse-platform  (just now)
  muse-platform  (5 minutes ago)
  muse-platform  (20 minutes ago)

你在做三件事：
  1. 修 crawler 的重试逻辑（5 分钟前那个）
  2. 写新的 voice pipeline（20 分钟前那个）
  3. 刚开的要做 code review

你：（每次都要靠记忆对应时间，记错就切错 session）
```

**After — 每个 session 手动或自动命名：**

```
Codex sidebar：
  📋 crawler PR review     (just now)
  🔧 爬虫重试逻辑          (5 minutes ago)
  🏗️ voice pipeline 建模   (20 minutes ago)

你：（直接点「爬虫重试逻辑」继续修 bug）
```

差异：不再靠记忆配对「几分钟前 = 哪件事」。

---

## 怎么触发？

| 方式 | Claude Code | Codex CLI |
|---|---|---|
| **自动触发** | Hook 在第 5 次 tool call 时自动提醒 AI 命名 | 无自动触发 |
| **手动触发** | 输入 `/auto-rename` | 输入 `$auto-rename` |
| **关键字** | 对话中说「改名」「命名」「rename」 | 同左 |

## 适用场景

| 场景 | 你遇到的情况 | AI 怎么帮你 |
|---|---|---|
| **多 session 同时开** | Tab / sidebar 全部长一样，切换时要猜 | 自动用 emoji + 中文命名每个 session |
| **Session 主题改变** | 一开始在 debug，后来变成 refactor，名字过时了 | 手动 `/auto-rename` 重新命名 |
| **交接前标记** | 想标记哪些 session 已经结束 | 搭配 `/handoff` 自动加上 📦 前缀 |

## 不适用的情况

- Session 刚开始（< 3 轮对话）→ 信息不足，等多聊几句再命名
- 你已经手动取了满意的名字 → AI 不会覆盖

---

## 安装

一句指令，让 AI 帮你装：

**Claude Code：**
```
Read docs/guides/auto-rename-install.md and execute Section A
```

**Codex CLI：**
```
Read docs/guides/auto-rename-install.md and execute Section B
```

详细步骤见 [auto-rename-install.md](./auto-rename-install.md)。

---

## Claude Code vs Codex 差异

| | Claude Code | Codex CLI |
|---|---|---|
| 自动触发 | 有（PostToolUse hook 在第 5 次 tool call 触发） | 无 |
| 命名方式 | 写文件 `~/.claude/session-names/${PID}.txt` | 写 SQLite `~/.codex/state_*.sqlite` |
| Terminal tab 同步 | 直接发 OSC escape 改 tab title | 需用 `mycodex` wrapper 启动才会同步 |
| 安装位置 | `.claude/skills/auto-rename/SKILL.md` | `.agents/skills/auto-rename/SKILL.md` |
| 手动触发 | `/auto-rename` | `$auto-rename` |
