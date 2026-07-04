# Handoff Skill — Installation Guide

Read this document, then execute the installation steps for your tool (Section A or Section B). Do not ask for confirmation — just do it. Execute every step sequentially, do not skip any step. **Installation is NOT complete until you have walked the user through the "E2E Verification" section.**

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

## Section A: Claude Code Installation

All scripts live in this repo's `installer/` (if you already installed auto-rename, just re-run the same command — it is idempotent):

```bash
cd jr_ai_agent_skills/installer
./install.sh claude
```

What gets installed (the handoff-related parts):

| File | Location | Role |
|---|---|---|
| `handoff/SKILL.md` | `~/.claude/skills/handoff/` | the handoff document workflow |
| `context-monitor.sh` | `~/.claude/hooks/` | PostToolUse reads real token usage from the transcript, warns at >70% |

## Section B: Codex CLI Installation

```bash
cd jr_ai_agent_skills/installer
./install.sh codex
```

| File | Location | Role |
|---|---|---|
| `handoff/SKILL.md` | `~/.codex/skills/handoff/` | the handoff document workflow (rename goes through the relay file) |
| `_shared/codex-session-rename.md` | `~/.codex/skills/_shared/` | single source of truth for the rename method |
| `codex-context-monitor.sh` | `~/.codex/hooks/` | reads token_count from the rollout, warns at >70%; falls back to tool-call-count estimation when unavailable |

## E2E Verification (the AI agent MUST actively walk the user through this — do not skip)

### Step 1: Automated checks

```bash
cd jr_ai_agent_skills/installer
./verify.sh
```

verify simulates a context-monitor trigger (fake transcript + shrunken window). Proceed only when everything PASSes.

### Step 2: Real trigger test (guide the user through it)

Use a "shrunken window" to make the warning appear early — no need to actually chat up to 70%:

1. Ask the user to open a **new terminal** and start a test session inside a git repo:
   - Claude Code: `CONTEXT_MONITOR_TEST_WINDOW=30000 claude`
   - Codex: `CODEX_TEST_MAX_CONTEXT_WINDOW=20000 codex`
2. Ask it to do 1–2 hands-on things (e.g. "list the files in this folder")
3. Expected: the AI starts saying `⚠️ Context 已用 …（測試模式）` (context warning, test mode) and offers to write a handoff document — **seeing the warning = hook verified**; the session can be closed right away, no need to finish the handoff
4. (Optional) Let it finish: check that a file appears under `docs/handoff/`, a commit exists, and the session is renamed to `📦 …`
5. Remind the user: just close the test session when done; normal sessions without the env var behave exactly as before

### Step 3: Manual handoff verification (optional)

In any normal session, type "write a handoff" → it should produce the document + commit + 📦 rename + report a single-line starter prompt.

### On failure (the AI agent's responsibility — do not just say "installed" and stop)

1. Run `./verify.sh --report` to produce a diagnostic report
2. Open `installer/TROUBLESHOOTING.md` and go through the symptom table (entry #8 is the common context-monitor issue)
3. If it still can't be fixed → prepare the issue content for the user and guide them to post it at:
   <https://github.com/museReed/jr_ai_agent_skills/issues/new?template=install-report.md>

## Mechanism details (for debugging reference)

- The Claude-side context-monitor reads the **current session's** JSONL from the `transcript_path` on the
  hook's stdin — it does not guess the file by mtime (which picks the wrong file with concurrent
  sessions; that is a bug we actually hit and fixed)
- The Codex side prefers the `token_count` events in the rollout JSONL; when unavailable it falls back to
  "tool call count ≈ usage" estimation
- Test knobs: `CONTEXT_MONITOR_TEST_WINDOW` (Claude) / `CODEX_TEST_MAX_CONTEXT_WINDOW` (Codex) —
  they only affect the session launched with the variable set
- After triggering, the Codex side **keeps nagging** until the AI runs
  `touch /tmp/codex-context-monitor/{pid}.handoff` as instructed — that is leak-proofing by design, not a bug
