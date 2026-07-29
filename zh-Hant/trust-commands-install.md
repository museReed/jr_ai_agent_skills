# Trust Commands Skill — 安裝指南（可選額外 skill）

Read this document, then execute the copy steps for the user's tool. Do not ask for confirmation on the copy itself — just install it. **安裝 = 把 SKILL.md 複製到位；skill 要開新 session 才會載入。**

這是**可選**額外 skill，不在核心三件套（auto-rename / handoff / structured-questions）的 `install.sh` 自動安裝內。功能介紹見 [trust-commands-skill.md](./trust-commands-skill.md)。

> 適用：Claude Code / Codex CLI（macOS / Linux）
> 需求：bash。（要真的寫白名單時另需 python3 改 JSON——skill 執行時才用到，安裝本身不需要。）

---

## 這個 skill 做什麼

讀你最近的 shell 指令紀錄 → 挑出最常用又安全的 → 逐條確認後：

- **Claude Code**：把 `Bash(指令:*)` 規則寫進 `~/.claude/settings.json` 的 `permissions.allow`
- **Codex**：切到 Auto 模式（`~/.codex/config.toml` 設 `approval_policy` / `sandbox_mode`）——Codex 沒有逐條白名單

---

## Section A: Claude Code 安裝

```bash
cd jr_ai_agent_skills/installer
mkdir -p "$HOME/.claude/skills/trust-commands"
cp -R skills/claude/trust-commands/. "$HOME/.claude/skills/trust-commands/"
```

裝到 `~/.claude/skills/trust-commands/SKILL.md`，手動觸發用 `/trust-commands`。

## Section B: Codex CLI 安裝

```bash
cd jr_ai_agent_skills/installer
mkdir -p "$HOME/.agents/skills/trust-commands"
cp -R skills/codex/trust-commands/. "$HOME/.agents/skills/trust-commands/"
```

裝到 `~/.agents/skills/trust-commands/SKILL.md`，手動觸發用 `$trust-commands`。

> 兩個工具都要 → 兩段都跑。

---

## 驗證

- 檔案就位：`ls ~/.claude/skills/trust-commands/SKILL.md`（Codex 換 `~/.agents/skills/...`）應存在。
- 功能驗證（開**新** session）：
  - Claude：輸入 `/trust-commands`，應該讀你的指令紀錄、列出「建議加入」清單並**停下來等你確認**（不會自己寫）。
  - Codex：輸入 `$trust-commands`，應該列出常用指令、說明要在 `config.toml` 改哪兩個 key、等你確認。
- 加完白名單後，再叫 AI 跑一個你剛加的指令（例如 `git status`），確認**不再跳出詢問**。

## 安全檢查（這個 skill 特別重要）

- skill **絕不主動**把 `rm`、`sudo`、`curl … | sh`、`git push --force` 加進白名單。
- 若你要求加危險指令，它會先警告風險並要求二次確認。
- 寫入前一定先列清單、先備份設定檔；只 append + 去重，不覆蓋你原有規則。
