# Personal Assistant — a Claude Code template

A starter project for running [Claude Code](https://claude.com/code) as a long-running personal assistant. Ships with:

- **Task list** (`TASKS.md`) — Eisenhower-classified active / waiting-on / someday / done
- **Memory wiki** (`memory/`) — interlinked knowledge base maintained by the assistant
- **Skills** for daily briefings, wiki ingest/query, voice transcription, Google Workspace access, browser automation, and memory consolidation
- **Slash commands** for AI podcast generation, weekly cleanup, and wiki ingest
- **Scheduler** — drop a markdown task into `.claude/schedules/` and it runs on a cron
- **Telegram-bot–ready** — wire a bot in once and chat with your assistant from your phone

Clone, run `./setup.sh`, you're done.

---

## Prerequisites

- [Claude Code](https://claude.com/code) installed (`claude` on PATH)
- [`gh`](https://cli.github.com) (for cloning + the `daily-briefing` PR-search step)
- [Bun](https://bun.sh) (only if you enable the Telegram bot)
- [`gws`](https://googleworkspace-cli.mintlify.app) (only if you enable the `google-workspace-cli` skill)
- macOS or Linux. Tested on macOS.

---

## Quick start

```sh
git clone https://github.com/<you>/<your-fork>.git ~/Workspace/my-assistant
cd ~/Workspace/my-assistant
./setup.sh
claude
```

`setup.sh` interactively asks for:

| Prompt | Used for |
|---|---|
| Your name | `{{NAME}}` in CLAUDE.md, skills, commands |
| Your email | `{{EMAIL}}` in CLAUDE.md |
| GitHub username (optional) | PR search in `daily-briefing` |
| Cursor transcript dir (optional) | `dream` skill (memory consolidation from Cursor sessions) |
| Telegram bot setup (optional) | Wires a bot at `~/.claude/channels/telegram-<nick>/` |
| Wipe template git history (optional) | Fresh `git init` so your assistant's history starts clean |

It's idempotent — re-run anytime to update placeholders.

---

## Personalize

After setup:

1. Open `CLAUDE.md` and edit the **Preferences** block to match how you want the assistant to behave.
2. Drop reference docs (meeting notes, articles, transcripts) into `sources/`. Run `/wiki-ingest` and the assistant will turn them into wiki pages under `memory/`.
3. Add tasks to `TASKS.md` directly, or just tell the assistant in chat ("add a task to call the dentist").
4. Ask "what's my plan today?" to test the `daily-briefing` skill end-to-end.

---

## Telegram bot

The Telegram plugin lets you DM your assistant from anywhere. Setup is split between BotFather (Telegram side) and `setup.sh` (local side):

1. In Telegram, message [@BotFather](https://t.me/BotFather): `/newbot`. Follow the prompts; copy the token it returns.
2. Run `./setup.sh` (or re-run it) and answer **yes** to "Set up a Telegram bot?". Paste the token.
3. The script writes the token to `~/.claude/channels/telegram-<nick>/.env` and prints the launch command:
   ```sh
   TELEGRAM_STATE_DIR=~/.claude/channels/telegram-<nick> \
     claude --channels plugin:telegram@claude-plugins-official
   ```
4. Once the session is running, DM your bot. It returns a 6-character pairing code. In Claude:
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
├── setup.sh                     interactive bootstrap
├── .claude/
│   ├── settings.json            project-level Claude Code settings
│   ├── settings.local.json.example  copy → .local on first setup
│   ├── mcp.json                 MCP servers (project-scoped)
│   ├── commands/                slash commands
│   ├── skills/                  capability skills
│   ├── scripts/                 helper shell scripts (used by skills)
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
