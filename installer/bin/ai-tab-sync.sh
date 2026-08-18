#!/usr/bin/env bash
# ai-tab-sync.sh — universal terminal tab title syncer.
# Polls a sync file and writes OSC title escapes directly to the tty device,
# bypassing IDE stdout filtering (works in iTerm2 / Cursor / Antigravity).
# Usage: ai-tab-sync.sh <sync-file> <tty-path>
#
# Re-assertion: the title is rewritten periodically even when the sync file has not
# changed. Writing only on change meant any external OSC write won permanently —
# observed when a session went to the background and came back: the tab title
# reverted to the CLI's own derived slug while the sync file still held the real
# name, and the watcher never wrote again. Owning the tab means re-claiming it,
# not claiming it once.

set -euo pipefail

SYNC_FILE="${1:?usage: ai-tab-sync.sh <sync-file> <tty-path>}"
TTY_PATH="${2:?usage: ai-tab-sync.sh <sync-file> <tty-path>}"

REASSERT_EVERY=5   # polls (~5s) between rewrites of an unchanged title

write_title() {
  printf '\033]0;%s\007' "$1" > "$TTY_PATH" 2>/dev/null || true
  printf '\033]1;%s\007' "$1" > "$TTY_PATH" 2>/dev/null || true
  printf '\033]2;%s\007' "$1" > "$TTY_PATH" 2>/dev/null || true
}

last_title=""
since=0

while true; do
  if [ -f "$SYNC_FILE" ]; then
    title=$(cat "$SYNC_FILE" 2>/dev/null || true)
    if [ -n "$title" ]; then
      if [ "$title" != "$last_title" ]; then
        write_title "$title"
        last_title="$title"
        since=0
      else
        since=$((since + 1))
        if [ "$since" -ge "$REASSERT_EVERY" ]; then
          write_title "$title"
          since=0
        fi
      fi
    fi
  fi
  sleep 1
done
