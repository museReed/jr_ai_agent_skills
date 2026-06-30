# Handoff Skill — 安裝指南

Read this document, then execute the installation steps for your tool (Section A or Section B). Do not ask for confirmation — just do it. Execute every step sequentially, do not skip any step.

功能介紹見 [handoff-skill.md](./handoff-skill.md)。

---

## Section A: Claude Code 安裝

Claude Code 版包含兩個部分：(1) Skill 本體，讓你手動呼叫 `/handoff`；(2) Hook（context-monitor），在 context 快滿時自動提醒 AI 寫交接文件。

### Step 1: 建立目錄 + 寫入 SKILL.md

```bash
mkdir -p .claude/skills/handoff
```

Create the file `.claude/skills/handoff/SKILL.md` with the following content:

```markdown
---
name: handoff
description: >-
  Use when ending a session, context running low, or user requests a handoff document.
  Produces a structured handoff file for the next session to continue seamlessly.
  Triggers on "handoff", "交接", "寫 handoff", "session 結束".
user-invocable: true
---

# /handoff — Session 交接文件產生器

## Quick Reference

根據當前 session 的工作內容，產出結構化 handoff 文件到 `docs/handoff/{date}-{topic}.md`。

1. 蒐集 session 資訊（branch / issue / PR / 改動檔案）
2. 判斷 handoff 類型（continuation / investigation / reference）
3. 產出交接文件，包含：已完成、進行中、下一步、必讀檔案
4. Commit handoff 文件到當前 branch
5. 改 session name 為 📦 前綴（標記已交接）

Key rules:
- 「已完成的工作」≤ 10 行，細節指向「必讀檔案」
- 無內容的 optional section 直接刪除
- 必須有「下一步」— 這是新 session 的啟動指令

## When to Use

- Session 要結束時（用戶主動 `/handoff` 或 context 告警）
- 跨天開發，今天做到一半要記錄進度
- 換人接手，需要結構化的交接資訊

## When NOT to Use

- 很短的一次性對話
- 所有工作在單次 session 完成
- 純閒聊

## Execution Flow

### Step 1: 蒐集 Session 資訊

自動執行，不需用戶提供：

git branch --show-current
git status -s
git log --oneline -20
gh pr list --state open --head "$(git branch --show-current)" --json number,title

### Step 2: 判斷 Handoff 類型

| 信號 | → Type |
|---|---|
| 有未完成的 checklist / 進行中的 step | continuation |
| Session 主要在調查、盤點、分析 | investigation |
| Session 主要在配置、設定、一次性建置 | reference |

不確定時問用戶。

### Step 3: 產出 Handoff 文件

檔名：`docs/handoff/{YYYY-MM-DD}-{topic}.md`（topic 英文 kebab-case，≤ 40 chars）

文件結構：
- **狀態摘要**：做了什麼（≤ 10 行）
- **必讀檔案**：每項附一句話說明為什麼要讀
- **下一步**：具體動作，新 session 可直接執行
- **已知問題**：如果有的話

路徑規則：
- 檔案路徑一律用 repo-relative（`docs/handoff/...`），禁止帶 `.worktrees/` 前綴
- 若檔案只存在於特定 branch，標注 `(branch: {name})`

✅ DO: 用具體的 PR 號碼、檔案路徑、指令
❌ DON'T: 寫模糊的「繼續之前的工作」

### Step 4: Commit

git add docs/handoff/{file}
git commit -m "docs: add session handoff — {topic}"

Commit 到當前 branch，不要切回 develop。

### Step 5: 改 Session Name + 回報

改名為 `📦 {topic}`（topic 轉中文敘述，≤ 30 字元）：

TERMINAL_PID=$(ps -o ppid= -p $PPID 2>/dev/null | tr -d ' ')
mkdir -p ~/.claude/session-names
echo '📦 {topic}' > ~/.claude/session-names/${TERMINAL_PID}.txt
printf '\033]0;📦 {topic}\007'

回報格式：
Handoff 已產出：docs/handoff/{file}
Branch: {current_branch}
{接續指引——依新 session 情境選一句}

## Common Mistakes

| Mistake | Why it fails | Fix |
|---------|-------------|-----|
| 已完成的工作寫成長篇報告 | 新 session 花大量 context 讀 | ≤ 10 行，detail 指向必讀檔案 |
| 缺「下一步」 | 新 session 不知道做什麼 | 必填，寫具體動作 |
| 必讀檔案只列路徑 | 新 session 不知道為什麼要讀 | 每項附原因 |
| 忘記改 terminal name | 無法辨識哪個 session 已交接 | Step 5 必做，📦 前綴 |
| 路徑帶 .worktrees/ 前綴 | 新 session 不在同一個 worktree 就 404 | 一律 repo-relative |
```

