# Auto-Rename — Cursor Tab 改名失效診斷

> 適用情境:在 Cursor / VS Code 的 integrated terminal 跑 Claude Code,呼叫 `/auto-rename` 後 tab 名稱沒有改變,但同一份 skill 在另一台機器卻正常。
> 本文用來抓出「兩台機器之間的差異」,定位真正卡點。

---

## ✅ 結論與已驗證解法（2026-07-01）

**根因**:Claude Code **2.1.x 起會過濾工具 stdout 裡的 ESC byte**（`0x1b`）。skill 的 `printf` OSC 寫到 stdout → 被 Claude Code 捕捉成工具輸出 → 渲染時 ESC 被 strip → 到不了 terminal。這就是「路徑 B（stdout 間接傳遞）」在新版被切斷。

| 機器 | Claude Code | 路徑 B（stdout OSC） | 結果 |
|---|---|---|---|
| reed | 2.1.52 | 生效（渲染保留 ESC） | `/auto-rename` 直接可用 |
| 另一台 | 2.1.197 | **被切斷（渲染 strip ESC）** | 需改走 tty 直寫 |

**已驗證解法（版本無關，2.1.197 實測通過）**:繞過 stdout，**直寫控制終端裝置**，並關掉內建 title 覆寫。

1. **skill / hook 直寫 tty 裝置**（不是 stdout）:
   ```bash
   TTY_DEV=$(ps -o tty= -p $PPID 2>/dev/null | tr -d ' ')
   [ -w "/dev/$TTY_DEV" ] && printf '\033]0;{名稱}\007' > "/dev/$TTY_DEV"
   ```
   Bash 工具子程序雖 `tty → not a tty`，但父程序（Claude Code）的控制終端裝置 `/dev/ttysXXX` 由同一使用者擁有、可寫入，直寫即到 xterm.js。
2. **關掉 Claude Code 內建 title**:`~/.claude/settings.json` 設 `env.CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1`。否則內建 title 每輪 tool call 覆寫 → 症狀是「tab 閃一下又變回」。**改後需重開 Claude Code**（env 啟動時載入）。
3. **Cursor 設定**:`terminal.integrated.tabs.title: "${sequence}"`，且只對「存檔後新開」的 terminal 生效。

**hook 每輪刷新**:讓 `session-auto-namer.sh` 每次 tool call 讀 `session-names/${PID}.txt` 並直寫 tty 裝置 → 手動 `/auto-rename` 與自動命名都即時生效、且不被蓋。

**中文編碼**:經 tty 裝置直寫，**中文/emoji 顯示正常**（2.1.197 實測「🔧中文測試」正確）。先前手動在 fresh terminal `printf` 出現的亂碼（`測試`→`æ¸¬è©¦`）是該路徑的 locale 差異，非 tty 直寫路徑的問題。

**驗證**:關 DISABLE + 重開 Claude Code 後，做 ≥5 次 tool call 或打 `/auto-rename` → tab 穩定變成 emoji 中文名，不再彈回。實作見 [auto-rename-install.md](./auto-rename-install.md) 的「單一 AI 引導式安裝流程」與「機制細節」。

> 以下為原始排查過程與跨機器數據，保留供追溯。

---

## 背景:已知的三層機制

auto-rename skill 靠 OSC escape sequence（`\033]0;title\007`）改 terminal tab 名。OSC 有**兩條路徑**可以到達 terminal：

### 路徑 A：直寫 `/dev/tty`（直接路徑）

Bash 子程序直接開 `/dev/tty` 寫入 OSC bytes → terminal 收到 → tab 改名。
前提：Bash 工具有控制終端（`tty` 回傳 `/dev/ttysXXX`）。

### 路徑 B：stdout 間接傳遞（實測發現的路徑）

```
printf → stdout（pipe）→ Claude Code 捕捉為工具輸出
→ Claude Code 渲染到畫面（寫到真 TTY）→ terminal 的 xterm.js 處理 OSC → tab 改名
```

