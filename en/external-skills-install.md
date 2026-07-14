# External Skills (for the one-shot demo) — Installation Guide

Read this document, then execute the installation steps for your tool (Section A or Section B). Do not ask for confirmation — just do it. **Installation is NOT complete until you have guided the user to open a new session and paste the demo prompt (see "One-shot demo" below).**

These are the official third-party skills used by the "frontend-design one-shot demo": the AI asks about colors via structured-questions → generates a webpage → shows it with the local live-preview.

> Applies to: Claude Code / Codex CLI (macOS / Linux)
> **Requirements: Node ≥ 18 + npx, network, python3** (needed by the local live-preview demo). This is separate from the offline `install.sh` because it pulls from npm / GitHub and downloads a browser.

---

## Which skill goes to which agent

| Skill | Claude | Codex |
|---|---|---|
| Frontend design | `frontend-design` (Anthropic) | official `frontend-skill` (**Codex installs it itself at demo time**, not in this script) |
| Skill authoring | `skill-creator` (Anthropic) | built-in `$skill-creator`, no install |
| Playwright | Playwright **MCP** (`claude mcp add`) | official `playwright` **CLI skill** |

> Why Codex does NOT get frontend-design: Codex has its own official `frontend-skill` (ships an OpenAI manifest, triggered by `$frontend-skill`). Forcing Anthropic's frontend-design onto Codex would give it two competing frontend-design skills. frontend-skill cannot be installed non-interactively (`npx skills add openai/skills` reports no match) — it goes through Codex's built-in `$skill-installer`, so the demo prompt has Codex install it inside the session.

## Section A: Claude Code Installation

```bash
cd jr_ai_agent_skills/installer
./install-external-skills.sh claude
```

Installs: `frontend-design` (`~/.claude/skills`, Claude-only), `skill-creator` (`~/.claude/skills`), Playwright MCP (`~/.claude.json`, user scope), and the local live-preview demo deps (python playwright + chromium).

## Section B: Codex CLI Installation

```bash
cd jr_ai_agent_skills/installer
./install-external-skills.sh codex
```

Installs: the official `playwright` CLI skill (`~/.agents/skills`) + the local demo deps. `frontend-skill` is **not in this step** — Codex installs it itself during the demo below; `skill-creator` is built into Codex.

> Using both tools → `./install-external-skills.sh` (no argument).
> The script guards: it stops with a clear message if Node/npx or network is missing; on a PEP 668 error it falls back to `--break-system-packages`.

---

## One-shot demo (do this right after installing; the AI agent guides it)

After installing, **guide the user to open a NEW terminal / session** (skills only load in a fresh session), then paste the matching prompt in full:

| Tool | Paste this |
|---|---|
| Claude Code | `installer/demo-prompt-claude.md` |
| Codex | `installer/demo-prompt-codex.md` |

Once pasted, the AI runs the one-shot flow: `structured-questions` asks about colors → `frontend-design` (Claude) / `frontend-skill` (Codex) generates a single-file webpage → the local `type_hl.py` shows it with "types code on the left, renders live on the right".

> The Codex prompt's first step has Codex confirm / install its official `frontend-skill` (`$skill-installer frontend-skill`).

---

## Verification

- Each install step prints ✅ / ⚠️; for any ⚠️, follow the message (usually missing Node, no network, or python playwright not set up).
- Claude: `claude mcp list` should show `playwright`; `/frontend-design` and `/skill-creator` can be triggered manually.
- Codex: `~/.agents/skills/playwright` should exist; `$skill-creator` is available; `$frontend-skill` is available after the demo's first step installs it.
- Final check = run the demo above and confirm the webpage actually renders on the right.
