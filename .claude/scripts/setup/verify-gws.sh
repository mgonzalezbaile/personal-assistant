#!/usr/bin/env bash
# Print the Google account email authenticated against a gws config dir, or
# exit non-zero if not authenticated.
#
# Usage: verify-gws.sh <config_dir>

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <config_dir>" >&2
  exit 64
fi

CONFIG_DIR="$1"

if [[ ! -d "$CONFIG_DIR" ]]; then
  echo "ERROR: config dir does not exist: $CONFIG_DIR" >&2
  exit 1
fi

STATUS_JSON=$(GOOGLE_WORKSPACE_CLI_CONFIG_DIR="$CONFIG_DIR" gws auth status --format=json 2>&1) || {
  echo "ERROR: gws auth status failed for $CONFIG_DIR" >&2
  echo "$STATUS_JSON" >&2
  exit 1
}

EMAIL=$(printf '%s' "$STATUS_JSON" | sed -n 's/.*"user": "\([^"]*\)".*/\1/p' | head -1)

if [[ -z "$EMAIL" ]]; then
  echo "ERROR: no authenticated user found in $CONFIG_DIR" >&2
  exit 1
fi

echo "$EMAIL"
