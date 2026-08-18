#!/bin/bash
# Single entry point for session naming, called by both:
#   - session-auto-namer.sh (hook-injected WRITE_CMD)
#   - auto-rename / handoff skills
#
# Whitelisting `Bash(.../set-session-name.sh:*)` covers every naming write in one
# rule — the echo/rm/printf/ps inside run as script internals, not re-checked by
# the AI's per-command permission layer.
#
# Usage: set-session-name.sh '{emoji} {name}' "$PPID" [session-id]
#
# The name reaches three surfaces, each written by its own section below:
#   tab title      -> a live ai-tab-sync.sh watcher's file, or OSC to the tty
#   statusline     -> ~/.claude/session-names/<terminal-pid>.txt
#   session badge  -> ~/.claude/jobs/<jobId>/state.json  (background sessions only)
#
# Arg 2 (AI process pid): the caller MUST pass its own $PPID. The original inline
# commands ran directly in the AI's Bash-tool shell where $PPID = the AI process;
# wrapping them in this script adds a process layer, so our own $PPID would be the
# calling shell — off by one.
# Arg 3 (session id, from the hook payload) is optional and only feeds the breadcrumb
# that gives background sessions a tab; skill paths may omit it and degrade to the
# pid-only behaviour.

NAME="$1"
[ -z "$NAME" ] && { echo "set-session-name: missing name arg" >&2; exit 1; }

CLAUDE_PID="${2:-$PPID}"
SESSION_ID="${3:-}"
TERMINAL_PID=$(ps -o ppid= -p "$CLAUDE_PID" 2>/dev/null | tr -d ' ')
NAME_DIR=~/.claude/session-names
BREADCRUMB_DIR=~/.claude/session-terminals

# Is this session in the background, and under which job? The CLI's per-pid session record
# answers both. $CLAUDE_JOB_DIR does NOT: it is only in the environment of a session that
# was *born* in the background, while one backgrounded later has a jobId and no such
# variable — that gap is what leaves those sessions showing the CLI's own slug.
# Empty means a purely interactive session.
#
# python3 rather than jq: the other hooks here already depend on python3 and nothing in the
# installer guarantees jq. A missing record, bad JSON or absent python all yield an empty
# JOB_ID, which degrades to the interactive path instead of failing.
JOB_ID=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get('jobId') or '')" \
  ~/.claude/sessions/"${CLAUDE_PID}".json 2>/dev/null)

# Is some ai-tab-sync.sh really polling this file? Both tab paths depend on the answer:
# a name written to a file nobody reads is silently lost.
watcher_alive() { [ -n "$1" ] && pgrep -f "ai-tab-sync.sh $1" >/dev/null 2>&1; }

# --------------------------------------------------------------------------------- name
#
# 校驗 emoji：模型有時會挑清單外的（實測看到 🎯）。改指示措辭只是拜託模型，
# 這裡才是最後一道關卡——不在清單裡就換成 🔍，名字其餘部分原樣保留。
#
# 📦 是第 9 個：handoff skill 用它標「已交接」。它原本不在清單裡，於是每次交接
# 完標題都被悄悄換成 🔍，而且腳本不出聲，看起來像改名整個沒生效（VM 實測，查了
# 三輪才找到）。命名 hook 那邊的指示仍然只給模型 8 個選，📦 是 skill 專用的。
#
# `[` 開頭代表名字已經帶了專案前綴，是既有名字被重新套用——emoji 已經驗過了，
# 再驗一次會把 `[` 當成非 emoji 而多塞一個 🔍。
case "$NAME" in
  🏗️*|🔧*|🐛*|📐*|📋*|💬*|⛴️*|🔍*|📦*|\[*) ;;
  *)
    # 只有「開頭那個 token 看起來是 emoji」時才把它換掉，否則會把真正的第一個
    # 詞吃掉（實測：「完全沒有 emoji」變成「🔍 emoji」）。判準用字元數：emoji
    # 最多兩個字元（本體 + variation selector），中文詞一般更長。
    first=${NAME%% *}
    if [ "$first" != "$NAME" ] && [ ${#first} -le 2 ]; then
      NAME="🔍 ${NAME#* }"
    else
      NAME="🔍 $NAME"
    fi
    ;;
esac

# Project prefix: keeps the owning project visible in the tab title while the AI is
# running, when the shell prompt (which also shows it) is hidden behind the TUI. Derived
# from the working directory, so it works in any terminal. The git repo root wins over a
# nested cwd; $HOME and / are not projects and get no tag, since "[yourname]" is noise.
project_tag() {
  dir="${CLAUDE_PROJECT_DIR:-$PWD}"
  root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)
  [ -n "$root" ] && dir="$root"
  case "$dir" in
    "$HOME" | / | "") return ;;
  esac
  basename "$dir"
}

case "$NAME" in
  \[*) ;;
  *)
    TAG=$(project_tag)
    [ -n "$TAG" ] && NAME="[$TAG] $NAME"
    ;;
esac

# ------------------------------------------------------------------- statusline surface

mkdir -p "$NAME_DIR"
echo "$NAME" > "$NAME_DIR/${TERMINAL_PID}.txt"

