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
3. **Launch + pair**: `make run`, DM your bot, then in the session:
   ```
   /telegram:access pair <code>
   /telegram:access policy allowlist
   ```

Repeat for the next assistant — different repo, different token, different nickname, different `gws`/`gh` config if you want isolated Google/GitHub identities.

## Concrete two-bot example

Two repos, each with its own `make run`:

```sh
cd ~/Workspace/productivity && make run      # bot 1 → ~/.claude/channels/telegram/
cd ~/Workspace/personal-assistant && make run # bot 2 → ~/.claude/channels/telegram-personal/
```

Run each in its own terminal — two independent sessions, two bots, two allowlists, optionally two Google accounts and two GitHub accounts.

## Common gotchas

- **Forgetting `--channels`**: without it the plugin's MCP server doesn't start and the bot won't reply.
- **Same token in two state dirs**: Telegram only delivers each message once. Don't share tokens across nicknames.
- **Pairing replies but allowlist is empty**: switch policy from `pairing` back to `allowlist` once you've paired, or strangers can keep getting pairing-code replies.
- **Bot offline**: check the bot is running by tailing `~/.claude/channels/telegram-<nick>/bot.pid` and the Claude session for `[telegram]` log lines.
