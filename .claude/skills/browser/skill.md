---
name: browser
description: "Open and control the cmux embedded browser. Handles pane creation and session loading automatically. Use whenever any web browsing or browser automation is needed."
tags: [browser, cmux, automation, navigation]
---

# Browser

Use this skill for ALL browser interactions. NEVER use `mcp__claude-in-chrome__*` or `mcp__chrome-devtools__*` tools.

## Steps

### 1. Find or open a browser pane

Check if one already exists in the current workspace:
```bash
cmux tree
```

If no browser surface exists, open one and note the returned surface ref (e.g. `surface:11`):
```bash
cmux browser open
```

### 2. Load all saved sessions

Navigate to a blank page first (required — Google and other strict domains block state loading via CSP):
```bash
cmux browser <surface> navigate about:blank
```

Then load every session file in one pass:
```bash
for f in ~/.cmux/sessions/*.json; do
  cmux browser <surface> state load "$f"
done
```

### 3. Navigate to the target URL

```bash
cmux browser <surface> navigate <url>
```

### 4. Interact as needed

Use `cmux browser <surface> <subcommand>` — `snapshot`, `click`, `fill`, `type`, `eval`, `screenshot`, etc.

---

## Saving a new session

After the user logs into a platform manually:

1. Navigate to blank page: `cmux browser <surface> navigate about:blank`
2. Save state: `cmux browser <surface> state save ~/.cmux/sessions/<platform>.json`
3. Add the platform to the table below.

## Saved sessions

| Platform | File |
|----------|------|
| NotebookLM | `~/.cmux/sessions/notebooklm.json` |
