#!/bin/bash
# Behaviour tests for installer/hooks/set-session-name.sh.
#
# Why these exist: every failure mode this script has ever had was silent — the name went
# to a file nobody read, or an emoji was swapped without a word, and it looked like renaming
# had simply stopped working. Assertions are cheaper than the three rounds of debugging
# each of those cost.
#
# Everything runs against a sandbox HOME, and the impersonated AI process is a plain sleep
# whose parent is this script, so no live ai-tab-sync.sh watcher can match it: the tab
# branch always falls through to the OSC path, which finds no tty and writes nothing.
#
# Usage: bash installer/tests/test_set_session_name.sh
set -u

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/hooks/set-session-name.sh"
PASS=0
FAIL=0

check() { # check <label> <expected> <actual>
  if [ "$2" = "$3" ]; then
    PASS=$((PASS + 1))
    echo "  ok   $1"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL $1"
    echo "       expected: $2"
    echo "       actual:   $3"
  fi
}

json_field() { # json_field <file> <key>
  python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get(sys.argv[2]))" \
    "$1" "$2" 2>/dev/null
}

run() { # run <sandbox> <name> [job-id] [session-id] -> echoes the name file contents
  sandbox=$1
  sleep 30 &
  fake_pid=$!
  mkdir -p "$sandbox/.claude/sessions"
  if [ -n "${3:-}" ]; then
    mkdir -p "$sandbox/.claude/jobs/$3"
    echo '{"name":null,"nameSource":null}' > "$sandbox/.claude/jobs/$3/state.json"
    printf '{"pid":%s,"kind":"bg","jobId":"%s"}\n' "$fake_pid" "$3" \
      > "$sandbox/.claude/sessions/$fake_pid.json"
  fi
  HOME="$sandbox" bash "$SCRIPT" "$2" "$fake_pid" "${4:-}" >/dev/null 2>&1
  kill "$fake_pid" 2>/dev/null
  wait "$fake_pid" 2>/dev/null
  cat "$sandbox"/.claude/session-names/*.txt 2>/dev/null
}

# The project prefix comes from the cwd, which varies per checkout, so strip it where the
# assertion is about the emoji rather than the prefix.
no_prefix() { sed 's/^\[[^]]*\] //'; }

echo "emoji guard"
S=$(mktemp -d); check "missing emoji gets 🔍" "🔍 沒有表情符號" "$(run "$S" '沒有表情符號' | no_prefix)"
S=$(mktemp -d); check "off-list emoji replaced" "🔍 清單外的" "$(run "$S" '🎯 清單外的' | no_prefix)"
S=$(mktemp -d); check "listed emoji kept" "🐛 除錯中" "$(run "$S" '🐛 除錯中' | no_prefix)"
S=$(mktemp -d); check "handoff 📦 kept" "📦 交接主題" "$(run "$S" '📦 交接主題' | no_prefix)"
S=$(mktemp -d); check "already-prefixed name untouched" "[proj] 🐛 已命名" "$(run "$S" '[proj] 🐛 已命名')"

echo "background session badge"
S=$(mktemp -d)
run "$S" '🐛 背景命名' testjob sess-id-1 >/dev/null
check "state.json nameSource becomes user" user "$(json_field "$S/.claude/jobs/testjob/state.json" nameSource)"
ends_with() { case "$1" in *"$2") echo yes ;; *) echo no ;; esac; }
check "state.json name ends with the given name" yes \
  "$(ends_with "$(json_field "$S/.claude/jobs/testjob/state.json" name)" '🐛 背景命名')"

echo "interactive session leaves job state alone"
S=$(mktemp -d)
mkdir -p "$S/.claude/jobs/testjob"
echo '{"name":null,"nameSource":null}' > "$S/.claude/jobs/testjob/state.json"
run "$S" '🐛 互動命名' >/dev/null
check "no jobId means no badge write" None "$(json_field "$S/.claude/jobs/testjob/state.json" nameSource)"

echo
echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
