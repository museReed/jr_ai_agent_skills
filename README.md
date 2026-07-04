# JR AI Agent Skills

> **三語版本 / 三语版本 / Trilingual**：[繁體中文](#繁體中文) · [简体中文](#简体中文) · [English](#english)

---

## 繁體中文

### 這是什麼？

三個 skill + 兩個 hook，讓 Claude Code / Codex CLI 的 session 管理不再靠人肉：

| 部件 | 一句話說明 | 文件 |
|---|---|---|
| **Auto-Rename**（skill + hook） | AI 自動幫每個 session 取名字並同步 terminal tab（Codex 連 sidebar），tab 不再全叫 "New chat" | [介紹](zh-Hant/auto-rename-skill.md) · [安裝](zh-Hant/auto-rename-install.md) |
| **Handoff**（skill + hook） | Session 結束前寫結構化交接文件；context 用到 70% 時 hook 自動催 | [介紹](zh-Hant/handoff-skill.md) · [安裝](zh-Hant/handoff-install.md) |
| **Structured Questions**（skill） | 遇到多個方案時，AI 拆成選擇題問你，不替你決定 | [介紹](zh-Hant/structured-questions-skill.md) · [安裝](zh-Hant/structured-questions-install.md) |

### 怎麼用？（什麼時候會發生、怎麼手動觸發）

| 功能 | 什麼時候自動發生 | Claude Code 手動觸發 | Codex 手動觸發 |
|---|---|---|---|
| Session 命名 | **第一句話之後**就命名；第 5 次 tool call 依討論重新評估；每 10 次兜底重試 | `/auto-rename` 或說「改名」 | `$auto-rename` 或說「改名」 |
| Context 警告 | context 用量 > 70% 時，hook 注入警告叫 AI 寫交接 | —（純自動） | —（純自動；警告有一回合時差） |
| 交接文件 | 被 context 警告觸發時 AI 會主動寫 | `/handoff` 或說「寫 handoff」 | `$handoff` 或說「寫 handoff」 |
| 交接後封存改名 | handoff 寫完自動把 session 改成 `📦 …` | （包含在 handoff 流程內） | （包含在 handoff 流程內） |
| 選擇題提問 | AI 遇到多個可行方案時 | 說「用選擇題問我」 | 說「用選擇題問我」 |

### 支援環境（2026-07-04 全數實測）

| 環境 | Claude Code | Codex CLI | 備註 |
|---|---|---|---|
| macOS + Terminal.app / iTerm | ✅ | ✅ | 原生吃 OSC，零設定 |
| macOS + Cursor terminal | ✅ | ✅ | 需在 Cursor `settings.json` 加 `"terminal.integrated.tabs.title": "${sequence}"` |
| macOS + Antigravity terminal | ✅ | ✅ | 同上（Antigravity 自己的 settings.json） |
| Linux | 未實測 | 未實測 | installer 理論相容，歡迎回報 |
| Windows（PowerShell / Windows Terminal） | 未實測 | 未實測 | 尚未完整測試，workshop 現場曾遇 PowerShell 相容問題——建議先在 macOS/Linux 使用，歡迎回報 |

### 怎麼安裝？

兩步：clone 這個 repo，然後**把下面的 prompt 原封不動貼給你的 AI**（它會自己讀指南、安裝、然後帶你跑完驗證）：

```bash
git clone https://github.com/museReed/jr_ai_agent_skills.git
```

**用 Claude Code 的人，貼這段給 Claude：**
```
Read jr_ai_agent_skills/zh-Hant/auto-rename-install.md and execute Section A,
then follow jr_ai_agent_skills/installer/VERIFICATION.md to walk me through the E2E verification.
```

**用 Codex CLI 的人，貼這段給 Codex：**
```
Read jr_ai_agent_skills/zh-Hant/auto-rename-install.md and execute Section B,
then follow jr_ai_agent_skills/installer/VERIFICATION.md to walk me through the E2E verification.
```

其他 skill 同理，換檔名即可（handoff 建議接著裝：同一個 prompt 把 `auto-rename` 換成 `handoff`）。

### 驗證與除錯

| 要做什麼 | 用哪個 |
|---|---|
| 裝完自動檢查（29 點） | `installer/verify.sh` |
| 引導式 E2E 驗證（AI agent 帶用戶跑四輪，含檢查點編號） | `installer/VERIFICATION.md` |
| 行為不對時查症狀 | `installer/TROUBLESHOOTING.md` |
| 修不掉回報（一個指令自動收證據 + 開 issue） | `installer/diagnose.sh "一句話症狀"` |

之後哪天行為不對，把這段貼給你的 AI 就會自動排查（修不掉會替你準備 issue）：
```
Read jr_ai_agent_skills/installer/TROUBLESHOOTING.md and debug this for me: {一句話描述症狀}
```

---

## 简体中文

### 这是什么？

三个 skill + 两个 hook，让 Claude Code / Codex CLI 的 session 管理不再靠人肉：

| 部件 | 一句话说明 | 文档 |
|---|---|---|
| **Auto-Rename**（skill + hook） | AI 自动帮每个 session 取名字并同步 terminal tab（Codex 连 sidebar），tab 不再全叫 "New chat" | [介绍](zh-Hans/auto-rename-skill.md) · [安装](zh-Hans/auto-rename-install.md) |
| **Handoff**（skill + hook） | Session 结束前写结构化交接文档；context 用到 70% 时 hook 自动催 | [介绍](zh-Hans/handoff-skill.md) · [安装](zh-Hans/handoff-install.md) |
| **Structured Questions**（skill） | 遇到多个方案时，AI 拆成选择题问你，不替你决定 | [介绍](zh-Hans/structured-questions-skill.md) · [安装](zh-Hans/structured-questions-install.md) |

### 怎么用？（什么时候会发生、怎么手动触发）

| 功能 | 什么时候自动发生 | Claude Code 手动触发 | Codex 手动触发 |
|---|---|---|---|
| Session 命名 | **第一句话之后**就命名；第 5 次 tool call 依讨论重新评估；每 10 次兜底重试 | `/auto-rename` 或说「改名」 | `$auto-rename` 或说「改名」 |
| Context 警告 | context 用量 > 70% 时，hook 注入警告叫 AI 写交接 | —（纯自动） | —（纯自动；警告有一回合时差） |
| 交接文档 | 被 context 警告触发时 AI 会主动写 | `/handoff` 或说「写 handoff」 | `$handoff` 或说「写 handoff」 |
| 交接后封存改名 | handoff 写完自动把 session 改成 `📦 …` | （包含在 handoff 流程内） | （包含在 handoff 流程内） |
| 选择题提问 | AI 遇到多个可行方案时 | 说「用选择题问我」 | 说「用选择题问我」 |

### 支持环境（2026-07-04 全部实测）

| 环境 | Claude Code | Codex CLI | 备注 |
|---|---|---|---|
| macOS + Terminal.app / iTerm | ✅ | ✅ | 原生支持 OSC，零设置 |
| macOS + Cursor terminal | ✅ | ✅ | 需在 Cursor `settings.json` 加 `"terminal.integrated.tabs.title": "${sequence}"` |
| macOS + Antigravity terminal | ✅ | ✅ | 同上（Antigravity 自己的 settings.json） |
| Linux | 未实测 | 未实测 | installer 理论兼容，欢迎反馈 |
| Windows（PowerShell / Windows Terminal） | 未实测 | 未实测 | 尚未完整测试，workshop 现场曾遇 PowerShell 兼容问题——建议先在 macOS/Linux 使用，欢迎反馈 |

### 怎么安装？

两步：clone 这个 repo，然后**把下面的 prompt 原封不动贴给你的 AI**（它会自己读指南、安装、然后带你跑完验证）：

```bash
git clone https://github.com/museReed/jr_ai_agent_skills.git
```

**用 Claude Code 的人，贴这段给 Claude：**
```
Read jr_ai_agent_skills/zh-Hans/auto-rename-install.md and execute Section A,
then follow jr_ai_agent_skills/installer/VERIFICATION.md to walk me through the E2E verification.
```

**用 Codex CLI 的人，贴这段给 Codex：**
```
Read jr_ai_agent_skills/zh-Hans/auto-rename-install.md and execute Section B,
then follow jr_ai_agent_skills/installer/VERIFICATION.md to walk me through the E2E verification.
```

其他 skill 同理，换文件名即可（handoff 建议接着装：同一个 prompt 把 `auto-rename` 换成 `handoff`）。

### 验证与排错

| 要做什么 | 用哪个 |
|---|---|
| 装完自动检查（29 点） | `installer/verify.sh` |
| 引导式 E2E 验证（AI agent 带用户跑四轮，含检查点编号） | `installer/VERIFICATION.md` |
| 行为不对时查症状 | `installer/TROUBLESHOOTING.md` |
| 修不掉回报（一个指令自动收证据 + 开 issue） | `installer/diagnose.sh "一句话症状"` |

之后哪天行为不对，把这段贴给你的 AI 就会自动排查（修不掉会替你准备 issue）：
```
Read jr_ai_agent_skills/installer/TROUBLESHOOTING.md and debug this for me: {一句话描述症状}
```

---

## English

### What is this?

Three skills + two hooks that take session management in Claude Code / Codex CLI off your hands:

| Component | Description | Docs |
|---|---|---|
| **Auto-Rename** (skill + hook) | AI names every session and syncs the terminal tab (and Codex sidebar) — no more tabs all called "New chat" | [Guide](en/auto-rename-skill.md) · [Install](en/auto-rename-install.md) |
| **Handoff** (skill + hook) | Writes a structured handoff document before the session ends; a hook nags automatically at 70% context usage | [Guide](en/handoff-skill.md) · [Install](en/handoff-install.md) |
| **Structured Questions** (skill) | When there are multiple viable options, AI turns them into structured choices instead of deciding for you | [Guide](en/structured-questions-skill.md) · [Install](en/structured-questions-install.md) |

### How to use (when it fires, how to trigger manually)

| Feature | Fires automatically when | Claude Code manual trigger | Codex manual trigger |
|---|---|---|---|
| Session naming | **Right after your first message**; re-evaluated at the 5th tool call; retried every 10 calls as a fallback | `/auto-rename` or just say "rename" | `$auto-rename` or say "rename" |
| Context warning | Context usage exceeds 70% — hook injects a warning telling the AI to hand off | — (fully automatic) | — (fully automatic; warning lags one turn) |
| Handoff document | The AI writes one when the context warning fires | `/handoff` or say "write a handoff" | `$handoff` or say "write a handoff" |
| Archive rename | After the handoff, the session is renamed to `📦 …` | (part of the handoff flow) | (part of the handoff flow) |
| Structured questions | The AI faces multiple viable options | say "ask me with options" | say "ask me with options" |

### Supported environments (all field-tested 2026-07-04)

| Environment | Claude Code | Codex CLI | Notes |
|---|---|---|---|
| macOS + Terminal.app / iTerm | ✅ | ✅ | Native OSC support, zero config |
| macOS + Cursor terminal | ✅ | ✅ | Add `"terminal.integrated.tabs.title": "${sequence}"` to Cursor's settings.json |
| macOS + Antigravity terminal | ✅ | ✅ | Same setting, in Antigravity's own settings.json |
| Linux | untested | untested | Installer should be compatible — reports welcome |
| Windows (PowerShell / Windows Terminal) | untested | untested | Not fully tested yet; PowerShell compatibility issues were seen in workshops — prefer macOS/Linux for now, reports welcome |

### How to install?

Two steps: clone this repo, then **paste the prompt below verbatim to your AI** (it will read the guide, install, and walk you through verification):

```bash
git clone https://github.com/museReed/jr_ai_agent_skills.git
```

**Claude Code users, paste this to Claude:**
```
Read jr_ai_agent_skills/en/auto-rename-install.md and execute Section A,
then follow jr_ai_agent_skills/installer/VERIFICATION.md to walk me through the E2E verification.
```

**Codex CLI users, paste this to Codex:**
```
Read jr_ai_agent_skills/en/auto-rename-install.md and execute Section B,
then follow jr_ai_agent_skills/installer/VERIFICATION.md to walk me through the E2E verification.
```

Same pattern for other skills — just swap the filename (install handoff next: same prompt with `auto-rename` → `handoff`).

### Verify & troubleshoot

| Goal | Use |
|---|---|
| Post-install automated check (29 points) | `installer/verify.sh` |
| Guided E2E verification (AI agent walks the user through 4 rounds with checkpoint IDs) | `installer/VERIFICATION.md` |
| Something behaves wrong | `installer/TROUBLESHOOTING.md` |
| Can't fix it — one command collects evidence and files the issue | `installer/diagnose.sh "one-line symptom"` |

If something misbehaves later, paste this to your AI and it will debug (and draft an issue if it can't fix it):
```
Read jr_ai_agent_skills/installer/TROUBLESHOOTING.md and debug this for me: {one-line symptom}
```

---

## License

MIT
