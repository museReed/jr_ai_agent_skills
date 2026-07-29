---
name: trust-commands
description: >-
  Use when the user is tired of approving the same shell commands over and over.
  Codex has no per-command allowlist file, so this scans recent shell history,
  ranks the most-used commands, and (after the user confirms) switches Codex to
  Auto mode in ~/.codex/config.toml so workspace commands run without asking.
  Triggers on "加白名單", "trust commands", "不要每次都問", "allowlist".
user-invocable: true
---

# Trust Commands — 讓 Codex 不再每次都問常用指令

## Quick Reference

Codex **沒有逐條白名單檔**（不像 Claude Code 的 `settings.json`）。控制「問不問」的是**模式**：`approval_policy` + `sandbox_mode`。所以這個 skill 的做法是：分析你常用哪些指令，然後幫你切到 **Auto 模式**，讓工作區內的指令自動跑。

1. 讀最近的 shell 指令紀錄，統計最常用的前 10–15 個
2. **分類**：安全／會寫檔／危險——確認你的常用指令多半落在安全區
3. **說明要改什麼、列出要寫的 config，等用戶確認**——絕不自己偷偷改
4. 在 `~/.codex/config.toml` 設 `approval_policy = "on-request"`、`sandbox_mode = "workspace-write"`（＝ Auto）
5. 收尾提醒：Auto 只在「工作資料夾內」自動跑；連網、跨出資料夾仍會問——這是保護

觸發條件：用戶抱怨「一直被問同樣的指令」「幫我加白名單」「不要每次都問」。

## When to Use

| 場景 | 觸發 | 說明 |
|------|------|------|
| 一直批准同一批工作區指令 | ✅ | `git status`、`ls`、`npm run test` 反覆出現 |
| 想對標 Claude 的 Accept Edits | ✅ | Auto 就是 Codex 的對應模式 |
| 想確認目前是哪個 approval 模式 | ✅ | 讀 config.toml 回報現況 |
| 想放行連網／全自動 | ⚠️ | 那是 Full Access（危險），只在拋棄式環境，且要二次確認 |
| 一次性、不會再用的指令 | ❌ | 不需動 config |

## When NOT to Use

- 用戶要的是「逐條」白名單 → 說明 Codex 沒有這機制，只有模式；進階可談 `codex execpolicy` 規則檔
- 用戶想連網也自動 → 那是 Full Access，預設不建議，改在 Docker／拋棄式 VM 才考慮
- 只是想跑一次某指令 → 直接跑並在提示時批准即可

## Execution Flow

### Step 1: 抓指令紀錄

依序嘗試：`~/.zsh_history` → `~/.bash_history` → 請用戶貼 `history | tail -100`。
統計「指令 + 第一個子命令」出現次數，取前 10–15 名。

### Step 2: 安全分類

| 類別 | 例子 | 意義 |
|------|------|------|
| ✅ 安全（唯讀／日常） | `git status`、`git diff`、`ls`、`cat`、`grep`、`npm run *`、`pytest` | Auto 下會在工作區自動跑 |
| ✏️ 會寫檔 | `git add`、`git commit`、`mkdir`、`touch` | Auto 下也會自動跑（限工作區內） |
| ⛔ 危險 | `rm -rf`、`sudo`、`curl … \| sh`、`git push --force` | Auto **不會**擋這些字面；靠 sandbox 限制在工作區。真正危險操作仍要你自己把關 |

確認用戶的常用指令多數是安全／寫檔類，Auto 才適合。

### Step 3: 說明並確認

明確告訴用戶會改什麼，列出將寫入的內容，**停下來等確認**：

```
Codex 沒有逐條白名單，改用「模式」一次放行工作區。
建議切到 Auto，會在 ~/.codex/config.toml 寫入：

  approval_policy = "on-request"
  sandbox_mode    = "workspace-write"

效果：工作資料夾內的指令（含你最常用的 git / ls / npm）自動跑，
只有要連網或跨出這個資料夾時才問你。要我改嗎？
```

### Step 4: 寫入 config.toml

- 讀 `~/.codex/config.toml`（不存在就建立），先備份
- 設 `approval_policy = "on-request"`、`sandbox_mode = "workspace-write"`（存在就更新，不重複整段）
- 保持既有其他設定不動
- 或提示用戶當場用 `/approvals auto` 切換（不寫檔、只當前 session）

### Step 5: 收尾提醒

> Auto 的界線是「工作資料夾」：裡面自動跑，連網或跨出去才問——這是保護，不是麻煩。
> 想要逐個指令的細緻控制（進階），可以用 `codex execpolicy` 規則檔，但一般同學用 Auto 就夠。

## Common Mistakes

| Mistake | Why it fails | Fix |
|---------|-------------|-----|
| 假裝 Codex 有逐條白名單、去編一個檔 | Codex 不吃那種 key，設了無效 | 用 `approval_policy` + `sandbox_mode` 模式控制 |
| 不問就改 config.toml | 用戶失去對信任範圍的控制 | 先列要寫的內容、等確認 |
| 直接建議 Full Access 求方便 | 連網＋全自動，風險高 | 預設 Auto；Full Access 只在拋棄式環境且二次確認 |
| 改 config 時洗掉其他設定 | 破壞用戶既有 config | 只更新這兩個 key，先備份 |
| 沒講 Auto 的「工作區」界線 | 用戶誤以為什麼都自動了 | Step 5 講清楚界線與保護意義 |
