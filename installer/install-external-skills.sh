#!/usr/bin/env bash
# install-external-skills.sh — 裝「一條龍 demo」用到的官方第三方 skill，for Claude Code / Codex。
#
# 跟 install.sh 分開的原因：這些是第三方官方 skill，用它們 GitHub 定義的安裝法（npx skills /
# claude mcp），要「網路 + Node」，還會下載瀏覽器。install.sh 是 offline 自包含核心，不混進來。
#
# 用法: ./install-external-skills.sh [claude|codex|all]
#
# 依賴：Node ≥18 + npx（必需）、網路（必需）、python3（本地 live-preview demo 需要）、
#       claude CLI（註冊 Playwright MCP 需要）。
set -uo pipefail   # 刻意不加 -e：某一步失敗要能繼續、只警告，不整支中斷

TARGET="${1:-all}"
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"

info() { echo "  $*"; }
warn() { echo "  ⚠️  $*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

# --- 依賴 guard ---
have npx || { echo "❌ 需要 Node ≥18 + npx（frontend-design / skill-creator / playwright 都靠 npx skills 裝）。裝好 Node 再跑。"; exit 1; }
if ! curl -sSf -m 8 https://registry.npmjs.org >/dev/null 2>&1; then
  echo "❌ 連不到 npm registry——這支要網路。確認連線後重跑。"; exit 1
fi

SKILLS="npx --yes skills add"

# --- 1. frontend-design（Anthropic，agent 無關，一裝通吃兩邊）---
echo "[1] frontend-design（Anthropic）"
AGENTS=""
[ "$TARGET" != codex ]  && AGENTS="$AGENTS -a claude-code"
[ "$TARGET" != claude ] && AGENTS="$AGENTS -a codex"
# shellcheck disable=SC2086
$SKILLS anthropics/skills --skill frontend-design -g $AGENTS -y \
  && info "frontend-design 已裝: ${AGENTS}" || warn "frontend-design 安裝失敗"

# --- 2. skill-creator（Claude 用 npx；Codex 新版內建 $skill-creator，免裝）---
if [ "$TARGET" != codex ]; then
  echo "[2] skill-creator（Claude）"
  $SKILLS anthropics/skills --skill skill-creator -g -a claude-code -y \
    && info "skill-creator 已裝（Claude）" || warn "skill-creator 安裝失敗"
fi
[ "$TARGET" != claude ] && info "Codex 的 skill-creator 為內建（\$skill-creator），免安裝。"

# --- 3. Playwright（Codex 用 CLI skill；Claude 用 MCP，不是 skill）---
if [ "$TARGET" != claude ]; then
  echo "[3a] Codex playwright skill（CLI）"
  $SKILLS openai/skills --skill playwright -g -a codex -y \
    && info "codex playwright skill 已裝" || warn "codex playwright skill 安裝失敗"

  # npx skills 把 Codex 的 skill 放進 ~/.agents/skills（canonical）。部分 Codex 版本只掃
  # ~/.codex/skills，這裡補 symlink 保證看得到（jr 的其他 skill 也都在 ~/.codex/skills）。
  mkdir -p "$HOME/.codex/skills"
  for s in frontend-design playwright; do
    [ -d "$HOME/.agents/skills/$s" ] \
      && ln -sfn "$HOME/.agents/skills/$s" "$HOME/.codex/skills/$s" \
      && info "~/.codex/skills/$s → ~/.agents/skills/$s"
  done
fi
if [ "$TARGET" != codex ]; then
  echo "[3b] Claude Playwright MCP"
  if have claude; then
    # -s user：註冊到 user scope，換目錄開新 session 也吃得到（預設 local 只綁當前專案）
    claude mcp add -s user playwright npx @playwright/mcp@latest 2>/dev/null \
      && info "Playwright MCP 已註冊（user scope）" || warn "Playwright MCP 註冊失敗（可能已存在，忽略即可）"
  else
    warn "找不到 claude CLI，跳過 MCP 註冊。手動：claude mcp add -s user playwright npx @playwright/mcp@latest"
  fi
fi

# --- 4. 本地 live-preview demo 依賴（Python playwright + chromium）---
echo "[4] live-preview demo 依賴（Python + chromium，約幾百 MB）"
if have python3; then
  if python3 -c "import playwright" 2>/dev/null; then
    info "python playwright 已在（略過 pip）"
  else
    # 新版 Python（PEP 668 externally-managed）會擋 --user，退而用 --break-system-packages
    python3 -m pip install --user --quiet playwright 2>/dev/null \
      || python3 -m pip install --user --quiet --break-system-packages playwright 2>/dev/null \
      && info "python playwright 已裝" \
      || warn "pip install playwright 失敗——請手動：python3 -m pip install playwright（或用 venv/pipx）"
  fi
  python3 -m playwright install chromium 2>/dev/null && info "chromium 已就緒" || warn "chromium 下載失敗（demo 需要，需網路）"
else
  warn "找不到 python3 → 本地 live-preview demo 跑不了。裝 Python 3 後重跑本步驟。"
fi

# --- 收尾：提示開新 session + 貼 demo prompt ---
echo
echo "✅ 完成。接著做一條龍 demo："
echo "  1. 開一個【新的】terminal / session（skill 要新 session 才會載入）"
echo "  2. 把對應的 demo prompt 整份貼進去："
[ "$TARGET" != codex ]  && echo "     Claude Code → $SRC_DIR/demo-prompt-claude.md"
[ "$TARGET" != claude ] && echo "     Codex       → $SRC_DIR/demo-prompt-codex.md"
echo
echo "  （demo 的左打碼右預覽腳本在 $SRC_DIR/demo/live-preview/type_hl.py）"
