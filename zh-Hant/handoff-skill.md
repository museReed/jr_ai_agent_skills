# Handoff — 讓 AI 幫你寫交接文件，下個 Session 不用從頭來

**適用工具**: Claude Code / Codex CLI
**安裝指南**: [handoff-install.md](./handoff-install.md)

---

## 這個 Skill 解決什麼問題？

你有沒有遇過這種情況——

你跟 AI 聊了很久，討論了很多細節、試了很多方法、做了很多決定。結果 session 關掉之後，下一個 session 完全不知道之前發生過什麼。你得從頭解釋一遍背景、重新說明需求、再把之前試過但沒用的方法又走一遍。

這個 skill 做兩件事：

1. **讓 AI 在 session 結束前，自動整理一份交接文件。** 包含：做了什麼、做到哪裡、下一步要做什麼、哪些檔案要讀。新 session 讀完這份文件就能無縫接手，不用你重新解釋。

2. **在 context 快滿的時候提醒你。** AI 不會等到突然斷掉才告訴你，而是提前警告「快滿了，我先寫交接文件」，讓你優雅地切換到新 session。

---

## Before / After 對比

### 價值一：開新 Session 後，不用從頭來

> 每次開新 session 都能從上次結束的地方繼續，不用重新解釋背景。

---

#### 場景 A：跟 AI 討論旅遊行程，關掉後要從頭講

**Before — 新 session 什麼都不知道：**

```
（上一個 session：討論了 30 分鐘京都行程，決定了住宿區域、交通方案、每天景點）

你：（隔天打開新對話）
你：我們昨天討論的京都行程，幫我繼續排第三天
AI：你好！請問你的京都行程是幾天？住哪裡？有什麼偏好？
你：（嘆氣，從頭講一遍）
```

問題：AI 不記得上次的對話，你得重新交代所有背景。

**After — 新 session 讀完交接文件就能接手：**

```
（上一個 session 結束前，AI 自動產出交接文件）

你：讀 docs/handoff/2026-06-30-kyoto-trip.md 繼續工作
AI：（讀完交接文件）
AI：好，上次決定了住四條河原町、買巴士一日券、第一天清水寺+祇園、
    第二天嵐山。接下來排第三天，你想去伏見稻荷還是金閣寺？
```

差異：不用重新解釋，AI 直接從上次結束的地方接續。

---

#### 場景 B：寫企劃書改了三輪，隔天打開新 session 又要重頭

**Before — 三輪修改的歷史全部遺失：**

```
（上一個 session：寫了企劃書初稿 → 主管反饋改了結構 → 又調了預算表）

你：（隔天）繼續修改企劃書
AI：好的，請問企劃書的主題是什麼？目前進度如何？
你：（要重新描述主題、結構、預算、主管的三輪反饋...）
```

**After — 所有修改歷史都在交接文件裡：**

```
你：讀 docs/handoff/2026-06-30-proposal-v3.md 繼續
AI：（讀完）企劃書已到第三版，主管反饋的預算調整已完成。
    下一步是加上 ROI 分析。要從這裡接續嗎？
```

差異：三輪修改的決策和原因都保留了，不用重新交代。

---

#### 場景 C：Debug 到一半 context 滿了，新 session 不知道試過哪些方法

**Before — 白走一遍已經排除的方向：**

```
（上一個 session：花了 45 分鐘 debug，排除了 3 種可能，鎖定到第 4 種）

你：（context 滿了，開新 session）
你：API 回傳 500 error，幫我 debug
AI：好的，讓我們從頭排查。首先檢查 request payload...
你：（這個我已經查過了！！！）
```

問題：新 session 從零開始，把已經排除的方向又走一遍。

**After — 交接文件記錄了排查進度：**

```
你：讀 docs/handoff/2026-06-30-api-500-debug.md 繼續
AI：（讀完）已排除：payload 格式、auth token、rate limit。
    目前鎖定在 DB connection pool 耗盡。下一步是看 connection 數量。
    直接從這裡繼續？
```

差異：不重走已排除的路，直接從鎖定的方向繼續。

---

#### 場景 D：跨天開發 feature，每天都要重新講背景

**Before — 每天開工都要花 10 分鐘交代 context：**

```
（昨天：寫完 TDD 的前 8 個 test，全綠。正要開始第 9 個）

你：（今天開新 session）
你：我在做 #1234 的 voice pipeline feature，昨天寫到 test 8，
    用的是 pytest，test file 在 tests/unit/test_voice.py，
    相關的 source code 在 platform/voice/...
AI：好的，讓我先讀一下這些檔案...
你：（又花了 10 分鐘等 AI 重新理解 codebase）
```

**After — 交接文件就是今天的啟動指令：**

```
你：讀 docs/handoff/2026-06-29-voice-pipeline-tdd.md 繼續
AI：（讀完）Issue #1234，TDD Phase 2。Test 1-8 全綠。
    下一步：寫 Test 9（Scenario: 空白 transcript 的 fallback）。
    需要讀的檔案：tests/unit/test_voice.py（看已有 test 的 pattern）、
    platform/voice/src/muse_voice/pipeline.py（實作對象）。
```

差異：交接文件就是「今天從哪裡開始」的完整指令，不用自己回想。

---

### 價值二：Context 快滿時優雅收尾，不會突然斷掉

> AI 提前警告「快滿了」，寫好交接再結束——不是等到斷掉才手忙腳亂。

