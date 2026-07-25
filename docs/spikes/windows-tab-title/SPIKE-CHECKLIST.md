# Spike 驗證清單 — Windows tab-title 到底走不走得通

## 為什麼要做這個 spike

macOS 版靠「背景 watcher 進程直接寫 `/dev/tty`」改 tab 名（`ai-tab-sync.sh:18`）。
Windows 沒有 `/dev/tty`，這個做法整個不成立。所以動手寫 Windows 版之前，
必須先確認：**在 Windows 上，一個「背景進程」到底改不改得到前景 terminal 的 tab 名？**

- 如果 **TEST 4/5 通** → watcher 架構可沿用，只換寫法。工作量小。
- 如果 **TEST 4/5 不通、只有 TEST 1-3（同進程）通** → 整個 watcher 架構要重設計
  （改成 hook 直接在 shell 進程內設 title，不用背景 watcher）。這會影響 plan 骨架。
- 如果 **全部不通** → tab 自動命名在 Windows 第一版就是做不到，維持「分階段、tab 後補」的決定。

## 怎麼跑

> workshop 定案（2026-07）：Windows 學生只用 Windows Terminal、不在 IDE 整合終端裡跑
> Claude Code，故移除 VS Code 組合，只測 Windows Terminal。

在 **2 種組合**各跑一次 `spike-tab-title.ps1`，因為行為可能不同：

| # | 終端 | Shell | 啟動指令 |
|---|------|-------|----------|
| A | Windows Terminal | PowerShell 7 (`pwsh`) | `pwsh -NoProfile -File .\spike-tab-title.ps1` |
| B | Windows Terminal | Windows PowerShell 5.1 (`powershell`) | `powershell -NoProfile -File .\spike-tab-title.ps1` |

> Windows Terminal 若沒反應，先確認 Settings → 該 profile → 沒有把 "Suppress
> title changes / 標題覆寫" 打開。

## 結果記錄表（跑完填這裡貼回來）

每格填：tab 標題**有沒有變**、變成什麼字。

| 測試 | A: WT+PS7 | B: WT+5.1 |
|------|-----------|-----------|
| 1 RawUI.WindowTitle | ✅ 變 | ✅ 變 |
| 2 OSC 0 → stdout | ✅ 變 | ✅ 變 |
| 3 OSC 2 → stdout | ✅ 變 | ✅ 變 |
| 4 背景 job 改 title | ✅ 變 | ✅ 變 |
| 5 獨立進程改 title | ✅ 變 | ✅ 變 |

另外附上腳本開頭印的環境資訊（PSVersion / WT_SESSION / TERM_PROGRAM）。

## 判讀（我拿到表格後會做的事）

- **TEST 4 或 5 有任一格「變成 SPIKE-4/5-*」** → watcher 模型可行，plan 走「換寫法」路線。
- **只有 TEST 1-3 變、4-5 全不變** → 放棄背景 watcher，plan 改「hook 內設 title」路線。
- **PS7 通、5.1 不通** → 最低版本要求定 PowerShell 7（呼應你選的支援矩陣）。

## 實測結果（2026-07-18，UTM Windows 11 ARM）

Windows Terminal × PowerShell 7 (7.6.3) 與 × Windows PowerShell 5.1，**兩組合五題全通**，
含最關鍵的跨程序 TEST 4/5（背景 job / 獨立進程改前景 tab）。

**結論**：
- Windows 雖無 `/dev/tty`，但在 Windows Terminal 下，背景／獨立程序能改到前景 tab title
  → **macOS 的 watcher 架構（背景程序改 tab）可直接沿用到 Windows**，不需改成 hook-inline。
- PS7 與 PS5.1 都通 → **不強制 PS7**，Windows 學生用內建的 5.1 即可（少一個安裝步驟）。
- 剩餘工作純為工程量（bash watcher → PowerShell 改寫），無架構級未知。
