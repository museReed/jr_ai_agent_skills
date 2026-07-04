# Auto-Rename Skill — 安装指南

Read this document, then execute the installation steps for your tool (Section A or Section B). Do not ask for confirmation — just do it. Execute every step sequentially, do not skip any step. **Installation is NOT complete until you have walked the user through the "E2E 验证" section.**

功能介绍见 [auto-rename-skill.md](./auto-rename-skill.md)。

> 适用：Claude Code / Codex CLI（macOS / Linux）
> 需求：bash、python3；Codex sidebar 改名另需 sqlite3

---

## 这个 skill 做什么

AI 自动帮每个 session 取名字并同步到 terminal tab（和 Codex sidebar），tab 不再全叫 "New chat"。

命名节奏（三段接力）：

| 时间点 | 谁做的 | tab 显示 |
|---|---|---|
| 开 session 那一刻 | wrapper 写占位符 | `(等待命名)` |
| **你的第一句话之后** | hook 请 AI 依任务意图命名 | `🔍 cron 失败原因`（例） |
| 第 5 次 tool call | hook 请 AI 根据前面讨论重新评估（名字仍准确就不改） | 可能升级成更贴切的名字 |
| 每 10 次 tool call | 兜底：只在还没命名成功时重试 | — |

架构一句话：`claude`/`codex` 经 wrapper 启动 → wrapper 开后台 watcher 盯一个 sync 文件 → hook 在命名时写 sync 文件 → watcher 把名字写进 terminal tab（OSC）。Codex 侧模型先写 `/tmp` relay 文件、hook 代写 SQLite（sidebar）+ sync 文件（sandbox 限制）。

## Section A: Claude Code 安装

所有 script 都在本 repo 的 `installer/`，一个指令装完（hooks + skills + 注册）：

```bash
cd jr_ai_agent_skills/installer
./install.sh claude
```

然后把 alias 加进 shell rc（`~/.zshrc` 或 `~/.bashrc`）：

```bash
alias claude='$HOME/.local/bin/myclaude'
```

装完跳到「编辑器设置」。

## Section B: Codex CLI 安装

```bash
cd jr_ai_agent_skills/installer
./install.sh codex
```

alias：

```bash
alias codex='$HOME/.local/bin/mycodex'
```

> 两个工具都用 → `./install.sh`（不带参数），两个 alias 都加。
> installer 是幂等的：重跑安全，会自动备份被取代的文件（`*.bak.{timestamp}`）。

## 编辑器设置（VS Code 系必做，iTerm / Terminal.app 跳过）

Cursor、Antigravity、VS Code 的 terminal tab **默认不显示** OSC 标题，必须在该编辑器的
`settings.json`（Cmd+Shift+P → "Open User Settings (JSON)"）加：

```json
"terminal.integrated.tabs.title": "${sequence}"
```

- 只对**保存后新开**的 terminal 生效
- 用哪个编辑器就设哪个（Cursor / Antigravity / VS Code 各有各的 settings.json）

## E2E 验证（AI agent 必须主动引导用户完成，不可跳过）

### 第 1 步：自动检查

```bash
cd jr_ai_agent_skills/installer
./verify.sh          # 或 ./verify.sh claude / ./verify.sh codex
```

全部 PASS 才往下；有 FAIL 先照信息修（改完重跑 `install.sh` 再 verify）。

### 第 2 步：真实行为验证（引导用户做这三件事）

1. 请用户**开一个新的 terminal**（旧 terminal 还在旧环境，测了不算）
2. 请用户跑 `claude`（或 `codex`），打一句有任务内容的话，例如「列出这个文件夹的文件」
3. 预期结果：**第一个回合内** terminal tab 变成 `{emoji} 任务描述`
4. Codex 额外验证 sidebar：

```bash
sqlite3 "$(ls -t ~/.codex/state_*.sqlite | head -1)" \
  "SELECT title FROM threads ORDER BY updated_at_ms DESC LIMIT 1;"
```

### 失败时（AI agent 的责任，不要只说「装完了」就结束）

1. 跑 `./verify.sh --report` 产出诊断报告
2. 开 `installer/TROUBLESHOOTING.md`，按症状对照表逐条检查
3. 修不掉 → 替用户准备好 issue 内容（报告全文 + 现场证据），引导用户贴到：
   <https://github.com/museReed/jr_ai_agent_skills/issues/new?template=install-report.md>

## 机制细节（debug 时参考）

| 组件 | 位置 | 作用 |
|---|---|---|
| `myclaude` / `mycodex` | `~/.local/bin/` | 建 sync 文件 + 起 watcher + 启动本体 |
| `ai-tab-sync.sh` | `~/.local/bin/` | watcher：轮询 sync 文件 → OSC 写 tty |
| sync 文件 | `~/.ai-session-names/{pid}.txt` | tab 名字的唯一事实来源 |
| `session-auto-namer.sh` | `~/.claude/hooks/` | UserPromptSubmit（第一句话命名）+ PostToolUse（#5 重评、每 10 次兜底） |
| `codex-session-namer.sh` | `~/.codex/hooks/` | 同上 + 消化 relay 文件、代写 SQLite |
| relay 文件（Codex） | `/tmp/codex-session-namer/{pid}.pending` | 模型在 sandbox 里唯一能写的交棒点 |
| skill | `~/.claude/skills/auto-rename/`、`~/.codex/skills/auto-rename/` | 手动 `/auto-rename` 时的规则 |

## 迁移到其他电脑

新电脑上 clone 本 repo → 跑同样的 `install.sh` + alias + 编辑器设置 + `verify.sh` 即可，
不需要从旧电脑复制任何文件。
