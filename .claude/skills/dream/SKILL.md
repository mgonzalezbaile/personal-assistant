---
name: dream
description: "Use when the .dream-pending flag is set or when explicitly invoked. Consolidates memory by scanning recent agent transcripts for corrections, decisions, preferences, and patterns, then merging findings into existing wiki pages in memory/."
tags: [memory, maintenance, consolidation, wiki]
---

# Dream — Memory Consolidation

Scans recent agent session transcripts and merges discoveries into the project's wiki (`memory/`). Runs in 4 sequential phases.

```
ORIENT → GATHER SIGNAL → CONSOLIDATE → PRUNE & INDEX
```

## Transcript location

Cursor agent transcripts live at:

```
{{TRANSCRIPT_DIR}}<uuid>/<uuid>.jsonl
```

Each `.jsonl` file is one session. Lines are JSON objects with a `role` field (`user` or `assistant`).

---

## Phase 1: ORIENT

**Goal:** Understand the current state of the wiki before changing anything.

### Steps

1. Read `memory/index.md` — note every page, its category (Projects / Concepts / Preferences), and one-line summary.
2. Read each wiki page listed in the index. For each, note:
   - Key entities (people, tools, projects)
   - Last-updated date (from frontmatter or content)
   - Areas that look stale or incomplete
3. Count total pages and total lines across the wiki.

### Output

A mental map of what the wiki knows, what's stale, and where gaps might be.

---

## Phase 2: GATHER SIGNAL

**Goal:** Extract important information from recent sessions without reading everything.

### Find recent transcripts

```bash
find {{TRANSCRIPT_DIR}} \
  -name "*.jsonl" -mtime -7 2>/dev/null | sort -r
```

Adjust `-mtime -7` to control the lookback window (default: 7 days).

### What to scan for

Use targeted grep on transcript files. Each pattern targets a specific signal type:

**User corrections** (highest priority):
```bash
rg -li "actually|no,|wrong|incorrect|not right|stop doing|don't do|I said|I meant|that's not|correction" <path>
```

**Preferences and configuration:**
```bash
rg -li "I prefer|always use|never use|I like|I don't like|from now on|going forward|remember that|keep in mind|default to" <path>
```

**Important decisions:**
```bash
rg -li "let's go with|I decided|we're using|the plan is|switch to|move to|chosen|picked|decision|we agreed" <path>
```

**New projects, tools, or people:**
```bash
rg -li "new project|started working on|hired|onboarded|evaluating|researching|testing" <path>
```

### How to read matches

For each matching file, read the surrounding context of the match — not the full session. Focus on `user` messages and the immediately following `assistant` response.

### What to extract

For each finding, note:
- **The fact** — what was said or decided
- **The date** — derive from the transcript file's modification time
- **Which wiki page it belongs to** — match against entities/topics from Phase 1
- **Confidence** — explicit instruction (high) or implied preference (medium)
- **Contradictions** — does this conflict with anything currently in the wiki?

---

## Phase 3: CONSOLIDATE

**Goal:** Merge new findings into existing wiki pages. This is the most delicate phase.

### Routing rules

Each finding goes to **the wiki page where it belongs** based on the entity or topic it relates to:

| Finding type | Where it goes |
|-------------|---------------|
| Decision about a project | That project's wiki page |
| New person/collaborator | The project page where they're relevant (never create person pages) |
| Tool evaluation or adoption | The project page driving the evaluation |
| Workflow change | The project or concept page it affects |
| General preference (not project-specific) | `memory/preferences.md` (create if it doesn't exist, type: `preference`) |
| Correction to existing wiki content | Update the page that contains the wrong information |
| New concept/theme not covered by any page | Create a new wiki page |

### Writing rules

1. **Never duplicate.** Before adding anything, check if the wiki already covers it. If so, update the existing section.
2. **Convert relative dates to absolute.** If a transcript from Apr 10 says "yesterday", write "2026-04-09" in the wiki.
3. **Fix contradictions.** If the wiki says X but a recent transcript corrects it to Y, update the wiki page. Add a note if the change is significant: `(Updated YYYY-MM-DD; previously: X)`.
4. **Follow wiki conventions:**
   - Frontmatter with `type`, `name`, and optionally `first_seen`
   - Use relative links between pages: `[Fibal](fibal.md)`
   - People are documented inline on project/concept pages, never as standalone pages
   - One page per entity — don't create duplicates
5. **New pages** follow the wiki ingest format:
   ```yaml
   ---
   type: concept  # or project, preference, synthesis
   name: Page Name
   first_seen: YYYY-MM-DD
   ---
   ```

### What NOT to consolidate

- Transient implementation details (file paths, command outputs, error messages)
- Task management actions (these live in TASKS.md, not the wiki)
- Information the user explicitly dismissed or rejected

---

## Phase 4: PRUNE & INDEX

**Goal:** Keep the wiki healthy after consolidation.

### Update index.md

1. Add any new pages to the appropriate section in `memory/index.md`.
2. Update one-line summaries that have become stale after consolidation.
3. Update the `Last updated` date.
4. Remove entries for pages that no longer exist.

### Prune stale content

Flag (don't auto-delete) wiki content that is:
- More than 90 days old with no references in recent transcripts
- About tools or projects that seem abandoned
- Contradicted by newer information (should have been caught in Phase 3)

Present flagged items to the user for confirmation before removing.

### Record the dream timestamp

After completing all 4 phases:
```bash
date -u +%Y-%m-%dT%H:%M:%SZ > memory/.last-dream
```

---

## Safety

- **Never delete wiki content without replacement.** Contradicted content is updated, not deleted. Stale content is flagged for user review.
- **Back up before first run.** On the very first dream against this wiki:
  ```bash
  cp -r memory/ memory-backup-$(date +%Y%m%d)/
  ```
- **Dry run option.** On first use, read through all 4 phases but only print what you WOULD change. Confirm with the user before applying.

---

## Verification

After running, verify:
1. All wiki pages referenced in `index.md` exist
2. No duplicate entries were introduced
3. No relative dates remain ("yesterday", "last week")
4. Cross-references between pages are valid
5. Print a summary: pages updated, sections added, contradictions resolved, new pages created