### Step 2: 安裝 Context Monitor Hook

這個 hook 在 context 用量超過 70% 時自動提醒 AI 寫交接文件。

#### 2a: 建立 hook 腳本

```bash
mkdir -p ~/.claude/hooks
```

Create the file `~/.claude/hooks/context-monitor.sh` with the following content:

```bash
#!/bin/bash
# Context Monitor Hook — reads session JSONL to get real token usage
# Triggered on PostToolUse to warn when context exceeds threshold

CLAUDE_PROJECTS_DIR="${HOME}/.claude/projects"
THRESHOLD=140000  # 70% of 200k context window
MAX_CONTEXT=200000

# Map CWD to Claude's project directory format: /a/b/c → -a-b-c
PROJECT_KEY=$(echo "${CWD:-$PWD}" | tr '/' '-')
PROJECT_DIR="${CLAUDE_PROJECTS_DIR}/${PROJECT_KEY}"

[ -d "$PROJECT_DIR" ] || exit 0

# Find most recently modified .jsonl (current session)
JSONL=$(find "$PROJECT_DIR" -maxdepth 1 -name "*.jsonl" -newer /tmp/.claude-context-monitor-start 2>/dev/null | head -1)
if [ -z "$JSONL" ]; then
  JSONL=$(ls -t "$PROJECT_DIR"/*.jsonl 2>/dev/null | head -1)
fi

[ -z "$JSONL" ] && exit 0

# Read last 30 lines for performance
TOTAL=$(tail -30 "$JSONL" | python3 -c "
import json, sys
best = 0
for line in sys.stdin:
    try:
        d = json.loads(line)
        if d.get('type') == 'assistant':
            u = d.get('message', {}).get('usage', {})
            t = u.get('input_tokens', 0) + u.get('cache_creation_input_tokens', 0) + u.get('cache_read_input_tokens', 0)
            if t > best:
                best = t
    except (json.JSONDecodeError, KeyError):
        pass
print(best)
" 2>/dev/null)

[ -z "$TOTAL" ] && exit 0
[ "$TOTAL" -eq 0 ] 2>/dev/null && exit 0

PCT=$((TOTAL * 100 / MAX_CONTEXT))

if [ "$TOTAL" -gt "$THRESHOLD" ]; then
  MSG="⚠️ Context 已用 ~${TOTAL} tokens (${PCT}%)。請立即：(1) 寫 docs/handoff/$(date +%F)-{topic}.md (2) 提示用戶開新 session 繼續工作。"
  printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}' "$MSG"
fi
```

#### 2b: 設定執行權限

```bash
chmod +x ~/.claude/hooks/context-monitor.sh
```

#### 2c: 註冊 Hook 到 settings.json

**操作方式**：Read `~/.claude/settings.json`。根據檔案現有狀態，選擇下面對應的做法：

**情況 A — 檔案不存在**：Create `~/.claude/settings.json` with this content:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "touch /tmp/.claude-context-monitor-start",
            "timeout": 2
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/context-monitor.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

**情況 B — 檔案存在但沒有 `hooks` key**：在 JSON 頂層加入整個 `"hooks"` object（同情況 A 的 hooks 部分）。

**情況 C — 檔案存在且已有 `hooks`**：需要加入兩個 hook entry：

1. **SessionStart hook**（context monitor 的 session 起點標記）：
   - 如果 `hooks.SessionStart` 不存在 → 加入整個 `"SessionStart"` key（同情況 A）
   - 如果已存在 → 在 `hooks.SessionStart[0].hooks` array 末尾 append：
     ```json
     { "type": "command", "command": "touch /tmp/.claude-context-monitor-start", "timeout": 2 }
     ```
   - **衝突檢查**：如果 command 中已包含 `claude-context-monitor-start`，跳過

2. **PostToolUse hook**（context monitor 本體）：
   - 如果 `hooks.PostToolUse` 不存在 → 加入整個 `"PostToolUse"` key（同情況 A）
   - 如果已存在 → 在 `hooks.PostToolUse[0].hooks` array 末尾 append：
     ```json
     { "type": "command", "command": "bash ~/.claude/hooks/context-monitor.sh", "timeout": 5 }
     ```
   - **衝突檢查**：如果 command 中已包含 `context-monitor.sh`，跳過

### Step 3: 驗證

執行以下檢查，確認安裝成功：

```bash
head -5 .claude/skills/handoff/SKILL.md
```

預期：輸出以 `---` 開頭，含 `name: handoff`。

