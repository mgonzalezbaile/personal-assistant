#!/usr/bin/env bash
# Transcribe a Telegram voice message (.oga) to text.
# Usage: transcribe.sh <input.oga> [message_id]
# Outputs only the transcribed text to stdout.

set -euo pipefail

INPUT="$1"
MSG_ID="${2:-voice}"
WAV="/tmp/telegram_voice_${MSG_ID}.wav"

# Resolve the whisper model. Search known locations in order so we reuse
# whatever's already on disk (e.g. from a prior Amical install) before
# falling back to the canonical setup.sh download path.
MODEL_CANDIDATES=(
  "$HOME/.cache/whisper/ggml-large-v3-turbo.bin"
  "$HOME/Library/Application Support/Amical/models/ggml-large-v3-turbo.bin"
  "$HOME/.local/share/whisper/ggml-large-v3-turbo.bin"
)

MODEL=""
for candidate in "${MODEL_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    MODEL="$candidate"
    break
  fi
done

if [[ -z "$MODEL" ]]; then
  echo "ERROR: ggml-large-v3-turbo.bin not found. Searched:" >&2
  for candidate in "${MODEL_CANDIDATES[@]}"; do
    echo "  - $candidate" >&2
  done
  echo "Re-run ./setup.sh and accept the model download, or place the file at the first path." >&2
  exit 1
fi

ffmpeg -y -i "$INPUT" -ar 16000 -ac 1 "$WAV" 2>/dev/null

TEXT=$(whisper-cli -m "$MODEL" -f "$WAV" --no-timestamps 2>/dev/null | sed '/^$/d')

rm -f "$WAV"

echo "$TEXT"
