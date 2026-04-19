# Running multiple Telegram bots on one machine

You can run several assistants from the same laptop, each backed by its own Telegram bot, with their own allowlists and inboxes. The official `telegram` plugin keys all per-bot state off the env var `TELEGRAM_STATE_DIR` (default: `~/.claude/channels/telegram/`).

The recipe: one BotFather bot per assistant + one state dir per bot + one launch alias per assistant.

## Setup

For **each** assistant:

1. **Create a bot** via @BotFather: `/newbot`, pick a unique username, save the token.
2. **Run `setup.sh`** in that assistant's repo and answer "yes" to Telegram. Pick a nickname (e.g. `personal`, `side-project`) — the script writes:
   - `~/.claude/channels/telegram-<nick>/.env` with `TELEGRAM_BOT_TOKEN=...`
   - `~/.claude/channels/telegram-<nick>/access.json` with default pairing policy
3. **Add a launch alias** to `~/.zshrc` (or `~/.bashrc`):
   ```sh
   alias claude-personal='cd ~/Workspace/personal-assistant && \
     TELEGRAM_STATE_DIR=~/.claude/channels/telegram-personal \
     claude --channels plugin:telegram@claude-plugins-official'
   ```
4. **Pair**: source `~/.zshrc`, run `claude-personal`, DM your bot, then in the session:
   ```
   /telegram:access pair <code>
   /telegram:access policy allowlist
   ```

Repeat for the next assistant — different repo, different token, different nickname, different alias.

## Concrete two-bot example

```sh
# In ~/.zshrc:
alias claude-fever='cd ~/Workspace/productivity && \
  TELEGRAM_STATE_DIR=~/.claude/channels/telegram \
  claude --channels plugin:telegram@claude-plugins-official'

alias claude-personal='cd ~/Workspace/personal-assistant && \
  TELEGRAM_STATE_DIR=~/.claude/channels/telegram-personal \
  claude --channels plugin:telegram@claude-plugins-official'
```

Run `claude-fever` in one terminal and `claude-personal` in another — two independent sessions, two bots, two allowlists.

## Common gotchas

- **Forgetting `--channels`**: without it the plugin's MCP server doesn't start and the bot won't reply.
- **Same token in two state dirs**: Telegram only delivers each message once. Don't share tokens across nicknames.
- **Pairing replies but allowlist is empty**: switch policy from `pairing` back to `allowlist` once you've paired, or strangers can keep getting pairing-code replies.
- **Bot offline**: check the bot is running by tailing `~/.claude/channels/telegram-<nick>/bot.pid` and the Claude session for `[telegram]` log lines.
