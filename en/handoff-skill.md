# Handoff — Let AI Write Your Handoff Document So the Next Session Doesn't Start from Scratch

**Supported tools**: Claude Code / Codex CLI
**Installation guide**: [handoff-install.md](./handoff-install.md)

---

## What Problem Does This Skill Solve?

Have you ever run into this situation --

You've been chatting with the AI for a long time, discussed lots of details, tried many approaches, and made many decisions. Then after closing the session, the next session has absolutely no idea what happened before. You have to explain the background all over again, restate the requirements, and walk through the approaches that didn't work -- again.

This skill does two things:

1. **Have the AI automatically compile a handoff document before the session ends.** It includes: what was done, how far you got, what to do next, and which files to read. A new session can pick up seamlessly after reading this document -- no need for you to re-explain.

2. **Warn you when context is running low.** The AI won't wait until it suddenly cuts off to tell you. Instead, it warns in advance: "Running low -- let me write the handoff document first," letting you gracefully switch to a new session.

---

## Before / After Comparison

### Value 1: After opening a new session, you don't start from scratch

> Every time you open a new session, you can continue from where the last one left off, without re-explaining the background.

---

#### Scenario A: Discussing a travel itinerary with AI, having to start over after closing

**Before -- The new session knows nothing:**

```
(Previous session: Spent 30 minutes discussing a Kyoto trip, decided on accommodation area, transportation, daily attractions)

You: (Open a new chat the next day)
You: Let's continue with the Kyoto trip we discussed yesterday -- help me plan Day 3
AI: Hello! How many days is your Kyoto trip? Where are you staying? Any preferences?
You: (Sigh, explain everything from the beginning)
```

Problem: The AI doesn't remember the previous conversation -- you have to relay all the background again.

**After -- The new session reads the handoff document and picks up:**

```
(Before the previous session ended, the AI automatically produced a handoff document)

You: Read docs/handoff/2026-06-30-kyoto-trip.md and continue working
AI: (Reads the handoff document)
AI: Got it. Last time we decided to stay in Shijo Kawaramachi, buy a bus day pass,
    Day 1 is Kiyomizu-dera + Gion, Day 2 is Arashiyama. Next up is Day 3 --
    would you like to go to Fushimi Inari or Kinkaku-ji?
```

Difference: No re-explaining needed -- the AI continues directly from where the last session left off.

---

#### Scenario B: Revised a proposal three times, have to start over when opening a new session the next day

**Before -- Three rounds of revision history all lost:**

```
(Previous session: Wrote a first draft → revised structure based on manager feedback → adjusted the budget table)

You: (Next day) Continue revising the proposal
AI: Sure, what's the proposal about? What's the current status?
You: (Need to re-describe the topic, structure, budget, manager's three rounds of feedback...)
```

**After -- All revision history is in the handoff document:**

```
You: Read docs/handoff/2026-06-30-proposal-v3.md and continue
AI: (Reads it) The proposal is at version 3 -- the budget adjustments from manager feedback are done.
    Next step is adding ROI analysis. Want to continue from here?
```

Difference: The decisions and reasoning from three rounds of revisions are all preserved -- no need to re-explain.

---

#### Scenario C: Debugging halfway when context fills up, new session doesn't know what was already tried

**Before -- Retracing paths already ruled out:**

```
(Previous session: Spent 45 minutes debugging, ruled out 3 possibilities, narrowed down to the 4th)

You: (Context full, open new session)
You: The API is returning a 500 error, help me debug
AI: Sure, let's start from scratch. First let's check the request payload...
You: (I already checked that!!!)
```

Problem: The new session starts from zero, retracing paths already eliminated.

**After -- The handoff document records the investigation progress:**

```
You: Read docs/handoff/2026-06-30-api-500-debug.md and continue
AI: (Reads it) Already ruled out: payload format, auth token, rate limit.
    Currently narrowed down to DB connection pool exhaustion. Next step is
    checking connection count. Continue from here?
```

Difference: No retracing eliminated paths -- continue directly from the narrowed direction.

---

#### Scenario D: Multi-day feature development, having to re-explain background every day

**Before -- Spending 10 minutes explaining context every day:**

```
(Yesterday: Finished writing the first 8 TDD tests, all green. About to start the 9th)

You: (Open new session today)
You: I'm working on the voice pipeline feature for #1234. Yesterday I got to test 8,
    using pytest, test file is at tests/unit/test_voice.py,
    related source code is at platform/voice/...
AI: Sure, let me read through these files first...
You: (Another 10 minutes waiting for AI to re-understand the codebase)
```

**After -- The handoff document is today's startup command:**

```
You: Read docs/handoff/2026-06-29-voice-pipeline-tdd.md and continue
AI: (Reads it) Issue #1234, TDD Phase 2. Tests 1-8 all green.
    Next step: Write Test 9 (Scenario: blank transcript fallback).
    Files to read: tests/unit/test_voice.py (see existing test patterns),
    platform/voice/src/muse_voice/pipeline.py (implementation target).
```

Difference: The handoff document is the complete "where to start today" instruction -- no need to recall anything yourself.

---

