#!/usr/bin/env bash
# verify.sh — E2E self-check for the auto-rename + handoff install.
#
# Usage:
#   ./verify.sh            # run all automated checks + print guided manual steps
#   ./verify.sh claude     # Claude Code checks only
#   ./verify.sh codex      # Codex checks only
#   ./verify.sh --report   # also write verify-report-YYYYMMDD-HHMMSS.md
#                          # (attach it to a GitHub issue when something fails)
#
# Exit code: 0 = all automated checks pass, 1 = at least one FAIL.
set -u

TARGET="all"
REPORT=""
for arg in "$@"; do
  case "$arg" in
    claude|codex) TARGET="$arg" ;;
    --report) REPORT="verify-report-$(date +%Y%m%d-%H%M%S).md" ;;
  esac
done

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS=0; FAIL=0; WARN=0
LINES=()

say()  { echo "$1"; LINES+=("$1"); }
ok()   { say "  ✅ PASS  $1"; PASS=$((PASS+1)); }
bad()  { say "  ❌ FAIL  $1${2:+ — $2}"; FAIL=$((FAIL+1)); }
warn() { say "  ⚠️  WARN  $1${2:+ — $2}"; WARN=$((WARN+1)); }

check_file() { # label src dst
  if [ ! -f "$3" ]; then bad "$1" "檔案不存在：$3"
  elif ! diff -q "$2" "$3" >/dev/null 2>&1; then bad "$1" "與 repo 版本不同（可能是舊版或被改過）：$3"
  else ok "$1"; fi
}

check_exec() { [ -x "$1" ] && ok "可執行：${1/#$HOME/~}" || bad "可執行：${1/#$HOME/~}" "chmod +x 沒做"; }

check_registered() { # label config_file marker event
  python3 - "$2" "$3" "$4" <<'PYEOF'
import json, sys
path, marker, event = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    cfg = json.load(open(path))
except Exception as e:
    sys.exit(2)
for grp in cfg.get("hooks", {}).get(event, []):
    for h in grp.get("hooks", []):
        if marker in h.get("command", ""):
            sys.exit(0)
sys.exit(1)
PYEOF
  case $? in
    0) ok "$1" ;;
    2) bad "$1" "$2 不存在或不是合法 JSON" ;;
    *) bad "$1" "hooks.$4 裡找不到 $3" ;;
  esac
}

say "════════════════════════════════════════════"
say " 自動檢查（$(date '+%Y-%m-%d %H:%M')）"
say "════════════════════════════════════════════"

say ""
say "▍0. 依賴與環境"
command -v python3 >/dev/null && ok "python3" || bad "python3" "hooks 需要它解析 JSON"
command -v sqlite3 >/dev/null && ok "sqlite3" || warn "sqlite3" "Codex sidebar 改名需要它"
case "$(locale 2>/dev/null | grep -m1 LC_CTYPE)" in
  *UTF-8*|*utf8*) ok "locale UTF-8" ;;
  *) warn "locale UTF-8" "LANG/LC_CTYPE 非 UTF-8，中文 tab 名可能亂碼；在 ~/.zshrc 加 export LANG=en_US.UTF-8" ;;
esac

say ""
say "▍1. 顯示層（wrapper + watcher）"
check_file "ai-tab-sync.sh" "$SRC_DIR/bin/ai-tab-sync.sh" "$HOME/.local/bin/ai-tab-sync.sh"
check_exec "$HOME/.local/bin/ai-tab-sync.sh"
if [ "$TARGET" != "codex" ]; then
  check_file "myclaude" "$SRC_DIR/bin/myclaude" "$HOME/.local/bin/myclaude"
  grep -qs "alias claude=.*myclaude" "$HOME/.zshrc" "$HOME/.bashrc" 2>/dev/null \
    && ok "alias claude → myclaude" || warn "alias claude → myclaude" "沒設 alias，tab 同步不會生效；在 shell rc 加 alias claude='\$HOME/.local/bin/myclaude'"
fi
if [ "$TARGET" != "claude" ]; then
  check_file "mycodex" "$SRC_DIR/bin/mycodex" "$HOME/.local/bin/mycodex"
  grep -qs "alias codex=.*mycodex" "$HOME/.zshrc" "$HOME/.bashrc" 2>/dev/null \
    && ok "alias codex → mycodex" || warn "alias codex → mycodex" "沒設 alias，tab 同步不會生效"
fi

