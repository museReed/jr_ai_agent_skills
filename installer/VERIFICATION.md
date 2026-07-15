# VERIFICATION — 三個 Skill 的引導式 E2E 驗證

> 這份文件是給執行安裝的 AI agent 使用的劇本。安裝完成後，依序驗證
> auto-rename、handoff、structured-questions；每個檢查點都要明確判定 PASS/FAIL。

## 事前準備

1. 確認安裝前曾執行只讀偵測，且 AI 記錄了學生最後選定的安裝目標與 terminal／IDE：

```bash
cd <本 repo>/installer
python3 detect-environment.py
```

`recommended_install_target` 是依本機 CLI 推薦，不取代學生在兩者皆有時的選擇；`terminal.detected` 也只是證據，不取代學生確認。只有學生確認的 Cursor、Antigravity 或 VS Code 可被修改；native／other 必須不改 editor settings。

2. 先跑自動檢查；有 FAIL 時先修復，不進入人工測試：

```bash
cd <本 repo>/installer
./verify.sh --editor=<confirmed-editor>  # 換成 cursor / antigravity / vscode / native
# 或加 claude / codex，只驗證實際安裝目標
```

3. installer 完成後，舊 AI session 必須停止。以下人工測試全部在新的 terminal / session 執行，確保剛安裝的 skill 已重新載入。
4. handoff 會建立文件與 commit，只能在下方指令建立的臨時 repo 中測試。

## A. auto-rename

### Claude Code

1. 開新 terminal 執行 `claude`。
2. 輸入：「列出這個資料夾的檔案」。
3. 預期：第一個回合內 terminal tab 變成 `{emoji} 任務描述`。

### Codex

1. 開新 terminal 執行 `codex`。
2. 輸入同一句任務。
3. 預期：第一個回合內 terminal tab 與 Codex sidebar 都變成任務名稱。

若學生使用 Cursor、Antigravity 或 VS Code integrated terminal，需在實際使用的 terminal
再跑一次；`verify.sh` 會先檢查 `terminal.integrated.tabs.title` 是否包含 `${sequence}`。

## B. handoff（完整流程）

測試變數只影響帶著變數啟動的 session，不會修改正式 70% 門檻或 shell 設定。

### Claude Code

開新 terminal，整段貼上：

```bash
TEST_REPO="$(mktemp -d "${TMPDIR:-/tmp}/jr-skill-e2e.XXXXXX")" && \
git -C "$TEST_REPO" init -q && \
printf '# e2e skill test\n' > "$TEST_REPO/README.md" && \
git -C "$TEST_REPO" add README.md && \
git -C "$TEST_REPO" config user.name 'Skill E2E' && \
git -C "$TEST_REPO" config user.email 'skill-e2e@example.invalid' && \
git -C "$TEST_REPO" commit -qm init && \
cd "$TEST_REPO" && CONTEXT_MONITOR_TEST_WINDOW=30000 claude
```

1. 輸入：「讀 README 並列出這個資料夾的檔案」。
2. 看到 `Context 已用 …（測試模式）` 後，輸入：「照警告完整寫 handoff」。
3. 預期：`docs/handoff/` 出現文件、git 多一個 commit、session 名稱變成 `📦 …`。
4. 離開 Claude Code 後，在原 shell 執行 `rm -rf "$TEST_REPO"`。

### Codex

開新 terminal，整段貼上：

```bash
TEST_REPO="$(mktemp -d "${TMPDIR:-/tmp}/jr-skill-e2e.XXXXXX")" && \
git -C "$TEST_REPO" init -q && \
printf '# e2e skill test\n' > "$TEST_REPO/README.md" && \
git -C "$TEST_REPO" add README.md && \
git -C "$TEST_REPO" config user.name 'Skill E2E' && \
git -C "$TEST_REPO" config user.email 'skill-e2e@example.invalid' && \
git -C "$TEST_REPO" commit -qm init && \
cd "$TEST_REPO" && CODEX_TEST_MAX_CONTEXT_WINDOW=5000 codex
```

1. 輸入：「讀 README 並列出這個資料夾的檔案」。
2. 再輸入：「再列一次」。Codex 在回合結束才寫入 token 帳本，警告通常從第二個指令開始出現。
3. 看到 `[context-monitor] 測試模式…` 後，輸入：「照指示完整寫 handoff，全部步驟做完」。
4. 預期：`docs/handoff/` 出現文件、git 多一個 commit、tab/sidebar 變成 `📦 …`；AI 建立 hook 指定的 `.handoff` marker 後，警告停止重複。
5. 離開 Codex 後，在原 shell 執行 `rm -rf "$TEST_REPO"`。

## C. structured-questions

### Claude Code

1. 在新 session 輸入：`/structured-questions 我想轉職`。
2. 預期：出現分組選項、推薦項與各選項取捨，而不是直接替使用者決定。

### Codex Default mode

1. 在新 session 輸入：`$structured-questions 我想轉職`。
2. 預期：只顯示 Plan mode 切換提示並停止，尚未列出轉職選項。
3. 回覆「不切換」。
4. 預期：接續原問題，以完整文字選項提問。

### Codex Plan mode

1. 另開新 session，輸入：`$structured-questions 幫我選資料庫`。
2. 依提示輸入：`/plan 繼續剛才的 structured questions`。
3. 預期：切換後透過 `request_user_input` 顯示互動選單。

## 判定與失敗處理

- 對已安裝的工具完成 A、B、C 且全部符合預期，才回報「三個 skills 全鏈路驗證通過」。
- 任一檢查點失敗，先對照 `TROUBLESHOOTING.md`；修復後重跑 `install.sh` 與 `verify.sh`。
- 仍無法排除時，記錄 skill、工具、預期與實際結果後執行：

```bash
./diagnose.sh "{工具} {skill}：{預期}，實際 {結果}"
```