# Drop name files whose process is gone — otherwise every closed terminal leaves one behind
# and the directory grows without bound. Background sessions key off the `claude
# bg-pty-host` pid, which their own statusline also walks up to, so those files are live:
# only liveness decides, never pid shape.
for f in "$NAME_DIR"/*.txt; do
  [ -e "$f" ] || continue
  pid=$(basename "$f" .txt)
  case "$pid" in
    '' | *[!0-9]*) continue ;;
  esac
  kill -0 "$pid" 2>/dev/null || rm -f "$f"
done

# -------------------------------------------------------------------------- tab surface
#
# Three ways to find the tab, in order of trust:
#
# 1. $AI_TAB_SYNC_FILE — set by the myclaude wrapper, but inherited, so a session that was
#    backgrounded and came back can hold one from an ancestor that exited long ago. The
#    name then lands in a file nobody polls, silently. Honoured only if a watcher is really
#    on it, and skipped entirely for background sessions, which inherit it from the daemon
#    and would write to a stranger's tab.
# 2. The watcher whose parent is this session's terminal — the process table, not the env.
# 3. A background session has no terminal at all: its tty is "??" and no watcher has it as
#    an ancestor. The displaying terminal cannot be read back either, because the viewing
#    client connects over a unix socket and macOS lsof does not report the client side. So
#    the link is recorded on the way in: every naming write from a session that owns a
#    terminal drops a session-id -> sync-file breadcrumb, and a fork follows its parent's
#    id to it.
#
# Accepted consequence: a background session and the interactive session that spawned it
# share one tab, so the last one named wins the title.
# Known gap: the parent id is only visible in `--resume .../<uuid>.jsonl` in the fork's own
# argv, and the daemon sometimes claims a pre-warmed `claude bg-spare` process whose argv
# names nobody — those forks find no breadcrumb and leave the tab alone.
breadcrumb_sync_file() {
  parent=$(ps -o args= -p "$CLAUDE_PID" 2>/dev/null |
    sed -n 's|.*--resume [^ ]*/\([0-9a-f-]*\)\.jsonl.*|\1|p')
  [ -n "$parent" ] && [ -f "$BREADCRUMB_DIR/$parent" ] || return
  file=$(head -1 "$BREADCRUMB_DIR/$parent")
  watcher_alive "$file" && echo "$file"
}

live_sync_file() {
  if [ -z "$JOB_ID" ] && watcher_alive "${AI_TAB_SYNC_FILE:-}"; then
    echo "$AI_TAB_SYNC_FILE"
    return
  fi
  for w in $(pgrep -f 'ai-tab-sync.sh' 2>/dev/null); do
    if [ "$(ps -o ppid= -p "$w" 2>/dev/null | tr -d ' ')" = "$TERMINAL_PID" ]; then
      # watcher argv is: bash .../ai-tab-sync.sh <sync-file> <tty>
      ps -o args= -p "$w" 2>/dev/null | awk '{print $3}'
      return
    fi
  done
  breadcrumb_sync_file
}

SYNC_FILE=$(live_sync_file)

if [ -n "$SYNC_FILE" ]; then
  echo "$NAME" > "$SYNC_FILE"

  # Record which tab this session belongs to, so a fork of it can find the same tab later.
  # Written for background sessions too, so a session backgrounded twice hands the tab down
  # the chain. Breadcrumbs whose watcher is gone are dropped — same unbounded growth the
  # name files had.
  if [ -n "$SESSION_ID" ]; then
    mkdir -p "$BREADCRUMB_DIR"
    echo "$SYNC_FILE" > "$BREADCRUMB_DIR/$SESSION_ID"
    for c in "$BREADCRUMB_DIR"/*; do
      [ -e "$c" ] || continue
      watcher_alive "$(head -1 "$c")" || rm -f "$c"
    done
  fi
else
  # No watcher: write the OSC title straight to the controlling tty. Claude Code strips ESC
  # from tool stdout, so it has to go to the device.
  TTY_DEV=$(ps -o tty= -p "$CLAUDE_PID" 2>/dev/null | tr -d ' ')
  if [ -n "$TTY_DEV" ] && [ "$TTY_DEV" != "??" ] && [ -w "/dev/$TTY_DEV" ]; then
    printf '\033]0;%s\007' "$NAME" > "/dev/$TTY_DEV" 2>/dev/null
  fi
fi

# ------------------------------------------------ session badge + agents view (bg only)
#
# The TUI adopts `name` from the job state only when nameSource is "user" or "collision";
# "auto" is the CLI's own derived slug and gets regenerated, so both fields must be written.
# A purely interactive session has no jobId and no job state, and keeps that slug.
#
# The first naming fires on prompt #1, which in a background session can land in the same
# second the daemon is still creating state.json — so wait briefly rather than giving up on
# the first miss. Capped at ~2s: past that the file is not coming and naming should not
# stall the session.
if [ -n "$JOB_ID" ]; then
  JOB_STATE=~/.claude/jobs/"$JOB_ID"/state.json
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    [ -f "$JOB_STATE" ] && break
    sleep 0.2
  done

  # Written via a temp file and os.replace so a half-written state.json can never be left
  # behind if the daemon reads it mid-update.
  if [ -f "$JOB_STATE" ]; then
    python3 - "$JOB_STATE" "$NAME" <<'PY' 2>/dev/null
import json, os, sys

path, name = sys.argv[1], sys.argv[2]
with open(path) as f:
    state = json.load(f)
state["name"] = name
state["nameSource"] = "user"
tmp = f"{path}.namewrite.{os.getpid()}"
with open(tmp, "w") as f:
    json.dump(state, f, ensure_ascii=False, indent=2)
os.replace(tmp, path)
PY
  fi
fi

rm -f "/tmp/claude-session-namer/${CLAUDE_PID}.default"