即使 `tty` 回 `not a tty`，`printf` 的 OSC bytes 仍然以 stdout 的形式被 Claude Code 捕捉。當 Claude Code 把工具輸出渲染到畫面時，raw bytes（含 ESC `0x1b`）寫進真正的 terminal，xterm.js 在 byte 層解析到 OSC sequence 就會改 tab。

**實測驗證**：在 Bash 工具跑 `printf '\033]0;TEST\007'`，工具輸出出現 `]0;TEST`（ESC byte 被 terminal 消費），tab 名確實改了。

### 三個條件（更新版）

| # | 條件 | 失效症狀 | 備註 |
|---|---|---|---|
| 1 | Cursor 設定 `terminal.integrated.tabs.title` 含 `${sequence}` | 預設模板會覆蓋 OSC 設的名稱 | 路徑 B 在 xterm.js raw byte 層生效，**可能不受此設定影響** |
| 2 | 設定生效的 terminal（只對「存檔後新開」的 terminal 生效） | 舊 terminal 仍用舊模板 | 同上 |
| 3 | OSC bytes 透過**任何路徑**送達 terminal | 若 Claude Code 渲染時 strip ESC byte → 兩條路都斷 | 路徑 B 是否生效取決於 Claude Code 版本的渲染行為 |

**關鍵發現**：原本認為 `tty` 回 `not a tty` = OSC 到不了 terminal（條件 3 不成立），但路徑 B 證明 stdout 間接傳遞**仍然有效**。`not a tty` 只代表路徑 A 不通，不代表路徑 B 也不通。

---

## 已驗證的事實

### 2026-07-01 — 失效機器（原始報告）

- `${sequence}` 設定正確：在「新開的」乾淨 terminal 手動 `printf '\033]0;X\007'` → tab 有變 → 條件 1 成立。
- 失效的 Claude Code tab 是「設定存檔前」開的 → 條件 2 不成立（舊 terminal 不吃 OSC）。
- Claude Code Bash 工具子程序 `tty` 回傳 `not a tty`，寫 `/dev/tty` 得到 `device not configured` → 路徑 A 不通。
- 額外發現：中文 / emoji 經 raw OSC 在此 Cursor 版本會變亂碼（「測試」→「æ¸¬è©¦」，UTF-8 被當 Latin-1 解碼）。Claude Code 內建 title 顯示中文則正常。

原始結論假設：路徑 A 不通 = tab 改不了。

### 2026-07-01 — reed 機器（路徑 B 驗證）

同一台機器上，`/auto-rename` 實際**成功**改了 tab 名。進一步診斷發現：

- `tty`（Bash 工具）→ `not a tty`（路徑 A 不通，與失效機器相同）
- Cursor `${sequence}` → **未設定**（條件 1 也不成立）
- 但在 Bash 工具跑 `printf '\033]0;OSC-TEST\007'` → 工具輸出出現 `]0;OSC-TEST`（ESC byte 被 terminal 消費），**tab 名確實改了**

**修正結論**：路徑 B（stdout 間接傳遞）在這台機器生效。`not a tty` 不等於 OSC 到不了 terminal。失效機器的真正卡點需要重新判定——可能是：
1. Claude Code 版本差異導致渲染時 strip ESC byte（路徑 B 被阻斷）
2. 條件 2（舊 terminal 不吃 OSC）才是真正主因
3. 中文亂碼問題導致 OSC 解析失敗（UTF-8 title 被當 Latin-1 → 整個 OSC sequence 損壞）

---

## 診斷步驟

### A. 在「Claude Code session 裡」執行(兩台都跑)

直接叫 Claude Code 執行,或自己用 `!` 前綴跑。重點是要跑在 **Bash 工具的同一個 context**:

