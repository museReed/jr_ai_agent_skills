# Auto-Rename — 讓每個 AI Session 都有自己的名字

**適用工具**: Claude Code / Codex CLI
**安裝指南**: [auto-rename-install.md](./auto-rename-install.md)

---

## 這個 Skill 解決什麼問題？

你有沒有遇過這種情況——

你開了好幾個 AI 對話視窗，每個 tab 都叫同一個名字。你想切回剛剛在做的那個，結果要一個一個點開來確認。開越多越混亂，最後乾脆全部關掉重來。

這個 skill 做一件事：

1. **讓 AI 自動幫每個 session 取一個看得懂的名字。** 根據你們在聊什麼，AI 會自動用 emoji + 中文敘述命名（例如「🏗️ voice profile pipeline」），你從 tab 列表一眼就能找到要的那個。

---

## Before / After 對比

### 價值：Tab 太多，找不到你要的 session

> 不管開幾個 session，每個都有名字，一眼就知道哪個在做什麼。

---

#### 場景 A：開了好幾個 AI 對話，全部叫一樣的名字

**Before — 你得一個一個點開確認：**

```
你的 tab 列表：
  [New chat]  [New chat]  [New chat]  [New chat]  [New chat]

你：（哪個是剛剛在討論食譜的？）
你：（點開第一個——不是，這個在聊旅遊）
你：（點開第二個——也不是，這個在問健身）
你：（點開第三個——終於找到了）
```

問題：開 5 個對話就要猜 5 次，開 10 個就放棄了。

**After — 每個對話自動有名字：**

```
你的 tab 列表：
  [🔍 京都五日行程]  [🏗️ 減脂菜單規劃]  [💬 健身課表討論]  [📐 側邊欄 UI]  [🐛 登入錯誤排查]

你：（一眼找到「京都五日行程」，點開繼續）
```

差異：不用猜、不用點開確認，tab 名字就是內容摘要。

---

#### 場景 B：上班時開了多個 AI 助手，分不清哪個在做什麼

**Before — sidebar 全部長一樣：**

```
Codex sidebar：
  muse-platform  (3 minutes ago)
  muse-platform  (15 minutes ago)
  muse-platform  (1 hour ago)

你：（15 分鐘前那個是在寫簡報還是整理會議紀錄？）
你：（只能靠時間猜，猜錯就浪費時間）
```

問題：同一個專案開多個 session，sidebar 顯示的都是專案名，毫無區別。

**After — 每個 session 自動命名：**

```
Codex sidebar：
  📐 Q3 簡報架構  (3 minutes ago)
  📋 週會紀錄整理  (15 minutes ago)
  🔍 競品分析      (1 hour ago)

你：（直接點「週會紀錄整理」繼續）
```

差異：不用靠時間推測內容，名字就說明了一切。

---

#### 場景 C：開了多個 Claude Code session，terminal tab 全部顯示 branch 名

**Before — 4 個 tab 全部顯示 `develop`：**

```
Terminal tabs：
  [develop]  [develop]  [develop]  [develop]

你：（哪個在跑 TDD？哪個在 debug？哪個在寫 PRD？）
你：（切到第三個——啊不是，這個在做 PR review）
```

問題：branch 名不能告訴你「這個 session 在做什麼」。

**After — 每個 tab 自動命名：**

```
Terminal tabs：
  [🏗️ voice profile pipeline]  [🐛 Gemini 429 debug]  [📐 PRD2 設計]  [📋 PR review]

你：（直接切到「Gemini 429 debug」繼續排查）
```

差異：tab 名從「你在哪個 branch」變成「你在做什麼事」。

---

#### 場景 D：同一個 repo 開 3 個 Codex session，做不同的事

**Before — sidebar 完全無法區分：**

```
Codex sidebar：
  muse-platform  (just now)
  muse-platform  (5 minutes ago)
  muse-platform  (20 minutes ago)

你在做三件事：
  1. 修 crawler 的重試邏輯（5 分鐘前那個）
  2. 寫新的 voice pipeline（20 分鐘前那個）
  3. 剛開的要做 code review

你：（每次都要靠記憶對應時間，記錯就切錯 session）
```

**After — 每個 session 手動或自動命名：**

```
Codex sidebar：
  📋 crawler PR review     (just now)
  🔧 爬蟲重試邏輯          (5 minutes ago)
  🏗️ voice pipeline 建模   (20 minutes ago)

你：（直接點「爬蟲重試邏輯」繼續修 bug）
```

差異：不再靠記憶配對「幾分鐘前 = 哪件事」。

---

## 怎麼觸發？

| 方式 | Claude Code | Codex CLI |
|---|---|---|
| **自動觸發** | Hook 在第 5 次 tool call 時自動提醒 AI 命名 | 無自動觸發 |
| **手動觸發** | 輸入 `/auto-rename` | 輸入 `$auto-rename` |
| **關鍵字** | 對話中說「改名」「命名」「rename」 | 同左 |

## 適用場景

| 場景 | 你遇到的情況 | AI 怎麼幫你 |
|---|---|---|
| **多 session 同時開** | Tab / sidebar 全部長一樣，切換時要猜 | 自動用 emoji + 中文命名每個 session |
| **Session 主題改變** | 一開始在 debug，後來變成 refactor，名字過時了 | 手動 `/auto-rename` 重新命名 |
| **交接前標記** | 想標記哪些 session 已經結束 | 搭配 `/handoff` 自動加上 📦 前綴 |

## 不適用的情況

- Session 剛開始（< 3 輪對話）→ 資訊不足，等多聊幾句再命名
- 你已經手動取了滿意的名字 → AI 不會覆蓋

---

## 安裝

同一段 prompt 可貼給 Claude Code 或 Codex；AI 會偵測工具、確認 terminal／IDE，並一次安裝三個核心 skills：

```
Read jr_ai_agent_skills/zh-Hant/auto-rename-install.md and guide me through its single installation flow.
```

詳細步驟見 [auto-rename-install.md](./auto-rename-install.md)。

---

## Claude Code vs Codex 差異

| | Claude Code | Codex CLI |
|---|---|---|
| 自動觸發 | 有（PostToolUse hook 在第 5 次 tool call 觸發） | 無 |
| 命名方式 | 寫檔案 `~/.claude/session-names/${PID}.txt` | 寫 SQLite `~/.codex/state_*.sqlite` |
| Terminal tab 同步 | 直接發 OSC escape 改 tab title | 需用 `mycodex` wrapper 啟動才會同步 |
| 安裝位置 | `.claude/skills/auto-rename/SKILL.md` | `.agents/skills/auto-rename/SKILL.md` |
| 手動觸發 | `/auto-rename` | `$auto-rename` |