if [ "$TARGET" != "codex" ]; then
  say ""
  say "▍2. Claude Code"
  check_file "session-auto-namer.sh" "$SRC_DIR/hooks/session-auto-namer.sh" "$HOME/.claude/hooks/session-auto-namer.sh"
  check_file "context-monitor.sh" "$SRC_DIR/hooks/context-monitor.sh" "$HOME/.claude/hooks/context-monitor.sh"
  check_file "auto-rename SKILL" "$SRC_DIR/skills/claude/auto-rename/SKILL.md" "$HOME/.claude/skills/auto-rename/SKILL.md"
  check_file "handoff SKILL" "$SRC_DIR/skills/claude/handoff/SKILL.md" "$HOME/.claude/skills/handoff/SKILL.md"
  check_file "structured-questions SKILL" "$SRC_DIR/skills/claude/structured-questions/SKILL.md" "$HOME/.claude/skills/structured-questions/SKILL.md"
  check_registered "註冊 namer PostToolUse" "$HOME/.claude/settings.json" "session-auto-namer.sh" "PostToolUse"
  check_registered "註冊 namer UserPromptSubmit" "$HOME/.claude/settings.json" "session-auto-namer.sh" "UserPromptSubmit"
  check_registered "註冊 context-monitor" "$HOME/.claude/settings.json" "/context-monitor.sh" "PostToolUse"

  # hook 模擬：prompt#1 應吐出 UserPromptSubmit 命名請求
  SIM_OUT=$(echo '{}' | bash "$HOME/.claude/hooks/session-auto-namer.sh" prompt 2>/dev/null)
  echo "$SIM_OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['hookSpecificOutput']['hookEventName']=='UserPromptSubmit'" 2>/dev/null \
    && ok "namer 模擬：第一句話觸發命名請求" || bad "namer 模擬" "prompt 事件沒吐出合法命名請求 JSON"
  rm -f "/tmp/claude-session-namer/$$" "/tmp/claude-session-namer/$$.prompts" "/tmp/claude-session-namer/$$.default"

  # context-monitor 模擬：小視窗 + 假 transcript 應觸發警告
  TMPJ=$(mktemp)
  echo '{"type":"assistant","message":{"model":"claude-test","usage":{"input_tokens":25000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}' > "$TMPJ"
  SIM_OUT=$(echo "{\"transcript_path\":\"$TMPJ\"}" | CONTEXT_MONITOR_TEST_WINDOW=30000 bash "$HOME/.claude/hooks/context-monitor.sh" 2>/dev/null)
  echo "$SIM_OUT" | grep -q "Context 已用" && ok "context-monitor 模擬：門檻觸發" || bad "context-monitor 模擬" "測試視窗下沒觸發警告"
  rm -f "$TMPJ"
fi

