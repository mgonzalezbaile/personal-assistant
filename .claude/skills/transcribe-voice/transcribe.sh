#!/usr/bin/env bash
# Transcribe a Telegram voice message (.oga) to text.
# Usage: transcribe.sh <input.oga> [message_id]
# Outputs only the transcribed text to stdout.

set -euo pipefail

INPUT="$1"
MSG_ID="${2:-voice}"
WAV="/tmp/telegram_voice_${MSG_ID}.wav"
MODEL="$HOME/Library/Application Support/Amical/models/ggml-large-v3-turbo.bin"

# Convert to 16kHz mono WAV
ffmpeg -y -i "$INPUT" -ar 16000 -ac 1 "$WAV" 2>/dev/null

# Transcribe and extract only the text (skip model loading logs)
TEXT=$(whisper-cli -m "$MODEL" -f "$WAV" --no-timestamps 2>/dev/null | sed '/^$/d')

# Cleanup
rm -f "$WAV"

echo "$TEXT"
