#!/usr/bin/env bash
# Wipe .git and re-init with an 'Initial commit from personal-assistant
# template' commit. The caller (/setup command) is responsible for confirming
# with the user before invoking this — the script itself has no safety guards.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$REPO_ROOT"

rm -rf .git
git init -q
git add -A
git commit -q -m "Initial commit from personal-assistant template"
echo "fresh git history initialized at $REPO_ROOT"
