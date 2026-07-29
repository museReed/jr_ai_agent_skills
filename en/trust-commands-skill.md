# Trust Commands — Add Your Frequent Commands to an Allowlist So the AI Stops Asking Every Time

**Supported tools**: Claude Code / Codex CLI
**Installation guide**: [trust-commands-install.md](./trust-commands-install.md)
**Nature**: Optional extra skill (not part of the core trio's automatic install — install it separately if you want it)

---

## What Problem Does This Skill Solve?

After you turn on **Accept Edits** (Codex's **Auto**), file edits no longer keep interrupting you. But whenever the AI wants to run a shell command, it still pops up every time to ask "Run `git status`?" — the same batch of commands gets asked dozens of times a day.

An **allowlist** is the fix: tell the AI "I trust these few commands forever, stop asking." But adding them one by one is tedious, and you have to remember the format yourself and judge which ones are safe yourself.

This skill does three things:

1. **Reads your recent command history** and tallies the top 10–15 most-used commands.
2. **Classifies them for you**: which are safe to add, which write files and need your call, and which are dangerous and must never be added.
3. **Lists them for you to confirm one by one** before writing anything to your settings — it never adds anything silently.

---

## Before / After Comparison

**Before — the same command gets asked over and over:**

```
AI: Run `git status`?        You: (press approve)
AI: Run `git diff`?          You: (press approve)
AI: Run `npm run test`?      You: (approve again)
...(over a day you press the exact same approval dozens of times)
```

**After — frequent and safe commands are cleared in one pass:**

```
You: /trust-commands
AI: I looked at your recent commands. These are the most-used and safe ones — add them to the allowlist?
    ✅ git status (42×)  ✅ git diff (31×)  ✅ npm run test (18×)
    ✏️ git commit (15×, writes a commit — add it?)
    ⛔ rm -rf (6×, dangerous, not recommended)
You: Add the first three, and git commit too
AI: Written to ~/.claude/settings.json — these won't ask you again.
```

---

## Safety Classification (how the skill decides)

| Category | Examples | Action |
|---|---|---|
| ✅ Safe (read-only / everyday) | `git status`, `git diff`, `ls`, `grep`, `npm run *`, `pytest` | Recommended to add by default |
| ✏️ Writes files | `git add`, `git commit`, `mkdir`, `touch` | Listed and flagged for you to check yourself |
| ⛔ Dangerous | `rm`, `sudo`, `curl … \| sh`, `git push --force` | Never added on its own; if you insist, it warns of the risk first |

---

## One Important Reminder: Compound Commands Still Get Asked

Even if `git status` is already on the allowlist, the moment the AI runs `git status && npm test`, as long as `npm test` isn't added, **the whole string still gets asked**. That's because the allowlist matches **each sub-command individually** — if any one in the string isn't trusted, it stops.

To get asked less, two paths:

- **Have the AI do one thing per command** (most recommended, and the easiest way to see what each step is doing)
- Or add every sub-command in the string to the allowlist

---

## Claude Code vs Codex Differences

| | Claude Code | Codex CLI |
|---|---|---|
| Allowlist mechanism | Yes — `permissions.allow` in `~/.claude/settings.json`, one `Bash(指令:*)` per line | **No per-command allowlist** |
| How this skill does it | Reads frequent commands → writes allow rules | Reads frequent commands → switches to **Auto mode** (`~/.codex/config.toml` sets `approval_policy="on-request"`, `sandbox_mode="workspace-write"`) |
| Scope cleared | Just the few commands you checked | All commands "within the working folder"; networking / stepping outside the folder still asks |
| Manual trigger | `/trust-commands` | `$trust-commands` |
| Advanced fine control | More precise prefix rules | `codex execpolicy` rule file |

---

## Installation

To add this optional skill, paste this line to the AI:

```
Read jr_ai_agent_skills/en/trust-commands-install.md and install this optional skill for me.
```

See [trust-commands-install.md](./trust-commands-install.md) for detailed steps.