if [ "$TARGET" != "claude" ]; then
  say ""
  say "▍3. Codex"
  check_file "codex-session-namer.sh" "$SRC_DIR/hooks/codex-session-namer.sh" "$HOME/.codex/hooks/codex-session-namer.sh"
  check_file "codex-context-monitor.sh" "$SRC_DIR/hooks/codex-context-monitor.sh" "$HOME/.codex/hooks/codex-context-monitor.sh"
  check_file "auto-rename SKILL" "$SRC_DIR/skills/codex/auto-rename/SKILL.md" "$HOME/.agents/skills/auto-rename/SKILL.md"
  check_file "handoff SKILL" "$SRC_DIR/skills/codex/handoff/SKILL.md" "$HOME/.agents/skills/handoff/SKILL.md"
  check_file "structured-questions SKILL" "$SRC_DIR/skills/codex/structured-questions/SKILL.md" "$HOME/.agents/skills/structured-questions/SKILL.md"
  diff -q "$SRC_DIR/skills/codex/_shared/codex-session-rename.md" "$HOME/.agents/skills/_shared/codex-session-rename.md" >/dev/null 2>&1 \
    && ok "_shared/codex-session-rename.md" || bad "_shared/codex-session-rename.md" "缺檔或內容過期"
  if [ -e "$HOME/.codex/skills/auto-rename" ] || [ -e "$HOME/.codex/skills/handoff" ] \
    || [ -e "$HOME/.codex/skills/structured-questions" ] || [ -e "$HOME/.codex/skills/_shared" ]; then
    bad "無 legacy Codex skill 目錄" "~/.codex/skills 仍有同名舊版，可能重複載入"
  else
    ok "無 legacy Codex skill 目錄"
  fi
  check_registered "註冊 namer PostToolUse" "$HOME/.codex/hooks.json" "codex-session-namer.sh" "PostToolUse"
  check_registered "註冊 namer UserPromptSubmit" "$HOME/.codex/hooks.json" "codex-session-namer.sh" "UserPromptSubmit"
  check_registered "註冊 context-monitor" "$HOME/.codex/hooks.json" "codex-context-monitor.sh" "PostToolUse"

  SIM_OUT=$(echo '{"session_id":""}' | bash "$HOME/.codex/hooks/codex-session-namer.sh" prompt 2>/dev/null)
  echo "$SIM_OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['hookSpecificOutput']['hookEventName']=='UserPromptSubmit'" 2>/dev/null \
    && ok "namer 模擬：第一句話觸發命名請求" || bad "namer 模擬" "prompt 事件沒吐出合法命名請求 JSON"
  rm -f "/tmp/codex-session-namer/$$" "/tmp/codex-session-namer/$$.prompts" "/tmp/codex-session-namer/$$.default"

  # context-monitor 模擬：使用當前 session 的 transcript_path 讀取 token_count
  TMPJ=$(mktemp)
  TMPMETA=$(mktemp)
  TMPOUT=$(mktemp)
  MONITOR_SESSION="verify-context-monitor"
  MONITOR_KEY=$(STATE_SOURCE="session:$MONITOR_SESSION" python3 -c 'import hashlib, os; print(hashlib.sha256(os.environ["STATE_SOURCE"].encode()).hexdigest()[:24])')
  MONITOR_PREFIX="/tmp/codex-context-monitor/$MONITOR_KEY"
  rm -f "$MONITOR_PREFIX.calls" "$MONITOR_PREFIX.handoff" "$MONITOR_PREFIX.token-read-failures"
  echo '{"payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":25000},"model_context_window":30000}}}' > "$TMPJ"
  printf '{"session_id":"%s","transcript_path":"%s"}\n' "$MONITOR_SESSION" "$TMPJ" > "$TMPMETA"
  bash "$HOME/.codex/hooks/codex-context-monitor.sh" < "$TMPMETA" > "$TMPOUT" 2>/dev/null
  SIM_OUT=$(cat "$TMPOUT")
  echo "$SIM_OUT" | grep -q "Context 已用" && ok "context-monitor 模擬：當前 session 門檻觸發" || bad "context-monitor 模擬" "當前 transcript 的 token_count 沒觸發警告"
  rm -f "$TMPJ" "$TMPMETA" "$TMPOUT"
  rm -f "$MONITOR_PREFIX.calls" "$MONITOR_PREFIX.handoff" "$MONITOR_PREFIX.token-read-failures"

  # fallback 模擬：計數與讀取失敗次數必須按 session_id 隔離
  FALLBACK_SESSION="verify-context-fallback-a"
  FALLBACK_KEY=$(STATE_SOURCE="session:$FALLBACK_SESSION" python3 -c 'import hashlib, os; print(hashlib.sha256(os.environ["STATE_SOURCE"].encode()).hexdigest()[:24])')
  FALLBACK_PREFIX="/tmp/codex-context-monitor/$FALLBACK_KEY"
  OTHER_SESSION="verify-context-fallback-b"
  OTHER_KEY=$(STATE_SOURCE="session:$OTHER_SESSION" python3 -c 'import hashlib, os; print(hashlib.sha256(os.environ["STATE_SOURCE"].encode()).hexdigest()[:24])')
  OTHER_PREFIX="/tmp/codex-context-monitor/$OTHER_KEY"
  rm -f "$FALLBACK_PREFIX.calls" "$FALLBACK_PREFIX.handoff" "$FALLBACK_PREFIX.token-read-failures"
  rm -f "$OTHER_PREFIX.calls" "$OTHER_PREFIX.handoff" "$OTHER_PREFIX.token-read-failures"
  echo 69 > "$FALLBACK_PREFIX.calls"
  echo 2 > "$FALLBACK_PREFIX.token-read-failures"
  SIM_OUT=$(printf '{"session_id":"%s"}\n' "$FALLBACK_SESSION" | bash "$HOME/.codex/hooks/codex-context-monitor.sh" 2>/dev/null)
  echo "$SIM_OUT" | grep -q "工具呼叫數估算：70/100" && ok "context-monitor fallback：同 session 累計" || bad "context-monitor fallback" "同 session 達門檻時沒有觸發"
  SIM_OUT=$(printf '{"session_id":"%s"}\n' "$OTHER_SESSION" | bash "$HOME/.codex/hooks/codex-context-monitor.sh" 2>/dev/null)
  OTHER_COUNT=$(cat "$OTHER_PREFIX.calls" 2>/dev/null || echo 0)
  [ -z "$SIM_OUT" ] && [ "$OTHER_COUNT" -eq 1 ] && ok "context-monitor fallback：跨 session 隔離" || bad "context-monitor fallback" "不同 session 沿用了既有計數"
  rm -f "$FALLBACK_PREFIX.calls" "$FALLBACK_PREFIX.handoff" "$FALLBACK_PREFIX.token-read-failures"
  rm -f "$OTHER_PREFIX.calls" "$OTHER_PREFIX.handoff" "$OTHER_PREFIX.token-read-failures"
