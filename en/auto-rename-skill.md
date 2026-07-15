# Auto-Rename — Give Every AI Session Its Own Name

**Supported tools**: Claude Code / Codex CLI
**Installation guide**: [auto-rename-install.md](./auto-rename-install.md)

---

## What Problem Does This Skill Solve?

Have you ever run into this situation --

You have several AI chat windows open, and every tab has the same name. You want to switch back to the one you were just working on, but you have to click through each one to check. The more you open, the messier it gets, until you just close them all and start over.

This skill does one thing:

1. **Have the AI automatically name each session with a readable name.** Based on what you're discussing, the AI will automatically name it with an emoji + description (e.g., "🏗️ voice profile pipeline"), so you can spot the one you need at a glance from the tab list.

---

## Before / After Comparison

### Value: Too many tabs, can't find the session you need

> No matter how many sessions you open, each one has a name, and you can instantly tell what each one is doing.

---

#### Scenario A: Multiple AI chats open, all with the same name

**Before -- You have to click through each one to check:**

```
Your tab list:
  [New chat]  [New chat]  [New chat]  [New chat]  [New chat]

You: (Which one was discussing recipes?)
You: (Open the first one -- nope, this one's about travel)
You: (Open the second one -- nope, this one's about fitness)
You: (Open the third one -- finally found it)
```

Problem: With 5 chats you're guessing 5 times; with 10, you just give up.

**After -- Each chat is automatically named:**

```
Your tab list:
  [🔍 Kyoto 5-day itinerary]  [🏗️ Fat-loss meal plan]  [💬 Workout schedule discussion]  [📐 Sidebar UI]  [🐛 Login error investigation]

You: (Spot "Kyoto 5-day itinerary" instantly, click to continue)
```

Difference: No guessing, no clicking through -- the tab name is a content summary.

---

#### Scenario B: Multiple AI assistants open at work, can't tell which is doing what

**Before -- The sidebar all looks the same:**

```
Codex sidebar:
  muse-platform  (3 minutes ago)
  muse-platform  (15 minutes ago)
  muse-platform  (1 hour ago)

You: (Was the 15-minute-ago one working on a presentation or organizing meeting notes?)
You: (Can only guess by time -- guess wrong and you waste time)
```

Problem: Multiple sessions for the same project, and the sidebar shows the project name for all of them -- no distinction at all.

**After -- Each session is automatically named:**

```
Codex sidebar:
  📐 Q3 presentation outline  (3 minutes ago)
  📋 Weekly meeting notes      (15 minutes ago)
  🔍 Competitor analysis       (1 hour ago)

You: (Click "Weekly meeting notes" directly to continue)
```

Difference: No need to guess content from timestamps -- the name says it all.

---

#### Scenario C: Multiple Claude Code sessions open, terminal tabs all showing the branch name

**Before -- All 4 tabs show `develop`:**

```
Terminal tabs:
  [develop]  [develop]  [develop]  [develop]

You: (Which one is running TDD? Which one is debugging? Which one is writing a PRD?)
You: (Switch to the third one -- nope, that one's doing a PR review)
```

Problem: The branch name can't tell you "what this session is doing."

**After -- Each tab is automatically named:**

```
Terminal tabs:
  [🏗️ voice profile pipeline]  [🐛 Gemini 429 debug]  [📐 PRD2 design]  [📋 PR review]

You: (Switch directly to "Gemini 429 debug" to continue investigating)
```

Difference: The tab name changes from "which branch you're on" to "what you're working on."

---

#### Scenario D: 3 Codex sessions open in the same repo, each doing different things

**Before -- The sidebar is completely indistinguishable:**

```
Codex sidebar:
  muse-platform  (just now)
  muse-platform  (5 minutes ago)
  muse-platform  (20 minutes ago)

You're doing three things:
  1. Fixing the crawler's retry logic (the 5-minute-ago one)
  2. Building a new voice pipeline (the 20-minute-ago one)
  3. Just opened one for code review

You: (Every time you have to match by memory to timestamps -- get it wrong and you switch to the wrong session)
```

**After -- Each session is manually or automatically named:**

```
Codex sidebar:
  📋 crawler PR review     (just now)
  🔧 Crawler retry logic   (5 minutes ago)
  🏗️ voice pipeline modeling (20 minutes ago)

You: (Click "Crawler retry logic" directly to continue fixing the bug)
```

Difference: No more relying on memory to match "how many minutes ago = which task."

---

## How to Trigger?

| Method | Claude Code | Codex CLI |
|---|---|---|
| **Auto trigger** | Hook automatically prompts AI to name the session at the 5th tool call | No auto trigger |
| **Manual trigger** | Type `/auto-rename` | Type `$auto-rename` |
| **Keywords** | Say "rename", "name this session" in conversation | Same |

## Use Cases

| Scenario | What you're experiencing | How AI helps |
|---|---|---|
| **Multiple sessions open** | Tabs / sidebar all look the same, have to guess when switching | Automatically names each session with emoji + description |
| **Session topic changed** | Started debugging, then shifted to refactoring -- the name is outdated | Manually run `/auto-rename` to rename |
| **Mark before handoff** | Want to mark which sessions are finished | Pairs with `/handoff` to automatically add a 📦 prefix |

## When Not to Use

- Session just started (< 3 rounds of conversation) -- not enough info, wait a few more exchanges before naming
- You already manually set a name you're happy with -- AI won't overwrite it

---

## Installation

Paste the same prompt into Claude Code or Codex; the AI detects the tools, confirms the terminal/IDE, and installs all three core skills together:

```
Read jr_ai_agent_skills/en/auto-rename-install.md and guide me through its single installation flow.
```

See [auto-rename-install.md](./auto-rename-install.md) for detailed steps.

---

## Claude Code vs Codex Differences

| | Claude Code | Codex CLI |
|---|---|---|
| Auto trigger | Yes (PostToolUse hook triggers at the 5th tool call) | No |
| Naming method | Writes file `~/.claude/session-names/${PID}.txt` | Writes to SQLite `~/.codex/state_*.sqlite` |
| Terminal tab sync | Sends OSC escape directly to change tab title | Requires launching with `mycodex` wrapper for sync |
| Install location | `.claude/skills/auto-rename/SKILL.md` | `.agents/skills/auto-rename/SKILL.md` |
| Manual trigger | `/auto-rename` | `$auto-rename` |
