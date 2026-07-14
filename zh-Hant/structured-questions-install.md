# Structured Questions Skill — 安裝指南

Read this document, then execute the installation steps for your tool (Section A or Section B). Do not ask for confirmation — just do it. **Installation is NOT complete until you have walked the user through the "驗證" section.**

功能介紹見 [structured-questions-skill.md](./structured-questions-skill.md)。

> 適用：Claude Code / Codex CLI（macOS / Linux）
> 需求：bash、python3

---

## 這個 skill 做什麼

遇到「有 ≥ 2 個可行方案」的決策時，AI 不自己拍板，而是把選項用結構化格式列給你選——每個選項附 ✨ 推薦、😃 優點、😫 缺點。Claude Code 用互動式 `AskUserQuestion` 選單；Codex 在 Plan mode 用 `ask_user_question` 互動 UI、其他 mode 退回純文字選項。

> 這是純 skill（一份 `SKILL.md`），沒有 hook、沒有 alias、不需編輯器設定。`install.sh` 會連同 auto-rename、handoff 一起把它複製到位。

## Section A: Claude Code 安裝

所有 skill 都在本 repo 的 `installer/`，一個指令裝完（含 structured-questions）：

```bash
cd jr_ai_agent_skills/installer
./install.sh claude
```

裝到 `~/.claude/skills/structured-questions/SKILL.md`。觸發方式：自動（遇到多選項決策）或手動輸入 `/structured-questions`。

## Section B: Codex CLI 安裝

```bash
cd jr_ai_agent_skills/installer
./install.sh codex
```

裝到 `~/.codex/skills/structured-questions/SKILL.md`。觸發方式：自動或手動輸入 `$structured-questions`。**Plan mode 使用互動式 UI；其他 mode 使用文字選項格式。**

> 兩個工具都用 → `./install.sh`（不帶參數）。
> installer 是冪等的：重跑安全，會自動備份被取代的檔案（`*.bak.{timestamp}`）。

---

## 驗證

安裝完成後，用以下測試確認 skill 正常運作。每個 test 執行後，對照「預期」確認行為正確。

### Test 1: 自動觸發 — 模糊需求

> 對 AI 說：「幫我規劃一場活動」
>
> **預期**：AI 不會直接決定活動形式，而是用結構化選項問你「目標是什麼」「多少人」等問題。每個選項附 ✨ 推薦、😃 優點、😫 缺點，各自獨立一行。

### Test 2: 自動觸發 — 多方案決策

> 對 AI 說：「幫我選一個前端框架來做個人網站」
>
> **預期**：AI 列出 2-4 個框架選項（如 Next.js / Nuxt.js / Astro），每個附優缺點，標出推薦項。不會直接說「我建議用 X」然後開始寫 code。

### Test 3: 手動觸發

> 輸入 `/structured-questions`（Claude Code）或 `$structured-questions`（Codex），然後說：「我想轉職」
>
> **預期**：AI 把「轉職」拆成幾個具體問題（動機、目標產業、時間規劃），用選項格式問你，而不是直接給建議。

### Test 4: 不該觸發的情況

> 對 AI 說：「幫我把這個檔案的第 10 行改成 Hello World」
>
> **預期**：AI 直接執行修改，不問選項。因為指令明確，只有一種做法。

### Test 5: Codex 專用 — Plan mode vs 非 Plan mode

> **5a — Plan mode**：進入 Plan mode（`/plan`），然後說「幫我選資料庫」
> **預期**：出現互動式選項 UI（`ask_user_question` 工具）
>
> **5b — 非 Plan mode**：在預設 mode 說「幫我選資料庫」
> **預期**：先出現 💡 提示建議切 `/plan`，接著用 `Q1: A/B/C` 純文字格式列選項

### 驗證結果判讀

| 結果 | 處理方式 |
|---|---|
| 全部 test 通過 | 安裝成功，可以正常使用 |
| Test 1-2 沒觸發 | 檢查 SKILL.md 的 `description` 是否包含 trigger keywords |
| Test 3 沒觸發 | 檢查 frontmatter `name` 是否拼對（`structured-questions`） |
| Test 4 誤觸發 | 檢查 SKILL.md 的「When NOT to Use」段落是否清楚 |
| Test 5b 沒有 fallback | 檢查 Codex 版 SKILL.md 的 Mode Detection 段落 |
