---
name: daily-briefing
description: Use when the user asks about their plan, agenda, to-do list, schedule, what's on their plate, what they should work on, morning briefing, or any synonym. Builds the complete daily picture — calendar events, pull requests awaiting review or assigned, and every task from TASKS.md.
---

# Daily Briefing

Produces {{NAME}}'s complete daily picture by gathering three data sources in parallel and presenting them in the plan format defined in `CLAUDE.md`.

## When to trigger

Whenever {{NAME}} asks anything that means "give me the big picture of my day":

- "What's my plan for today?" / "What's my agenda?"
- "What's on my to-do?" / "What's in my to-do list?"
- "What should I work on today?" / "What's on my plate?"
- "Morning briefing" / "What's my schedule?"
- Any close synonym.

Do NOT trigger for narrow lookups ("what's my next meeting?", "any PRs from Karan?"). Those don't need the full briefing.

## Step 1 — Gather data IN PARALLEL

Issue all three tool calls in a single message. Never sequential.

**1a. Calendar** — today's events via `gws` (see the `google-workspace-cli` skill for CLI details):

```
gws calendar events list --params '{"calendarId": "primary", "timeMin": "YYYY-MM-DDT00:00:00Z", "timeMax": "YYYY-MM-DDT23:59:59Z", "singleEvents": true, "orderBy": "startTime"}'
```

Pipe through a short python snippet to get `HH:MM - HH:MM  Title  [type]` per line.

**1b. Pull requests** — two `gh` queries:

```
gh search prs --review-requested={{GH_HANDLE}} --state=open
gh search prs --assignee={{GH_HANDLE}} --state=open
```

Empty output = none.

**1c. Tasks** — Read `TASKS.md`. Capture every item in Active and Someday.

## Step 2 — Present the picture

Use this plan format:

```
Good morning, {{NAME}}. [Day] [Month] [Date].

📅 [Meeting 1] [time]
📅 [Meeting 2] [time]
(or: 📅 No meetings today — full day for deep work.)

**Do now** (urgent + important)

1. [Task] `[tag]`

2. [Task] `[tag]`

**Schedule** (important, not urgent)

3. [Task] `[tag]`

4. [Task] `[tag]`

**Delegate** (urgent, not important)

5. [Task] `[tag]`

(or: _(nothing today)_ if empty)

**Backlog** (not urgent, not important)

6. [Task] `[tag]`

(or: _(nothing today)_ if empty)
```

Format rules:
- One line per task, no long explanations
- Inline tag after each task: 2-4 words max (e.g., `due tomorrow`, `unblocks team`, `quick win`)
- Blank line between every numbered item for readability
- Only show sections that have tasks, except "Do now" which always appears
- Empty sections show _(nothing today)_
- Greeting adapts to time of day (Good morning / afternoon / evening)

Additional constraints:

- **PRs awaiting review always land in "Do now"** — they are high-urgency blockers.
- **Propose the Eisenhower classification** for tasks; {{NAME}} reviews.
- **Never skip one of the three data sources** — missing one is a failure of this skill.
- **Show all tasks** — every item from TASKS.md must appear, no silent filtering.

After the plan, offer a short next step ("want me to tackle #1?" / "should I draft a plan around the workshop?").
