# Structured Questions Skill — Installation Guide

Read this document, then execute the installation steps for your tool (Section A or Section B). Do not ask for confirmation — just do it. **Installation is NOT complete until you have walked the user through the "Verification" section.**

See [structured-questions-skill.md](./structured-questions-skill.md) for feature overview.

> Applies to: Claude Code / Codex CLI (macOS / Linux)
> Requirements: bash, python3

---

## What this skill does

When a decision has ≥ 2 viable options, the AI does not decide on its own — it lays the options out in a structured format for you to pick from, each with a ✨ recommendation, 😃 pros, and 😫 cons. Claude Code uses the interactive `AskUserQuestion` picker; Codex uses the `ask_user_question` interactive UI in Plan mode and falls back to plain-text options in other modes.

> This is a pure skill (a single `SKILL.md`) — no hooks, no alias, no editor settings. `install.sh` copies it into place alongside auto-rename and handoff.

## Section A: Claude Code Installation

All skills live in this repo's `installer/`; one command installs everything (including structured-questions):

```bash
cd jr_ai_agent_skills/installer
./install.sh claude
```

Installs to `~/.claude/skills/structured-questions/SKILL.md`. Triggers: automatically (on any multi-option decision) or manually via `/structured-questions`.

## Section B: Codex CLI Installation

```bash
cd jr_ai_agent_skills/installer
./install.sh codex
```

Installs to `~/.codex/skills/structured-questions/SKILL.md`. Triggers: automatically or manually via `$structured-questions`. **Plan mode uses the interactive UI; other modes use the plain-text option format.**

> Using both tools → `./install.sh` (no argument).
> The installer is idempotent: safe to re-run; it automatically backs up any file it replaces (`*.bak.{timestamp}`).

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
> **Expected**: the interactive option UI appears (`ask_user_question` tool)
>
> **5b — non-Plan mode**: in default mode, say "help me pick a database"
> **Expected**: a 💡 hint suggesting `/plan` appears first, then options are listed in the `Q1: A/B/C` plain-text format

### Reading the results

| Result | What to do |
|---|---|
| All tests pass | Install succeeded, ready to use |
| Tests 1-2 don't trigger | Check that the SKILL.md `description` contains the trigger keywords |
| Test 3 doesn't trigger | Check the frontmatter `name` is spelled correctly (`structured-questions`) |
| Test 4 mis-triggers | Check the SKILL.md "When NOT to Use" section is clear |
| Test 5b has no fallback | Check the Mode Detection section in the Codex SKILL.md |
