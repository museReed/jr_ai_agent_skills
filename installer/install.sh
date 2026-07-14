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
  echo "[2/3] Claude Code: hooks + skills"
  install_file "$SRC_DIR/hooks/session-auto-namer.sh" "$HOME/.claude/hooks/session-auto-namer.sh" 755
  install_file "$SRC_DIR/hooks/context-monitor.sh" "$HOME/.claude/hooks/context-monitor.sh" 755
  for skill in auto-rename handoff structured-questions; do
    mkdir -p "$HOME/.claude/skills/$skill"
    backup "$HOME/.claude/skills/$skill/SKILL.md"
    cp -R "$SRC_DIR/skills/claude/$skill/." "$HOME/.claude/skills/$skill/"
    echo "  installed: ~/.claude/skills/$skill/"
  done

  # 1M context-window 偵測用的快取種子（context-monitor.sh 靠它查真實視窗，避免把 1M 模型當 200k）。
  # 只在缺檔時種下，不覆蓋學生本機已 populated 的版本。
  [ -f "$HOME/.claude/model-context-windows-cache.json" ] \
    || install_file "$SRC_DIR/model-context-windows-cache.json" "$HOME/.claude/model-context-windows-cache.json" 644

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
namer = f'bash {os.path.expanduser("~/.claude/hooks/session-auto-namer.sh")}'
monitor = f'bash {os.path.expanduser("~/.claude/hooks/context-monitor.sh")}'
# drop any stale entries for our scripts, then add ours
# (match "/context-monitor.sh" with a slash so it can't hit codex-context-monitor.sh)
for event, marker, cmd in [
    ("PostToolUse", "session-auto-namer.sh", namer),
    ("UserPromptSubmit", "session-auto-namer.sh", f"{namer} prompt"),
    ("PostToolUse", "/context-monitor.sh", monitor),
]:
    lst = hooks.setdefault(event, [])
    for grp in lst:
        grp["hooks"] = [h for h in grp.get("hooks", []) if marker not in h.get("command", "")]
    lst[:] = [g for g in lst if g.get("hooks")]
    lst.append({"hooks": [{"type": "command", "command": cmd, "timeout": 3}]})
with open(path, "w") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
print("  registered session-namer (PostToolUse + UserPromptSubmit) + context-monitor (PostToolUse) in ~/.claude/settings.json")
PYEOF
fi

# --- Codex ---
if [ "$TARGET" != "claude" ]; then
  echo "[3/3] Codex: hooks + skills"
  install_file "$SRC_DIR/hooks/codex-session-namer.sh" "$HOME/.codex/hooks/codex-session-namer.sh" 755
  install_file "$SRC_DIR/hooks/codex-context-monitor.sh" "$HOME/.codex/hooks/codex-context-monitor.sh" 755
  for skill in auto-rename handoff structured-questions; do
    mkdir -p "$HOME/.codex/skills/$skill"
    backup "$HOME/.codex/skills/$skill/SKILL.md"
    cp -R "$SRC_DIR/skills/codex/$skill/." "$HOME/.codex/skills/$skill/"
    echo "  installed: ~/.codex/skills/$skill/"
  done
  mkdir -p "$HOME/.codex/skills/_shared"
  backup "$HOME/.codex/skills/_shared/codex-session-rename.md"
  cp "$SRC_DIR/skills/codex/_shared/codex-session-rename.md" "$HOME/.codex/skills/_shared/codex-session-rename.md" 2>/dev/null \
    || echo "  skipped: ~/.codex/skills/_shared/codex-session-rename.md（已存在同內容 symlink）"
  echo "  installed: ~/.codex/skills/_shared/codex-session-rename.md"

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
namer = f'bash {os.path.expanduser("~/.codex/hooks/codex-session-namer.sh")}'
monitor = f'bash {os.path.expanduser("~/.codex/hooks/codex-context-monitor.sh")}'
for event, marker, cmd in [
    ("PostToolUse", "codex-session-namer.sh", namer),
    ("UserPromptSubmit", "codex-session-namer.sh", f"{namer} prompt"),
    ("PostToolUse", "codex-context-monitor.sh", monitor),
]:
    lst = hooks.setdefault(event, [])
    for grp in lst:
        grp["hooks"] = [h for h in grp.get("hooks", []) if marker not in h.get("command", "")]
    lst[:] = [g for g in lst if g.get("hooks")]
    lst.append({"hooks": [{"type": "command", "command": cmd, "timeout": 3}]})
with open(path, "w") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
print("  registered session-namer (PostToolUse + UserPromptSubmit) + context-monitor (PostToolUse) in ~/.codex/hooks.json")
PYEOF
fi

echo
echo "Done. The AI guiding your install should add these aliases to your shell rc"
echo "(~/.zshrc or ~/.bashrc) for you. If it didn't, add them manually as a fallback:"
[ "$TARGET" != "codex" ]  && echo "  alias claude='\$HOME/.local/bin/myclaude'"
[ "$TARGET" != "claude" ] && echo "  alias codex='\$HOME/.local/bin/mycodex'"
echo
echo "Then restart your terminal. Tab titles auto-update right after your first message."
echo
echo "Next: run ./verify.sh (from this directory) to check the install end-to-end."
