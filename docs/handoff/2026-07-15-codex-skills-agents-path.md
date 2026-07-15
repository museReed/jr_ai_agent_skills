# Handoff — Codex skills migrate to ~/.agents/skills

## 狀態摘要

- Branch：`external-skills-and-demo`；PR #9 已開啟。
- structured-questions 已改成 Default mode 先停頓，Plan mode 使用 `request_user_input`。
- `installer/install.sh` 已改採方案 A：三個 Codex skills 與 `_shared` 複製到 `~/.agents/skills`，不使用 symlink。
- 舊 `~/.codex/skills/{auto-rename,handoff,structured-questions,_shared}` 會安全搬到 `~/.agents/skill-backups/{timestamp}/`，不碰 `.system`。
- `verify.sh`、context-monitor、handoff 引用及繁中／簡中／英文文件已同步。
- 隔離 HOME 測試：首次安裝、legacy migration、重跑與 `verify.sh codex` 全過（17 PASS、0 FAIL、1 預期 alias WARN）。

## 必讀檔案

- `installer/install.sh`：新的 copy 安裝、備份與 legacy migration 邏輯。
- `installer/verify.sh`：驗證官方 user skill 路徑並拒絕 legacy 同名目錄。
- `installer/skills/codex/structured-questions/SKILL.md`：四條 mode 路徑與 `request_user_input` 契約。
- `installer/hooks/codex-context-monitor.sh`：handoff discovery 路徑已改成 `.agents/skills`。

## 下一步

1. 逐檔 review 目前未提交 diff；不要撤掉 structured-questions 與三語文件變更。
2. 若要部署到本機，執行 `cd /Users/reed/Projects/jr_ai_agent_skills/installer && ./install.sh codex`，再重啟 Codex。
3. 在新 session 手動跑 structured-questions Test 5a／5b；確認後由維護者 commit、push 並更新 PR #9。

## 已知問題

- 尚未對真實 HOME 執行 installer；目前只在 `/tmp` 隔離 HOME 驗證。
- `verify.sh` 的唯一 WARN 來自隔離 HOME 沒有 `codex → mycodex` alias，非產品錯誤。
