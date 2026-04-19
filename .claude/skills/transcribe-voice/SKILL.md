---
name: transcribe-voice
description: Use when a Telegram message arrives with attachment_kind="voice". Transcribes voice messages using ffmpeg and whisper-cpp with the local ggml-large-v3-turbo model.
user-invocable: false
allowed-tools:
  - Bash(ffmpeg *)
  - Bash(whisper-cli *)
  - Bash(rm *)
  - Bash(*transcribe.sh*)
  - Read
  - mcp__plugin_telegram_telegram__download_attachment
  - mcp__plugin_telegram_telegram__reply
---

# Transcribe Telegram Voice Messages

When a Telegram message arrives with `attachment_kind="voice"` and an
`attachment_file_id`, follow this pipeline:

## Steps

1. **Download** — call `mcp__plugin_telegram_telegram__download_attachment`
   with the `attachment_file_id`. It returns a local `.oga` file path.

2. **Transcribe** — run the bundled script (converts + transcribes + cleans up in one call):
   ```
   bash "<skill_dir>/transcribe.sh" <input.oga> <message_id>
   ```
   Where `<skill_dir>` is the base directory shown when the skill loads.
   The script outputs only the transcribed text to stdout.

3. **Respond** — treat the transcribed text as if the user had typed it.
   Process the request and reply via `mcp__plugin_telegram_telegram__reply`.
   Do NOT quote the transcription back unless clarification is needed —
   just act on it naturally.

## Notes

- Model: Whisper large-v3-turbo (GGML format)
- Runtime: whisper-cpp (installed via Homebrew: `brew install whisper-cpp ffmpeg`)
- `transcribe.sh` searches for the model in this order and uses the first hit:
  1. `~/.cache/whisper/ggml-large-v3-turbo.bin` (canonical, written by `setup.sh`)
  2. `~/Library/Application Support/Amical/models/ggml-large-v3-turbo.bin` (reused if Amical is installed)
  3. `~/.local/share/whisper/ggml-large-v3-turbo.bin`
- If none exist, run `./setup.sh` and accept the model download (~1.6 GB from Hugging Face).
- Transcription takes ~1-2 seconds on M4 Max
- The model auto-detects language (supports 100 languages)
