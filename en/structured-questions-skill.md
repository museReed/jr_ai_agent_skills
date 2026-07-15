# Structured Questions — Let AI Help You Ask the Questions You Can't Think Of

**Supported tools**: Claude Code / Codex CLI
**Installation guide**: [structured-questions-install.md](./structured-questions-install.md)

---

## What Problem Does This Skill Solve?

Have you ever run into this situation --

You ask the AI to help you with something, and it replies with a long wall of text with three or four decisions buried in it that you need to make, but after reading the whole thing, you're even less sure how to respond. Or even more commonly: **you don't even know what questions to ask, and the AI just decides for you.**

This skill does two things:

1. **Have the AI proactively help you organize your thinking.** When you haven't even figured out what you want yet, the AI will break down the messy situation into a few specific multiple-choice questions, each with options, pros/cons, and its recommendation -- you don't need to come up with "what to ask" yourself, the AI asks for you.

2. **Consolidate decision points scattered across a long response into a single checklist.** No more "please read the analysis above and tell me your thoughts" type of ball-tossing replies. Each thing that needs your decision is listed independently, with options that include pros/cons and the recommended choice marked -- you can scan it and decide in seconds.

---

## Before / After Comparison

### Value 1: When you haven't thought things through yet, AI helps you break down the problem

> You don't need to figure out "what to ask" first -- the AI proactively breaks vague ideas into specific multiple-choice questions.

---

#### Scenario A: Want to organize an event, but all you have in mind is "I want to do one"

**Before -- AI decides everything for you:**

```
You: Help me plan an event

AI: Sure! I suggest a 30-person weekend workshop at a coworking space,
themed "AI Tools for Beginners." Let me outline the schedule for you...
```

Problem: You just "wanted to hold an event," and the AI already decided the attendee count, format, topic, and venue. You never even thought about "what types of events are possible."

**After -- AI helps you sort things out from the confusion:**

```
Q1: What is the core goal of this event?

  ✨ A) Teaching / Knowledge sharing (Recommended)
     Help attendees learn a specific skill
     😃: Easy to prepare content, measurable results
     😫: Requires sufficient expertise on your part

  B) Community building / Networking
     Help people in the same field connect with each other
     😃: Relaxed, low pressure for attendees
     😫: Hard to measure results, can devolve into small talk

  C) Brand exposure / Marketing
     Get more people to know about you or your product
     😃: Directly generates potential customers
     😫: Needs marketing budget and promotion channels

Q2: How many attendees do you expect?
  ✨ A) 10-15 people (Recommended) ...
  B) 30-50 people ...
  C) 100+ people ...
```

Difference: You only had "want to hold an event." The AI helped you clarify "goal," "headcount," and "format" -- after answering, you know what to organize.

---

#### Scenario B: Want to start creating content on social media, but don't know where to begin

**Before -- AI picks the platform and direction for you:**

```
You: I want to start building a social media presence

AI: I suggest starting with Instagram, posting 3 Reels per week, focusing on your
area of expertise. Let me plan your first week's content schedule...
```

Problem: You were still thinking about "whether to do it," and the AI is already scheduling next week's posts.

**After -- AI helps you think through a few key questions first:**

```
Q1: What is your main motivation for building a social media presence?

  ✨ A) Build a personal brand (Recommended)
     Let the industry know who you are and what you're good at
     😃: Compounds over time, career benefits
     😫: Requires consistent output, no visible returns short-term

  B) Monetization / Making money
     Earn through sponsorships, courses, paid content
     😃: Clear revenue goals to track
     😫: Almost zero income when you have no traffic initially

  C) Documenting and sharing
     Write down what you've learned, and help others along the way
     😃: Lowest pressure, just do what makes you happy
     😫: Slow growth, easy to abandon midway

Q2: What content format are you best at?
  ✨ A) Writing (Recommended) ...
  B) Making videos ...
  C) Recording podcasts ...
```

Difference: The AI didn't tell you to "go create an IG account." Instead, it first helped you think through "why" and "in what format."

---

#### Scenario C: Want to build a side project, but haven't figured out the direction yet

**Before -- AI decides what to build and which tech to use:**

```
You: Help me build a side project

AI: Sure! I suggest building a personal blog. I'll use Next.js + MDX,
with Tailwind CSS for styling, deployed to Vercel. Let me initialize the project...
```

Problem: You just wanted to do "a side project," and the AI decided the product, framework, and deployment. You didn't even know "there were other choices."

**After -- AI breaks your vague idea into three multiple-choice questions:**

