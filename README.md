# Personal Assistant — a Claude Code / Cursor template

A starter project for running a long-running personal assistant on top of [Claude Code](https://claude.com/code) or [Cursor](https://cursor.com) — the templates, skills, and memory layout are agent-agnostic, so use whichever you prefer. Ships with:

- **Task list** (`TASKS.md`) — Eisenhower-classified active / waiting-on / someday / done
- **Memory wiki** (`memory/`) — interlinked knowledge base maintained by the assistant
- **Skills** for daily briefings, wiki ingest/query, voice transcription, Google Workspace access, browser automation, and memory consolidation
- **Slash commands** for AI podcast generation, weekly cleanup, and wiki ingest
- **Scheduler** — drop a markdown task into `.claude/schedules/` and it runs on a cron
- **Telegram-bot–ready** — wire a bot in once and chat with your assistant from your phone

Clone, launch your agent of choice, run the setup flow, you're done.

---

## Demos

Two short walkthroughs covering the core use cases — ingesting a meeting transcript into the memory wiki, building a daily briefing from GitHub and Google Calendar, and creating tasks that pull context from existing memories.

|  |  |
|:---:|:---:|
| [![Demo 1](https://img.youtube.com/vi/hw3QfQ75yc0/hqdefault.jpg)](https://www.youtube.com/watch?v=hw3QfQ75yc0) | [![Demo 2](https://img.youtube.com/vi/h1O2-p98OXQ/hqdefault.jpg)](https://www.youtube.com/watch?v=h1O2-p98OXQ) |

---

## Prerequisites

- [Claude Code](https://claude.com/code) (`claude` on PATH) **or** [Cursor](https://cursor.com) — either one drives the setup flow. Claude Code is also required for the scheduler (see below) if you want cron-style runs.
- [`gh`](https://cli.github.com) (for cloning + the `daily-briefing` PR-search step)
- [Bun](https://bun.sh) (only if you enable the Telegram bot)
- [`gws`](https://googleworkspace-cli.mintlify.app) (only if you enable Google Workspace integration — `/setup` walks you through the OAuth step; you'll also need Node.js + the [`gcloud` SDK](https://cloud.google.com/sdk/docs/install))
- `ffmpeg` + [`whisper-cpp`](https://github.com/ggerganov/whisper.cpp) (only for Telegram voice-note transcription — `brew install ffmpeg whisper-cpp`; `/setup` will offer to download the ~1.6 GB Whisper model, or reuse it from an existing [Amical](https://amical.ai) install)
- macOS or Linux. Tested on macOS.

---

## Quick start

Clone the template:

```sh
git clone https://github.com/<you>/<your-fork>.git ~/Workspace/my-assistant
cd ~/Workspace/my-assistant
```

Then pick your agent:

### With Claude Code

```sh
claude
```

In the Claude session:

```
/setup
```

### With Cursor

Open the project in Cursor and start an agent chat. Then send:

```
/setup
```

Cursor will read the runbook and walk you through the exact same interview. (The `.claude/commands/` files are just natural-language instructions — nothing in them is Claude-Code-only.)

---

`/setup` (or the Cursor equivalent above) is agent-driven: it interviews you, runs deterministic scripts under [.claude/scripts/setup/](.claude/scripts/setup/) for the mechanical work, and pauses for you to complete interactive steps (OAuth, BotFather) outside the chat. What it asks for:

| Prompt | Used for |
|---|---|
| Your name | `{{NAME}}` in CLAUDE.md, skills, commands |
| Your email | `{{EMAIL}}` in CLAUDE.md |
| GitHub username (optional) | PR search in `daily-briefing` |
| Cursor transcript dir (optional) | `dream` skill (memory consolidation from Cursor sessions) |
| Voice transcription deps | Checks for `ffmpeg`, `whisper-cli`, Whisper model; offers to download the model |
| Google Workspace (optional) | Creates an isolated `~/.config/gws-<nick>/` and walks you through `gws auth setup` against the Google account this assistant should use |
| GitHub account pin (optional, only if 2+ `gh` accounts) | Bakes `gh auth token --user <chosen>` into the makefile so `daily-briefing` uses the right account |
| Telegram bot (optional) | Guides you through BotFather, wires token to `~/.claude/channels/telegram-<nick>/` |
| Wipe template git history (optional) | Fresh `git init` so your assistant's history starts clean |

At the end `/setup` generates a `makefile` with the right per-assistant env vars. Launch with `make run`.

`/setup` is idempotent — re-run it anytime and it'll detect completed steps and offer to skip or redo each one individually.

---

## Personalize

After setup:

1. Open `CLAUDE.md` and edit the **Preferences** block to match how you want the assistant to behave.
2. Drop reference docs (meeting notes, articles, transcripts) into `sources/`. Run `/wiki-ingest` and the assistant will turn them into wiki pages under `memory/`.
3. Add tasks to `TASKS.md` directly, or just tell the assistant in chat ("add a task to call the dentist").
4. Ask "what's my plan today?" to test the `daily-briefing` skill end-to-end.

---

## Telegram bot

The Telegram plugin lets you DM your assistant from anywhere. Setup is split between BotFather (Telegram side) and `/setup` (local side):

1. In Telegram, message [@BotFather](https://t.me/BotFather): `/newbot`. Follow the prompts; copy the token it returns.
2. In your agent session (Claude Code or Cursor), run the setup flow again and answer **yes** to "Set up a Telegram bot?". Paste the token.
3. `/setup` writes the token to `~/.claude/channels/telegram-<nick>/.env` and generates a `makefile` with the right `TELEGRAM_STATE_DIR` wired in.
4. Launch the assistant with `make run`, then DM your bot. It returns a 6-character pairing code. In your agent session:
   ```
   /telegram:access pair <code>
   /telegram:access policy allowlist
   ```

After pairing, the bot only accepts messages from you.

For running **multiple assistants** with **separate bots** on the same machine, see [`docs/multi-bot-telegram.md`](docs/multi-bot-telegram.md).

---

## What's in the box

```
.
├── CLAUDE.md                    persistent assistant instructions (loaded every session)
├── TASKS.md                     your task list
├── memory/index.md              wiki index (catalog of memory/ pages)
├── sources/                     drop raw docs here for /wiki-ingest
├── makefile                     generated by /setup; runs the assistant via 'make run'
├── .claude/
│   ├── settings.json            project-level Claude Code settings
│   ├── settings.local.json.example  copy → .local on first setup
│   ├── mcp.json                 MCP servers (project-scoped)
│   ├── commands/                slash commands (includes /setup, the bootstrap flow)
│   ├── skills/                  capability skills
│   ├── scripts/
│   │   └── setup/               deterministic building blocks invoked by /setup
│   └── schedules/               drop .md files here for cron-style runs
└── docs/
    └── multi-bot-telegram.md
```

### Skills

| Skill | Purpose | External deps |
|---|---|---|
| `daily-briefing` | Calendar + PRs + tasks → Eisenhower-classified plan | `gws`, `gh` |
| `dream` | Scans Cursor transcripts, merges into wiki | none |
| `wiki` | Ingest / query / lint the memory wiki | none |
| `task-context` | Loads relevant wiki pages when creating/editing tasks | none |
| `browser` | Drives the cmux embedded browser | cmux |
| `transcribe-voice` | Turns Telegram voice notes into text | `ffmpeg`, `whisper-cpp` |
| `google-workspace-cli` | Search/read/edit Drive, Docs, Sheets, Gmail, Calendar | `gws` |

### Slash commands

| Command | Purpose |
|---|---|
| `/setup` | One-time agent-driven bootstrap (identity, gws, Telegram, makefile) |
| `/wiki-ingest` | Process raw docs from `sources/` into wiki pages |
| `/weekly-done-cleanup` | Archive stale completed tasks |
| `/ai-podcast` | Generate an audio briefing via NotebookLM |

---

## Scheduler

Drop a `.md` file into `.claude/schedules/` with frontmatter like:

```yaml
---
name: morning-briefing
schedule: "0 8 * * *"     # cron expression
---

Send a daily-briefing reply via Telegram to my paired chat.
```

The dispatcher (`schedule-dispatcher.sh`) runs every 15 minutes via launchd / cron and executes any due tasks via the `claude` CLI. Wire it up in your launchd / crontab pointing at `.claude/scripts/schedule-dispatcher.sh`.

---

## License

MIT — see [LICENSE](LICENSE).
