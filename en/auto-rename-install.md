# Auto-Rename Skill — Installation Guide

Read this document, then execute the installation steps for your tool (Section A or Section B). Do not ask for confirmation — just do it. Execute every step sequentially, do not skip any step. **Installation is NOT complete until you have walked the user through the "E2E Verification" section.**

See [auto-rename-skill.md](./auto-rename-skill.md) for feature overview.

> Applies to: Claude Code / Codex CLI (macOS / Linux)
> Requirements: bash, python3; Codex sidebar renaming additionally needs sqlite3

---

## What this skill does

The AI automatically names each session and syncs the name to the terminal tab (and the Codex sidebar), so tabs no longer all say "New chat".

Naming cadence (a three-stage relay):

| When | Who does it | Tab shows |
|---|---|---|
| The moment the session opens | wrapper writes a placeholder | `(等待命名)` (waiting for a name) |
| **Right after your first message** | hook asks the AI to name it from your task intent | `🔍 cron failure root cause` (example) |
| 5th tool call | hook asks the AI to re-evaluate against the conversation so far (keeps the name if still accurate) | may upgrade to a more fitting name |
| Every 10 tool calls | safety net: retries only if no AI name has landed yet | — |

Architecture in one sentence: `claude`/`codex` starts via a wrapper → the wrapper spawns a background watcher polling a sync file → the hook writes the sync file when naming happens → the watcher writes the name to the terminal tab (OSC). On the Codex side, the model first writes a `/tmp` relay file and the hook applies it to SQLite (sidebar) + the sync file (a sandbox restriction).

## Section A: Claude Code Installation

All scripts live in this repo's `installer/`; one command installs everything (hooks + skills + registration):

```bash
cd jr_ai_agent_skills/installer
./install.sh claude
```

Then write the alias into your shell rc (**the AI must actually run this write, not just print it for the user to paste**; it is idempotent and won't add a duplicate if already present):

```bash
RC="$HOME/.zshrc"; case "$SHELL" in *bash*) RC="$HOME/.bashrc";; esac
grep -q "alias claude=.*myclaude" "$RC" 2>/dev/null \
  || echo "alias claude='\$HOME/.local/bin/myclaude'" >> "$RC"
echo "Wrote to $RC — restart the terminal or source it; the alias not taking effect = the feature not working"
```

When done, jump to "Editor settings".

## Section B: Codex CLI Installation

```bash
cd jr_ai_agent_skills/installer
./install.sh codex
```

alias (**the AI runs this write directly**, idempotent):

```bash
RC="$HOME/.zshrc"; case "$SHELL" in *bash*) RC="$HOME/.bashrc";; esac
grep -q "alias codex=.*mycodex" "$RC" 2>/dev/null \
  || echo "alias codex='\$HOME/.local/bin/mycodex'" >> "$RC"
echo "Wrote to $RC — restart the terminal or source it"
```

> Using both tools → `./install.sh` (no argument) and add both aliases.
> The installer is idempotent: safe to re-run; it automatically backs up any file it replaces (`*.bak.{timestamp}`).

## Editor settings (required for the VS Code family; skip for iTerm / Terminal.app)

The terminal tabs of Cursor, Antigravity, and VS Code do **not** display OSC titles by default. You must add `"terminal.integrated.tabs.title": "${sequence}"` to that editor's `settings.json`.

**The AI edits settings.json directly (don't make the user go through Cmd+Shift+P)**: figure out which editor the user has (set whichever path exists), use the python below to **merge the key in (preserving existing settings)**, creating the file if it doesn't exist. macOS paths:

| Editor | settings.json path |
|---|---|
| Cursor | `~/Library/Application Support/Cursor/User/settings.json` |
| Antigravity | `~/Library/Application Support/Antigravity/User/settings.json` |
| VS Code | `~/Library/Application Support/Code/User/settings.json` |

```bash
python3 - "<path from the table above>" <<'PY'
import json, os, sys
p = os.path.expanduser(sys.argv[1])
os.makedirs(os.path.dirname(p), exist_ok=True)
cfg = {}
if os.path.exists(p):
    with open(p) as f:
        cfg = json.load(f)          # raises if it contains // comments → use the fallback below
cfg["terminal.integrated.tabs.title"] = "${sequence}"
with open(p, "w") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
print("set terminal.integrated.tabs.title in", p)
PY
```

- **Only takes effect for terminals opened after saving** → have the user open a new terminal once it's set
- Configure every editor you use (each has its own settings.json)
- Fallback: if none of the paths above exist, or python errors out because of JSONC comments → ask the user to
  Cmd+Shift+P → "Open User Settings (JSON)" and add that line manually

## E2E Verification (the AI agent MUST actively walk the user through this — do not skip)

> Full step-by-step playbook (4 rounds × checkpoint IDs) → Read `installer/VERIFICATION.md` and walk the user through it.

### Step 1: Automated checks

```bash
cd jr_ai_agent_skills/installer
./verify.sh          # or ./verify.sh claude / ./verify.sh codex
```

Proceed only when everything PASSes; on FAIL, fix per the message first (re-run `install.sh`, then verify again).

### Step 2: Real-behavior verification (guide the user through these three things)

1. Ask the user to **open a NEW terminal** (existing terminals still run the old environment — testing there doesn't count)
2. Ask the user to run `claude` (or `codex`) and type one sentence with real task content, e.g. "list the files in this folder"
3. Expected result: **within the first turn**, the terminal tab changes to `{emoji} task description`
4. For Codex, additionally verify the sidebar:

```bash
sqlite3 "$(ls -t ~/.codex/state_*.sqlite | head -1)" \
  "SELECT title FROM threads ORDER BY updated_at_ms DESC LIMIT 1;"
```

### On failure (the AI agent's responsibility — do not just say "installed" and stop)

1. Read `installer/TROUBLESHOOTING.md`, work through the symptom table; after fixing, rerun `install.sh` then `verify.sh`
2. Can't fix it → report with one command (runs verify --report, collects scene evidence, files the issue — no manual assembly):

```bash
cd jr_ai_agent_skills/installer
./diagnose.sh "{tool} {one-line symptom}"     # e.g. ./diagnose.sh "codex tab not renaming @ Cursor"
```

With `gh` CLI authed it files the issue directly; otherwise the body lands in the clipboard and a prefilled new-issue page opens — the user just pastes and submits.

## Mechanism details (for debugging reference)

| Component | Location | Role |
|---|---|---|
| `myclaude` / `mycodex` | `~/.local/bin/` | creates the sync file + spawns the watcher + launches the tool |
| `ai-tab-sync.sh` | `~/.local/bin/` | watcher: polls the sync file → writes OSC to the tty |
| sync file | `~/.ai-session-names/{pid}.txt` | single source of truth for the tab name |
| `session-auto-namer.sh` | `~/.claude/hooks/` | UserPromptSubmit (name from first message) + PostToolUse (#5 re-evaluation, every-10 safety net) |
| `codex-session-namer.sh` | `~/.codex/hooks/` | same as above + consumes the relay file, writes SQLite on the model's behalf |
| relay file (Codex) | `/tmp/codex-session-namer/{pid}.pending` | the only handoff point the model can write from inside the sandbox |
| skill | `~/.claude/skills/auto-rename/`, `~/.codex/skills/auto-rename/` | rules for manual `/auto-rename` |

## Migrating to another machine

On the new machine: clone this repo → run the same `install.sh` + alias + editor settings + `verify.sh`.
No files need to be copied from the old machine.
