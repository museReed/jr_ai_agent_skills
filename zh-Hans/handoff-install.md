# Handoff Skill — 安装指南

全新安装请读 [auto-rename-install.md](./auto-rename-install.md)，按单一 AI 引导流程检测 Claude／Codex 与当前 terminal／IDE，再一次安装 auto-rename、handoff、structured-questions。以下命令只供直接重装，不是分开安装 skill。**学生打开新 session 并完成三段 E2E 前，不算安装完成。**

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

## Claude Code 直接重装参考

所有 script 都在本 repo 的 `installer/`（auto-rename 装过的话重跑同个指令即可，幂等）：

```bash
cd jr_ai_agent_skills/installer
./install.sh claude --editor=<confirmed-editor>
```

装了什么（handoff 相关部分）：

| 文件 | 位置 | 作用 |
|---|---|---|
| `handoff/SKILL.md` | `~/.claude/skills/handoff/` | 交接文档产出流程 |
| `context-monitor.sh` | `~/.claude/hooks/` | PostToolUse 读 transcript 的真实 token 数，>70% 警告 |

## Codex CLI 直接重装参考

```bash
cd jr_ai_agent_skills/installer
./install.sh codex --editor=<confirmed-editor>
```

| 文件 | 位置 | 作用 |
|---|---|---|
| `handoff/SKILL.md` | `~/.agents/skills/handoff/` | 交接文档产出流程（改名走 relay 文件） |
| `_shared/codex-session-rename.md` | `~/.agents/skills/_shared/` | 改名方法的唯一事实来源 |
| `codex-context-monitor.sh` | `~/.codex/hooks/` | 读 rollout 的 token_count，>70% 警告；读不到时用 tool call 数估算 |

## E2E 验证（AI agent 必须主动引导用户完成，不可跳过）

> 完整逐步引导剧本（四轮 × 检查点编号）→ Read `installer/VERIFICATION.md`，照它带用户跑。

### 第 1 步：自动检查

```bash
cd jr_ai_agent_skills/installer
./verify.sh
```

verify 会模拟 context-monitor 触发（假 transcript + 缩小窗口），全 PASS 才往下。

### 第 2 步：完整 handoff 测试（引导用户做）

handoff 会建立文档与 commit，必须在临时 repo 测试。请用户开**新 terminal**，先贴：

```bash
TEST_REPO="$(mktemp -d "${TMPDIR:-/tmp}/jr-skill-e2e.XXXXXX")" && \
git -C "$TEST_REPO" init -q && printf '# e2e skill test\n' > "$TEST_REPO/README.md" && \
git -C "$TEST_REPO" add README.md && \
git -C "$TEST_REPO" config user.name 'Skill E2E' && \
git -C "$TEST_REPO" config user.email 'skill-e2e@example.invalid' && \
git -C "$TEST_REPO" commit -qm init && \
cd "$TEST_REPO"
```

1. 启动测试 session：
   - Claude Code：`CONTEXT_MONITOR_TEST_WINDOW=30000 claude`
   - Codex：`CODEX_TEST_MAX_CONTEXT_WINDOW=5000 codex`
2. 叫它读 README 并列出文件；Codex 再下第二个指令「再列一次」。
3. 看到测试模式 context 警告后，要求「照警告完整写 handoff，全部步骤做完」。
4. 必须确认：`docs/handoff/` 出现文档、有新 commit、session 改名成 `📦 …`；Codex 的警告也停止重复。
5. 离开测试 session，在原 shell 执行 `rm -rf "$TEST_REPO"`。正常 session 不带测试变量，行为完全不变。

### 失败时（AI agent 的责任，不要只说「装完了」就结束）

1. Read `installer/TROUBLESHOOTING.md`，按症状对照表排查；修好后重跑 `install.sh` 再 `verify.sh`
2. 修不掉 → 跑一个指令回报（自动跑 verify --report、收集现场证据、开 issue，不用手工整理）：

```bash
cd jr_ai_agent_skills/installer
./diagnose.sh "{工具} {一句话症状}"     # 例：./diagnose.sh "codex tab 不改名 @ Cursor"
```

有 `gh` CLI 且已登录会直接开好 issue；没有则内容进剪贴板 + 打开预填的 new-issue 页，请用户贴上提交。

## 机制细节（debug 时参考）

- Claude 侧 context-monitor 从 hook stdin 的 `transcript_path` 读**当前 session** 的 JSONL——
  不用 mtime 猜文件（多 session 同开会猜错，这是修过的坑）
- Codex 侧优先读 rollout JSONL 的 `token_count` 事件；读不到退回「tool call 数 ≈ 用量」估算
- Codex 的 `token_count` 在**回合结束**才写入，hook 在回合中执行 → 警告有一回合时差，
  测试时第二个指令才会看到（正常使用无感，70% 不会只差一回合）
- 测试旋钮：`CONTEXT_MONITOR_TEST_WINDOW`（Claude）/ `CODEX_TEST_MAX_CONTEXT_WINDOW`（Codex），
  只影响带着变量启动的那个 session
- Codex 触发后会**持续催**直到 AI 建立 hook 消息指定的 `.handoff` marker——
  这是防漏设计，不是 bug
