#!/usr/bin/env bash
# Create ~/.config/<dir_name>/ and print the 'gws auth setup' command the user
# should run with the right env var set so gws writes credentials there.
#
# Usage: ensure-gws-config-dir.sh <dir_name>

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <dir_name>" >&2
  exit 64
fi

DIR_NAME="$1"
CONFIG_DIR="$HOME/.config/$DIR_NAME"

mkdir -p "$CONFIG_DIR"

cat <<EOF
ready: $CONFIG_DIR

Run this in a separate terminal to complete OAuth against the Google account you want this assistant to use:

  GOOGLE_WORKSPACE_CLI_CONFIG_DIR=$CONFIG_DIR gws auth setup

It opens a browser. Sign in with the correct Google account. When it finishes, come back here and confirm.
EOF