```bash
test -x ~/.claude/hooks/context-monitor.sh && echo "Hook OK" || echo "Hook MISSING"
```

預期：輸出 `Hook OK`。

```bash
python3 -c "import json; d=json.load(open('$HOME/.claude/settings.json')); hooks=[h['command'] for g in d.get('hooks',{}).get('PostToolUse',[]) for h in g.get('hooks',[])]; print('Hook registered' if any('context-monitor' in c for c in hooks) else 'Hook NOT registered')"
```

預期：輸出 `Hook registered`。

### Done

回報：「handoff skill 已安裝。包含 SKILL.md + context-monitor hook。觸發方式：手動 `/handoff`，或 context 用量 > 70% 時 hook 自動提醒。」

---

## Section B: Codex CLI 安裝

> **與 Claude Code 版的差異**：Codex 沒有 context-monitor hook，只能手動呼叫。
> Session 封存改名走 SQLite 路徑。

### Step 1: 建立目錄 + 寫入 SKILL.md

```bash
mkdir -p .codex/skills/handoff
mkdir -p .codex/skills/_shared
```

Create the file `.codex/skills/handoff/SKILL.md` with the following content:

```markdown
---
name: handoff
description: >-
  Use when ending a session, context running low, or user requests a handoff document.
  Produces a structured handoff file for the next session to continue seamlessly.
  Triggers on "handoff", "交接", "寫 handoff", "session 結束".
---

# /handoff — Session 交接文件產生器（Codex-Compatible）

## Quick Reference

根據當前 session 的工作內容，產出結構化 handoff 文件到 `docs/handoff/{date}-{topic}.md`。

1. 蒐集 session 資訊（branch / issue / PR / 改動檔案）
2. 判斷 handoff 類型（continuation / investigation / reference）
3. 產出交接文件，包含：已完成、進行中、下一步、必讀檔案
4. Commit handoff 文件到當前 branch
5. 改 terminal name 為 `📦 {topic}` 標記已交接

Key rules:
- 「已完成的工作」≤ 10 行，細節指向「必讀檔案」
- 無內容的 optional section 直接刪除
- 必須有「下一步」— 這是新 session 的啟動指令

## When to Use

- Session 要結束時
- 跨天開發，今天做到一半要記錄進度
- 換人接手

## When NOT to Use

- 很短的一次性對話
- 所有工作在單次 session 完成

## Execution Flow

### Step 1: 蒐集 Session 資訊

自動執行：

git branch --show-current
git status -s
git log --oneline -20

### Step 2: 判斷 Handoff 類型

| 信號 | → Type |
|---|---|
| 有未完成的 checklist | continuation |
| Session 主要在調查 | investigation |
| Session 主要在配置 | reference |

### Step 3: 產出 Handoff 文件

檔名：`docs/handoff/{YYYY-MM-DD}-{topic}.md`

✅ DO: 用具體的檔案路徑、指令
❌ DON'T: 寫模糊的「繼續之前的工作」

### Step 4: Commit

git add docs/handoff/{file}
git commit -m "docs: add session handoff — {topic}"

### Step 5: Terminal 改名 + 回報

改名方法 → Read `.codex/skills/_shared/codex-session-rename.md`

名稱格式：`📦 {topic}`（topic 轉中文敘述，≤ 30 字元）。

回報格式：
Handoff 已產出：docs/handoff/{file}
Branch: {current_branch}

## Common Mistakes

| Mistake | Why it fails | Fix |
|---------|-------------|-----|
| 已完成的工作寫成長篇報告 | 新 session 花大量 context 讀 | ≤ 10 行 |
| 缺「下一步」 | 新 session 不知道做什麼 | 必填 |
| 必讀檔案只列路徑 | 不知道為什麼要讀 | 附原因 |
| 忘記改 terminal name | 無法辨識已交接 | Step 5 必做 |
| 用 ORDER BY 找 session | 多 session 改錯 | 用 $CODEX_THREAD_ID |
```

### Step 2: 建立共用參考文件

Create the file `.codex/skills/_shared/codex-session-rename.md` with the following content:

