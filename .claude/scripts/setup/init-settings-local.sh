#!/usr/bin/env bash
# Copy .claude/settings.local.json.example → .claude/settings.local.json if
# missing, and create the scheduler runtime directories (which are gitignored).
# Idempotent.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$REPO_ROOT"

if [[ ! -f .claude/settings.local.json ]]; then
  if [[ -f .claude/settings.local.json.example ]]; then
    cp .claude/settings.local.json.example .claude/settings.local.json
    echo "created .claude/settings.local.json from example"
  else
    echo "ERROR: .claude/settings.local.json.example not found" >&2
    exit 1
  fi
else
  echo "settings.local.json already exists, skipping"
fi

mkdir -p .claude/schedules/logs .claude/schedules/.last-run
echo "scheduler dirs ready"