```bash
echo "=== version ===";            claude --version 2>/dev/null
echo "=== Bash 工具有無控制終端 ==="; tty
echo "=== 父程序 tty ===";          ps -o tty= -p $PPID | tr -d ' '
echo "=== 內建 title 是否被關 ===";  echo "DISABLE=${CLAUDE_CODE_DISABLE_TERMINAL_TITLE:-(未設)}"
echo "=== claude 是否 wrapper ===";  type claude 2>/dev/null; alias claude 2>/dev/null
echo "=== TERM_PROGRAM ===";        echo "$TERM_PROGRAM / $TERM_PROGRAM_VERSION"
```

### B. 在「普通 shell」執行(非 Claude session,兩台都跑)

```bash
grep -iE 'tabs.title|sequence|terminal' \
  "$HOME/Library/Application Support/Cursor/User/settings.json"
```

---

## 判讀表

| 檢查項 | 失效機器 | 正常機器（reed） | 意義 |
|---|---|---|---|
| `tty`（Bash 工具） | `not a tty` | `not a tty` | 兩台都一樣 → **路徑 A 都不通，不是分歧點** |
| `printf` OSC 間接傳遞 | 未測 | tab 有改 → 路徑 B 生效 | **失效機器需補測此項** |
| `${sequence}` 設定 | 已設 | 未設定 | 正常機器沒設也能改 → **此設定不影響路徑 B** |
| Claude Code 版本 | （記錄） | 2.1.52 | 版本差異可能影響渲染是否保留 ESC byte |
| `claude` 是否 wrapper | 直接二進位 | 直接二進位 + alias | 兩台都不是 wrapper |
| `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` | 未設 | 未設 | 兩台一樣 |

### 新增診斷項：路徑 B 測試

在失效機器的 Claude Code session 裡跑：

```bash
printf '\033]0;PATH-B-TEST\007' && echo "done"
```

- 若 tab 變成 `PATH-B-TEST` → 路徑 B 生效，失效原因在其他地方（條件 2 / 中文亂碼）
- 若 tab 沒變 → 路徑 B 也不通，差異在 Claude Code 渲染行為（版本 / 環境）

---

## 實測紀錄

### 機器 A — reed（失效）

- **日期**：2026-07-01
- **環境**：macOS Darwin 25.3.0, Cursor (vscode 3.7.42)

| 檢查項 | 結果 | 判讀 |
|---|---|---|
| Claude Code 版本 | 2.1.52 | — |
| `tty`（Bash 工具） | `not a tty` | **條件 3 不成立** — `printf` OSC 寫到 stdout，被 Claude Code 捕捉成工具輸出，到不了 terminal |
| `TERM_PROGRAM` | `vscode / 3.7.42` | 跑在 Cursor integrated terminal |
| `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` | (unset) | 內建 title 未被關閉，每輪 tool call 會被 Claude Code 覆寫 |
| `claude` 是否 wrapper | 直接二進位（`Mach-O arm64` at `~/.local/bin/claude`），alias `ANTHROPIC_API_KEY= claude` | 不是 wrapper script，alias 只清 env var |
| Cursor `${sequence}` 設定 | **未設定** — 只有 `terminal.integrated.fontFamily` | **條件 1 不成立** — tab 用預設模板，即使 OSC 送達也會被吃掉 |

**原結論（已修正）**：~~雙重失效~~ → 實際上 `/auto-rename` 在這台機器**正常運作**。條件 1 和路徑 A 雖然都不成立，但路徑 B（stdout 間接傳遞）生效，OSC bytes 經 Claude Code 渲染後仍到達 terminal。

### 機器 B — 另一台（原失效 → 已修復）

- **日期**：2026-07-01
- **環境**：macOS Darwin 24.6.0, Cursor (vscode)