---

#### 場景 E：AI 回覆越來越短，你才發現 context 快滿了

**Before — 沒有預警，突然就斷了：**

```
你：幫我把這個函數重構一下
AI：好

你：...就這樣？
AI：抱歉，由於上下文限制，我無法提供完整的回覆...
你：（之前討論的所有 context 都在這個即將關閉的視窗裡）
```

問題：沒有預警，等你發現的時候已經來不及整理了。

**After — 提前警告 + 自動寫交接：**

```
AI：⚠️ Context 已用 ~145k tokens（72%）。我先寫交接文件，
    建議之後開新 session 繼續。

AI：Handoff 已產出：docs/handoff/2026-06-30-refactor-session.md
    Branch: feature/1234-voice-pipeline
    讀 docs/handoff/2026-06-30-refactor-session.md 繼續工作。
```

差異：不會突然斷掉，而是有計畫地收尾。

---

#### 場景 F：做簡報做到一半，AI 突然不能回覆了

**Before — 進度卡在關掉的視窗裡：**

```
（寫了 20 頁簡報，改了 5 輪）

AI：[token limit reached]
你：（那我改到哪一版了？第 12 頁的圖表改了沒？主管的第三輪反饋處理了嗎？）
你：（全部都要自己回想或翻紀錄）
```

**After — 斷掉之前就有完整紀錄：**

```
AI：⚠️ Context 快滿了，我先整理交接文件。

交接文件內容：
- 已完成：第 1-15 頁定稿、第 16-18 頁圖表更新
- 進行中：第 19 頁的 ROI 分析
- 下一步：完成第 19-20 頁 → 全文校稿
```

差異：進度不會隨著視窗關閉而消失。

---

#### 場景 G：跑 TDD 到第 8 個 test，context 滿了

**Before — 不知道哪些 test 過了、哪些沒寫：**

```
你：（開新 session）我在做 voice pipeline 的 TDD，跑到哪了？
AI：請問你的 test file 在哪裡？目前有哪些 test case？
你：（又要從頭交代一遍 TDD 計畫和進度）
```

**After — 交接文件有完整的 TDD 進度：**

```
交接文件：
- Test 1-8：全綠 ✅
- Test 9-12：尚未實作
- 下一步：Test 9（空白 transcript fallback）
- 必讀：TDD Index 在 docs/features/voice/tdd-index.md
```

差異：新 session 知道「8 個過了、從第 9 個開始」。

---

#### 場景 H：PR review 做到一半，context 滿了

**Before — reviewer 的意見散落在關掉的對話裡：**

```
你：（reviewer 提了 5 點，AI 幫你改了 3 點，還有 2 點沒處理）
你：（context 滿了，新 session 不知道哪些改了、哪些沒改）
```

**After — 交接文件追蹤每一點的處理狀態：**

```
交接文件：
- Reviewer 意見 1-3：已修改並 commit ✅
- 意見 4：需要跟 reviewer 確認（等回覆）
- 意見 5：尚未處理（型別定義要改）
- 下一步：處理意見 5 → re-request review
```

差異：review 進度不會因為 context 滿了而遺失。

---

## 怎麼觸發？

| 方式 | Claude Code | Codex CLI |
|---|---|---|
| **自動觸發** | Context 用量 > 70% 時，hook 提醒 AI 寫交接文件 | 無自動觸發 |
| **手動觸發** | 輸入 `/handoff` | 輸入 `$handoff` |
| **關鍵字** | 對話中說「交接」「handoff」「session 結束」 | 同左 |

## 適用場景

| 場景 | 你遇到的情況 | AI 怎麼幫你 |
|---|---|---|
| **Session 要結束** | 今天做到一半，明天要繼續 | 自動產出交接文件，記錄做了什麼、下一步做什麼 |
| **Context 快滿** | AI 回覆變短、hook 警告 token 用量高 | 提前整理交接 + 提示你開新 session |
| **換人接手** | 你做了一半要交給同事的 AI session 繼續 | 交接文件是通用格式，任何新 session 都能讀 |
| **跨天開發** | 每天開新 session 要重新交代背景 | 每天結束前跑 `/handoff`，隔天直接讀文件繼續 |

## 不適用的情況

- 很短的一次性對話 → 沒東西要交接
- 所有工作都在單次 session 內完成 → 不需要跨 session 接續
- 純閒聊 → 不需要結構化記錄

---

## 安裝

一句指令，讓 AI 幫你裝：

**Claude Code：**
```
Read docs/guides/handoff-install.md and execute Section A
```

**Codex CLI：**
```
Read docs/guides/handoff-install.md and execute Section B
```

詳細步驟見 [handoff-install.md](./handoff-install.md)。

---

## Claude Code vs Codex 差異

| | Claude Code | Codex CLI |
|---|---|---|
| 自動觸發 | 有（context-monitor hook 在 70% 時警告） | 無 |
| Session 封存改名 | 寫檔 `~/.claude/session-names/${PID}.txt` + OSC escape | 寫 SQLite `~/.codex/state_*.sqlite` |
| 安裝位置 | `.claude/skills/handoff/SKILL.md` | `.agents/skills/handoff/SKILL.md` |
| 手動觸發 | `/handoff` | `$handoff` |
| 交接文件位置 | `docs/handoff/{date}-{topic}.md`（兩邊相同） | 相同 |
