#!/usr/bin/env bash
# install.sh — AI session auto-rename + terminal tab sync installer
# for Claude Code and/or Codex CLI. Idempotent; backs up files it replaces.
#
# Usage:
#   ./install.sh            # install for both tools
#   ./install.sh claude     # Claude Code only
#   ./install.sh codex      # Codex only
#
# Works on macOS / Linux. Requires: bash, python3; sqlite3 for Codex sidebar names.
set -euo pipefail

TARGET="${1:-all}"
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
TS=$(date +%Y%m%d%H%M%S)

backup() { [ -f "$1" ] && cp "$1" "$1.bak.$TS" && echo "  backup: $1.bak.$TS" || true; }

install_file() { # src dst mode
  mkdir -p "$(dirname "$2")"
  backup "$2"
  cp "$1" "$2"
  chmod "$3" "$2"
  echo "  installed: $2"
}

# --- shared display layer (wrapper + watcher) ---
echo "[1/3] Display layer (wrappers + watcher) → ~/.local/bin"
install_file "$SRC_DIR/bin/ai-tab-sync.sh" "$HOME/.local/bin/ai-tab-sync.sh" 755
[ "$TARGET" != "codex" ]  && install_file "$SRC_DIR/bin/myclaude" "$HOME/.local/bin/myclaude" 755
[ "$TARGET" != "claude" ] && install_file "$SRC_DIR/bin/mycodex"  "$HOME/.local/bin/mycodex" 755

# --- Claude Code ---
if [ "$TARGET" != "codex" ]; then
  echo "[2/3] Claude Code: hook + skill"
  install_file "$SRC_DIR/hooks/session-auto-namer.sh" "$HOME/.claude/hooks/session-auto-namer.sh" 755
  mkdir -p "$HOME/.claude/skills/auto-rename"
  backup "$HOME/.claude/skills/auto-rename/SKILL.md"
  cp "$SRC_DIR/skills/claude/auto-rename/SKILL.md" "$HOME/.claude/skills/auto-rename/SKILL.md"
  echo "  installed: ~/.claude/skills/auto-rename/SKILL.md"

  backup "$HOME/.claude/settings.json"
  python3 - "$HOME/.claude/settings.json" <<'PYEOF'
import json, os, sys
path = sys.argv[1]
os.makedirs(os.path.dirname(path), exist_ok=True)
cfg = {}
if os.path.exists(path):
    with open(path) as f:
        cfg = json.load(f)
hooks = cfg.setdefault("hooks", {})
ptu = hooks.setdefault("PostToolUse", [])
cmd = f'bash {os.path.expanduser("~/.claude/hooks/session-auto-namer.sh")}'
# drop any stale session-auto-namer entries, then add ours
for grp in ptu:
    grp["hooks"] = [h for h in grp.get("hooks", []) if "session-auto-namer.sh" not in h.get("command", "")]
ptu[:] = [g for g in ptu if g.get("hooks")]
ptu.append({"hooks": [{"type": "command", "command": cmd, "timeout": 3}]})
with open(path, "w") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
print("  registered hook in ~/.claude/settings.json")
PYEOF
fi

# --- Codex ---
if [ "$TARGET" != "claude" ]; then
  echo "[3/3] Codex: hook + skill"
  install_file "$SRC_DIR/hooks/codex-session-namer.sh" "$HOME/.codex/hooks/codex-session-namer.sh" 755
  mkdir -p "$HOME/.codex/skills/auto-rename"
  backup "$HOME/.codex/skills/auto-rename/SKILL.md"
  cp "$SRC_DIR/skills/codex/auto-rename/SKILL.md" "$HOME/.codex/skills/auto-rename/SKILL.md"
  echo "  installed: ~/.codex/skills/auto-rename/SKILL.md"

  backup "$HOME/.codex/hooks.json"
  python3 - "$HOME/.codex/hooks.json" <<'PYEOF'
import json, os, sys
path = sys.argv[1]
os.makedirs(os.path.dirname(path), exist_ok=True)
cfg = {}
if os.path.exists(path):
    with open(path) as f:
        cfg = json.load(f)
hooks = cfg.setdefault("hooks", {})
ptu = hooks.setdefault("PostToolUse", [])
cmd = f'bash {os.path.expanduser("~/.codex/hooks/codex-session-namer.sh")}'
for grp in ptu:
    grp["hooks"] = [h for h in grp.get("hooks", []) if "codex-session-namer.sh" not in h.get("command", "")]
ptu[:] = [g for g in ptu if g.get("hooks")]
ptu.append({"hooks": [{"type": "command", "command": cmd, "timeout": 3}]})
with open(path, "w") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
print("  registered hook in ~/.codex/hooks.json")
PYEOF
fi

echo
echo "Done. Add these aliases to your shell rc (~/.zshrc or ~/.bashrc):"
[ "$TARGET" != "codex" ]  && echo "  alias claude='\$HOME/.local/bin/myclaude'"
[ "$TARGET" != "claude" ] && echo "  alias codex='\$HOME/.local/bin/mycodex'"
echo
echo "Then restart your terminal. Tab titles auto-update after ~3-5 tool calls."
