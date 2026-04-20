#!/usr/bin/env bash
# Approve a Telegram pairing code against a nicked state dir.
#
# Usage: pair-telegram.sh <nick> <code>
#
# Background: the @claude-plugins-official/telegram@0.0.6 plugin ships a
# /telegram:access slash command whose SKILL.md hardcodes
# ~/.claude/channels/telegram/access.json — it ignores $TELEGRAM_STATE_DIR.
# That means the slash command reads/writes the wrong file whenever nick is
# anything other than the default. This script is the portable workaround:
# it edits the correct state dir directly (same shape the bot server
# expects) so the bot replies to the paired sender regardless of which nick
# is in use.
#
# Side effects (mirroring the /telegram:access pair <code> skill):
#   - Adds pending[<code>].senderId to allowFrom (dedupe)
#   - Sets dmPolicy to "allowlist"
#   - Deletes pending[<code>]
#   - Writes approved/<senderId> with chatId as contents (the bot server
#     polls this dir to send the "you're in" confirmation)

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <nick> <code>" >&2
  exit 64
fi

NICK="$1"
CODE="$2"

if [[ -z "$NICK" ]]; then
  echo "ERROR: nick must not be empty" >&2
  exit 64
fi
if [[ -z "$CODE" ]]; then
  echo "ERROR: code must not be empty" >&2
  exit 64
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required. Install with: brew install jq" >&2
  exit 1
fi

STATE_DIR="$HOME/.claude/channels/telegram-$NICK"
ACCESS_FILE="$STATE_DIR/access.json"

if [[ ! -f "$ACCESS_FILE" ]]; then
  echo "ERROR: $ACCESS_FILE not found — has 'make run' been started with this nick?" >&2
  exit 1
fi

# Pull sender/chat IDs out before mutating, so we can verify and write the
# approved marker. Empty string if the code isn't pending.
SENDER_ID="$(jq -r --arg code "$CODE" '.pending[$code].senderId // ""' "$ACCESS_FILE")"
CHAT_ID="$(jq -r --arg code "$CODE" '.pending[$code].chatId // ""' "$ACCESS_FILE")"

if [[ -z "$SENDER_ID" ]]; then
  echo "ERROR: no pending pairing with code '$CODE' in $ACCESS_FILE" >&2
  echo "Pending codes:" >&2
  jq -r '.pending | keys[]' "$ACCESS_FILE" >&2 || true
  exit 1
fi

EXPIRES_AT="$(jq -r --arg code "$CODE" '.pending[$code].expiresAt // 0' "$ACCESS_FILE")"
NOW_MS="$(date +%s000)"
if [[ "$EXPIRES_AT" != "0" && "$EXPIRES_AT" -lt "$NOW_MS" ]]; then
  echo "ERROR: pairing code '$CODE' has expired. Have the user DM the bot again." >&2
  exit 1
fi

TMP="$(mktemp)"
jq --arg code "$CODE" --arg sender "$SENDER_ID" '
  .allowFrom = ((.allowFrom // []) + [$sender] | unique)
  | .dmPolicy = "allowlist"
  | del(.pending[$code])
' "$ACCESS_FILE" > "$TMP"
mv "$TMP" "$ACCESS_FILE"

mkdir -p "$STATE_DIR/approved"
printf '%s' "$CHAT_ID" > "$STATE_DIR/approved/$SENDER_ID"

echo "paired sender $SENDER_ID (chat $CHAT_ID) in $STATE_DIR"
echo "dmPolicy set to 'allowlist'; bot server should DM the user 'you're in' shortly"
