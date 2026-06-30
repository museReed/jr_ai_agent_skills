# Structured Questions Skill — 安裝指南

Read this document, then execute the installation steps for your tool (Section A or Section B). Do not ask for confirmation — just do it.

功能介紹見 [structured-questions-skill.md](./structured-questions-skill.md)。

---

## Section A: Claude Code 安裝

### Step 1: 建立目錄

```bash
mkdir -p .claude/skills/structured-questions
```

### Step 2: 寫入 SKILL.md

Create the file `.claude/skills/structured-questions/SKILL.md` with the following content:

```markdown
---
name: structured-questions
description: >-
  Use when facing multiple options or design decisions that need user input.
  Defines how to structure AskUserQuestion calls: tab grouping, recommended tags,
  option detail level, and triggering conditions.
  Triggers on "ask user", "structured questions", "提問格式".
---

# Structured Questions — AskUserQuestion 使用規範

## Quick Reference

遇到多個可行方案時，**必須用 `AskUserQuestion` tool 提問**，不自行決定。

1. 多決策點 → tab 分組一次問完（`questions` array 放 2-4 題）
2. 每題必標 `✨ (Recommended)` — 放在推薦選項的 label 尾端
3. 每個選項帶 **標題 + 說明 + 😃/😫**（寫在 `description` 欄位）
4. `header` ≤ 12 字元，中文優先
5. 選項數 2-4 個，不含 Other（系統自動加）
6. 有具體 artifact 可比較時用 `markdown` preview

觸發條件：任何存在 ≥ 2 個可行方案的決策點。

## When to Use

| 場景 | 觸發 | 說明 |
|------|------|------|
| 架構 / 技術選型 | ✅ | DB schema、API 設計、module 結構、第三方選擇 |
| 命名 / 慣例 | ✅ | 變數名、branch name、file placement |
| 實作策略 | ✅ | TDD 順序、拆 PR 策略、並行 vs 序列 |
| 範圍取捨 | ✅ | MVP vs 完整版、edge case 處理範圍 |
| 任何多選項決策 | ✅ | 上述未列但存在 ≥ 2 可行方案的情境 |
| 只有一種合理做法 | ❌ | 不要為問而問，直接做 |
| 純執行步驟確認 | ❌ | 用文字說明即可，不需選項 UI |

## When NOT to Use

- 只有一種合理做法 → 直接執行
- 用戶已在指令中明確指定做法 → 遵從不問
- 純狀態回報 / 進度更新 → 用文字輸出

## Execution Flow

### Step 1: 識別決策點

掃描當前任務，列出所有需要用戶決定的點。

✅ DO: 把相關的決策點分組，一次問完
❌ DON'T: 每個小問題分開問，打斷用戶節奏

### Step 2: 構造 AskUserQuestion 參數

每個決策點對應 `questions` array 中的一個 item：

{
  "question": "完整問句，結尾帶問號",
  "header": "≤12字標籤",
  "multiSelect": false,
  "options": [
    {
      "label": "✨ 選項名稱 (Recommended)",
      "description": "一句說明\n😃：...\n😫：..."
    },
    {
      "label": "選項名稱",
      "description": "一句說明\n😃：...\n😫：..."
    }
  ]
}

### Step 3: 選項描述格式

每個 `description` 遵循三行格式：

{一句話說明這是什麼}
😃：{pros}
😫：{cons}

- 第一行：說明，一句話
- 第二行：😃 獨立一行
- 第三行：😫 獨立一行
- 沒有明顯缺點可寫「😫：無明顯缺點」
- 推薦項的 label 前加 `✨`，尾端加 ` (Recommended)`

### Step 4: Preview（可選）

當選項是具體 artifact（UI mockup、code snippet、config 範例）時，用 `markdown` 欄位：

{
  "label": "✨ 方案 A (Recommended)",
  "description": "說明\n😃：...\n😫：...",
  "markdown": "```python\ndef example():\n    ...\n```"
}

### Step 5: 處理回答

- 用戶選了推薦項 → 直接執行
- 用戶選了其他項 → 按選擇執行，不質疑
- 用戶選了 Other 並打字 → 理解意圖後執行或追問
- 用戶加了 notes → 把 notes 納入執行考量

## Common Mistakes

| Mistake | Why it fails | Fix |
|---------|-------------|-----|
| 遇到多方案時直接選一個做 | 用戶失去控制權，可能做錯方向 | 任何 ≥ 2 方案必問 |
| 每個決策點分開問 | 打斷節奏，用戶要回答 5 次 | Tab 分組一次問完 |
| 選項只有標題沒有說明 | 用戶缺乏判斷依據 | 必帶說明 + 😃/😫 |
| 沒標推薦選項 | 用戶要花時間自己分析優劣 | 每題必標 ✨ Recommended |
| 😃/😫 跟說明擠同一行 | 不好掃讀 | 😃 和 😫 各自獨立一行 |
| header 太長 | UI 顯示截斷 | ≤ 12 字元 |
| 只有一種做法也硬問 | 浪費用戶時間 | 直接做，不為問而問 |
```

