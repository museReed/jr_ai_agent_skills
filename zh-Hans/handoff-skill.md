# Handoff — 让 AI 帮你写交接文件，下个 Session 不用从头来

**适用工具**: Claude Code / Codex CLI
**安装指南**: [handoff-install.md](./handoff-install.md)

---

## 这个 Skill 解决什么问题？

你有没有遇过这种情况——

你跟 AI 聊了很久，讨论了很多细节、试了很多方法、做了很多决定。结果 session 关掉之后，下一个 session 完全不知道之前发生过什么。你得从头解释一遍背景、重新说明需求、再把之前试过但没用的方法又走一遍。

这个 skill 做两件事：

1. **让 AI 在 session 结束前，自动整理一份交接文件。** 包含：做了什么、做到哪里、下一步要做什么、哪些文件要读。新 session 读完这份文件就能无缝接手，不用你重新解释。

2. **在 context 快满的时候提醒你。** AI 不会等到突然断掉才告诉你，而是提前警告「快满了，我先写交接文件」，让你优雅地切换到新 session。

---

## Before / After 对比

### 价值一：开新 Session 后，不用从头来

> 每次开新 session 都能从上次结束的地方继续，不用重新解释背景。

---

#### 场景 A：跟 AI 讨论旅游行程，关掉后要从头讲

**Before — 新 session 什么都不知道：**

```
（上一个 session：讨论了 30 分钟京都行程，决定了住宿区域、交通方案、每天景点）

你：（隔天打开新对话）
你：我们昨天讨论的京都行程，帮我继续排第三天
AI：你好！请问你的京都行程是几天？住哪里？有什么偏好？
你：（叹气，从头讲一遍）
```

问题：AI 不记得上次的对话，你得重新交代所有背景。

**After — 新 session 读完交接文件就能接手：**

```
（上一个 session 结束前，AI 自动产出交接文件）

你：读 docs/handoff/2026-06-30-kyoto-trip.md 继续工作
AI：（读完交接文件）
AI：好，上次决定了住四条河原町、买巴士一日券、第一天清水寺+祇园、
    第二天岚山。接下来排第三天，你想去伏见稻荷还是金阁寺？
```

差异：不用重新解释，AI 直接从上次结束的地方接续。

---

#### 场景 B：写企划书改了三轮，隔天打开新 session 又要重头

**Before — 三轮修改的历史全部遗失：**

```
（上一个 session：写了企划书初稿 → 主管反馈改了结构 → 又调了预算表）

你：（隔天）继续修改企划书
AI：好的，请问企划书的主题是什么？目前进度如何？
你：（要重新描述主题、结构、预算、主管的三轮反馈...）
```

**After — 所有修改历史都在交接文件里：**

```
你：读 docs/handoff/2026-06-30-proposal-v3.md 继续
AI：（读完）企划书已到第三版，主管反馈的预算调整已完成。
    下一步是加上 ROI 分析。要从这里接续吗？
```

差异：三轮修改的决策和原因都保留了，不用重新交代。

---

#### 场景 C：Debug 到一半 context 满了，新 session 不知道试过哪些方法

**Before — 白走一遍已经排除的方向：**

```
（上一个 session：花了 45 分钟 debug，排除了 3 种可能，锁定到第 4 种）

你：（context 满了，开新 session）
你：API 回传 500 error，帮我 debug
AI：好的，让我们从头排查。首先检查 request payload...
你：（这个我已经查过了！！！）
```

问题：新 session 从零开始，把已经排除的方向又走一遍。

**After — 交接文件记录了排查进度：**

```
你：读 docs/handoff/2026-06-30-api-500-debug.md 继续
AI：（读完）已排除：payload 格式、auth token、rate limit。
    目前锁定在 DB connection pool 耗尽。下一步是看 connection 数量。
    直接从这里继续？
```

差异：不重走已排除的路，直接从锁定的方向继续。

---

#### 场景 D：跨天开发 feature，每天都要重新讲背景

**Before — 每天开工都要花 10 分钟交代 context：**

```
（昨天：写完 TDD 的前 8 个 test，全绿。正要开始第 9 个）

你：（今天开新 session）
你：我在做 #1234 的 voice pipeline feature，昨天写到 test 8，
    用的是 pytest，test file 在 tests/unit/test_voice.py，
    相关的 source code 在 platform/voice/...
AI：好的，让我先读一下这些文件...
你：（又花了 10 分钟等 AI 重新理解 codebase）
```

**After — 交接文件就是今天的启动指令：**

```
你：读 docs/handoff/2026-06-29-voice-pipeline-tdd.md 继续
AI：（读完）Issue #1234，TDD Phase 2。Test 1-8 全绿。
    下一步：写 Test 9（Scenario: 空白 transcript 的 fallback）。
    需要读的文件：tests/unit/test_voice.py（看已有 test 的 pattern）、
    platform/voice/src/muse_voice/pipeline.py（实现对象）。
```

差异：交接文件就是「今天从哪里开始」的完整指令，不用自己回想。

---

### 价值二：Context 快满时优雅收尾，不会突然断掉

> AI 提前警告「快满了」，写好交接再结束——不是等到断掉才手忙脚乱。

