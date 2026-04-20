#!/usr/bin/env bash
# Report the state of voice-transcription dependencies as JSON on stdout.
# No side effects, never fails.
#
# Output schema:
# {
#   "ffmpeg": "<version>" | null,
#   "whisper_cli": true | false,
#   "model_path": "<absolute path>" | null
# }

set -euo pipefail

if command -v ffmpeg >/dev/null 2>&1; then
  FFMPEG_VERSION=$(ffmpeg -version 2>/dev/null | head -1 | awk '{print $3}')
  FFMPEG_JSON="\"$FFMPEG_VERSION\""
else
  FFMPEG_JSON="null"
fi

if command -v whisper-cli >/dev/null 2>&1; then
  WHISPER_JSON="true"
else
  WHISPER_JSON="false"
fi

MODEL_CANDIDATES=(
  "$HOME/.cache/whisper/ggml-large-v3-turbo.bin"
  "$HOME/Library/Application Support/Amical/models/ggml-large-v3-turbo.bin"
  "$HOME/.local/share/whisper/ggml-large-v3-turbo.bin"
)

MODEL_JSON="null"
for candidate in "${MODEL_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    ESCAPED=$(printf '%s' "$candidate" | sed 's/\\/\\\\/g; s/"/\\"/g')
    MODEL_JSON="\"$ESCAPED\""
    break
  fi
done

cat <<EOF
{"ffmpeg": $FFMPEG_JSON, "whisper_cli": $WHISPER_JSON, "model_path": $MODEL_JSON}
EOF
