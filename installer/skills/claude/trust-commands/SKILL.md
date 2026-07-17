---
name: trust-commands
description: >-
  Use when the user is tired of approving the same shell commands over and over.
  Scans recent shell history, ranks the most-used commands, filters out dangerous
  ones, and (after the user confirms) adds the safe ones to the Claude Code
  allowlist in ~/.claude/settings.json so they stop asking.
  Triggers on "加白名單", "trust commands", "不要每次都問", "allowlist".
user-invocable: true
---

# Trust Commands — 把常用指令加進白名單，不再每次都問

## Quick Reference

目標：讓 Claude Code 在 **Accept Edits** 模式下，對你信任的常用指令直接放行。

1. 讀最近的 shell 指令紀錄，統計最常用的前 10–15 個
2. **分類**：安全（可加）／要寫檔（提醒）／危險（絕不加）
3. **列清單讓用戶逐條確認**——絕不自己偷偷寫入
4. 用 `Bash(指令:*)` 格式，加到 `~/.claude/settings.json` 的 `permissions.allow`（去重，不重複既有規則）
5. 收尾提醒：複合指令（`a && b`）每個子指令都要各自在白名單才不會問

觸發條件：用戶抱怨「一直被問同樣的指令」「幫我加白名單」「不要每次都問」。

## When to Use

| 場景 | 觸發 | 說明 |
|------|------|------|
| 一直批准同一批指令 | ✅ | `git status`、`ls`、`npm run test` 之類反覆出現 |
| 剛開 Accept Edits，想少被打斷 | ✅ | 把安全常用指令一次放行 |
| 想檢視／清理現有白名單 | ✅ | 列出目前 allow 規則，找出多餘或過寬的 |
| 用戶要求放行危險指令 | ⚠️ | 明確警告風險，要求二次確認，預設不加 |
| 一次性、不會再用的指令 | ❌ | 加進白名單沒意義 |

## When NOT to Use

- 用戶還沒開 Accept Edits → 先建議切模式（Shift+Tab），白名單才有感
- 指令會刪檔／連外／提權 → 不主動加，只在用戶堅持且理解風險時處理
- 用戶只是想跑一次某指令 → 直接跑，不需動白名單

## Execution Flow

### Step 1: 抓指令紀錄

依序嘗試，取到為止：

- zsh：`~/.zsh_history`
- bash：`~/.bash_history`
- 或請用戶貼上 `history | tail -100` 的輸出

統計每個「指令 + 第一個子命令」的出現次數，取前 10–15 名。

### Step 2: 安全分類

| 類別 | 例子 | 動作 |
|------|------|------|
| ✅ 安全（唯讀／日常） | `git status`、`git diff`、`git log`、`ls`、`cat`、`grep`、`rg`、`find`、`pwd`、`tree`、`npm run *`、`pytest` | 預設建議加入 |
| ✏️ 會寫檔 | `git add`、`git commit`、`mkdir`、`touch`、`git checkout` | 列出並標註，讓用戶自己勾 |
| ⛔ 危險（絕不主動加） | `rm`、`rmdir`、`mv`、`sudo`、`curl … \| sh`、`wget`、`dd`、`chmod 777`、`git push --force`、`git reset --hard`、`kill`、`> /系統路徑` | 不加；若用戶堅持，先警告風險再二次確認 |

### Step 3: 列清單確認

用結構化清單呈現，標好每條的類別與建議：

```
建議加入白名單（你確認要哪些）：
  ✅ Bash(git status:*)      出現 42 次 · 唯讀
  ✅ Bash(git diff:*)        出現 31 次 · 唯讀
  ✅ Bash(npm run test:*)    出現 18 次 · 測試
  ✏️ Bash(git commit:*)     出現 15 次 · 會寫 commit（要加嗎？）
  ⛔ rm -rf …                出現 6 次 · 危險，不建議加
```

等用戶回覆要加哪些，才進 Step 4。

### Step 4: 寫入 settings.json

- 讀 `~/.claude/settings.json`，先備份
- 在 `permissions.allow` 陣列**附加**用戶勾選的規則，跳過已存在的
- 用 `python3 -c` 或直接編輯，保持 JSON 格式與縮排
- 寫完把最終 `allow` 清單列給用戶確認

### Step 5: 收尾提醒

一句話講清楚複合指令的雷：

> 注意：白名單是「逐個子指令」比對。就算 `git status` 已加，跑 `git status && npm test` 只要 `npm test` 沒加還是會問。想少被問，讓 AI「一條指令做一件事」，或把每個子指令都加進來。

## Common Mistakes

| Mistake | Why it fails | Fix |
|---------|-------------|-----|
| 不問就直接寫 settings.json | 用戶失去對信任範圍的控制 | 一律先列清單、等確認 |
| 把 `rm`、`sudo`、`curl \| sh` 加進去 | 等於讓 AI 無聲執行破壞性／連外指令 | 危險類絕不主動加 |
| 加 `Bash(git *)` 這種超寬規則當預設 | 信任範圍過大，學生無感風險 | 預設用精確前綴，寬規則要用戶明確要求 |
| 覆蓋掉既有 allow 規則 | 洗掉用戶原本的設定 | 只 append + 去重，並先備份 |
| 忘了講複合指令的雷 | 用戶加完還是被問，以為沒生效 | Step 5 一定要提醒 |
| 在 Manual 模式加白名單卻沒提切模式 | 白名單有加但體感沒差 | 先建議 Shift+Tab 開 Accept Edits |
