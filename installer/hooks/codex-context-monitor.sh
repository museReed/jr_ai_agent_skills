#!/bin/bash
# PostToolUse hook for Codex CLI: trigger handoff when context reaches 70%.
#
# Prefer real Codex token_count events from the current rollout JSONL:
#   - pct = latest last_token_usage.input_tokens / model_context_window
# Fallback when token_count is unavailable:
#   - ~100 tool calls ≈ full context, so 70 calls ≈ 70%
#   - Repeat every 10 calls after the fallback threshold if not yet handed off
# Temporary small-context test mode: launch as
#   CODEX_TEST_MAX_CONTEXT_WINDOW=20000 codex
# to test handoff triggering. Unset = normal operation.

CODEX_PID=$PPID
COUNTER_DIR="/tmp/codex-context-monitor"
mkdir -p "$COUNTER_DIR"
COUNTER_FILE="$COUNTER_DIR/$CODEX_PID"
HANDOFF_MARKER="$COUNTER_DIR/${CODEX_PID}.handoff"
THRESHOLD_PCT=70
FALLBACK_FULL_TOOL_CALLS=100
FALLBACK_THRESHOLD=$((FALLBACK_FULL_TOOL_CALLS * THRESHOLD_PCT / 100))
TEST_MAX_CONTEXT_WINDOW="${CODEX_TEST_MAX_CONTEXT_WINDOW:-}"

# Already handed off — stop nagging
[ -f "$HANDOFF_MARKER" ] && exit 0

# Read and increment counter
COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"

ROLLOUT_PATH=""
if [ -n "${CODEX_THREAD_ID:-}" ] && command -v sqlite3 >/dev/null 2>&1; then
  CODEX_DB=$(ls -t "$HOME"/.codex/state_*.sqlite 2>/dev/null | head -1)
  if [ -n "$CODEX_DB" ]; then
    ROLLOUT_PATH=$(sqlite3 "$CODEX_DB" "SELECT rollout_path FROM threads WHERE id='${CODEX_THREAD_ID}' LIMIT 1;" 2>/dev/null || true)
  fi
fi

if [ -z "$ROLLOUT_PATH" ] || [ ! -f "$ROLLOUT_PATH" ]; then
  if [ -z "${CODEX_THREAD_ID:-}" ]; then
    # 完全沒 thread id（單 session 情境）才允許猜最新 rollout
    ROLLOUT_PATH=$(find "$HOME/.codex/sessions" -type f -name "rollout-*.jsonl" -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null | head -1)
  fi
  # 有 thread id 卻查不到 → 留空，改走 per-PID 工具呼叫數 fallback，不猜別的 session（誤報 99% 教訓）
fi

PCT=""
INPUT_TOKENS=""
MAX_CONTEXT=""
if [ -n "$ROLLOUT_PATH" ] && [ -f "$ROLLOUT_PATH" ]; then
  TOKEN_INFO=$(ROLLOUT_PATH="$ROLLOUT_PATH" TEST_MAX_CONTEXT_WINDOW="$TEST_MAX_CONTEXT_WINDOW" python3 - <<'PYEOF'
from collections import deque
import json
import os
import sys

best = None
path = os.environ.get("ROLLOUT_PATH")
try:
    with open(path, encoding="utf-8") as fh:
        lines = deque(fh, maxlen=200)
except OSError:
    lines = []

for line in lines:
    try:
        event = json.loads(line)
    except json.JSONDecodeError:
        continue
    payload = event.get("payload") or {}
    if payload.get("type") != "token_count":
        continue
    info = payload.get("info") or {}
    last = info.get("last_token_usage") or {}
    input_tokens = int(last.get("input_tokens") or 0)
    max_context = int(info.get("model_context_window") or 0)
    test_max_context = os.environ.get("TEST_MAX_CONTEXT_WINDOW")
    if test_max_context:
        max_context = int(test_max_context)
    if input_tokens > 0 and max_context > 0:
        best = (input_tokens, max_context)

if best:
    input_tokens, max_context = best
    pct = input_tokens * 100 // max_context
    print(f"{pct} {input_tokens} {max_context}")
PYEOF
)
  if [ -n "$TOKEN_INFO" ]; then
    read -r PCT INPUT_TOKENS MAX_CONTEXT <<EOF
$TOKEN_INFO
EOF
  fi
fi

TRIGGER_REASON=""
if [ -n "$PCT" ] && [ "$PCT" -ge "$THRESHOLD_PCT" ] 2>/dev/null; then
  if [ -n "$TEST_MAX_CONTEXT_WINDOW" ]; then
    TRIGGER_REASON="測試模式：Context 以小視窗 ${MAX_CONTEXT} 計算，已用約 ${PCT}%（${INPUT_TOKENS}/${MAX_CONTEXT} input tokens），已達 ${THRESHOLD_PCT}% 門檻。"
  else
    TRIGGER_REASON="Context 已用約 ${PCT}%（${INPUT_TOKENS}/${MAX_CONTEXT} input tokens），已達 ${THRESHOLD_PCT}% 門檻。"
  fi
elif [ -z "$PCT" ] && { [ "$COUNT" -eq "$FALLBACK_THRESHOLD" ] || { [ "$COUNT" -gt "$FALLBACK_THRESHOLD" ] && [ $(( (COUNT - FALLBACK_THRESHOLD) % 10 )) -eq 0 ]; }; }; then
  TRIGGER_REASON="無法讀取 Codex token_count，改用工具呼叫數估算：${COUNT}/${FALLBACK_FULL_TOOL_CALLS}，約達 ${THRESHOLD_PCT}% 門檻。"
fi

if [ -n "$TRIGGER_REASON" ]; then
  python3 <<PYEOF
import json
ctx = "[context-monitor] ${TRIGGER_REASON} 請立即觸發 \$handoff skill：Read and follow .agents/skills/handoff/SKILL.md（repo 有的話優先）或 ~/.agents/skills/handoff/SKILL.md 寫交接文件。\n\n重要：寫完 handoff 並 commit 後，必須把 session 改名為 📦 {topic}（按 SKILL.md Step 5a 執行）。\n\n全部完成後執行：touch /tmp/codex-context-monitor/${CODEX_PID}.handoff"
obj = {"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": ctx}}
json.dump(obj, __import__('sys').stdout, ensure_ascii=False)
PYEOF
fi
