# Trust Commands Skill — 安装指南（可选额外 skill）

Read this document, then execute the copy steps for the user's tool. Do not ask for confirmation on the copy itself — just install it. **安装 = 把 SKILL.md 复制到位；skill 要开新 session 才会载入。**

这是**可选**额外 skill，不在核心三件套（auto-rename / handoff / structured-questions）的 `install.sh` 自动安装内。功能介绍见 [trust-commands-skill.md](./trust-commands-skill.md)。

> 适用：Claude Code / Codex CLI（macOS / Linux）
> 需求：bash。（要真的写白名单时另需 python3 改 JSON——skill 执行时才用到，安装本身不需要。）

---

## 这个 skill 做什么

读你最近的 shell 命令记录 → 挑出最常用又安全的 → 逐条确认后：

- **Claude Code**：把 `Bash(指令:*)` 规则写进 `~/.claude/settings.json` 的 `permissions.allow`
- **Codex**：切到 Auto 模式（`~/.codex/config.toml` 设 `approval_policy` / `sandbox_mode`）——Codex 没有逐条白名单

---

## Section A: Claude Code 安装

```bash
cd jr_ai_agent_skills/installer
mkdir -p "$HOME/.claude/skills/trust-commands"
cp -R skills/claude/trust-commands/. "$HOME/.claude/skills/trust-commands/"
```

装到 `~/.claude/skills/trust-commands/SKILL.md`，手动触发用 `/trust-commands`。

## Section B: Codex CLI 安装

```bash
cd jr_ai_agent_skills/installer
mkdir -p "$HOME/.agents/skills/trust-commands"
cp -R skills/codex/trust-commands/. "$HOME/.agents/skills/trust-commands/"
```

装到 `~/.agents/skills/trust-commands/SKILL.md`，手动触发用 `$trust-commands`。

> 两个工具都要 → 两段都跑。

---

## 验证

- 文件就位：`ls ~/.claude/skills/trust-commands/SKILL.md`（Codex 换 `~/.agents/skills/...`）应存在。
- 功能验证（开**新** session）：
  - Claude：输入 `/trust-commands`，应该读你的命令记录、列出「建议加入」清单并**停下来等你确认**（不会自己写）。
  - Codex：输入 `$trust-commands`，应该列出常用命令、说明要在 `config.toml` 改哪两个 key、等你确认。
- 加完白名单后，再叫 AI 跑一个你刚加的命令（例如 `git status`），确认**不再跳出询问**。

## 安全检查（这个 skill 特别重要）

- skill **绝不主动**把 `rm`、`sudo`、`curl … | sh`、`git push --force` 加进白名单。
- 若你要求加危险命令，它会先警告风险并要求二次确认。
- 写入前一定先列清单、先备份配置文件；只 append + 去重，不覆盖你原有规则。
