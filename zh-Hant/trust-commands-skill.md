# Trust Commands — 把常用指令加進白名單，AI 不再每次都問

**適用工具**: Claude Code / Codex CLI
**安裝指南**: [trust-commands-install.md](./trust-commands-install.md)
**性質**: 可選額外 skill（不在核心三件套的自動安裝內，想要再單獨裝）

---

## 這個 Skill 解決什麼問題？

你開了 **Accept Edits**（Codex 的 **Auto**）之後，改檔不再一直被打斷了。但只要 AI 要跑 shell 指令，還是每次都跳出來問你「要執行 `git status` 嗎？」——同一批指令一天被問幾十次。

**白名單**就是解法：告訴 AI「這幾個指令我永遠信任，別再問」。但一條條手動加很煩，而且要自己記得格式、自己判斷哪些安全。

這個 skill 做三件事：

1. **讀你最近的指令紀錄**，統計最常用的前 10–15 個。
2. **幫你分類**：哪些安全可加、哪些會寫檔要你自己決定、哪些危險絕不能加。
3. **列清單讓你逐條確認**後，才寫進設定——絕不偷偷加。

---

## Before / After 對比

**Before — 同一個指令一直被問：**

```
AI：要執行 `git status` 嗎？        你：（按同意）
AI：要執行 `git diff` 嗎？          你：（按同意）
AI：要執行 `npm run test` 嗎？      你：（又按同意）
...（一天下來按了幾十次一模一樣的同意）
```

**After — 常用又安全的指令一次放行：**

```
你：/trust-commands
AI：我看了你最近的指令，最常用又安全的有這些，要加進白名單嗎？
    ✅ git status（42 次）✅ git diff（31 次）✅ npm run test（18 次）
    ✏️ git commit（15 次，會寫 commit，要加嗎？）
    ⛔ rm -rf（6 次，危險，不建議加）
你：前三個加、git commit 也加
AI：已寫進 ~/.claude/settings.json，之後這幾個不會再問你。
```

---

## 安全分類（skill 怎麼判斷）

| 類別 | 例子 | 動作 |
|---|---|---|
| ✅ 安全（唯讀／日常） | `git status`、`git diff`、`ls`、`grep`、`npm run *`、`pytest` | 預設建議加入 |
| ✏️ 會寫檔 | `git add`、`git commit`、`mkdir`、`touch` | 列出、標註，讓你自己勾 |
| ⛔ 危險 | `rm`、`sudo`、`curl … \| sh`、`git push --force` | 絕不主動加；堅持要加會先警告風險 |

---

## 一個重要提醒：複合指令還是會問

就算 `git status` 已加白名單，AI 一跑 `git status && npm test`，只要 `npm test` 沒加，**整串還是會問你**。因為白名單是「逐個子指令」比對——一串裡任何一個沒信任就停。

想少被問，兩條路：

- **讓 AI 一條指令做一件事**（最推薦，也最容易看懂它每步在幹嘛）
- 或把串裡每個子指令都加進白名單

---

## Claude Code vs Codex 差異

| | Claude Code | Codex CLI |
|---|---|---|
| 白名單機制 | 有——`~/.claude/settings.json` 的 `permissions.allow`，逐條 `Bash(指令:*)` | **沒有逐條白名單** |
| 這個 skill 怎麼做 | 讀常用指令 → 寫 allow 規則 | 讀常用指令 → 切到 **Auto 模式**（`~/.codex/config.toml` 設 `approval_policy="on-request"`、`sandbox_mode="workspace-write"`） |
| 放行範圍 | 你勾選的那幾個指令 | 整個「工作資料夾內」的指令；連網／跨出資料夾仍問 |
| 手動觸發 | `/trust-commands` | `$trust-commands` |
| 進階細部控制 | 更精確的前綴規則 | `codex execpolicy` 規則檔 |

---

## 安裝

想加這個可選 skill，把下面這句貼給 AI：

```
Read jr_ai_agent_skills/zh-Hant/trust-commands-install.md and install this optional skill for me.
```

詳細步驟見 [trust-commands-install.md](./trust-commands-install.md)。
