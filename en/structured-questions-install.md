# Structured Questions Skill — Installation Guide

For a fresh install, read [auto-rename-install.md](./auto-rename-install.md) and follow its single AI-guided flow. It detects Claude/Codex and the current terminal/IDE, then installs auto-rename, handoff, and structured-questions together. The commands below are direct re-install references, not separate skill installers. **Installation is NOT complete until the user opens a new session and completes all three E2E checks.**

See [structured-questions-skill.md](./structured-questions-skill.md) for feature overview.

> Applies to: Claude Code / Codex CLI (macOS / Linux)
> Requirements: bash, python3

---

## What this skill does

When a decision has ≥ 2 viable options, the AI does not decide on its own — it lays out structured choices with a recommendation and trade-offs. Claude Code uses the interactive `AskUserQuestion` picker; Codex uses `request_user_input` in Plan mode. In Default mode, it pauses to ask whether to switch and only falls back to plain-text options after an explicit refusal.

> This is a pure skill (a single `SKILL.md`) — no hooks, no alias, no editor settings. `install.sh` copies it into place alongside auto-rename and handoff.

## Claude Code direct re-install reference

All skills live in this repo's `installer/`; one command installs everything (including structured-questions):

```bash
cd jr_ai_agent_skills/installer
./install.sh claude --editor=<confirmed-editor>
```

Installs to `~/.claude/skills/structured-questions/SKILL.md`. Triggers: automatically (on any multi-option decision) or manually via `/structured-questions`.

## Codex CLI direct re-install reference

```bash
cd jr_ai_agent_skills/installer
./install.sh codex --editor=<confirmed-editor>
```

Installs to `~/.agents/skills/structured-questions/SKILL.md`. Triggers: automatically or manually via `$structured-questions`. **Plan mode uses `request_user_input`; Default mode waits for a switch decision and only uses plain-text options after the user declines.**

> Using both tools → `./install.sh --editor=<confirmed-editor>`; replace the value with `cursor`, `antigravity`, `vscode`, or `native`.
> The installer is idempotent and safe to re-run. Codex skill backups go to `~/.agents/skill-backups/{timestamp}/`; other replaced files use `*.bak.{timestamp}`.

---

## Verification

After installing, run the tests below to confirm the skill works. After each test, check the behavior against "Expected".

### Test 1: Auto-trigger — vague request

> Tell the AI: "Help me plan an event"
>
> **Expected**: The AI does not decide the event format outright; it uses structured options to ask "what's the goal", "how many people", etc. Each option carries a ✨ recommendation, 😃 pros, and 😫 cons, each on its own line.

### Test 2: Auto-trigger — multi-option decision

> Tell the AI: "Help me pick a frontend framework for a personal site"
>
> **Expected**: The AI lists 2-4 framework options (e.g. Next.js / Nuxt.js / Astro), each with pros and cons, and marks the recommended one. It does not just say "I recommend X" and start coding.

### Test 3: Manual trigger

> Type `/structured-questions` (Claude Code) or `$structured-questions` (Codex), then say: "I want to change careers"
>
> **Expected**: The AI breaks "change careers" into a few concrete questions (motivation, target industry, timeline) and asks them as options, rather than giving advice directly.

### Test 4: Cases where it should NOT trigger

> Tell the AI: "Change line 10 of this file to Hello World"
>
> **Expected**: The AI makes the edit directly, no options asked. The instruction is unambiguous — only one way to do it.

### Test 5: Codex-specific — Plan mode vs non-Plan mode

> **5a — Plan mode**: enter Plan mode (`/plan`), then say "help me pick a database"
> **Expected**: the interactive option UI appears (`request_user_input` tool)
>
> **5b — Default mode**: in Default mode, say "help me pick a database"
> **Expected 1**: only the switch prompt appears, then the AI stops; no database options are shown yet
>
> Next, reply "don't switch"
> **Expected 2**: the AI resumes the original question in the same turn using the `Q1: A/B/C` plain-text format

### Reading the results

| Result | What to do |
|---|---|
| All tests pass | Install succeeded, ready to use |
| Tests 1-2 don't trigger | Check that the SKILL.md `description` contains the trigger keywords |
| Test 3 doesn't trigger | Check the frontmatter `name` is spelled correctly (`structured-questions`) |
| Test 4 mis-triggers | Check the SKILL.md "When NOT to Use" section is clear |
| Test 5b does not pause first, or has no fallback after refusal | Check the Mode Detection section in the Codex SKILL.md |