```markdown
# Codex Session Rename — 共用參考文件

> 任何需要手動改 Codex session 名稱的 skill，引用此文件取得方法。
> 不要各自重寫 — 改版時只改這一份。

---

## 原理

Codex 把 session 資料存在 SQLite（`~/.codex/state_*.sqlite`），每個 session 是 `threads` 表的一筆 row。
`/title` 指令背後就是 UPDATE `threads.title` — 我們直接用 `sqlite3` 做一樣的事。

## 改名指令

# 1. 取得 Codex thread ID
SESSION_ID="${CODEX_THREAD_ID}"

# 2. 找到 SQLite DB（支援版號變更）
CODEX_DB=$(ls -t ~/.codex/state_*.sqlite 2>/dev/null | head -1)

# 3. 先確認 target row 是這次對話
sqlite3 -header -column "$CODEX_DB" \
  "SELECT id, title, first_user_message FROM threads WHERE id='${SESSION_ID}';"

# 4. 改名
sqlite3 "$CODEX_DB" "UPDATE threads SET title='新名稱', preview='新名稱' WHERE id='${SESSION_ID}';"

## 注意事項

| 項目 | 說明 |
|---|---|
| **Session 定位** | 用 `$CODEX_THREAD_ID` 環境變數定位，不用 `ORDER BY updated_at_ms DESC LIMIT 1` |
| **SQLite locking** | 短暫 UPDATE 不會跟 Codex 衝突 |
| **版號變更** | DB 檔名可能從 `state_5.sqlite` 變成 `state_6`，用 `ls -t state_*.sqlite | head -1` 適配 |
| **單引號轉義** | 名稱含 `'` 時用 `''` 跳脫 |
| **preview 欄位** | 必須跟 title 一起改，否則 sidebar 顯示舊文字 |
| **Claude Code 環境** | 偵測 `$HOME/.claude/session-names` 存在 → 走 Claude Code 路徑（寫檔），不走 SQLite |
```

### Step 3: 驗證

```bash
head -5 .codex/skills/handoff/SKILL.md
```

預期：輸出以 `---` 開頭，含 `name: handoff`。

```bash
head -3 .codex/skills/_shared/codex-session-rename.md
```

預期：輸出 `# Codex Session Rename`。

### Done

回報：「handoff skill 已安裝。Codex 無自動觸發 hook，手動輸入 `$handoff` 使用。」

---

## 驗證

安裝完成後，用以下測試確認 skill 正常運作。每個 test 執行後，對照「預期」確認行為正確。

### Test 1: 手動觸發

> 輸入 `/handoff`（Claude Code）或 `$handoff`（Codex），在一個已經做了一些工作的 session 中。
>
> **預期**：AI 自動蒐集 git 資訊，產出 `docs/handoff/{date}-{topic}.md`，commit 到當前 branch，並改 terminal name 為 `📦 {topic}`。

### Test 2: 自動觸發（僅 Claude Code）

> 在一個 context 用量接近 70% 的長 session 中，繼續使用 tool。
>
> **預期**：context-monitor hook 輸出 `⚠️ Context 已用` 警告，AI 收到後主動開始寫交接文件。

### Test 3: 不該觸發的情況

> 對 AI 說：「幫我把這個函數的參數交接給另一個函數」
>
> **預期**：AI 執行程式碼修改，不觸發 handoff skill。「交接」在程式碼脈絡中不應觸發。

### Test 4: 交接文件品質

> 在一個做了多件事的 session 中觸發 `/handoff`。
>
> **預期**：
> - 「已完成」≤ 10 行
> - 有「下一步」section，內容是具體可執行的動作
> - 「必讀檔案」每項有說明
> - 路徑全部是 repo-relative（不含 `.worktrees/`）

### Test 5: 封存改名

> 觸發 `/handoff` 後，檢查 terminal tab / sidebar 名稱。
>
> **預期**：
> - Claude Code：terminal tab 變成 `📦 {中文 topic}`
> - Codex：sidebar 顯示 `📦 {中文 topic}`（需用 `mycodex` 啟動才會即時同步 tab）

### Test 6: 新 Session 接續

> 開一個新 session，讀取剛剛產出的 handoff 文件。
>
> **預期**：新 session 能直接從「下一步」開始工作，不需要額外解釋背景。

### 驗證結果判讀

| 結果 | 處理方式 |
|---|---|
| 全部 test 通過 | 安裝成功 |
| Test 1 沒觸發 | 檢查 SKILL.md 的 `description` 是否包含 trigger keywords（handoff、交接） |
| Test 2 hook 沒觸發 | 檢查 `~/.claude/settings.json` 的 hook 註冊和腳本權限 |
| Test 3 誤觸發 | 在 SKILL.md 的 When NOT to Use 加上「程式碼層面的參數傳遞」 |
| Test 4 品質不達標 | 檢查 SKILL.md 的 Step 3 是否有 ≤ 10 行和必讀檔案規則 |
| Test 5 名稱沒改 | Claude Code：檢查 Step 5 的 PID 取法。Codex：確認用 mycodex 啟動 |
| Test 6 新 session 卡住 | 檢查交接文件的「下一步」是否夠具體 |
