#!/usr/bin/env bash
# diagnose.sh — one-command failure reporting. Deterministic; no agent judgment needed
# beyond a one-line symptom description.
#
# Usage:
#   ./diagnose.sh "tab 不改名 @ Cursor"            # collect everything + file the issue
#   ./diagnose.sh --dry-run "任何症狀"              # collect + print, don't submit
#
# What it does, in order:
#   1. verify.sh --report            (29-point check + env snapshot)
#   2. scene evidence               (watcher / sync file / relay dir / sqlite / registrations)
#   3. compose the issue body       (matches .github/ISSUE_TEMPLATE/install-report.md)
#   4. submit: gh CLI if available+authed → creates the issue directly and prints its URL;
#      otherwise copies the body to the clipboard and opens the prefilled new-issue page —
#      the user only has to paste and press submit.
set -u

REPO_SLUG="museReed/jr_ai_agent_skills"
DRY=""
SYMPTOM=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY=1 ;;
    *) SYMPTOM="$arg" ;;
  esac
done
if [ -z "$SYMPTOM" ]; then
  echo "用法：./diagnose.sh \"一句話症狀\"（例：tab 不改名 @ Cursor）"
  exit 2
fi

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="${TMPDIR:-/tmp}/skill-diagnose-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT_DIR"
BODY="$OUT_DIR/issue-body.md"

echo "▍1/4 跑 verify.sh --report …"
( cd "$OUT_DIR" && bash "$SRC_DIR/verify.sh" --report >/dev/null 2>&1 )
REPORT=$(ls -t "$OUT_DIR"/verify-report-*.md 2>/dev/null | head -1)

echo "▍2/4 收集現場證據 …"
EVIDENCE="$OUT_DIR/evidence.txt"
{
  echo "## AI_TAB_SYNC_FILE"
  echo "value: ${AI_TAB_SYNC_FILE:-（空——本 shell 不在 wrapper session 裡，正常）}"
  [ -n "${AI_TAB_SYNC_FILE:-}" ] && echo "content: $(cat "$AI_TAB_SYNC_FILE" 2>/dev/null || echo 讀不到)"
  echo
  echo "## watcher processes"
  ps aux | grep -v grep | grep ai-tab-sync | head -5 || echo "（沒有 watcher 在跑）"
  echo
  echo "## sync files (~/.ai-session-names, 最新 5 個)"
  ls -lt "$HOME/.ai-session-names" 2>/dev/null | head -6 || echo "（目錄不存在）"
  echo
  echo "## codex relay dir (/tmp/codex-session-namer)"
  ls -lt /tmp/codex-session-namer 2>/dev/null | head -8 || echo "（目錄不存在）"
  echo
  echo "## codex sidebar titles (最新 3 筆)"
  DB=$(ls -t "$HOME"/.codex/state_*.sqlite 2>/dev/null | head -1)
  [ -n "$DB" ] && sqlite3 "$DB" "SELECT substr(id,1,8), title FROM threads ORDER BY updated_at_ms DESC LIMIT 3;" 2>/dev/null || echo "（無 DB 或無 sqlite3）"
  echo
  echo "## claude hook registrations"
  python3 -c "
import json, os
try:
    cfg = json.load(open(os.path.expanduser('~/.claude/settings.json')))
    for evt, groups in cfg.get('hooks', {}).items():
        for g in groups:
            for h in g.get('hooks', []):
                c = h.get('command', '')
                if 'namer' in c or 'monitor' in c: print(evt, '→', c)
except Exception as e: print('讀取失敗:', e)"
  echo
  echo "## codex hook registrations"
  python3 -c "
import json, os
try:
    cfg = json.load(open(os.path.expanduser('~/.codex/hooks.json')))
    for evt, groups in cfg.get('hooks', {}).items():
        for g in groups:
            for h in g.get('hooks', []):
                c = h.get('command', '')
                if 'namer' in c or 'monitor' in c: print(evt, '→', c)
except Exception as e: print('讀取失敗:', e)"
} > "$EVIDENCE" 2>&1

echo "▍3/4 組 issue 內容 …"
{
  echo "## 症狀（一句話：預期 vs 實際）"
  echo
  echo "$SYMPTOM"
  echo
  echo "## verify.sh --report 輸出"
  echo
  echo '```'
  [ -n "$REPORT" ] && cat "$REPORT" || echo "（verify.sh --report 產出失敗）"
  echo '```'
  echo
  echo "## 現場證據"
  echo
  echo '```'
  cat "$EVIDENCE"
  echo '```'
  echo
  echo "## 環境補充"
  echo
  echo "- Terminal / 編輯器：TERM_PROGRAM=${TERM_PROGRAM:-unknown}"
  echo "- 提交方式：diagnose.sh 自動產出"
} > "$BODY"

TITLE="[install] $SYMPTOM"
echo "▍4/4 提交 …"
if [ -n "$DRY" ]; then
  echo "--dry-run：不提交。issue 內容在 $BODY"
  exit 0
fi

if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  URL=$(gh issue create -R "$REPO_SLUG" --title "$TITLE" --body-file "$BODY" 2>/dev/null)
  if [ -n "$URL" ]; then
    echo "✅ issue 已開：$URL"
    exit 0
  fi
  echo "（gh 建立失敗，改走瀏覽器路徑）"
fi

# 無 gh：內容進剪貼簿 + 開預填標題的 new-issue 頁，用戶貼上送出即可
if command -v pbcopy >/dev/null 2>&1; then cat "$BODY" | pbcopy; COPIED=1
elif command -v xclip >/dev/null 2>&1; then cat "$BODY" | xclip -selection clipboard; COPIED=1
else COPIED=""; fi

ENC_TITLE=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$TITLE")
NEW_URL="https://github.com/$REPO_SLUG/issues/new?labels=install-report&title=$ENC_TITLE"
if command -v open >/dev/null 2>&1; then open "$NEW_URL"; elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$NEW_URL"; fi
echo "已開啟 new-issue 頁：$NEW_URL"
[ -n "$COPIED" ] && echo "✅ issue 內容已複製到剪貼簿——在內文欄貼上（Cmd+V）後送出" \
                 || echo "把這個檔案的內容貼進 issue 內文：$BODY"
