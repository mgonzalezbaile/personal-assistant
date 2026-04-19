#!/usr/bin/env bash
# Personal Assistant template — interactive bootstrap.
# Run once after `git clone`. Idempotent: re-run to update placeholders.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_ROOT"

# ── helpers ───────────────────────────────────────────────────────────────
sed_inplace() {
  # Cross-platform sed -i: macOS needs '' after -i, GNU does not.
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

ask() {
  local prompt="$1"
  local default="${2:-}"
  local var
  if [[ -n "$default" ]]; then
    read -r -p "$prompt [$default]: " var
    echo "${var:-$default}"
  else
    read -r -p "$prompt: " var
    echo "$var"
  fi
}

confirm() {
  local prompt="$1"
  local default="${2:-n}"
  local yn
  read -r -p "$prompt [y/N]: " yn
  yn="${yn:-$default}"
  [[ "$yn" =~ ^[Yy]$ ]]
}

substitute() {
  # substitute PLACEHOLDER VALUE [files...]
  local placeholder="$1"; shift
  local value="$1"; shift
  # Escape sed metacharacters in value
  local escaped
  escaped=$(printf '%s\n' "$value" | sed 's/[\&/]/\\&/g')
  for file in "$@"; do
    [[ -f "$file" ]] || continue
    sed_inplace "s/{{${placeholder}}}/${escaped}/g" "$file"
  done
}

# ── 1. identity ──────────────────────────────────────────────────────────
echo
echo "Personal Assistant — setup"
echo "──────────────────────────"
echo

NAME=$(ask "Your name")
EMAIL=$(ask "Your email")

# ── 2. GitHub handle (optional) ──────────────────────────────────────────
GH_HANDLE=$(ask "Your GitHub username (for daily-briefing PR search; leave empty to skip)" "")

# ── 3. transcript dir for dream skill ────────────────────────────────────
DEFAULT_TRANSCRIPT_DIR="$HOME/.cursor/projects/$(echo "$REPO_ROOT" | sed 's|^/||; s|/|-|g')/agent-transcripts/"
TRANSCRIPT_DIR=$(ask "Path to Cursor agent-transcripts (used by 'dream' skill)" "$DEFAULT_TRANSCRIPT_DIR")

# ── 4. apply substitutions ───────────────────────────────────────────────
echo
echo "Applying placeholders..."

# Files with {{NAME}} / {{EMAIL}}
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

# Today's date in memory/index.md
substitute DATE "$(date +%Y-%m-%d)" "memory/index.md"

# Daily-briefing GH handle (or strip the section if empty)
if [[ -n "$GH_HANDLE" ]]; then
  substitute GH_HANDLE "$GH_HANDLE" ".claude/skills/daily-briefing/SKILL.md"
else
  echo "  - no GH handle given; leaving {{GH_HANDLE}} placeholder in daily-briefing/SKILL.md"
  echo "    (edit manually or remove the PR-search section)"
fi

# Dream transcript dir
substitute TRANSCRIPT_DIR "$TRANSCRIPT_DIR" ".claude/skills/dream/SKILL.md"

# ── 5. settings.local.json + scheduler dirs ──────────────────────────────
if [[ ! -f .claude/settings.local.json ]]; then
  cp .claude/settings.local.json.example .claude/settings.local.json
  echo "  - created .claude/settings.local.json from example"
fi
mkdir -p .claude/schedules/logs .claude/schedules/.last-run

# ── 6. Google Workspace integration (optional) ───────────────────────────
echo
if confirm "Enable Google Workspace integration (gws CLI — used by daily-briefing and the google-workspace-cli skill)?"; then
  echo
  echo "Checklist:"

  if command -v node >/dev/null 2>&1; then
    echo "  ✓ node found ($(node --version))"
  else
    echo "  ✗ node not found. Install Node.js: https://nodejs.org"
    echo "    (the gws CLI is distributed via npm)"
  fi

  if command -v gws >/dev/null 2>&1; then
    echo "  ✓ gws found ($(gws --version 2>/dev/null || echo 'version unknown'))"
  else
    echo "  ✗ gws not found. Install with:"
    echo "      npm install -g @googleworkspace/cli"
  fi

  if command -v gcloud >/dev/null 2>&1; then
    echo "  ✓ gcloud found ($(gcloud --version 2>/dev/null | head -1))"
  else
    echo "  ✗ gcloud not found. Install the Google Cloud SDK:"
    echo "      https://cloud.google.com/sdk/docs/install"
    echo "    Then run 'gcloud auth login' before the next step."
  fi

  cat <<'EOF'

Once node, gws, and gcloud are all installed (and gcloud is authenticated), run:

  gws auth setup

This is interactive: it creates a Google Cloud project for you, enables the
Workspace APIs (Gmail, Drive, Calendar, etc), creates an OAuth client, and
opens your browser to complete login. Takes ~2 minutes.

Manual alternative (if you'd rather not use gws auth setup):
  - Create your own GCP project at https://console.cloud.google.com
  - Enable the Workspace APIs you need
  - Create OAuth 2.0 Desktop client credentials
  - Save the JSON as ~/.config/gws/client_secret.json
  - Run: gws auth login

EOF
else
  echo "  - skipping Google Workspace setup"
  echo "    (the daily-briefing skill's calendar step + google-workspace-cli skill won't work until you set this up)"
fi

# ── 7. Telegram bot setup (optional) ─────────────────────────────────────
echo
if confirm "Set up a Telegram bot for this assistant?"; then
  echo
  echo "Steps before continuing:"
  echo "  1. Open Telegram, message @BotFather, send /newbot"
  echo "  2. Follow prompts to pick a name + username"
  echo "  3. Copy the token BotFather returns (looks like 12345:AAH...)"
  echo
  read -r -p "Paste the bot token: " BOT_TOKEN

  default_nick="$(basename "$REPO_ROOT")"
  NICK=$(ask "State-dir nickname (chosen as 'telegram-<nick>')" "$default_nick")
  STATE_DIR="$HOME/.claude/channels/telegram-$NICK"

  mkdir -p "$STATE_DIR"
  printf 'TELEGRAM_BOT_TOKEN=%s\n' "$BOT_TOKEN" > "$STATE_DIR/.env"
  chmod 600 "$STATE_DIR/.env"
  if [[ ! -f "$STATE_DIR/access.json" ]]; then
    cat > "$STATE_DIR/access.json" <<'JSON'
{
  "dmPolicy": "pairing",
  "allowFrom": [],
  "groups": {},
  "pending": {}
}
JSON
  fi

  echo
  echo "Voice-message transcription dependencies (used by the transcribe-voice skill):"

  if command -v ffmpeg >/dev/null 2>&1; then
    echo "  ✓ ffmpeg found ($(ffmpeg -version 2>/dev/null | head -1 | awk '{print $3}'))"
  else
    echo "  ✗ ffmpeg not found. Install with:"
    echo "      brew install ffmpeg"
  fi

  if command -v whisper-cli >/dev/null 2>&1; then
    echo "  ✓ whisper-cli found"
  else
    echo "  ✗ whisper-cli not found. Install with:"
    echo "      brew install whisper-cpp"
  fi

  # Same search order as transcribe.sh — reuse any existing copy first.
  WHISPER_MODEL_CANDIDATES=(
    "$HOME/.cache/whisper/ggml-large-v3-turbo.bin"
    "$HOME/Library/Application Support/Amical/models/ggml-large-v3-turbo.bin"
    "$HOME/.local/share/whisper/ggml-large-v3-turbo.bin"
  )
  WHISPER_MODEL=""
  for candidate in "${WHISPER_MODEL_CANDIDATES[@]}"; do
    if [[ -f "$candidate" ]]; then
      WHISPER_MODEL="$candidate"
      break
    fi
  done

  if [[ -n "$WHISPER_MODEL" ]]; then
    echo "  ✓ whisper model found (reusing $WHISPER_MODEL)"
  else
    echo "  ✗ whisper model (ggml-large-v3-turbo.bin) not found in any known location."
    if confirm "    Download it now from Hugging Face (~1.6 GB) into ~/.cache/whisper/?"; then
      WHISPER_MODEL_DEST="$HOME/.cache/whisper/ggml-large-v3-turbo.bin"
      mkdir -p "$(dirname "$WHISPER_MODEL_DEST")"
      WHISPER_MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin"
      if command -v curl >/dev/null 2>&1; then
        if curl -L --fail --progress-bar -o "$WHISPER_MODEL_DEST" "$WHISPER_MODEL_URL"; then
          echo "  ✓ model downloaded to $WHISPER_MODEL_DEST"
        else
          echo "  ✗ download failed. Retry manually:"
          echo "      curl -L -o \"$WHISPER_MODEL_DEST\" \"$WHISPER_MODEL_URL\""
          rm -f "$WHISPER_MODEL_DEST"
        fi
      else
        echo "  ✗ curl not found. Install curl, or download manually:"
        echo "      $WHISPER_MODEL_URL"
        echo "    and place it at $WHISPER_MODEL_DEST"
      fi
    else
      echo "    Skipped. To enable voice transcription later, either:"
      echo "      • download the model:"
      echo "          curl -L --create-dirs -o ~/.cache/whisper/ggml-large-v3-turbo.bin \\"
      echo "            https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin"
      echo "      • or install Amical (https://amical.ai), which ships the same model."
    fi
  fi

  cat <<EOF

Telegram bot wired up at: $STATE_DIR

To launch this assistant with the bot, run:
  cd "$REPO_ROOT" && TELEGRAM_STATE_DIR="$STATE_DIR" \\
    claude --channels plugin:telegram@claude-plugins-official

Tip: add a shell alias to ~/.zshrc:
  alias claude-$NICK='cd "$REPO_ROOT" && TELEGRAM_STATE_DIR="$STATE_DIR" claude --channels plugin:telegram@claude-plugins-official'

Then DM your bot, get the 6-char pairing code, and run:
  /telegram:access pair <code>
  /telegram:access policy allowlist
EOF
else
  echo "  - skipping Telegram bot setup (see README for how to add it later)"
fi

# ── 8. fresh git history (optional) ──────────────────────────────────────
echo
if [[ -d .git ]] && confirm "Wipe template git history and re-init? (recommended for personal projects)"; then
  rm -rf .git
  git init -q
  git add -A
  git commit -q -m "Initial commit from personal-assistant template"
  echo "  - fresh git history initialized"
fi

# ── done ─────────────────────────────────────────────────────────────────
cat <<EOF

✓ Setup complete.

Next steps:
  - Open CLAUDE.md and tweak preferences if you want
  - Drop notes into sources/ and use /wiki-ingest to build the wiki
  - Add tasks to TASKS.md
  - Start a session: claude

For multi-bot setups, see docs/multi-bot-telegram.md
EOF
