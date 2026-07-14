# External Skills（一条龙 demo 用）— 安装指南

Read this document, then execute the installation steps for your tool (Section A or Section B). Do not ask for confirmation — just do it. **Installation is NOT complete until you have guided the user to open a new session and paste the demo prompt（见文末「一条龙 demo」）。**

装的是「frontend-design 一条龙 demo」用到的官方第三方 skill：AI 依 structured-questions 问配色 → 生成网页 → 本地 live-preview 展示。

> 适用：Claude Code / Codex CLI（macOS / Linux）
> **需求：Node ≥ 18 + npx、网络、python3**（本地 live-preview demo 需要）。这支跟 offline 的 `install.sh` 分开，因为要连 npm / GitHub 并下载浏览器。

---

## 这几个 skill 各给谁

| Skill | Claude | Codex |
|---|---|---|
| 前端设计 | `frontend-design`（Anthropic） | `frontend-design`（同一份） |
| 造 skill | `skill-creator`（Anthropic） | 内建 `$skill-creator`，免装 |
| Playwright | Playwright **MCP**（`claude mcp add`） | 官方 `playwright` **CLI skill** |

> 为什么 Codex 也用 frontend-design：OpenAI 官方原本的 `frontend-skill` 已于 2026-04-23 被移除且无替代（`openai/skills` 的 `.curated` 查无任何前端生成 skill）。frontend-design 是 agent 无关的，一份装进 `~/.agents/skills`（Codex 官方 user 目录）两边都能用。

## Section A: Claude Code 安装

```bash
cd jr_ai_agent_skills/installer
./install-external-skills.sh claude
```

装：`frontend-design`、`skill-creator`、Playwright MCP（`~/.claude.json` user scope）、以及本地 live-preview demo 依赖（python playwright + chromium）。

## Section B: Codex CLI 安装

```bash
cd jr_ai_agent_skills/installer
./install-external-skills.sh codex
```

装：`frontend-design`（`~/.agents/skills`）＋官方 `playwright` CLI skill＋本地 demo 依赖。`skill-creator` 是 Codex 内建。

> 两个工具都用 → `./install-external-skills.sh`（不带参数）。
> 脚本有 guard：缺 Node/npx 或没网络会直接挡下并说明；pip 撞 PEP 668 会自动退 `--break-system-packages`。

---

## 一条龙 demo（安装完必做，AI agent 主动引导）

装完后，**引导用户开一个【新的】terminal / session**（skill 要新 session 才会载入），然后把对应的 prompt 整份贴进去：

| 工具 | 贴这份 |
|---|---|
| Claude Code | `installer/demo-prompt-claude.md` |
| Codex | `installer/demo-prompt-codex.md` |

贴上后 AI 会跑一条龙：`structured-questions` 问配色 → `frontend-design` 生成单档网页 → 本地 `type_hl.py` 左打码右预览展示成果。

---

## 验证

- 安装脚本每一步都会印 ✅ / ⚠️；有 ⚠️ 依信息补（多半是缺 Node、没网络、或 python playwright 没装好）。
- Claude：`claude mcp list` 应看到 `playwright`；`/frontend-design`、`/skill-creator` 可手动触发。
- Codex：`~/.agents/skills/{frontend-design,playwright}` 应存在；`$skill-creator` 可用。
- 最终验证＝跑完上面那条 demo，右边真的长出网页。