fi

say ""
say "▍4. 編輯器 terminal 設定（VS Code 系才需要）"
FOUND_EDITOR=""
for APP in "Cursor" "Antigravity" "Code"; do
  SETTINGS="$HOME/Library/Application Support/$APP/User/settings.json"
  [ -f "$SETTINGS" ] || SETTINGS="$HOME/.config/$APP/User/settings.json"   # Linux
  [ -f "$SETTINGS" ] || continue
  FOUND_EDITOR=1
  if grep -qs '"terminal.integrated.tabs.title".*sequence' "$SETTINGS"; then
    ok "${APP}：tabs.title 含 \${sequence}"
  else
    warn "${APP}：tabs.title 未設 \${sequence}" "該編輯器的 terminal tab 不會顯示改名；在 settings.json 加 \"terminal.integrated.tabs.title\": \"\${sequence}\""
  fi
done
[ -z "$FOUND_EDITOR" ] && say "  （沒偵測到 VS Code 系編輯器，iTerm/Terminal.app 原生支援，跳過）"

say ""
say "════════════════════════════════════════════"
say " 結果：$PASS PASS / $FAIL FAIL / $WARN WARN"
say "════════════════════════════════════════════"
say ""
say "▍5. 人工 E2E 驗證（自動檢查全過後，引導用戶做這三步）"
say "  1. 開一個【新的】terminal（舊的還在舊環境，測了不算）"
say "  2. 跑 claude（或 codex），打一句有任務內容的話，例如「列出這個資料夾的檔案」"
say "  3. 預期：第一個回合內 terminal tab 變成「{emoji} 任務描述」"
say "     Codex 額外看：sidebar 的 session 名稱也應同步"
say "  沒變 → 跑 ./verify.sh --report，把報告開成 GitHub issue（見 TROUBLESHOOTING.md）"

if [ -n "$REPORT" ]; then
  {
    echo "# Install Verify Report"
    echo ""
    echo "- Date: $(date '+%Y-%m-%d %H:%M %Z')"
    echo "- OS: $(uname -srm)"
    echo "- Shell: $SHELL"
    echo "- TERM_PROGRAM: ${TERM_PROGRAM:-（空）}"
    echo "- locale: $(locale 2>/dev/null | grep -m1 LC_CTYPE || echo unknown)"
    echo "- claude: $(command -v claude >/dev/null && claude --version 2>/dev/null | head -1 || echo 未安裝)"
    echo "- codex: $(command -v codex >/dev/null && codex --version 2>/dev/null | head -1 || echo 未安裝)"
    echo "- installer commit: $(git -C "$SRC_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
    echo ""
    echo '```'
    printf '%s\n' "${LINES[@]}"
    echo '```'
  } > "$REPORT"
  echo ""
  echo "診斷報告已寫入：$REPORT"
  echo "回報方式：把整份檔案內容貼到 GitHub issue → https://github.com/museReed/jr_ai_agent_skills/issues/new?template=install-report.md"
fi

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "════════════════════════════════════════════"
  echo " ❌ 有 ${FAIL} 項 FAIL — AI agent 接下來必須做的兩件事（不要只回報失敗就結束）："
  echo "   1. Read $SRC_DIR/TROUBLESHOOTING.md，按症狀對照表排查；修好後重跑 ./install.sh 再 ./verify.sh"
  echo "   2. 修不掉 → 跑一個指令回報（自動收證據 + 開 issue，不用手工整理）："
  echo "      $SRC_DIR/diagnose.sh \"{一句話症狀}\""
  echo "════════════════════════════════════════════"
fi
[ "$FAIL" -eq 0 ]
