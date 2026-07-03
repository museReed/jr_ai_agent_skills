#!/bin/bash
# PostToolUse hook for Codex: auto-name sessions after N tool calls.
# Reads session_id from stdin JSON (Codex passes it to all hooks).
#
#   count=3  → write git branch as default name (hook writes SQLite directly)
#   count=5  → inject additionalContext asking the model for a better name
#   every 20 → retry if the model hasn't improved the default name
#
# Sandbox note: the Codex MODEL cannot write ~/.codex/state_*.sqlite or
# ~/.ai-session-names/ outside a trusted cwd ("attempt to write a readonly
# database"). Hooks run unsandboxed, so the model only writes the chosen name
# to a /tmp relay file (always writable); this hook applies it to SQLite
# (sidebar name) + the tab-sync file on the next PostToolUse event.

STDIN_JSON=$(cat)

CODEX_PID=$PPID
COUNTER_DIR="/tmp/codex-session-namer"
mkdir -p "$COUNTER_DIR"
COUNTER_FILE="$COUNTER_DIR/$CODEX_PID"
DEFAULT_MARKER="$COUNTER_DIR/${CODEX_PID}.default"
RELAY_FILE="$COUNTER_DIR/${CODEX_PID}.pending"

SESSION_ID=$(echo "$STDIN_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null || true)

apply_name() {
  local name="$1"
  local db esc
  db=$(ls -t "$HOME"/.codex/state_*.sqlite 2>/dev/null | head -1)
  if [ -n "$SESSION_ID" ] && [ -n "$db" ] && [ -f "$db" ]; then
    esc=${name//\'/\'\'}
    sqlite3 "$db" "UPDATE threads SET title='${esc}', preview='${esc}' WHERE id='${SESSION_ID}';" 2>/dev/null || true
  fi
  if [ -n "${AI_TAB_SYNC_FILE:-}" ]; then
    echo "$name" > "$AI_TAB_SYNC_FILE" 2>/dev/null || true
  fi
}

# Apply a model-chosen name left in the relay file (sandbox-safe handoff)
if [ -f "$RELAY_FILE" ]; then
  NAME=$(head -1 "$RELAY_FILE" | cut -c1-120)
  rm -f "$RELAY_FILE"
  if [ -n "$NAME" ]; then
    apply_name "$NAME"
    rm -f "$DEFAULT_MARKER"
  fi
fi

COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"

# count=3: git branch (or dirname) as immediate default
if [ "$COUNT" -eq 3 ]; then
  BRANCH=$(git branch --show-current 2>/dev/null)
  if [ -n "$BRANCH" ]; then
    NAME=$(echo "$BRANCH" | sed 's|^feature/||;s|^fix/||;s|^hotfix/||')
  else
    NAME=$(basename "$(pwd)")
  fi
  apply_name "$NAME"
  touch "$DEFAULT_MARKER"
fi

NEEDS_BETTER_NAME=false
if [ "$COUNT" -eq 5 ]; then
  NEEDS_BETTER_NAME=true
elif [ "$COUNT" -gt 5 ] && [ $(( COUNT % 20 )) -eq 0 ] && [ -f "$DEFAULT_MARKER" ]; then
  NEEDS_BETTER_NAME=true
fi

if [ "$NEEDS_BETTER_NAME" = true ]; then
  RELAY_FILE="$RELAY_FILE" python3 <<'PYEOF'
import json, os, sys

relay = os.environ["RELAY_FILE"]
ctx = (
    "[session-namer] 請為此 session 命名。\n\n"
    "命名規則：\n"
    "- 格式：{emoji} {中文敘述}，總長度 ≤ 40 字元，技術名詞保留英文\n"
    "- emoji 只能從這 8 個選：🏗️ build/implement/refactor、🔧 fix、🐛 debug、"
    "📐 plan/design、📋 review/audit、💬 discuss、⛴️ pilot/spike、🔍 research\n"
    "- 根據對話「主要目的」命名，不是最新一句話\n\n"
    f"執行指令（只需這一步，hook 會自動同步 sidebar 與 terminal tab）：\n"
    f"mkdir -p /tmp/codex-session-namer && echo '{{名稱}}' > {relay}"
)
obj = {"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": ctx}}
json.dump(obj, sys.stdout, ensure_ascii=False)
PYEOF
fi
