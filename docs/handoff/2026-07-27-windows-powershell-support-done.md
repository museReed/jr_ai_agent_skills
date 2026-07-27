# Handoff — Windows/PowerShell 支援完成 + 嚮導架構待決

## 狀態摘要

- 類型：continuation。
- **Windows/PowerShell 支援全部完成並 merge 進 `main`**（PR #15–#19，`b8fbde3`）。
  bash runtime 的每個元件都有 PowerShell 對照版，全部經真實 session 實機驗證。
- 學生現在打 `claude` 或 `codex` 就自動走 wrapper：session 自動命名、tab 顯示
  `{emoji} 中文`、context 過 70% 提醒寫 handoff。
- 驗證分兩層才抓得完：harness 驗元件（7 輪），真實 session 驗宿主行為。
  七個真 bug 裡有四個只有掛進真實 session 才看得到。
- 後半段轉為設計討論：workshop 網頁嚮導要不要「控制 CLI」。**尚未動工**，
  架構有一個未決的分岔（見下）。

## 必讀檔案

- `docs/windows-powershell-runtime.md` — **最重要**。檔案對照表、平台差異、手動安裝、
  七輪驗證的完整記錄與每個 bug 的根因。要改 Windows 這條線先讀它。
- `installer/install-windows.ps1` — Windows 安裝器。改任何 `.ps1` 都要同步看它有沒有裝到、
  有沒有改寫 skill 裡的 bash 指令。
- `docs/spikes/windows-tab-title/verify-powershell-runtime.ps1` — T1–T9 驗證 harness。
  動 runtime 後在 VM 重跑一次。
- `docs/handoff/2026-07-25-workshop-terminal-tabtitle-verified.md` — 上一份交接，
  terminal 選型定案的脈絡，以及 workshop 那三項還沒做的事。

## 三個貫穿全場的教訓（已寫進 runtime 文件）

1. **Windows 上 escape sequence 不可靠，API 呼叫才可靠。** 這句話在三個地方各殺一次：
   寫進 `CONOUT$` 沒作用、被 Codex TUI 吞掉、設完被蓋回去。全專案已無一處靠 OSC 改標題。
2. **pid 不能當 session 身分。** Windows 每次 spawn hook 都開一個用完即丟的中介程序，
   parent pid 每次都不同。session_id 才是正解。
3. **元件級 harness 驗不出「宿主怎麼 spawn 你」。** harness 全綠之後仍有四個 bug 只在
   真實 session 浮現。

## 下一步

### A. 嚮導架構分岔（要先拍板，卡住 B 和 C）

想做的是「網頁輸入 prompt → CLI 接收並執行」。既有機制在
`claude-code-workshop/assets/js/debug-overlay.js`：按鈕寫 `window.__dbgSubmit`，
Playwright 在 CLI 端輪詢，看門狗（shell 常駐腳本）叫 agent 執行。

**未決**：嚮導該不該照抄那套。分析結論是**不該**——debug-overlay 用 Playwright 是因為
「頁面不是我們的、server 改不了」，嚮導兩個前提都不成立，可以簡化成：

```
網頁 POST /submit → server 排隊 → 看門狗讀佇列 → codex exec / claude -p
                                      ↓
                            寫回 server → 網頁輪詢 /result
```

省掉 Playwright = 學生不用裝瀏覽器驅動、不用讓 Chrome 帶 debug port、
不會有被自動控制的視窗在旁邊跳。

**動工前要先做的事**：
1. **找出 watchdog server 現在在哪個 repo。** `/watchdog/state`、`POST /watchdog/on|off`
   的伺服器端不在 `claude-code-workshop`（只有前端），也不在 `playwright-live-demo` 或
   `html-debug-overlay` skill。記憶提到 `src/debug/debug-panel.tsx` 與
   `src/watchdog/watchdog-manager.ts`，是另一個 TS 專案。掃 `~/Projects` 找出來。
2. 決定「擴充現有 server」還是「為嚮導另寫一個小的」。

已確認的前提：`claude -p` 與 `codex exec` 都吃訂閱額度、不需要 API key；
但背景程序下 CLI 未登入會**靜默全掛**（launchd 那次的坑），看門狗要先驗登入狀態。

### B. `jr_workshop_setup_env` 嚮導盤點

本機 `~/Projects/jr_workshop_setup_env`，靜態 SPA（`index.html` + `assets/js/steps.js`）。
**注意**：2026-07-11 曾在 `CodeBlock.tsx`（React 版）做過「Terminal / AI Agent」分頁切換，
但本機這份是純靜態、沒有 `src/`——兩套不是同一份程式碼。先確認分頁切換還在不在，
再決定是「擴充」還是「把掉了的東西補回來」。

嚮導內容的分界線已定：前 2–3 步是複製指令（裝第一個 CLI），之後全部換成
「複製這段話貼給 AI」。

### C. `claude-code-workshop-jr-student` 安裝流程改寫

Phase 1 從「餵 Antigravity」改成「網頁嚮導帶學生在 terminal 手動裝」。
相關檔：`agent-setup/to_IDE_AI_Agent_setup.md`。

### D. SPICE guest tools 納入 VM 安裝流程

用 VM 的學生會撞剪貼簿痛點。

## 已知問題

- **`context-monitor` 的門檻觸發只在測試模式下驗過**
  （`CONTEXT_MONITOR_TEST_WINDOW` / `CODEX_TEST_MAX_CONTEXT_WINDOW`），
  真實跑到 70% 的情況尚未遇到。
- **Codex sandbox 第一次寫 relay 檔會跳一次授權**（`%TEMP%` 在工作目錄外），
  同 session 內只跳一次。判定為可接受、不改 relay 落點——改設定等於教學生放寬安全預設。
  但那一次落在學生打完第一句話之後，嚮導要預告。
- **本地殘留 branch 未清**：`fix-codex-session-key`、`shadow-native-commands`、
  `windows-context-monitor`、`windows-installer`、`windows-tab-title-spike` 五條都已 merge，
  遠端已刪，本地還在。
- PR #13（`trust-commands` skill）自 7/16 起還開著，與 Windows 這條線無關。
