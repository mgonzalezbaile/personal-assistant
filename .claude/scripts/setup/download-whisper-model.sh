#!/usr/bin/env bash
# Download Whisper large-v3-turbo (~1.6 GB) into ~/.cache/whisper/.
# No prompts. The caller is responsible for asking the user first.
# Idempotent: if the file already exists at the destination, exits 0 without
# re-downloading.

set -euo pipefail

DEST="$HOME/.cache/whisper/ggml-large-v3-turbo.bin"
URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin"

if [[ -f "$DEST" ]]; then
  echo "already present at $DEST"
  exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "ERROR: curl not found. Install curl or download manually:" >&2
  echo "  $URL" >&2
  echo "  -> $DEST" >&2
  exit 1
fi

mkdir -p "$(dirname "$DEST")"

if curl -L --fail --progress-bar -o "$DEST" "$URL"; then
  echo "downloaded to $DEST"
else
  rm -f "$DEST"
  echo "ERROR: download failed" >&2
  exit 1
fi