```
Q1: What is the goal of this side project?

  ✨ A) Learn new technology (Recommended)
     Finish it and learn a new framework or language
     😃: High sense of achievement, something to put on your resume
     😫: Might not finish it

  B) Solve your own pain point
     Build a small tool you'll use every day
     😃: Motivated to finish because you need it yourself
     😫: Scope creep is easy

  C) Build a portfolio
     Make something to show interviewers
     😃: Direct boost for job hunting
     😫: Need to spend time polishing the UI

Q2: How much time are you willing to invest?
  ✨ A) One weekend (Recommended) ...
  B) 2-4 weeks of evenings ...
```

Difference: After answering the goal and time questions, the AI will recommend suitable tech and scope based on your answers -- instead of deciding for you upfront.

---

#### Scenario D: Refactoring a module, but the AI just starts changing code

**Before -- AI picks a refactoring strategy and starts modifying code:**

```
You: This module is too bloated, help me refactor it

AI: Sure, I'll split this module into three sub-modules: core, utils, types.
Let me start by moving the helper functions...
```

Problem: You just felt "it's too bloated," and the AI decided the split strategy. Maybe what you wanted was to extract an interface, or just move a few functions out -- no major split needed.

**After -- AI asks how you want to split it first:**

```
Q1: What is the goal of the refactoring?

  ✨ A) Reduce single-file line count (Recommended)
     Split files with more than 500 lines into multiple smaller files
     😃: Minimal changes, low risk
     😫: Only addresses the surface issue, dependency relationships unchanged

  B) Clarify responsibility boundaries
     Split by function into independent modules, define clear interfaces
     😃: Architecture becomes cleaner, easier to maintain in the future
     😫: Large scope of changes, need to update all imports

  C) Extract shared logic
     Only extract the duplicated parts into shared utils
     😃: Fewest changes, immediate results
     😫: Doesn't solve the module's structural issues
```

Difference: The AI didn't start splitting code right away -- instead, it first confirmed which kind of "refactoring" you meant.

---

### Value 2: AI gives a long analysis, and you can't finish reading it -- consolidated into multiple-choice questions

> The AI gave lots of information, but decision points are scattered throughout the long text. This skill extracts them and turns them into a checklist.

---

#### Scenario E: AI analyzed three marketing channels, and after reading it all you still don't know which to pick

**Before -- Decision points buried in prose:**

```
AI: Regarding promotion channels, Facebook Ads have a CPC around $0.5-2, suitable for
B2C products, but reach rates have noticeably declined in recent years. Google Ads have
clearer intent, typically higher conversion rates, though competitive keyword CPCs can
reach $5+. If your audience is young, TikTok's CPM is still low, but content production
barriers are higher, and the algorithm changes frequently...

What do you think is the best fit?
```

Problem: You read it three times and still aren't sure what the actual differences are between the three channels, or which suits you.

**After -- The same analysis, consolidated into a multiple-choice question:**

```
Q1: Which primary promotion channel?

  ✨ A) Google Ads (Recommended)
     Clear search intent, users actively find you
     😃: High conversion rate, trackable results
     😫: Popular keywords are expensive (CPC $5+)

  B) Facebook Ads
     Wide reach, good for B2C brand awareness
     😃: Precise audience targeting, multiple ad formats
     😫: Declining reach year over year, fewer young users

  C) TikTok
     Young audience concentration, big traffic bonus right now
     😃: Low CPM, high viral potential
     😫: High content production barrier, unstable algorithm
```

Difference: See the trade-offs of all three channels in three seconds and just pick.

---

#### Scenario F: AI wrote a long travel plan, and you don't know what it's asking you

**Before -- Lots of information but no structure:**

```
AI: For a five-day Kyoto trip, the first day you could visit Kiyomizu-dera and Gion,
but if you're more interested in shrines, Fushimi Inari is also nearby. For transportation,
I'd suggest a bus day pass, but if you're going to Arashiyama, a JR Pass might be
more economical. For accommodation, Shijo Kawaramachi is most convenient, though
the Higashiyama area has more atmosphere -- just a bit farther from the station...

How would you like to arrange things?
```

**After -- Things you need to decide are extracted:**

```
Q1: Itinerary style preference?
  ✨ A) Classic must-sees (Recommended)
     Kiyomizu-dera, Kinkaku-ji, Fushimi Inari -- the tourist route
     😃: Won't miss the highlights on your first visit
     😫: Crowded, lots of queuing

  B) Local experiences
     Machiya cafes, market strolling, kimono walks
     😃: Relaxing, great for photos
     😫: Might feel like "I didn't see any real attractions"

Q2: Accommodation area?
  ✨ A) Shijo Kawaramachi (Recommended) ...
  B) Higashiyama area ...
```

---

#### Scenario G: AI gave a long technical analysis, and you can't finish reading it

