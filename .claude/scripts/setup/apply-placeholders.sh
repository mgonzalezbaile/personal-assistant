#!/usr/bin/env bash
# Substitute {{NAME}}/{{EMAIL}}/{{GH_HANDLE}}/{{DATE}}/{{TRANSCRIPT_DIR}}
# across the files that carry them in a fresh template clone.
#
# Usage: apply-placeholders.sh <name> <email> <gh_handle_or_empty> <transcript_dir>
#
# Safe to re-run: sed targets {{PLACEHOLDER}} tokens, so once replaced they
# won't match again. Passing "" for gh_handle leaves {{GH_HANDLE}} intact for
# the user to edit manually later.

set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "Usage: $0 <name> <email> <gh_handle_or_empty> <transcript_dir>" >&2
  exit 64
fi

NAME="$1"
EMAIL="$2"
GH_HANDLE="$3"
TRANSCRIPT_DIR="$4"

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$REPO_ROOT"

sed_inplace() {
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

substitute() {
  local placeholder="$1"; shift
  local value="$1"; shift
  local escaped
  escaped=$(printf '%s\n' "$value" | sed 's/[\&/]/\\&/g')
  for file in "$@"; do
    [[ -f "$file" ]] || continue
    sed_inplace "s/{{${placeholder}}}/${escaped}/g" "$file"
  done
}

NAME_FILES=(
  "CLAUDE.md"
  ".claude/commands/wiki-ingest.md"
  ".claude/commands/weekly-done-cleanup.md"
  ".claude/skills/wiki/SKILL.md"
  ".claude/skills/daily-briefing/SKILL.md"
  ".claude/skills/task-context/SKILL.md"
)
substitute NAME "$NAME" "${NAME_FILES[@]}"
substitute EMAIL "$EMAIL" "CLAUDE.md"
substitute DATE "$(date +%Y-%m-%d)" "memory/index.md"

if [[ -n "$GH_HANDLE" ]]; then
  substitute GH_HANDLE "$GH_HANDLE" ".claude/skills/daily-briefing/SKILL.md"
fi

substitute TRANSCRIPT_DIR "$TRANSCRIPT_DIR" ".claude/skills/dream/SKILL.md"

echo "OK"
