---
name: weekly-done-cleanup
description: >
  Weekly cleanup of the Done section in TASKS.md. Runs every Sunday morning autonomously.
  Archives completed tasks that are no longer relevant to active work into done-archive.md.
  Keeps tasks that still provide context for ongoing projects, EPICs, or active decisions.
  Use this skill when it's time for the weekly cleanup, or when {{NAME}} says things like
  "clean up done tasks", "archive old tasks", "prune the done list", or "tidy up TASKS.md".
---

# Weekly Done Cleanup

Every Sunday, prune the Done section of TASKS.md so it stays lean and useful. Tasks that
still provide context for active work stay. Tasks that don't get archived to done-archive.md.

## Why This Matters

The Done section serves two purposes: it gives the daily plan context about recent work
(what was already tried, what was shipped, what unblocked something), and it provides a
sense of momentum. But if it grows forever, it becomes noise. This job keeps it focused
on what's actually relevant this week.

## When to Run

- Every Sunday morning (scheduled task)
- Anytime {{NAME}} asks to clean up or archive done tasks

## Steps

### Step 1: Load context

Read CLAUDE.md to understand current projects, people, terms, and active initiatives.
Read TASKS.md in full — all sections: Active, Waiting On, Someday, and Done.

### Step 2: Evaluate each Done task

For each task in the Done section, ask: "Does this task still provide useful context
for anything in Active or Waiting On?"

A task is RELEVANT if any of these are true:
- It belongs to the same project or EPIC as an Active or Waiting On task
- It involved the same person who is mentioned in an Active or Waiting On task
- It describes a decision or outcome that informs upcoming work
- It was completed within the last 3 days (keep recent completions for short-term context)
- Removing it would leave a gap in understanding why something is in its current state

A task is NOT RELEVANT if:
- The project or initiative it belonged to is fully completed
- No Active or Waiting On task references the same people, project, or EPIC
- It's a routine/admin task older than a week with no downstream dependencies
- It's a one-off task with no connection to anything currently in flight

When in doubt, KEEP the task. Over-retaining is better than losing context.

### Step 3: Archive irrelevant tasks

Move tasks that are no longer relevant to done-archive.md at the project root.

If done-archive.md doesn't exist, create it.

Append archived tasks under a week header. Use plain text formatting — no Markdown
hash headers.

Format for done-archive.md:

```
Done Archive


Week of [day] [Month] [Year]

- [x] [Task name] — [Description]. Completed [date].
- [x] [Task name] — [Description]. Completed [date].


Week of [day] [Month] [Year]

- [x] [Task name] — [Description]. Completed [date].
```

### Step 4: Update TASKS.md

Remove the archived tasks from the Done section. Keep everything else untouched —
never modify Active, Waiting On, or Someday sections.

### Step 5: Report

Write a brief summary of what was done:

```
Weekly cleanup done. [X] tasks archived, [Y] kept for context.
```

## Important Rules

- This runs autonomously. Do not ask questions — make reasonable judgments.
- Never delete tasks. They either stay in Done or move to done-archive.md.
- Never touch Active, Waiting On, or Someday sections.
- Keep recent tasks (last 3 days) regardless of relevance.
- When in doubt, keep the task in Done.
- Archive file uses plain text formatting, no Markdown syntax with # symbols.
