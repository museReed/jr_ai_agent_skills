# Auto-Rename Skill — 安装指南

Read this document and guide the user through the single installation flow below. Detect first, ask only when a real choice remains, and execute every step sequentially. **Installation is NOT complete until the user has opened a new session and completed all three skills' E2E checks.**

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

## 单一 AI 引导式安装流程

### 1. 先检测，不修改任何设置

```bash
cd jr_ai_agent_skills/installer
python3 detect-environment.py
```

读取 JSON 中的 `cli`、`recommended_install_target`、`terminal` 与 `editors`。父进程是强证据，`TERM_PROGRAM` 次之；设置文件存在只代表该 IDE 安装或用过，不能代表当前 terminal。

### 2. 决定安装目标

| 检测结果 | AI 行为 |
|---|---|
| 只有 Claude CLI | 告知“检测到 Claude Code，将安装 Claude 版本”，不提问 |
| 只有 Codex CLI | 告知“检测到 Codex CLI，将安装 Codex 版本”，不提问 |
| 两者都有 | 用结构化问题询问“两者（Recommended）／Claude／Codex” |
| 两者都没有 | 停止；请用户先安装至少一个 CLI |

安装前不能假设 `structured-questions` skill 已存在，因此直接遵守以下内置流程：

- Claude Code：使用 `AskUserQuestion` 交互菜单。
- Codex Plan mode：使用 `request_user_input`；每次最多 3 题、每题 2–3 个选项，推荐项置首并加 `(Recommended)`，每个 description 用一行说明取舍。
- Codex Default mode：输出“你目前不在 Plan mode。若要互动式选单，请输入 `/plan 繼續安裝 jr_ai_agent_skills`；若不要切换，请回复‘不切换’，我会改用文字选项。”然后停止，不先列选项。
- 用户回复“要／切换”时，引导输入 `/plan 繼續安裝 jr_ai_agent_skills` 后停止；直接输入该指令并切换成功后，用 `request_user_input` 继续。
- 只有明确回复“不要／不切换”才在同一轮列出完整文字选项；模糊回答必须再问“切换”或“不切换”，不得自行 fallback。

### 3. 一律确认当前 terminal／IDE

检测结果只是推荐，AI 必须用同一套结构化问题让学生确认。明确检测时先问“使用检测结果（Recommended）／其他 VS Code 系 IDE／Terminal、iTerm 或其他”；选其他 VS Code 系 IDE 时，再问“Cursor／Antigravity／VS Code”。检测不明时先问“VS Code 系 IDE／Terminal、iTerm 或其他”，选前者后再问是哪一个 IDE。

只设置学生最后确认的 IDE：

```bash
python3 configure-editor.py cursor       # 或 antigravity / vscode
python3 configure-editor.py native       # Terminal.app、iTerm 或其他：明确不修改设置
```

若已有 `settings.json` 含 JSONC 注释而解析失败，原文件不会被写入；请学生在已确认的那个 IDE 内用 "Open User Settings (JSON)" 手动加入 `"terminal.integrated.tabs.title": "${sequence}"`。不可因为其他 IDE 的设置文件存在而修改它。

### 4. 执行非交互 installer 并写 alias

```bash
./install.sh claude --editor=<confirmed-editor>   # 只安装 Claude Code
./install.sh codex --editor=<confirmed-editor>    # 只安装 Codex CLI
./install.sh --editor=<confirmed-editor>          # 两者都安装
```

一个指令会安装该目标的 auto-rename、handoff、structured-questions 三个 skills 与相关 hooks，无需逐个 skill 安装。AI 接着把对应 alias 写进 shell rc（幂等，两者都装就执行两段）：

```bash
RC="$HOME/.zshrc"; case "$SHELL" in *bash*) RC="$HOME/.bashrc";; esac
TARGET="<claude|codex|all>"
case "$TARGET" in claude|all) grep -q "alias claude=.*myclaude" "$RC" 2>/dev/null || echo "alias claude='\$HOME/.local/bin/myclaude'" >> "$RC";; esac
case "$TARGET" in codex|all) grep -q "alias codex=.*mycodex" "$RC" 2>/dev/null || echo "alias codex='\$HOME/.local/bin/mycodex'" >> "$RC";; esac
```

只写入实际安装目标的 alias。installer 可安全重跑；Codex skill 备份放在 `~/.agents/skill-backups/{timestamp}/`，其他文件使用 `*.bak.{timestamp}`。

### 5. 必须停下并要求新环境

installer 完成后，AI 必须明确要求学生**打开新的 terminal，再启动新的 AI session**，并把 installer 输出的 target-aware continuation prompt 贴进新 session，然后停止当前流程。旧 session 不会重新加载刚安装的 skills，不得在旧 session 宣称安装或 E2E 已完成。

## E2E 验证（AI agent 必须主动引导用户完成，不可跳过）

> 完整逐步引导剧本（四轮 × 检查点编号）→ Read `installer/VERIFICATION.md`，照它带用户跑。

### 第 1 步：自动检查

```bash
cd jr_ai_agent_skills/installer
./verify.sh claude --editor=<confirmed-editor>  # 替换为 cursor / antigravity / vscode / native
# 或改用 codex；两者都装时省略 claude/codex
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

1. Read `installer/TROUBLESHOOTING.md`，按症状对照表排查；修好后重跑 `install.sh` 再 `verify.sh`
2. 修不掉 → 跑一个指令回报（自动跑 verify --report、收集现场证据、开 issue，不用手工整理）：

```bash
cd jr_ai_agent_skills/installer
./diagnose.sh "{工具} {一句话症状}"     # 例：./diagnose.sh "codex tab 不改名 @ Cursor"
```

有 `gh` CLI 且已登录会直接开好 issue；没有则内容进剪贴板 + 打开预填的 new-issue 页，请用户贴上提交。

## 机制细节（debug 时参考）

| 组件 | 位置 | 作用 |
|---|---|---|
| `myclaude` / `mycodex` | `~/.local/bin/` | 建 sync 文件 + 起 watcher + 启动本体 |
| `ai-tab-sync.sh` | `~/.local/bin/` | watcher：轮询 sync 文件 → OSC 写 tty |
| sync 文件 | `~/.ai-session-names/{pid}.txt` | tab 名字的唯一事实来源 |
| `session-auto-namer.sh` | `~/.claude/hooks/` | UserPromptSubmit（第一句话命名）+ PostToolUse（#5 重评、每 10 次兜底） |
| `set-session-name.sh` | `~/.claude/hooks/` | 命名写入包装脚本（hook 自动命名与 `/auto-rename` 共用；把写文件/OSC/清 marker 收进单一脚本，免 `&&` 串接、一条白名单放行） |
| `codex-session-namer.sh` | `~/.codex/hooks/` | 同上 + 消化 relay 文件、代写 SQLite |
| relay 文件（Codex） | `/tmp/codex-session-namer/{pid}.pending` | 模型在 sandbox 里唯一能写的交棒点 |
| skill | `~/.claude/skills/auto-rename/`、`~/.agents/skills/auto-rename/` | 手动 `/auto-rename` 时的规则 |

## 迁移到其他电脑

新电脑上 clone 本 repo → 让 AI 跑检测与确认 → `install.sh` + alias + 已确认的编辑器设置 + `verify.sh` 即可，
不需要从旧电脑复制任何文件。
