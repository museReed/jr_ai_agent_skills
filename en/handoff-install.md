# Handoff Skill — Installation Guide

For a fresh install, read [auto-rename-install.md](./auto-rename-install.md) and follow its single AI-guided flow. It detects Claude/Codex and the current terminal/IDE, then installs auto-rename, handoff, and structured-questions together. The commands below are direct re-install references, not separate skill installers. **Installation is NOT complete until the user opens a new session and completes all three E2E checks.**

See [handoff-skill.md](./handoff-skill.md) for feature overview.

> Applies to: Claude Code / Codex CLI (macOS / Linux)
> Requirements: bash, python3, a git repo (handoff documents are committed to `docs/handoff/`)
> Install [auto-rename](./auto-rename-install.md) first — the 📦 rename after a handoff relies on its sync mechanism.

---

## What this skill does

Two parts, installed by the same installer:

1. **handoff skill**: when a session is ending (or context is running low), the AI produces a structured
   handoff document at `docs/handoff/{date}-{topic}.md`, commits it, then renames the session to
   `📦 {topic}` to mark it as handed off. A new session can pick up seamlessly by reading one file.
2. **context-monitor hook**: after every tool call, reads the session's real token usage and injects a
   warning telling the AI to write a handoff immediately once usage exceeds **70%** — so you never
   remember the handoff only after the context has already blown up.

## Claude Code direct re-install reference

All scripts live in this repo's `installer/` (if you already installed auto-rename, just re-run the same command — it is idempotent):

```bash
cd jr_ai_agent_skills/installer
./install.sh claude --editor=<confirmed-editor>
```

What gets installed (the handoff-related parts):

| File | Location | Role |
|---|---|---|
| `handoff/SKILL.md` | `~/.claude/skills/handoff/` | the handoff document workflow |
| `context-monitor.sh` | `~/.claude/hooks/` | PostToolUse reads real token usage from the transcript, warns at >70% |

## Codex CLI direct re-install reference

```bash
cd jr_ai_agent_skills/installer
./install.sh codex --editor=<confirmed-editor>
```

| File | Location | Role |
|---|---|---|
| `handoff/SKILL.md` | `~/.agents/skills/handoff/` | the handoff document workflow (rename goes through the relay file) |
| `_shared/codex-session-rename.md` | `~/.agents/skills/_shared/` | single source of truth for the rename method |
| `codex-context-monitor.sh` | `~/.codex/hooks/` | reads token_count from the rollout, warns at >70%; falls back to tool-call-count estimation when unavailable |

## E2E Verification (the AI agent MUST actively walk the user through this — do not skip)

> Full step-by-step playbook (4 rounds × checkpoint IDs) → Read `installer/VERIFICATION.md` and walk the user through it.

### Step 1: Automated checks

```bash
cd jr_ai_agent_skills/installer
./verify.sh
```

verify simulates a context-monitor trigger (fake transcript + shrunken window). Proceed only when everything PASSes.

### Step 2: Complete handoff test (guide the user through it)

The handoff creates a document and commit, so it must run in a temporary repo. Ask the user to open a **new terminal** and paste:

```bash
TEST_REPO="$(mktemp -d "${TMPDIR:-/tmp}/jr-skill-e2e.XXXXXX")" && \
git -C "$TEST_REPO" init -q && printf '# e2e skill test\n' > "$TEST_REPO/README.md" && \
git -C "$TEST_REPO" add README.md && \
git -C "$TEST_REPO" config user.name 'Skill E2E' && \
git -C "$TEST_REPO" config user.email 'skill-e2e@example.invalid' && \
git -C "$TEST_REPO" commit -qm init && \
cd "$TEST_REPO"
```

1. Start the test session:
   - Claude Code: `CONTEXT_MONITOR_TEST_WINDOW=30000 claude`
   - Codex: `CODEX_TEST_MAX_CONTEXT_WINDOW=5000 codex`
2. Ask it to read README and list the files; for Codex, then give a second command: "list them again."
3. After the test-mode context warning appears, ask it to "follow the warning and complete every handoff step."
4. Required checks: a file appears under `docs/handoff/`, a new commit exists, the session name starts with `📦 …`, and the Codex warning stops repeating.
5. Exit the test session and run `rm -rf "$TEST_REPO"` in the original shell. Normal sessions without the test variable behave exactly as before.

### On failure (the AI agent's responsibility — do not just say "installed" and stop)

1. Read `installer/TROUBLESHOOTING.md`, work through the symptom table; after fixing, rerun `install.sh` then `verify.sh`
2. Can't fix it → report with one command (runs verify --report, collects scene evidence, files the issue — no manual assembly):

```bash
cd jr_ai_agent_skills/installer
./diagnose.sh "{tool} {one-line symptom}"     # e.g. ./diagnose.sh "codex tab not renaming @ Cursor"
```

With `gh` CLI authed it files the issue directly; otherwise the body lands in the clipboard and a prefilled new-issue page opens — the user just pastes and submits.

## Mechanism details (for debugging reference)

- The Claude-side context-monitor reads the **current session's** JSONL from the `transcript_path` on the
  hook's stdin — it does not guess the file by mtime (which picks the wrong file with concurrent
  sessions; that is a bug we actually hit and fixed)
- The Codex side prefers the `token_count` events in the rollout JSONL; when unavailable it falls back to
  per-session "tool call count ≈ usage" estimation
- Codex writes `token_count` at the **end of each turn**, while the hook runs mid-turn → the warning lags by one turn; in tests it shows up on the second command (imperceptible in real use — hitting 70% is never a one-turn margin)
- Test knobs: `CONTEXT_MONITOR_TEST_WINDOW` (Claude) / `CODEX_TEST_MAX_CONTEXT_WINDOW` (Codex) —
  they only affect the session launched with the variable set
- After triggering, the Codex side **keeps nagging** until the AI creates the `.handoff` marker named in the hook message — that is leak-proofing by design, not a bug
