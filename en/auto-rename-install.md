# Auto-Rename Skill — Installation Guide

Read this document and guide the user through the single installation flow below. Detect first, ask only when a real choice remains, and execute every step sequentially. **Installation is NOT complete until the user has opened a new session and completed all three skills' E2E checks.**

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

## Single AI-guided installation flow

### 1. Detect first without modifying settings

```bash
cd jr_ai_agent_skills/installer
python3 detect-environment.py
```

Read `cli`, `recommended_install_target`, `terminal`, and `editors` from the JSON. Parent-process names are strong evidence, `TERM_PROGRAM` is secondary evidence, and an existing settings file only means an editor is installed or has been used—it does not identify the current terminal.

### 2. Choose the installation target

| Detection result | AI behavior |
|---|---|
| Claude CLI only | Announce “Claude Code detected; installing the Claude version” without asking |
| Codex CLI only | Announce “Codex CLI detected; installing the Codex version” without asking |
| Both CLIs | Ask a structured question with “Both (Recommended) / Claude / Codex” |
| Neither CLI | Stop and ask the user to install at least one CLI first |

The pre-install flow must not assume that `structured-questions` is already installed, so follow these rules directly:

- Claude Code: use the native `AskUserQuestion` picker.
- Codex Plan mode: use `request_user_input`; ask at most 3 questions per call, give each question 2–3 options, put the recommended option first with `(Recommended)`, and keep each trade-off to one description line.
- Codex Default mode: output “You are not currently in Plan mode. For interactive menus, enter `/plan 繼續安裝 jr_ai_agent_skills`; if you do not want to switch, reply ‘do not switch’ and I will use text options.” Then stop without listing options.
- If the user says “yes/switch,” direct them to enter `/plan 繼續安裝 jr_ai_agent_skills`, then stop. If they enter it and the mode changes, continue with `request_user_input`.
- Only an explicit “no/do not switch” enables full text choices in that same turn. For an ambiguous answer, ask again for “switch” or “do not switch”; never fall back automatically.

When the active agent is Codex, preserve the exact command `/plan 繼續安裝 jr_ai_agent_skills` so the next session can resume this flow unambiguously.

### 3. Always confirm the current terminal/IDE

Detection is only a recommendation. The AI must confirm it with the same structured-question behavior. With a specific detection, ask “Use detected result (Recommended) / Different VS Code-family IDE / Terminal, iTerm, or other.” If the user picks a different VS Code-family IDE, ask “Cursor / Antigravity / VS Code.” If detection is unknown, first ask “VS Code-family IDE / Terminal, iTerm, or other,” then ask which IDE when needed.

Configure only the editor the student finally confirms:

```bash
python3 configure-editor.py cursor       # or antigravity / vscode
python3 configure-editor.py native       # Terminal.app, iTerm, or other: explicitly changes nothing
```

If an existing `settings.json` contains JSONC comments and parsing fails, the file remains untouched. Ask the student to use “Open User Settings (JSON)” in the confirmed editor and manually add `"terminal.integrated.tabs.title": "${sequence}"`. Never edit another editor merely because its settings file exists.

### 4. Run the non-interactive installer and add aliases

```bash
./install.sh claude --editor=<confirmed-editor>   # Claude Code only
./install.sh codex --editor=<confirmed-editor>    # Codex CLI only
./install.sh --editor=<confirmed-editor>          # both
```

One command installs auto-rename, handoff, and structured-questions plus the relevant hooks for the chosen target; the skills are not installed separately. The AI then adds only the matching aliases to the shell rc (idempotently; run both lines when both tools were chosen):

```bash
RC="$HOME/.zshrc"; case "$SHELL" in *bash*) RC="$HOME/.bashrc";; esac
TARGET="<claude|codex|all>"
case "$TARGET" in claude|all) grep -q "alias claude=.*myclaude" "$RC" 2>/dev/null || echo "alias claude='\$HOME/.local/bin/myclaude'" >> "$RC";; esac
case "$TARGET" in codex|all) grep -q "alias codex=.*mycodex" "$RC" 2>/dev/null || echo "alias codex='\$HOME/.local/bin/mycodex'" >> "$RC";; esac
```

The installer is idempotent and safe to rerun. Codex skill backups go to `~/.agents/skill-backups/{timestamp}/`; other replaced files use `*.bak.{timestamp}`.

### 5. Stop and require a fresh environment

After the installer finishes, the AI must explicitly ask the student to **open a new terminal and start a new AI session**, paste the target-aware continuation prompt printed by the installer, then stop the current flow. The old session cannot reload newly installed skills and must not claim the install or E2E is complete.

## E2E Verification (the AI agent MUST actively walk the user through this — do not skip)

> Full step-by-step playbook (4 rounds × checkpoint IDs) → Read `installer/VERIFICATION.md` and walk the user through it.

### Step 1: Automated checks

```bash
cd jr_ai_agent_skills/installer
./verify.sh claude --editor=<confirmed-editor>  # replace with cursor / antigravity / vscode / native
# use codex instead, or omit claude/codex when both were installed
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
| `set-session-name.sh` | `~/.claude/hooks/` | Naming-write wrapper (shared by hook auto-naming and `/auto-rename`; folds file/OSC writes + marker cleanup into one script — no `&&` chain, one allowlist rule) |
| `codex-session-namer.sh` | `~/.codex/hooks/` | same as above + consumes the relay file, writes SQLite on the model's behalf |
| relay file (Codex) | `/tmp/codex-session-namer/{pid}.pending` | the only handoff point the model can write from inside the sandbox |
| skill | `~/.claude/skills/auto-rename/`, `~/.agents/skills/auto-rename/` | rules for manual `/auto-rename` |

## Migrating to another machine

On the new machine: clone this repo → let the AI detect and confirm → run `install.sh` + aliases + the confirmed editor setting + `verify.sh`.
No files need to be copied from the old machine.
