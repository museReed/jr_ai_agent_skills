# 給 Windows VM 裡 AI agent 的執行指示

你正在一台 Windows 11 ARM VM 裡（UTM）。這個 spike 要驗證：
**在 Windows 上，一個「背景程序」改不改得到前景 terminal 的 tab 名。**
（macOS 版靠背景 watcher 寫 `/dev/tty` 達成；Windows 沒有 `/dev/tty`，要找替代路。）

## 你要做的事

1. 讀 `SPIKE-CHECKLIST.md`，理解 5 個測試與 4 種終端組合。
2. 執行 `spike-tab-title.ps1`。**注意**：腳本有 5 個 `Read-Host` 暫停點，
   每個測試後會停下來讓人「看 tab 標題有沒有變」。你（AI agent）看不到 UI tab，
   所以：
   - 若你能請人類使用者回報每個測試後的 tab 標題 → 照做，逐題記錄。
   - 若要全自動，改用可觀測的替代：把每次設定 title 後，用
     `[Console]::Title`（讀回目前 console title）印出來當佐證，並註明
     「RawUI 讀回值 ≠ 一定反映到 WT tab」，tab 實際變化仍需人眼確認。
3. 理想上在這 4 種組合各跑一次（無法全跑就註明跑了哪幾種）：
   - Windows Terminal × PowerShell 7 (`pwsh`)
   - Windows Terminal × Windows PowerShell 5.1 (`powershell`)
   - VS Code 整合終端 × PowerShell 7
   - VS Code 整合終端 × Windows PowerShell 5.1
4. 把結果填進 `SPIKE-CHECKLIST.md` 的表格（哪個測試、哪種組合、tab 有沒有變、變成什麼），
   連同腳本開頭印的環境資訊（PSVersion / WT_SESSION / TERM_PROGRAM）。

## 最重要的一件事

TEST 4 / TEST 5（跨程序改 title）是關鍵：
- **通** → macOS 的 watcher 架構可沿用，只換寫法。
- **不通、只有 TEST 1-3（同程序）通** → 要放棄背景 watcher，改成 hook 在 shell 程序內直接設 title。

把觀察到的結果如實回報，不要臆測。跑不動或報錯就把完整錯誤訊息貼回。
