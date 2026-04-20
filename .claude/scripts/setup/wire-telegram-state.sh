#!/usr/bin/env bash
# Create ~/.claude/channels/telegram-<nick>/ with .env (token) and access.json
# (default pairing policy).
#
# Usage: wire-telegram-state.sh <nick> <bot_token> [--force]
#
# Without --force, refuses to overwrite an existing non-empty .env so re-running
# /setup can't silently replace a paired bot's token.

set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: $0 <nick> <bot_token> [--force]" >&2
  exit 64
fi

NICK="$1"
TOKEN="$2"
FORCE="${3:-}"

if [[ -z "$NICK" ]]; then
  echo "ERROR: nick must not be empty" >&2
  exit 64
fi
if [[ -z "$TOKEN" ]]; then
  echo "ERROR: token must not be empty" >&2
  exit 64
fi
if [[ -n "$FORCE" && "$FORCE" != "--force" ]]; then
  echo "ERROR: third arg must be --force or omitted (got: $FORCE)" >&2
  exit 64
fi

STATE_DIR="$HOME/.claude/channels/telegram-$NICK"
ENV_FILE="$STATE_DIR/.env"
ACCESS_FILE="$STATE_DIR/access.json"

mkdir -p "$STATE_DIR"

if [[ -s "$ENV_FILE" && "$FORCE" != "--force" ]]; then
  echo "ERROR: $ENV_FILE already exists and is non-empty; pass --force to overwrite" >&2
  exit 1
fi

printf 'TELEGRAM_BOT_TOKEN=%s\n' "$TOKEN" > "$ENV_FILE"
chmod 600 "$ENV_FILE"

if [[ ! -f "$ACCESS_FILE" ]]; then
  cat > "$ACCESS_FILE" <<'JSON'
{
  "dmPolicy": "pairing",
  "allowFrom": [],
  "groups": {},
  "pending": {}
}
JSON
fi

echo "$STATE_DIR"