---

#### 场景 E：AI 回复越来越短，你才发现 context 快满了

**Before — 没有预警，突然就断了：**

```
你：帮我把这个函数重构一下
AI：好

你：...就这样？
AI：抱歉，由于上下文限制，我无法提供完整的回复...
你：（之前讨论的所有 context 都在这个即将关闭的窗口里）
```

问题：没有预警，等你发现的时候已经来不及整理了。

**After — 提前警告 + 自动写交接：**

```
AI：⚠️ Context 已用 ~145k tokens（72%）。我先写交接文件，
    建议之后开新 session 继续。

AI：Handoff 已产出：docs/handoff/2026-06-30-refactor-session.md
    Branch: feature/1234-voice-pipeline
    读 docs/handoff/2026-06-30-refactor-session.md 继续工作。
```

差异：不会突然断掉，而是有计划地收尾。

---

#### 场景 F：做简报做到一半，AI 突然不能回复了

**Before — 进度卡在关掉的窗口里：**

```
（写了 20 页简报，改了 5 轮）

AI：[token limit reached]
你：（那我改到哪一版了？第 12 页的图表改了没？主管的第三轮反馈处理了吗？）
你：（全部都要自己回想或翻纪录）
```

**After — 断掉之前就有完整纪录：**

```
AI：⚠️ Context 快满了，我先整理交接文件。

交接文件内容：
- 已完成：第 1-15 页定稿、第 16-18 页图表更新
- 进行中：第 19 页的 ROI 分析
- 下一步：完成第 19-20 页 → 全文校稿
```

差异：进度不会随着窗口关闭而消失。

---

#### 场景 G：跑 TDD 到第 8 个 test，context 满了

**Before — 不知道哪些 test 过了、哪些没写：**

```
你：（开新 session）我在做 voice pipeline 的 TDD，跑到哪了？
AI：请问你的 test file 在哪里？目前有哪些 test case？
你：（又要从头交代一遍 TDD 计划和进度）
```

**After — 交接文件有完整的 TDD 进度：**

```
交接文件：
- Test 1-8：全绿 ✅
- Test 9-12：尚未实现
- 下一步：Test 9（空白 transcript fallback）
- 必读：TDD Index 在 docs/features/voice/tdd-index.md
```

差异：新 session 知道「8 个过了、从第 9 个开始」。

---

#### 场景 H：PR review 做到一半，context 满了

**Before — reviewer 的意见散落在关掉的对话里：**

```
你：（reviewer 提了 5 点，AI 帮你改了 3 点，还有 2 点没处理）
你：（context 满了，新 session 不知道哪些改了、哪些没改）
```

**After — 交接文件追踪每一点的处理状态：**

```
交接文件：
- Reviewer 意见 1-3：已修改并 commit ✅
- 意见 4：需要跟 reviewer 确认（等回复）
- 意见 5：尚未处理（类型定义要改）
- 下一步：处理意见 5 → re-request review
```

差异：review 进度不会因为 context 满了而遗失。

---

## 怎么触发？

| 方式 | Claude Code | Codex CLI |
|---|---|---|
| **自动触发** | Context 用量 > 70% 时，hook 提醒 AI 写交接文件 | 无自动触发 |
| **手动触发** | 输入 `/handoff` | 输入 `$handoff` |
| **关键字** | 对话中说「交接」「handoff」「session 结束」 | 同左 |

## 适用场景

| 场景 | 你遇到的情况 | AI 怎么帮你 |
|---|---|---|
| **Session 要结束** | 今天做到一半，明天要继续 | 自动产出交接文件，记录做了什么、下一步做什么 |
| **Context 快满** | AI 回复变短、hook 警告 token 用量高 | 提前整理交接 + 提示你开新 session |
| **换人接手** | 你做了一半要交给同事的 AI session 继续 | 交接文件是通用格式，任何新 session 都能读 |
| **跨天开发** | 每天开新 session 要重新交代背景 | 每天结束前跑 `/handoff`，隔天直接读文件继续 |

## 不适用的情况

- 很短的一次性对话 → 没东西要交接
- 所有工作都在单次 session 内完成 → 不需要跨 session 接续
- 纯闲聊 → 不需要结构化记录

---

## 安装

一句指令，让 AI 帮你装：

**Claude Code：**
```
Read docs/guides/handoff-install.md and execute Section A
```

**Codex CLI：**
```
Read docs/guides/handoff-install.md and execute Section B
```

详细步骤见 [handoff-install.md](./handoff-install.md)。

---

## Claude Code vs Codex 差异

| | Claude Code | Codex CLI |
|---|---|---|
| 自动触发 | 有（context-monitor hook 在 70% 时警告） | 无 |
| Session 封存改名 | 写文件 `~/.claude/session-names/${PID}.txt` + OSC escape | 写 SQLite `~/.codex/state_*.sqlite` |
| 安装位置 | `.claude/skills/handoff/SKILL.md` | `.codex/skills/handoff/SKILL.md` |
| 手动触发 | `/handoff` | `$handoff` |
| 交接文件位置 | `docs/handoff/{date}-{topic}.md`（两边相同） | 相同 |
