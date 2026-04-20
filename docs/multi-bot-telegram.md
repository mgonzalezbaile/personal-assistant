# Running multiple Telegram bots on one machine

You can run several assistants from the same laptop, each backed by its own Telegram bot, with their own allowlists and inboxes. The official `telegram` plugin keys all per-bot state off the env var `TELEGRAM_STATE_DIR` (default: `~/.claude/channels/telegram/`).

The recipe: one BotFather bot per assistant + one state dir per bot + one repo per assistant with a generated `makefile` that pins `TELEGRAM_STATE_DIR`.

## Setup

For **each** assistant:

1. **Create a bot** via @BotFather: `/newbot`, pick a unique username, save the token.
2. **In that assistant's repo**, launch `claude` and run `/setup`. Answer "yes" to Telegram. Pick a nickname (e.g. `personal`, `side-project`) — `/setup` writes:
   - `~/.claude/channels/telegram-<nick>/.env` with `TELEGRAM_BOT_TOKEN=...`
   - `~/.claude/channels/telegram-<nick>/access.json` with default pairing policy
   - `./makefile` at the repo root, with `TELEGRAM_STATE_DIR` (and optionally `GOOGLE_WORKSPACE_CLI_CONFIG_DIR` / `GH_TOKEN`) wired to this assistant
3. **Launch + pair**: `make run`, DM your bot to receive a 6-char pairing code. **Do not use `/telegram:access pair <code>`** when running with a non-default nick — see the "`/telegram:access` and custom nicks" gotcha below. Instead, from a second terminal in the repo:
   ```sh
   .claude/scripts/setup/pair-telegram.sh <nick> <code>
   ```
   The script mutates the correct nicked state dir directly; the bot server picks up the change and replies with "you're in".

Repeat for the next assistant — different repo, different token, different nickname, different `gws`/`gh` config if you want isolated Google/GitHub identities.

## Concrete two-bot example

Two repos, each with its own `make run`:

```sh
cd ~/Workspace/productivity && make run      # bot 1 → ~/.claude/channels/telegram/
cd ~/Workspace/personal-assistant && make run # bot 2 → ~/.claude/channels/telegram-personal/
```

Run each in its own terminal — two independent sessions, two bots, two allowlists, optionally two Google accounts and two GitHub accounts.

## Common gotchas

- **Forgetting `--channels`**: without it the plugin's MCP server doesn't start and the bot won't reply. `/setup`'s generated `makefile` already wires this flag.
- **Plugin not enabled in settings**: `settings.local.json` must contain `"enabledPlugins": {"telegram@claude-plugins-official": true}`. The template's `.example` has this, and `init-settings-local.sh` reconciles it into any pre-existing `settings.local.json`.
- **`/telegram:access` and custom nicks**: as of `@claude-plugins-official/telegram@0.0.6`, the `/telegram:access` slash command hardcodes `~/.claude/channels/telegram/access.json` — it ignores `TELEGRAM_STATE_DIR`. That means it operates on the wrong file whenever you're running with a non-default nick. Workaround: use `.claude/scripts/setup/pair-telegram.sh <nick> <code>` instead of `/telegram:access pair <code>`. The script writes directly to the correct state dir (same shape the skill would produce). Track upstream for a proper fix.
- **Same token in two state dirs**: Telegram only delivers each message once. Don't share tokens across nicknames.
- **Pairing replies but allowlist is empty**: switch policy from `pairing` back to `allowlist` once you've paired, or strangers can keep getting pairing-code replies. `pair-telegram.sh` does this flip for you.
- **Bot offline**: check the bot is running by tailing `~/.claude/channels/telegram-<nick>/bot.pid` and the Claude session for `[telegram]` log lines.
