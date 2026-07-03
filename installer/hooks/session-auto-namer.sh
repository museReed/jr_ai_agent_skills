#!/bin/bash
# PostToolUse hook: auto-name Claude Code sessions & terminal tabs.
#   count=3  → write git branch as default name (deterministic, no LLM)
#   count=5  → inject additionalContext asking the model for a better name
#   every 20 → retry if the model hasn't improved the default name
#
# Display paths (in priority order):
#   1. $AI_TAB_SYNC_FILE set (launched via myclaude wrapper) → watcher owns the tab
#   2. no wrapper → this hook refreshes the tab title by writing OSC directly to
#      the controlling tty on every tool call. Requires
#      CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1 so the built-in title doesn't fight back.

CLAUDE_PID=$PPID
COUNTER_DIR="/tmp/claude-session-namer"
mkdir -p "$COUNTER_DIR"
COUNTER_FILE="$COUNTER_DIR/$CLAUDE_PID"

COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"

# Terminal shell PID (claude's parent) keys the session-name file
TERMINAL_PID=$(ps -o ppid= -p "$CLAUDE_PID" 2>/dev/null | tr -d ' ')
NAMES_DIR="$HOME/.claude/session-names"
SESSION_FILE="$NAMES_DIR/${TERMINAL_PID}.txt"
DEFAULT_MARKER="$COUNTER_DIR/${CLAUDE_PID}.default"

# No-wrapper display path: refresh tab title from saved name on every tool call.
# Newer Claude Code strips ESC bytes from tool stdout, so OSC must go straight
# to the tty device.
if [ -z "${AI_TAB_SYNC_FILE:-}" ]; then
  TTY_DEV=$(ps -o tty= -p "$CLAUDE_PID" 2>/dev/null | tr -d ' ')
  if [ -n "$TTY_DEV" ] && [ "$TTY_DEV" != "??" ] && [ -w "/dev/$TTY_DEV" ] && [ -r "$SESSION_FILE" ]; then
    printf '\033]0;%s\007' "$(cat "$SESSION_FILE")" > "/dev/$TTY_DEV" 2>/dev/null
  fi
fi

set_session_name() {
  local name="$1"
  mkdir -p "$NAMES_DIR"
  echo "$name" > "$SESSION_FILE"
  if [ -n "${AI_TAB_SYNC_FILE:-}" ]; then
    echo "$name" > "$AI_TAB_SYNC_FILE" 2>/dev/null || true
  fi
}

# count=3: git branch (or dirname) as immediate default
if [ "$COUNT" -eq 3 ]; then
  SHELL_CWD=$(lsof -d cwd -p "$TERMINAL_PID" -Fn 2>/dev/null | grep '^n' | head -1 | sed 's|^n||')
  [ -z "$SHELL_CWD" ] && SHELL_CWD=$(pwd)
  BRANCH=$(git -C "$SHELL_CWD" branch --show-current 2>/dev/null)
  if [ -n "$BRANCH" ]; then
    NAME=$(echo "$BRANCH" | sed 's|^feature/||;s|^fix/||;s|^hotfix/||')
  else
    NAME=$(basename "$SHELL_CWD")
  fi
  set_session_name "$NAME"
  touch "$DEFAULT_MARKER"
fi

NEEDS_BETTER_NAME=false
if [ "$COUNT" -eq 5 ]; then
  NEEDS_BETTER_NAME=true
elif [ "$COUNT" -gt 5 ] && [ $(( COUNT % 20 )) -eq 0 ] && [ -f "$DEFAULT_MARKER" ]; then
  NEEDS_BETTER_NAME=true
fi

if [ "$NEEDS_BETTER_NAME" = true ]; then
  if [ -n "${AI_TAB_SYNC_FILE:-}" ]; then
    WRITE_CMD="echo '{名稱}' > $AI_TAB_SYNC_FILE && mkdir -p ~/.claude/session-names && echo '{名稱}' > ~/.claude/session-names/${TERMINAL_PID}.txt && rm -f /tmp/claude-session-namer/${CLAUDE_PID}.default"
  else
    WRITE_CMD="mkdir -p ~/.claude/session-names && echo '{名稱}' > ~/.claude/session-names/${TERMINAL_PID}.txt && rm -f /tmp/claude-session-namer/${CLAUDE_PID}.default"
  fi
  cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"[session-namer] 請為此 session 命名並寫入檔案。\n\n命名規則：\n- 格式：{emoji} {中文敘述}，emoji 取代英文動詞，技術名詞可保留英文\n- 總長度 ≤ 40 字元\n- emoji 只能從這 8 個選：🏗️ build/implement/refactor、🔧 fix、🐛 debug、📐 plan/design、📋 review/audit、💬 discuss、⛴️ pilot/spike、🔍 research\n- 根據對話「主要目的」命名，不是最新一句話\n\n執行指令：\n${WRITE_CMD}"}}
EOF
fi
