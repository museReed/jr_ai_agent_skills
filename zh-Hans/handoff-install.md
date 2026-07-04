# Handoff Skill — 安装指南

Read this document, then execute the installation steps for your tool (Section A or Section B). Do not ask for confirmation — just do it. Execute every step sequentially, do not skip any step. **Installation is NOT complete until you have walked the user through the "E2E 验证" section.**

功能介绍见 [handoff-skill.md](./handoff-skill.md)。

> 适用：Claude Code / Codex CLI（macOS / Linux）
> 需求：bash、python3、git repo（handoff 文档 commit 到 `docs/handoff/`）
> 建议先装 [auto-rename](./auto-rename-install.md)——handoff 完成后的 📦 改名依赖它的同步机制。

---

## 这个 skill 做什么

两个部件，同一个 installer 装：

1. **handoff skill**：session 要结束（或 context 快满）时，AI 产出结构化交接文档到
   `docs/handoff/{date}-{topic}.md`，commit，然后把 session 改名成 `📦 {topic}` 标记已交接。
   新 session 读一个文件就能无缝接续。
2. **context-monitor hook**：每次 tool call 后读 session 的真实 token 用量，
   超过 **70%** 就注入警告叫 AI 立刻写 handoff——避免 context 爆掉才想起来要交接。

## Section A: Claude Code 安装

所有 script 都在本 repo 的 `installer/`（auto-rename 装过的话重跑同个指令即可，幂等）：

```bash
cd jr_ai_agent_skills/installer
./install.sh claude
```

装了什么（handoff 相关部分）：

| 文件 | 位置 | 作用 |
|---|---|---|
| `handoff/SKILL.md` | `~/.claude/skills/handoff/` | 交接文档产出流程 |
| `context-monitor.sh` | `~/.claude/hooks/` | PostToolUse 读 transcript 的真实 token 数，>70% 警告 |

## Section B: Codex CLI 安装

```bash
cd jr_ai_agent_skills/installer
./install.sh codex
```

| 文件 | 位置 | 作用 |
|---|---|---|
| `handoff/SKILL.md` | `~/.codex/skills/handoff/` | 交接文档产出流程（改名走 relay 文件） |
| `_shared/codex-session-rename.md` | `~/.codex/skills/_shared/` | 改名方法的唯一事实来源 |
| `codex-context-monitor.sh` | `~/.codex/hooks/` | 读 rollout 的 token_count，>70% 警告；读不到时用 tool call 数估算 |

## E2E 验证（AI agent 必须主动引导用户完成，不可跳过）

> 完整逐步引导剧本（四轮 × 检查点编号）→ Read `installer/VERIFICATION.md`，照它带用户跑。

### 第 1 步：自动检查

```bash
cd jr_ai_agent_skills/installer
./verify.sh
```

verify 会模拟 context-monitor 触发（假 transcript + 缩小窗口），全 PASS 才往下。

### 第 2 步：真实触发测试（引导用户做）

用「缩小窗口」让警告提早出现，不用真的聊到 70%：

1. 请用户开**新 terminal**，在一个 git repo 里启动测试 session：
   - Claude Code：`CONTEXT_MONITOR_TEST_WINDOW=30000 claude`
   - Codex：`CODEX_TEST_MAX_CONTEXT_WINDOW=20000 codex`
2. 叫它做 1-2 件会动手的事（例如「列出这个文件夹的文件」），做完**再下第二个指令**（例如「再列一次」）
3. 预期：**第二个指令的回合起**，AI 开始说「⚠️ Context 已用 …（測試模式）请写交接文档」——**看到警告＝hook 验证成功**，可以直接关掉，不用真的写完 handoff
4. （可选）让它写完：检查 `docs/handoff/` 出现文档、有 commit、session 改名成 `📦 …`
5. 提醒用户：测试 session 关掉即可，正常 session 不设环境变量、行为完全不变

### 第 3 步：手动 handoff 验证（可选）

任何正常 session 里打「写 handoff」→ 应产出文档 + commit + 📦 改名 + 汇报单行起始 prompt。

### 失败时（AI agent 的责任，不要只说「装完了」就结束）

1. 跑 `./verify.sh --report` 产出诊断报告
2. 开 `installer/TROUBLESHOOTING.md` 按症状对照表检查（第 8 条就是 context-monitor 常见问题）
3. 修不掉 → 替用户准备好 issue 内容，引导用户贴到：
   <https://github.com/museReed/jr_ai_agent_skills/issues/new?template=install-report.md>

## 机制细节（debug 时参考）

- Claude 侧 context-monitor 从 hook stdin 的 `transcript_path` 读**当前 session** 的 JSONL——
  不用 mtime 猜文件（多 session 同开会猜错，这是修过的坑）
- Codex 侧优先读 rollout JSONL 的 `token_count` 事件；读不到退回「tool call 数 ≈ 用量」估算
- Codex 的 `token_count` 在**回合结束**才写入，hook 在回合中执行 → 警告有一回合时差，
  测试时第二个指令才会看到（正常使用无感，70% 不会只差一回合）
- 测试旋钮：`CONTEXT_MONITOR_TEST_WINDOW`（Claude）/ `CODEX_TEST_MAX_CONTEXT_WINDOW`（Codex），
  只影响带着变量启动的那个 session
- Codex 触发后会**持续催**直到 AI 照指示 `touch /tmp/codex-context-monitor/{pid}.handoff`——
  这是防漏设计，不是 bug
