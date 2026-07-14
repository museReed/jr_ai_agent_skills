# External Skills（一條龍 demo 用）— 安裝指南

Read this document, then execute the installation steps for your tool (Section A or Section B). Do not ask for confirmation — just do it. **Installation is NOT complete until you have guided the user to open a new session and paste the demo prompt（見文末「一條龍 demo」）。**

裝的是「frontend-design 一條龍 demo」用到的官方第三方 skill：AI 依 structured-questions 問配色 → 生成網頁 → 本地 live-preview 展示。

> 適用：Claude Code / Codex CLI（macOS / Linux）
> **需求：Node ≥ 18 + npx、網路、python3**（本地 live-preview demo 需要）。這支跟 offline 的 `install.sh` 分開，因為要連 npm / GitHub 並下載瀏覽器。

---

## 這幾個 skill 各給誰

| Skill | Claude | Codex |
|---|---|---|
| 前端設計 | `frontend-design`（Anthropic） | 官方 `frontend-skill`（**由 demo 時 Codex 自己裝**，不在本腳本內） |
| 造 skill | `skill-creator`（Anthropic） | 內建 `$skill-creator`，免裝 |
| Playwright | Playwright **MCP**（`claude mcp add`） | 官方 `playwright` **CLI skill** |

> 為什麼 Codex 不裝 frontend-design：Codex 有自己官方的 `frontend-skill`（帶 OpenAI manifest、`$frontend-skill` 觸發）。硬塞 Anthropic 的 frontend-design 會讓 Codex 有兩個前端設計 skill 搶著觸發。frontend-skill 無法非互動安裝（`npx skills add openai/skills` 查無），只能靠 Codex 內建的 `$skill-installer`，所以交給 demo-prompt 讓 Codex 在 session 裡自己裝。

## Section A: Claude Code 安裝

```bash
cd jr_ai_agent_skills/installer
./install-external-skills.sh claude
```

裝：`frontend-design`（`~/.claude/skills`，Claude 專用）、`skill-creator`（`~/.claude/skills`）、Playwright MCP（`~/.claude.json` user scope）、以及本地 live-preview demo 依賴（python playwright + chromium）。

## Section B: Codex CLI 安裝

```bash
cd jr_ai_agent_skills/installer
./install-external-skills.sh codex
```

裝：官方 `playwright` CLI skill（`~/.agents/skills`）＋本地 demo 依賴。`frontend-skill` **不在這步**——它在下方 demo 時由 Codex 自己裝；`skill-creator` 是 Codex 內建。

> 兩個工具都用 → `./install-external-skills.sh`（不帶參數）。
> 腳本有 guard：缺 Node/npx 或沒網路會直接擋下並說明；pip 撞 PEP 668 會自動退 `--break-system-packages`。

---

## 一條龍 demo（安裝完必做，AI agent 主動引導）

裝完後，**引導用戶開一個【新的】terminal / session**（skill 要新 session 才會載入），然後把對應的 prompt 整份貼進去：

| 工具 | 貼這份 |
|---|---|
| Claude Code | `installer/demo-prompt-claude.md` |
| Codex | `installer/demo-prompt-codex.md` |

貼上後 AI 會跑一條龍：`structured-questions` 問配色 → `frontend-design`（Claude）/ `frontend-skill`（Codex）生成單檔網頁 → 本地 `type_hl.py` 左打碼右預覽展示成果。

> Codex 版的 prompt 第一步會讓 Codex 自己確認 / 安裝官方 `frontend-skill`（`$skill-installer frontend-skill`）。

---

## 驗證

- 安裝腳本每一步都會印 ✅ / ⚠️；有 ⚠️ 依訊息補（多半是缺 Node、沒網路、或 python playwright 沒裝好）。
- Claude：`claude mcp list` 應看到 `playwright`；`/frontend-design`、`/skill-creator` 可手動觸發。
- Codex：`~/.agents/skills/playwright` 應存在；`$skill-creator` 可用；`$frontend-skill` 於 demo 第一步裝好後可用。
- 最終驗證＝跑完上面那條 demo，右邊真的長出網頁。
