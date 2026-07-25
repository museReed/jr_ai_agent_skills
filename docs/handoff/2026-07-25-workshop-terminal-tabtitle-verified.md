# Handoff — Workshop 環境改造：Terminal 選型 + Tab-title 驗證

## 狀態摘要

- 類型：決策固化 + spike 驗證完成。
- 目標：把 workshop 環境安裝流程從「用 AI IDE（Antigravity）安裝」改成「教學生用現代 terminal + 網頁嚮導」裝 Claude Code / Codex CLI，並讓三個核心 skill（auto-rename / handoff / structured-questions）的 tab 改名支援涵蓋各平台。
- 本次成果：**terminal 選型定案 + tab-title 改名機制在兩平台全部驗證通過**。剩餘為純工程量（bash → PowerShell 改寫），無架構級未知。

## 定案（不要再反覆）

| 項目 | 定案 |
|---|---|
| mac terminal | **Ghostty**（獨立終端，不在 IDE 裡跑 CC） |
| Windows terminal | **Windows Terminal**（獨立終端，不在 IDE 裡跑 CC） |
| Windows Claude Code | **原生 Windows**（`irm https://claude.ai/install.ps1 \| iex`，不需 WSL / Node，Git for Windows 可選） |
| Windows PowerShell 版本 | **不強制 PS7**，內建 PowerShell 5.1 即可（auto-rename 兩版本都驗過通） |
| Antigravity | **不再當安裝工具**；改網頁嚮導帶學生在 terminal 裝。Antigravity 仍可當 auto-rename 支援的 terminal 之一（mac 已驗），但 workshop 路徑不用 |
| IDE 整合終端命名 | **不做**（mac/Windows 都免）——砍掉最難那層（ConPTY + VS Code fork + `${sequence}` 未知） |

理由脈絡：terminal 選型走「各平台選最佳」而非「跨平台統一 WezTerm」，因為 (1) 改名機制本來就要 mac(tty)/Windows(ConPTY) 兩套，統一 terminal 省不掉底層工 (2) 平台差異由網頁嚮導吸收。Ghostty 排除 Windows（官方無 Windows 版）；Windows Terminal 勝在 Win11 預裝、零門檻，對零 CLI 學生摩擦最小。

## 驗證結果（本次完成）

### mac / Ghostty — ✅ 全通
- spike 機制（OSC 0/2 + 背景直寫 `/dev/tty`）三題全通。
- 端到端 smoke：`myclaude`（= `claude` alias）在 Ghostty 跑，tab 顯示 `{emoji} 中文名`（AI 命名路徑都通）。
- 結論：現有 `ai-tab-sync.sh` + wrapper 架構**零改動**支援 Ghostty。
- 未驗（低風險）：`CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1` 在 Ghostty 的細節。

### Windows / Windows Terminal — ✅ 全通（推翻悲觀預測）
- 環境：UTM Windows 11 ARM VM，PowerShell 7.6.3 + 內建 5.1，已裝 UTM guest tools（剪貼簿）。
- spike 五題（RawUI / OSC 0 / OSC 2 / 背景 job 跨程序 / 獨立進程跨程序）**在 WT×PS7 和 WT×PS5.1 兩組合全部有變**。
- 關鍵：**跨程序 TEST 4/5 通** → 原本擔心「Windows 無 `/dev/tty`、背景程序改不到前景 tab」被推翻。**macOS watcher 架構可直接沿用到 Windows**，不需改成 hook-inline。
- 結果已寫入 `docs/spikes/windows-tab-title/SPIKE-CHECKLIST.md`。

## 本次改動的檔案（jr_ai_agent_skills，branch `windows-tab-title-spike`）

- `docs/spikes/windows-tab-title/SPIKE-CHECKLIST.md` — 移除 VS Code 整合終端組合（4→2）、填入 PS7/5.1 實測結果、加實測結論段。
- `docs/spikes/windows-tab-title/README-FOR-AGENT.md` — 組合 4→2。
- `docs/spikes/windows-tab-title/spike-tab-title.ps1` — 註解移除 VS Code。
- `installer/README.md` — 支援矩陣加 Ghostty。

## 下一步（open）

1. **PowerShell 版實作** — 把 `ai-tab-sync.sh` + 命名 hook（`session-auto-namer.sh` 等）的 bash 邏輯改寫成 PowerShell。純工程量，無架構未知。參 `docs/handoff/2026-07-15-windows-powershell-plan.md` 的 Phase 0 官方 API 清單（`$PROFILE`、`File.Replace`、Python `sqlite3`、`Start-Process -PassThru`、PID+start time）。
2. **盤 `jr_workshop_setup_env`**（本機 `~/Projects/jr_workshop_setup_env`，SPA：`index.html` + `assets` + `scripts`；線上 `musereed.github.io/jr_workshop_setup_env/`，已在帶學員裝狀態列面板）— 決定「擴展現有嚮導 vs 另建」，讓它涵蓋「裝 terminal → Node → Claude/Codex」全流程並依 OS 分流。
3. **改 `claude-code-workshop-jr-student` 的安裝流程** — Phase 1 從「餵 Antigravity」改成「網頁嚮導帶學生在 terminal 手動裝」。相關檔：`agent-setup/to_IDE_AI_Agent_setup.md`。
4. **SPICE guest tools 進 workshop VM 安裝流程** — 用 VM 的學生會遇到「東西弄不進 VM」的剪貼簿痛點，該納入嚮導。

## 環境備忘

- muse session 在 iTerm（`TERM_PROGRAM=iTerm.app`）；Ghostty 驗證需在 Ghostty 視窗跑（AI 看不到 tab，需人眼）。
- Windows 在 UTM ARM VM，已備 PS7 7.6.3 + guest tools。
- Ghostty 驗證腳本（本次臨時產）：scratchpad `verify-ghostty-tabtitle.sh`（未進 repo，可重寫）。