### Value 2: Graceful wrap-up when context is running low, instead of a sudden cutoff

> The AI warns "running low" in advance, writes the handoff, then ends -- instead of waiting until it cuts off and scrambling.

---

#### Scenario E: AI responses getting shorter and shorter, you only then realize context is almost full

**Before -- No warning, it just cuts off:**

```
You: Help me refactor this function
AI: OK

You: ...that's it?
AI: Sorry, due to context limitations, I'm unable to provide a complete response...
You: (All the context from earlier discussions is in this window that's about to close)
```

Problem: No warning -- by the time you notice, it's too late to organize anything.

**After -- Early warning + automatic handoff:**

```
AI: ⚠️ Context is at ~145k tokens (72%). Let me write a handoff document first.
    I suggest opening a new session to continue afterward.

AI: Handoff produced: docs/handoff/2026-06-30-refactor-session.md
    Branch: feature/1234-voice-pipeline
    Read docs/handoff/2026-06-30-refactor-session.md to continue working.
```

Difference: No sudden cutoff -- instead, a planned wrap-up.

---

#### Scenario F: Working on a presentation halfway through when the AI suddenly can't respond

**Before -- Progress is trapped in the closed window:**

```
(Wrote 20 slides, revised 5 times)

AI: [token limit reached]
You: (So which version am I on? Did I update the chart on slide 12? Was the manager's third round of feedback handled?)
You: (Have to recall everything yourself or dig through the history)
```

**After -- Complete record before the cutoff:**

```
AI: ⚠️ Context is almost full -- let me compile the handoff document.

Handoff document contents:
- Completed: Slides 1-15 finalized, slides 16-18 charts updated
- In progress: ROI analysis on slide 19
- Next steps: Finish slides 19-20 → proofread entire document
```

Difference: Progress doesn't vanish when the window closes.

---

#### Scenario G: Running TDD up to the 8th test when context fills up

**Before -- Don't know which tests passed and which weren't written:**

```
You: (Open new session) I'm doing TDD for the voice pipeline -- where did I get to?
AI: Where's your test file? What test cases do you have so far?
You: (Have to explain the TDD plan and progress all over again)
```

**After -- The handoff document has complete TDD progress:**

```
Handoff document:
- Tests 1-8: All green ✅
- Tests 9-12: Not yet implemented
- Next step: Test 9 (blank transcript fallback)
- Must read: TDD Index at docs/features/voice/tdd-index.md
```

Difference: The new session knows "8 passed, start from the 9th."

---

#### Scenario H: PR review halfway done when context fills up

**Before -- Reviewer comments scattered across the closed conversation:**

```
You: (Reviewer raised 5 points, AI fixed 3, still 2 left unhandled)
You: (Context full, new session doesn't know which were fixed and which weren't)
```

**After -- The handoff document tracks the status of every point:**

```
Handoff document:
- Reviewer comments 1-3: Modified and committed ✅
- Comment 4: Need to confirm with reviewer (waiting for reply)
- Comment 5: Not yet handled (type definition needs changing)
- Next step: Handle comment 5 → re-request review
```

Difference: Review progress isn't lost just because context filled up.

---

## How to Trigger?

| Method | Claude Code | Codex CLI |
|---|---|---|
| **Auto trigger** | When context usage > 70%, hook prompts AI to write handoff document | No auto trigger |
| **Manual trigger** | Type `/handoff` | Type `$handoff` |
| **Keywords** | Say "handoff", "end session" in conversation | Same |

## Use Cases

| Scenario | What you're experiencing | How AI helps |
|---|---|---|
| **Session ending** | Done for the day, need to continue tomorrow | Automatically produces handoff document recording what was done and what's next |
| **Context running low** | AI responses getting shorter, hook warns of high token usage | Compiles handoff early + prompts you to open a new session |
| **Handing off to someone else** | You're halfway through and need to pass it to a colleague's AI session | Handoff document is in a universal format any new session can read |
| **Multi-day development** | Every day you open a new session and have to re-explain background | Run `/handoff` at end of each day, read the file directly the next day to continue |

## When Not to Use

- Very short one-off conversations -- nothing to hand off
- All work completed within a single session -- no need for cross-session continuity
- Casual chat -- no need for structured records

---

## Installation

One command, and the AI installs it for you:

**Claude Code:**
```
Read docs/guides/handoff-install.md and execute Section A
```

**Codex CLI:**
```
Read docs/guides/handoff-install.md and execute Section B
```

See [handoff-install.md](./handoff-install.md) for detailed steps.

---

## Claude Code vs Codex Differences

| | Claude Code | Codex CLI |
|---|---|---|
| Auto trigger | Yes (context-monitor hook warns at 70%) | No |
| Session archive rename | Writes file `~/.claude/session-names/${PID}.txt` + OSC escape | Writes to SQLite `~/.codex/state_*.sqlite` |
| Install location | `.claude/skills/handoff/SKILL.md` | `.codex/skills/handoff/SKILL.md` |
| Manual trigger | `/handoff` | `$handoff` |
| Handoff file location | `docs/handoff/{date}-{topic}.md` (same for both) | Same |