**Before -- Decision points buried in prose, you have to find them yourself:**

```
AI: Regarding database selection, PostgreSQL is the most mature relational database,
supports JSONB for semi-structured data, but if your data volume isn't large, SQLite
is actually sufficient -- it doesn't require a separate server process and has a
better dev experience. However, if multiple concurrent writes are needed in the future,
SQLite's write lock will be a bottleneck. You could also consider Supabase, which
is PostgreSQL under the hood but provides a real-time API and authentication, though
it adds a vendor dependency...

Which direction do you prefer?
```

Problem: You read it three times and still aren't sure how many choices there are or what the differences are.

**After -- The same analysis, consolidated into a multiple-choice question:**

```
Q1: Which database?

  ✨ A) SQLite (Recommended)
     Embedded, no need to install a separate DB server
     😃: Zero config, fastest to develop, great for solo projects
     😫: Concurrent writes will hit lock contention

  B) PostgreSQL
     The most mature relational database
     😃: Full-featured, great JSONB support, easy to scale later
     😫: Requires a server, one extra step for dev environment

  C) Supabase
     PostgreSQL + real-time API + Auth all-in-one
     😃: Quick backend, no need to write your own API
     😫: Adds vendor dependency, limited free tier
```

Difference: Same amount of information, but you can see all the trade-offs in three seconds and just pick.

---

#### Scenario H: CI pipeline is broken, AI throws a bunch of possible causes

**Before -- AI lists five possibilities, you don't know where to start:**

```
AI: The CI failure could be caused by: inconsistent npm install lock file,
Node version different from local, a test is hitting a real API but CI doesn't
have credentials, possibly a new ESLint rule is blocking things, or the last
merge introduced a type error. I suggest you check the CI log first...
```

**After -- Sorted by priority, asking which one to investigate first:**

```
Q1: Which direction to start investigating?

  ✨ A) Look at the first error in the CI log (Recommended)
     Read the error message directly, no guessing
     😃: Most accurate, no wasted time
     😫: Long logs can take time to search through

  B) Compare local vs CI Node versions
     Run node -v and check against CI config
     😃: Can be ruled out in 30 seconds
     😫: If it's not a version issue, you wasted time

  C) Check the diff from the most recent merge
     See what the last PR changed
     😃: If it's a regression, you'll spot it immediately
     😫: Large diffs are hard to read
```

---

## How to Trigger?

| Method | Claude Code | Codex CLI |
|---|---|---|
| **Auto trigger** | When AI encounters something that needs your decision, it proactively uses the structured format to ask | Same |
| **Manual trigger** | Type `/structured-questions` | Type `$structured-questions` |
| **Keywords** | Also triggers when the conversation includes "help me choose", "not sure", "there are several approaches" | Same |

## Use Cases

| Scenario | What you're experiencing | How AI helps |
|---|---|---|
| **Ideas still vague** | "I want to hold an event / do a side project / build a social media presence, but don't know how to start" | Breaks it down into goal, scope, and format questions -- after answering, the direction is clear |
| **AI gave a long response** | Read a long technical analysis / marketing strategy / travel plan and don't know the key points | Extracts decision points from the prose into multiple-choice questions with pros/cons |
| **Don't know what choices exist** | AI decided for you, and you didn't even know "there were other options" | Lists all viable approaches so you see the full picture before deciding |
| **Troubleshooting** | CI is broken / bug you don't know where to start investigating, AI throws a bunch of possible causes | Sorted by priority, asks which one to investigate first |
| **Direction disagreement** | You and the AI have different ideas about "how to do it" | Puts both approaches side by side with pros/cons, giving you a basis for choosing |

## When Not to Use

- Only one reasonable approach -- AI just does it, doesn't waste your time
- You already clearly specified how to do it in your instructions -- AI follows through, doesn't ask back
- Pure progress reports -- just use text

---

## Installation

Paste the same prompt into Claude Code or Codex; the AI detects the tools, confirms the terminal/IDE, and installs all three core skills together:

```
Read jr_ai_agent_skills/en/auto-rename-install.md and guide me through its single installation flow.
```

See [structured-questions-install.md](./structured-questions-install.md) for detailed steps.

---

## Claude Code vs Codex Differences

| | Claude Code | Codex CLI |
|---|---|---|
| Interactive UI | Available anytime (`AskUserQuestion` tool) | Plan mode uses `request_user_input` |
| Default mode | N/A | Pauses to ask whether to switch; uses plain text only after an explicit refusal |
| Install path | `.claude/skills/structured-questions/SKILL.md` | `.agents/skills/structured-questions/SKILL.md` |
| Trigger method | `/structured-questions` or auto trigger | `$structured-questions` or auto trigger |
