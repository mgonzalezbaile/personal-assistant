#!/usr/bin/env bash
# Ensure .claude/settings.local.json exists and has the template's default
# enabledPlugins merged in. Claude Code's permission-approval UI may create a
# minimal settings.local.json as soon as the user approves a single command,
# which would otherwise shadow the template's .example defaults — so we always
# reconcile enabledPlugins, not just cp-if-missing.
#
# Also creates the scheduler runtime directories (which are gitignored).
# Idempotent.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$REPO_ROOT"

EXAMPLE=".claude/settings.local.json.example"
TARGET=".claude/settings.local.json"

if [[ ! -f "$EXAMPLE" ]]; then
  echo "ERROR: $EXAMPLE not found" >&2
  exit 1
fi

if [[ ! -f "$TARGET" ]]; then
  cp "$EXAMPLE" "$TARGET"
  echo "created $TARGET from example"
else
  if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required to reconcile $TARGET with $EXAMPLE." >&2
    echo "Install with: brew install jq" >&2
    exit 1
  fi
  # Preserve every existing key; layer example.enabledPlugins on top so any
  # plugin the template expects (e.g. telegram) is enabled even when the local
  # file predates /setup. Existing enabledPlugins entries survive; example wins
  # on key conflict.
  TMP="$(mktemp)"
  jq --slurpfile ex "$EXAMPLE" '
    .enabledPlugins = (.enabledPlugins // {}) + (($ex[0].enabledPlugins) // {})
  ' "$TARGET" > "$TMP"
  mv "$TMP" "$TARGET"
  echo "reconciled enabledPlugins in $TARGET with $EXAMPLE"
fi

mkdir -p .claude/schedules/logs .claude/schedules/.last-run
echo "scheduler dirs ready"
