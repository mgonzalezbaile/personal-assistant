# AI Podcast

Generate a NotebookLM Audio Overview podcast from yesterday's AI newsletter links.

## Step 1 — Fetch newsletters

Search the personal Gmail account for recent AI newsletters:

```
mcp__claude_ai_Gmail__gmail_search_messages with q="label:subscriptions-ai newer_than:2d", maxResults=20
```

If no results, widen to `newer_than:3d`. If still empty, ask the user.

**Important**: Use the Gmail MCP connector (personal account), NOT the `gws` CLI (work account). The `subscriptions-ai` label lives on the personal Gmail.

## Step 2 — Read all newsletters

Read every message returned in Step 1 using `mcp__claude_ai_Gmail__gmail_read_message`. Read all emails in parallel to save time.

## Step 3 — Extract article links

Parse each email body and extract article/resource URLs. **Include** blog posts, research papers, product announcements, GitHub repos, and technical deep dives. **Exclude**:

- Unsubscribe / manage subscription links
- Referral / share links
- Advertise / sponsor signup links
- Social media profile links (twitter.com/user, linkedin.com/in/user)
- Newsletter homepage / signup links
- Ad/sponsor landing pages (CData, Modulate, Wispr, Scroll, etc.)

Deduplicate by domain+path (ignore UTM params). Group by topic for readability.

**CRITICAL — cap at ~20 URLs**: Adding too many sources (e.g. 30+) causes NotebookLM **notebook creation itself to fail** (not just audio generation). If extraction yields more than 20 links, curate down to the most substantive 20 (long-form articles, research papers, key announcements). Skip shorter quick-link items, duplicates, and social media posts.

## Step 4 — Create notebook and generate podcast

Write the curated URLs to a temp file (one per line) and run the automation script:

```bash
# Write URLs
cat > /tmp/podcast-urls.txt <<'URLS'
https://example.com/article-1
https://example.com/article-2
...
URLS

# Run the script — it creates the notebook, adds sources, and triggers Audio Overview generation
.claude/scripts/notebooklm-podcast.sh /tmp/podcast-urls.txt
```

The script handles everything: opens browser, loads NotebookLM session, creates notebook, adds URLs as website sources, selects Long length, and clicks Generate. It prints the notebook URL on completion.

If the script fails, see the **Troubleshooting** section below for manual fallback steps.

## Step 5 — Notify via Telegram

Get the notebook URL: `cmux browser <surface> url`

Send a Telegram message to chat_id `5453788502` with:

- Confirmation that the podcast is generating
- Number of sources and which newsletters were included
- Key topics covered
- Link to the notebook

## cmux browser gotchas (learned the hard way)

These behaviors differ from typical Playwright/Chrome MCP expectations:

- **Snapshots miss dynamically-rendered dialog content.** `snapshot --filter interactive` often returns only the background tabs/buttons, not the active dialog. When you cannot find an element in the snapshot, fall back to `get html --selector "mat-dialog-container"` (or a broader selector) and grep for `jslog` attributes. NotebookLM's `jslog` values are stable identifiers tied to specific actions (e.g. 279308=Websites button, 261212=Audio Overview card, 281099=Generate button).
- **`find role button --name X`** fails with `js_error`. Don't use it.
- **Key press commands (`press`, `key`)** — `Control+a`, `Escape`, etc. all fail with `js_error: A JavaScript exception occurred`. Don't rely on them for clearing/dismissing.
- **`fill` with empty string** does not clear a textarea. Use a single space if you must, though here we skip clearing altogether.
- **Selectors that match multiple elements** pick the wrong one silently. Always scope: `mat-dialog-container textarea`, not `textarea`; specific jslog, not `button:last-of-type`.
- **Screenshots are essential** — the accessibility snapshot lies often enough that visual verification after each click is the only way to catch mistakes like opening the settings dropdown instead of Generate.
- **Angular Material pseudo-checkboxes** on mat-button-toggles have `state="checked"` regardless of whether selected — don't trust that to tell you which option is active. Read `aria-checked="true"` on the inner `button` instead.

## Notes

- NotebookLM auto-names the notebook based on source content
- Audio generation takes a few minutes — the notification is sent immediately, not after completion
- Use `cmux browser <surface> screenshot` + `Read` tool after any risky click to verify UI state
- If the browser skill isn't loaded, invoke it first via `Skill` with `browser`