### Step 3: 驗證

```bash
cat .claude/skills/structured-questions/SKILL.md | head -5
```

確認輸出為 YAML frontmatter（`---` 開頭，含 `name: structured-questions`）。

### Done

回報：「structured-questions skill 已安裝至 `.claude/skills/structured-questions/SKILL.md`。觸發方式：自動（遇到多選項決策）或手動輸入 `$structured-questions`。」

---

## Section B: Codex CLI 安裝

> **與 Claude Code 版的差異**：Codex 的 `ask_user_question` 工具僅在 Plan mode 可用。
> 此版本會自動偵測 mode——Plan mode 用互動式 UI，其他 mode 用純文字選項格式。

### Step 1: 建立目錄

```bash
mkdir -p .codex/skills/structured-questions
```

### Step 2: 寫入 SKILL.md

Create the file `.codex/skills/structured-questions/SKILL.md` with the following content:

```markdown
---
name: structured-questions
description: >-
  Use when facing multiple options or design decisions that need user input.
  Presents structured choice prompts with grouped questions, recommended tags,
  and option trade-offs. Works in any mode — uses ask_user_question tool in
  Plan mode, falls back to formatted text output in other modes.
  Triggers on "ask user", "structured questions", "提問格式".
---

# Structured Questions — 結構化提問規範

## Quick Reference

遇到多個可行方案時，**必須結構化提問**，不自行決定。

1. 多決策點 → 分組一次問完（最多 2-4 題）
2. 每題必標 ✨ 推薦選項
3. 每個選項帶 **標題 + 說明 + 😃/😫**
4. 選項數 2-4 個
5. 有具體 artifact 可比較時附 code preview

觸發條件：任何存在 ≥ 2 個可行方案的決策點。

## Mode Detection — 根據當前 mode 選擇輸出方式

**Step 0: 檢查 `ask_user_question` tool 是否可用。**

- **可用**（Plan mode）→ 走 Path A: Tool UI
- **不可用**（其他 mode）→ 先提示用戶切換，再走 fallback

### 不可用時的處理流程

1. **先提示用戶**：輸出以下訊息——

   > 💡 建議先輸入 `/plan` 切換到 Plan mode，可以獲得互動式選項 UI。
   > 如果不方便切換，我會用文字格式列出選項，你回覆編號即可。

2. **不等用戶切換，直接走 Path B: Text Fallback** 繼續輸出問題。
   - 如果用戶看到提示後決定切 `/plan`，下一輪自然會走 Path A。
   - 不要因為等用戶切 mode 而卡住流程。

## When to Use

| 場景 | 觸發 | 說明 |
|------|------|------|
| 架構 / 技術選型 | ✅ | DB schema、API 設計、module 結構、第三方選擇 |
| 命名 / 慣例 | ✅ | 變數名、branch name、file placement |
| 實作策略 | ✅ | TDD 順序、拆 PR 策略、並行 vs 序列 |
| 範圍取捨 | ✅ | MVP vs 完整版、edge case 處理範圍 |
| 任何多選項決策 | ✅ | 上述未列但存在 ≥ 2 可行方案的情境 |
| 只有一種合理做法 | ❌ | 不要為問而問，直接做 |
| 純執行步驟確認 | ❌ | 用文字說明即可 |

## When NOT to Use

- 只有一種合理做法 → 直接執行
- 用戶已在指令中明確指定做法 → 遵從不問
- 純狀態回報 / 進度更新 → 用文字輸出

## Execution Flow

### Step 1: 識別決策點

掃描當前任務，列出所有需要用戶決定的點。

✅ DO: 把相關的決策點分組，一次問完
❌ DON'T: 每個小問題分開問，打斷用戶節奏

### Step 2: 輸出問題

---

#### Path A: Tool UI（Plan mode — `ask_user_question` 可用時）

每個決策點對應 `questions` array 中的一個 item：

{
  "question": "完整問句，結尾帶問號",
  "header": "≤12字標籤",
  "multiSelect": false,
  "options": [
    {
      "label": "✨ 選項名稱 (Recommended)",
      "description": "一句說明\n😃：...\n😫：..."
    },
    {
      "label": "選項名稱",
      "description": "一句說明\n😃：...\n😫：..."
    }
  ]
}

規則：
- `header` ≤ 12 字元，中文優先
- 推薦項的 label 前加 `✨`，尾端加 ` (Recommended)`，放第一個
- 選項數 2-4 個，不含 Other（系統自動加）
- 有具體 artifact 時用 `markdown` 欄位附 code preview

---

#### Path B: Text Fallback（其他 mode — `ask_user_question` 不可用時）

用以下純文字格式輸出，然後**停下來等用戶回覆**：

---
### Q1: {問題標題}
{完整問句}

  ✨ A) {推薦選項名稱} (Recommended)
     {一句說明}
     😃：{pros}
     😫：{cons}

  B) {選項名稱}
     {一句說明}
     😃：{pros}
     😫：{cons}

  C) {選項名稱}
     {一句說明}
     😃：{pros}
     😫：{cons}

  D) Other（請說明）

---
### Q2: {問題標題}
...
---

請回覆各題的選項編號（例如 Q1: A, Q2: B），或直接說明你的想法。

規則：
- 推薦項前加 `✨` 並標 `(Recommended)`，放第一個
- 最後一個選項固定是 `Other（請說明）`
- 結尾必須加回覆引導句
- 有具體 artifact 時在選項下方附 fenced code block

---

### Step 3: 選項描述格式（兩個 Path 共用）

每個選項的說明遵循三行格式：

{一句話說明這是什麼}
😃：{pros}
😫：{cons}

- 第一行：說明，一句話
- 第二行：😃 獨立一行
- 第三行：😫 獨立一行
- 沒有明顯缺點可寫「😫：無明顯缺點」

### Step 4: 處理回答

- 用戶選了推薦項 → 直接執行
- 用戶選了其他項 → 按選擇執行，不質疑
- 用戶選了 Other 並打字 → 理解意圖後執行或追問
- 用戶加了 notes → 把 notes 納入執行考量

## Common Mistakes

| Mistake | Why it fails | Fix |
|---------|-------------|-----|
| 遇到多方案時直接選一個做 | 用戶失去控制權，可能做錯方向 | 任何 ≥ 2 方案必問 |
| 每個決策點分開問 | 打斷節奏，用戶要回答 5 次 | 分組一次問完 |
| 選項只有標題沒有說明 | 用戶缺乏判斷依據 | 必帶說明 + 😃/😫 |
| 沒標推薦選項 | 用戶要花時間自己分析優劣 | 每題必標 ✨ Recommended |
| 😃/😫 跟說明擠同一行 | 不好掃讀 | 😃 和 😫 各自獨立一行 |
| 非 Plan mode 硬呼叫 ask_user_question | 工具不可用，報錯中斷 | 偵測 mode，走 Text Fallback |
| 只有一種做法也硬問 | 浪費用戶時間 | 直接做，不為問而問 |
```

### Step 3: 驗證

```bash
cat .codex/skills/structured-questions/SKILL.md | head -5
```

確認輸出為 YAML frontmatter（`---` 開頭，含 `name: structured-questions`）。

### Done

回報：「structured-questions skill 已安裝至 `.codex/skills/structured-questions/SKILL.md`。觸發方式：自動（遇到多選項決策）或手動輸入 `$structured-questions`。Plan mode 使用互動式 UI；其他 mode 使用文字選項格式。」

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
