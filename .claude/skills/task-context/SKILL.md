---
name: task-context
description: Use when creating or editing tasks — in TASKS.md, Jira, or anywhere. Loads relevant wiki memories by retrieving top-k pages related to the task and letting the user pick which ones to use for full context.
---

# Task Context

Ensures relevant wiki memories are loaded whenever {{NAME}} creates or edits a task, so the assistant has full context (why it matters, who it connects to, what prior knowledge applies).

## When to trigger

Any time the assistant is about to **create, edit, or enrich a task** — regardless of where the task lives. This includes:

- Writing to `TASKS.md` (add, edit, move between sections, mark done)
- Creating or editing a **Jira ticket**
- Any other task-tracking action that would benefit from wiki context

### Examples

Explicit commands:
- "Add a task to …"
- "Create a task for …"
- "Update the task about …"
- "Move X to Someday"
- "I think we can add a task to Jira to research this"

Implicit triggers (easy to miss — be vigilant):
- During a **task review/cleanup session**, when creating Jira tickets or writing richer descriptions for existing tasks
- When **converting** a TASKS.md item into a Jira ticket
- When a conversation leads to "let's track this" even if the word "task" isn't used

### When NOT to trigger

- Read-only operations ("show me my tasks", "what's in Active?")
- Simple status changes that don't benefit from wiki context (e.g. just checking a box with no description change)
- Bulk deletes/archives where no new content is being written

## Step 1 — Identify the task

Extract the **task description** from the user's message — the subject, keywords, and any project/person names mentioned. This is the query text used for ranking.

## Step 2 — Rank memories

Read `memory/index.md`. For each page listed, score its relevance to the task query by comparing the page name, summary, and any entity names against the task description. Use keyword overlap, entity matching, and semantic proximity.

Select the **top-k most relevant pages** (k = min(5, total pages)). Always include every page that shares an explicit entity name (person, project, squad) with the task.

## Step 3 — Ask the user

Present the top-k pages using the `AskQuestion` tool with `allow_multiple: true`. Format:

- **id**: `select-memories`
- **prompt**: "I found these memories related to your task. Which ones should I load for context?"
- **options**: one per page, using the page name as label and the filename as id.

If there is only one relevant page, still ask — don't auto-load silently.

If no pages seem relevant (score is very low for all), skip this step and tell the user no related memories were found. Proceed directly to task management.

## Step 4 — Load and proceed

Read the selected memory pages. Use their content as context while creating or editing the task (in `TASKS.md`, Jira, or wherever the task is being tracked).

When writing or updating the task, leverage loaded context to:
- Write a richer task description that captures why the task matters.
- Add relevant cross-references if appropriate (e.g., project names, people).
- Flag connections the user might not have mentioned ("this relates to X from your SDLC Consulting notes").
