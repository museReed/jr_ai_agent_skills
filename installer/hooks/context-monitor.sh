#!/bin/bash
# Context Monitor Hook — reads session JSONL to get real token usage
# Triggered on PostToolUse to warn when context exceeds threshold
#
# How it works:
#   1. Reads transcript_path from the hook input JSON on stdin (exact current-session JSONL;
#      guessing by mtime breaks with concurrent sessions)
#   2. Reads the last assistant message's usage.input_tokens + cache tokens
#   3. If total > THRESHOLD, tells model to read and follow handoff skill

JSONL=$(python3 -c "import json,sys; print(json.load(sys.stdin).get('transcript_path',''))" 2>/dev/null)

[ -f "$JSONL" ] || exit 0

# Read last 30 lines for performance (avoid scanning multi-MB files)
# Outputs "TOTAL MODEL" — model taken from the same assistant message as the max usage
read -r TOTAL MODEL <<EOF
$(tail -30 "$JSONL" | python3 -c "
import json, sys
best, model = 0, ''
for line in sys.stdin:
    try:
        d = json.loads(line)
        if d.get('type') == 'assistant':
            u = d.get('message', {}).get('usage', {})
            t = u.get('input_tokens', 0) + u.get('cache_creation_input_tokens', 0) + u.get('cache_read_input_tokens', 0)
            if t > best:
                best = t
                model = d.get('message', {}).get('model', '') or ''
    except (json.JSONDecodeError, KeyError):
        pass
print(best, model)
" 2>/dev/null)
EOF

[ -z "$TOTAL" ] && exit 0
[ "$TOTAL" -eq 0 ] 2>/dev/null && exit 0

# Context window by model: Claude Code marks 1M long-context mode with a [1m] suffix
# (e.g. claude-sonnet-4-5[1m]); everything else is the 200k default.
case "$MODEL" in
  *\[1m\]*)  MAX_CONTEXT=1000000 ;;
  *fable*)   MAX_CONTEXT=1000000 ;;  # Fable 5 default window is 1M (no [1m] marker)
  *)         MAX_CONTEXT=200000 ;;
esac

# Temporary small-context test mode: launch as
#   CONTEXT_MONITOR_TEST_WINDOW=30000 claude
# to test handoff triggering. Unset = normal operation.
TEST_TAG=""
if [ -n "${CONTEXT_MONITOR_TEST_WINDOW:-}" ]; then
  MAX_CONTEXT=$CONTEXT_MONITOR_TEST_WINDOW
  TEST_TAG="（測試模式：以小視窗 ${MAX_CONTEXT} 計算）"
fi

THRESHOLD=$((MAX_CONTEXT * 70 / 100))

PCT=$((TOTAL * 100 / MAX_CONTEXT))

if [ "$TOTAL" -gt "$THRESHOLD" ]; then
  python3 -c "
import json, sys
ctx = '⚠️ Context 已用 ~${TOTAL} tokens (${PCT}%)${TEST_TAG}。請立即 Read and follow .claude/skills/handoff/SKILL.md（repo 有的話優先）或 ~/.claude/skills/handoff/SKILL.md 寫交接文件。'
obj = {'hookSpecificOutput': {'hookEventName': 'PostToolUse', 'additionalContext': ctx}}
json.dump(obj, sys.stdout, ensure_ascii=False)
"
fi
