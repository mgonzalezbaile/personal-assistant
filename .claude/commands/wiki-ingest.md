---
name: wiki-ingest
description: >
  Process raw sources from sources/ into the wiki. Reads each source, categorizes it
  by project (with user confirmation), extracts key information into wiki pages, updates
  the index, deletes the source, and reports remaining files.
---

# Wiki Ingest

Interactive command to process raw sources into the wiki, one at a time.

Read the wiki skill at `.claude/skills/wiki/SKILL.md` before proceeding — it defines
the full ingest rules (page types, frontmatter, cross-references, index updates).

## Workflow

Follow these steps strictly and in order. Use `TodoWrite` to track progress through each step. 

### Step 1: Find sources to process

1. List all files in `sources/` (`.md` and `.txt` files only, ignore dotfiles).
2. If no files exist, tell {{NAME}} "No sources to process." and stop.
3. Pick the **oldest** file (by filename date prefix, or filesystem date if no prefix).

### Step 2: Categorize by project

1. Read the source file fully.
2. Read `memory/index.md` to get the list of existing projects.
3. Determine which project this source belongs to. Consider:
   - Explicit project mentions in the source text
   - People mentioned who are associated with known projects
   - Topics/themes that match existing project descriptions
4. Use `AskQuestion` to confirm the categorization:
   - **If clear match (one project):** present it as the selected option plus an "Other" option.
   - **If ambiguous (multiple possible projects):** list all candidates as options, plus "New project" and "None / general".
   - **If no match:** propose "New project" and ask for the project name.
5. Wait for {{NAME}}'s response before proceeding.

### Step 3: Process the source

Follow the ingest steps defined in `.claude/skills/wiki/SKILL.md`:

1. Extract key information from the source:
   - Decisions and rationale
   - Action items and owners
   - People (names, roles, context) — captured inline on project/concept pages, never as standalone pages
   - Concepts/themes
   - Contradictions with existing wiki content
2. Create new wiki pages for new concepts (with proper frontmatter). Never create person pages.
3. Update existing pages with new information. Add cross-references between related pages.
4. Update `memory/index.md` — add new pages, refresh summaries, update the date.
5. Delete the processed source file from `sources/`.

### Step 4: Report and continue

1. Count how many source files remain in `sources/`.
2. Tell {{NAME}}:
   - What was processed and what pages were created/updated
   - How many sources are left: "[N] source(s) remaining in sources/."
   - If more remain, suggest: "Run `/project:wiki-ingest` again to process the next one."
