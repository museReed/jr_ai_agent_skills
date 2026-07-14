# External Skills（一条龙 demo 用）— 安装指南

Read this document, then execute the installation steps for your tool (Section A or Section B). Do not ask for confirmation — just do it. **Installation is NOT complete until you have guided the user to open a new session and paste the demo prompt（见文末「一条龙 demo」）。**

装的是「frontend-design 一条龙 demo」用到的官方第三方 skill：AI 依 structured-questions 问配色 → 生成网页 → 本地 live-preview 展示。

> 适用：Claude Code / Codex CLI（macOS / Linux）
> **需求：Node ≥ 18 + npx、网络、python3**（本地 live-preview demo 需要）。这支跟 offline 的 `install.sh` 分开，因为要连 npm / GitHub 并下载浏览器。

---

## 这几个 skill 各给谁

| Skill | Claude | Codex |
|---|---|---|
| 前端设计 | `frontend-design`（Anthropic） | 官方 `frontend-skill`（**由 demo 时 Codex 自己装**，不在本脚本内） |
| 造 skill | `skill-creator`（Anthropic） | 内建 `$skill-creator`，免装 |
| Playwright | Playwright **MCP**（`claude mcp add`） | 官方 `playwright` **CLI skill** |

> 为什么 Codex 不装 frontend-design：Codex 有自己官方的 `frontend-skill`（带 OpenAI manifest、`$frontend-skill` 触发）。硬塞 Anthropic 的 frontend-design 会让 Codex 有两个前端设计 skill 抢着触发。frontend-skill 无法非交互安装（`npx skills add openai/skills` 查无），只能靠 Codex 内建的 `$skill-installer`，所以交给 demo-prompt 让 Codex 在 session 里自己装。

## Section A: Claude Code 安装

```bash
cd jr_ai_agent_skills/installer
./install-external-skills.sh claude
```

装：`frontend-design`（`~/.claude/skills`，Claude 专用）、`skill-creator`（`~/.claude/skills`）、Playwright MCP（`~/.claude.json` user scope）、以及本地 live-preview demo 依赖（python playwright + chromium）。

## Section B: Codex CLI 安装

```bash
cd jr_ai_agent_skills/installer
./install-external-skills.sh codex
```

装：官方 `playwright` CLI skill（`~/.agents/skills`）＋本地 demo 依赖。`frontend-skill` **不在这步**——它在下方 demo 时由 Codex 自己装；`skill-creator` 是 Codex 内建。

> 两个工具都用 → `./install-external-skills.sh`（不带参数）。
> 脚本有 guard：缺 Node/npx 或没网络会直接挡下并说明；pip 撞 PEP 668 会自动退 `--break-system-packages`。

---

## 一条龙 demo（安装完必做，AI agent 主动引导）

装完后，**引导用户开一个【新的】terminal / session**（skill 要新 session 才会载入），然后把对应的 prompt 整份贴进去：

| 工具 | 贴这份 |
|---|---|
| Claude Code | `installer/demo-prompt-claude.md` |
| Codex | `installer/demo-prompt-codex.md` |

贴上后 AI 会跑一条龙：`structured-questions` 问配色 → `frontend-design`（Claude）/ `frontend-skill`（Codex）生成单档网页 → 本地 `type_hl.py` 左打码右预览展示成果。

> Codex 版的 prompt 第一步会让 Codex 自己确认 / 安装官方 `frontend-skill`（`$skill-installer frontend-skill`）。

---

## 验证

- 安装脚本每一步都会印 ✅ / ⚠️；有 ⚠️ 依信息补（多半是缺 Node、没网络、或 python playwright 没装好）。
- Claude：`claude mcp list` 应看到 `playwright`；`/frontend-design`、`/skill-creator` 可手动触发。
- Codex：`~/.agents/skills/playwright` 应存在；`$skill-creator` 可用；`$frontend-skill` 于 demo 第一步装好后可用。
- 最终验证＝跑完上面那条 demo，右边真的长出网页。
