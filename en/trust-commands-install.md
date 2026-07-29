# Trust Commands Skill — Installation Guide (optional extra skill)

Read this document, then execute the copy steps for the user's tool. Do not ask for confirmation on the copy itself — just install it. **Installation = copying SKILL.md into place; the skill only loads in a new session.**

This is an **optional** extra skill, not part of the automatic `install.sh` install for the core trio (auto-rename / handoff / structured-questions). See [trust-commands-skill.md](./trust-commands-skill.md) for the feature overview.

> Applies to: Claude Code / Codex CLI (macOS / Linux)
> Requirements: bash. (Actually writing the allowlist also needs python3 to edit JSON — only used when the skill runs, not for installation itself.)

---

## What this skill does

Reads your recent shell command history → picks out the most-used and safe ones → after confirming one by one:

- **Claude Code**: writes `Bash(指令:*)` rules into `permissions.allow` in `~/.claude/settings.json`
- **Codex**: switches to Auto mode (`~/.codex/config.toml` sets `approval_policy` / `sandbox_mode`) — Codex has no per-command allowlist

---

## Section A: Claude Code installation

```bash
cd jr_ai_agent_skills/installer
mkdir -p "$HOME/.claude/skills/trust-commands"
cp -R skills/claude/trust-commands/. "$HOME/.claude/skills/trust-commands/"
```

Installs to `~/.claude/skills/trust-commands/SKILL.md`, manually triggered with `/trust-commands`.

## Section B: Codex CLI installation

```bash
cd jr_ai_agent_skills/installer
mkdir -p "$HOME/.agents/skills/trust-commands"
cp -R skills/codex/trust-commands/. "$HOME/.agents/skills/trust-commands/"
```

Installs to `~/.agents/skills/trust-commands/SKILL.md`, manually triggered with `$trust-commands`.

> Want both tools → run both sections.

---

## Verification

- File in place: `ls ~/.claude/skills/trust-commands/SKILL.md` (for Codex, swap in `~/.agents/skills/...`) should exist.
- Functional check (open a **new** session):
  - Claude: type `/trust-commands` — it should read your command history, list a "recommended to add" list, and **stop to wait for your confirmation** (it won't write on its own).
  - Codex: type `$trust-commands` — it should list your frequent commands, explain which two keys to change in `config.toml`, and wait for your confirmation.
- After adding to the allowlist, ask the AI to run one of the commands you just added (e.g. `git status`) and confirm it **no longer prompts**.

## Safety checks (especially important for this skill)

- The skill **never proactively** adds `rm`, `sudo`, `curl … | sh`, or `git push --force` to the allowlist.
- If you ask to add a dangerous command, it warns of the risk first and requires a second confirmation.
- Before writing, it always lists the items first and backs up the config file first; it only appends + dedupes, never overwriting your existing rules.
