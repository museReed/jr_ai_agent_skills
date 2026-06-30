# Auto-Rename — Cursor Tab 改名失效診斷

> 適用情境:在 Cursor / VS Code 的 integrated terminal 跑 Claude Code,呼叫 `/auto-rename` 後 tab 名稱沒有改變,但同一份 skill 在另一台機器卻正常。
> 本文用來抓出「兩台機器之間的差異」,定位真正卡點。

---

## 背景:已知的三層機制

auto-rename skill 靠 OSC escape sequence(`\033]0;title\007`)改 terminal tab 名。要成功,三個條件缺一不可:

| # | 條件 | 失效症狀 |
|---|---|---|
| 1 | Cursor 設定 `terminal.integrated.tabs.title` 含 `${sequence}` | 預設 `${process}` 會吃掉 OSC,tab 永遠不變 |
| 2 | 設定生效的 terminal(只對「存檔後新開」的 terminal 生效) | 舊 terminal 仍用舊模板,OSC 無效 |
| 3 | OSC bytes 真的送達 terminal 的 TTY | 若被 stdout 捕捉,只會顯示成文字 `]0;title` |

第 3 點是最隱蔽的卡點:**skill 的 `printf` 跑在 Claude Code 的 Bash 工具裡。如果該子程序沒有控制終端(controlling tty),`printf` 寫到 stdout 會被 Claude Code 捕捉成工具輸出,結構上到不了 terminal,tab 不會變。** 內建 title 能改,是因為它從 Claude Code 主程序直接寫控制 TTY,走的是另一條管道。

---

## 已驗證的事實(2026-07-01,一台失效機器上)

- `${sequence}` 設定正確:在「新開的」乾淨 terminal 手動 `printf '\033]0;X\007'` → tab 有變 → 條件 1 成立。
- 失效的 Claude Code tab 是「設定存檔前」開的 → 條件 2 不成立(舊 terminal 不吃 OSC)。
- Claude Code Bash 工具子程序 `tty` 回傳 `not a tty`,寫 `/dev/tty` 得到 `device not configured` → **條件 3 不成立(致命)**。
- 額外發現:中文 / emoji 經 raw OSC 在此 Cursor 版本會變亂碼(「測試」→「æ¸¬è©¦」,UTF-8 被當 Latin-1 解碼)。Claude Code 內建 title 顯示中文則正常。

**結論假設:兩台機器的差異,最可能在「Claude Code 的 Bash 工具有沒有控制終端」。** 有 → skill 的 `printf` 直達 tab;無(pipe)→ 結構上到不了。

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

| 檢查項 | 失效機器 | 正常機器若不同 → 代表 |
|---|---|---|
| `tty`(Bash 工具) | `not a tty` | 若回 `/dev/ttysXXX` → 正常機器用 pty 跑 Bash 工具,OSC 才到得了 tab(**主因**) |
| `claude` 是否 wrapper | 直接二進位 | 若是 script / alias → wrapper 可能補了 tty 或轉發 OSC |
| `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` | 未設 | 若為 `1` → 內建 title 被關,skill 名才不會被每輪覆蓋 |
| Claude Code 版本 | (記錄) | 版本差異可能改變 Bash 工具的 spawn 方式 |
| `${sequence}` 設定 | 已設 | 兩台應一致 |

---

## 可能的修法(依診斷結果)

- **若正常機器 `tty` 回傳真 pts**:差異在 Claude Code spawn Bash 的方式(版本 / wrapper)。對齊版本或複製 wrapper。
- **若正常機器有 `claude` wrapper**:把 wrapper 腳本複製過來(類似 Codex 的 `mycodex` 思路:在真 TTY 上監聽並 emit OSC)。
- **若兩台 `tty` 都是 `not a tty`**:代表 skill 的 stdout-OSC 路在 Cursor + Claude Code 下本就無效,正常機器其實是靠內建 title。改用內建 title,或改寫 skill 成「寫 session-names 檔 + zsh precmd hook 在真 shell emit OSC」。
- **中文亂碼**:raw OSC 在此 Cursor 版本對 UTF-8 標題解碼有問題;若要中文正常,優先用內建 title。

---

## 備註

- 此文件為跨機器排查紀錄,非安裝步驟。安裝見 [auto-rename-install.md](./auto-rename-install.md)。
- 內建 title 開關:`CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1`(寫 `~/.claude/settings.json` 的 `env`)。格式不可自訂,為 Claude Code 官方行為。