| 檢查項 | 結果 | 判讀 |
|---|---|---|
| Claude Code 版本 | **2.1.197** | 比 reed 新 145 版號 → **渲染時 strip 工具 stdout 的 ESC byte，路徑 B 被切斷** |
| `tty`（Bash 工具） | `not a tty` | 與 reed 相同，非分歧點 |
| 路徑 B 測試（`printf` 純 ASCII 到 stdout） | **tab 沒變** | 路徑 B 死（與 reed 2.1.52 相反）→ 確認是版本差異 |
| tty 裝置直寫（`> /dev/ttysXXX`，ASCII） | **tab 有變**（隨即被內建 title 覆寫回去） | tty 直寫可行，內建 title 是覆寫元兇 |
| tty 裝置直寫（中文/emoji） | **顯示正常**（🔧中文測試） | tty 直寫路徑中文不亂碼 |
| `TERM_PROGRAM` | `vscode` | Cursor integrated terminal |
| `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` | 原未設 → **改設 1** | 未設時內建 title 每輪覆寫；設 1 + 重開後解決 |
| `claude` 是否 wrapper | 直接二進位 | 非 wrapper |
| Cursor `${sequence}` 設定 | 已設 | tab 願意吃 OSC |

**結論**:版本 2.1.197 切斷路徑 B。改走「tty 裝置直寫 + `CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1` + 重開」後，`/auto-rename` 即時生效、中文正常、不再彈回。詳見本文頂部「✅ 結論與已驗證解法」。

### 跨機器比對

> 兩台都填完後，對照 §判讀表 找出差異項。最可能的分歧點：

| 差異項 | 機器 A | 機器 B | 意義 |
|---|---|---|---|
| `tty` | `not a tty` | （待填） | 若 B 回真 pts → B 的 Bash 工具有控制終端，OSC 直達 tab |
| `${sequence}` | 未設定 | （待填） | 若 B 已設 → B 的 Cursor 接受 OSC 當 tab 名 |
| `claude` wrapper | 直接二進位 | （待填） | 若 B 是 wrapper → wrapper 可能補了 tty 轉發 |
| Claude Code 版本 | 2.1.52 | （待填） | 版本差異可能改變 Bash spawn 方式 |

---

## 可能的修法(依診斷結果)

### 若失效機器路徑 B 測試也失敗

差異在 Claude Code 渲染行為。可能的解法：

- **對齊 Claude Code 版本**：升級到與正常機器相同版本（2.1.52+），新版可能改善了工具輸出的 byte 傳遞
- **改寫 skill 繞過 stdout**：skill 只寫 `~/.claude/session-names/${PID}.txt`，搭配 zsh `precmd` hook 在真 shell 裡 emit OSC（類似 Codex 的 `mycodex` wrapper 思路）

### 若失效機器路徑 B 測試成功（英文 title 有改）

失效原因不在 OSC 傳遞，而在：

- **條件 2（舊 terminal）**：改完設定後沒重開 terminal → 關掉舊 tab，開新的
- **中文亂碼**：UTF-8 title 被 Cursor 當 Latin-1 解碼 → OSC sequence 損壞 → 改用純 ASCII title 測試確認
- **內建 title 覆蓋**：`CLAUDE_CODE_DISABLE_TERMINAL_TITLE` 未設 → Claude Code 每次 tool call 都用內建 title 覆蓋 skill 設的名稱 → 看起來「沒改」但其實改了又被蓋回去

### 中文亂碼

raw OSC 在部分 Cursor 版本對 UTF-8 標題解碼有問題。若要中文正常，優先用 Claude Code 內建 title（走不同的渲染管道，中文正常）。

---

## 備註

- 此文件為跨機器排查紀錄，非安裝步驟。安裝見 [auto-rename-install.md](./auto-rename-install.md)。
- 內建 title 開關：`CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1`（寫 `~/.claude/settings.json` 的 `env`）。格式不可自訂，為 Claude Code 官方行為。
- 路徑 B（stdout 間接傳遞）的發現來自 reed 機器實測（2026-07-01）。原始三條件模型已更新。
