---
name: setup
description: >
  Interactive, agent-guided setup for this Personal Assistant. Walks the user
  through identity (name/email/GitHub), voice-transcription dependencies,
  Google Workspace authentication in an isolated config dir, Telegram bot
  wiring, and makefile generation. Runs deterministic scripts from
  .claude/scripts/setup/ for everything that can be automated, and pauses to
  confirm anything that requires the user (OAuth flows, BotFather, etc).
  Use this immediately after cloning the template.
---

# /setup — stand up this Personal Assistant

You are orchestrating a one-time setup flow that turns a fresh template clone into a personalized, running assistant. The user just cloned the template repo and started a Claude session in it. Your job is to interview them, run the scripts under `.claude/scripts/setup/`, and at the end leave them with a working `make run` command plus clear next steps.

## Principles

- **Favor determinism.** Every side effect goes through one of the scripts in `.claude/scripts/setup/`. Don't use Write/StrReplace/Edit to replicate what a script can do. Reserve direct file edits for things the scripts don't cover (e.g. showing the generated makefile to the user).
- **Verify after each side effect.** If a script runs, read back the file(s) it touched and confirm the change took. If verification fails, abort (see "Error handling" below).
- **Track progress with `TodoWrite`.** Create the full todo list at the start of the flow, update status as you go. The user watches this to know where you are.
- **Ask one question at a time** unless a group of questions is genuinely atomic (e.g. "name AND email"). Use the `AskQuestion` tool for multi-choice, plain text for free-form answers.
- **Idempotency.** If `/setup` is re-run, detect completed state and offer to skip or re-run each step individually. Don't blindly redo everything.

## Error handling

On any non-zero exit from a setup script, STOP the flow. Report to the user:

1. Which step failed (e.g. "wire-telegram-state.sh")
2. The exact stderr the script emitted
3. The most likely fix (based on the script's error message)
4. Instruction to re-run `/setup` after fixing

Do NOT attempt automatic retry. Do NOT skip past the failing step. The user decides how to proceed.

## Flow

### 1. Greet and scope

Briefly explain what this command does (one paragraph). Warn that some steps (Google Workspace OAuth, Telegram BotFather) happen outside the chat and you'll pause for the user to complete them in another terminal or app.

Immediately after greeting, create the initial todo list with these items:

- Identity: collect name, email, optional GitHub handle, Cursor transcript dir
- Apply placeholders (substitute {{NAME}} etc.)
- Init local settings and scheduler dirs
- Voice transcription deps check (ffmpeg, whisper-cli, model)
- Google Workspace auth (optional, isolated config dir)
- GitHub account pin for `gh auth token` (optional)
- Telegram bot wiring (optional)
- Generate makefile
- Fresh git history (optional)
- Print next steps

### 2. Identity

Ask for:
- Name
- Email
- GitHub username (optional — drives PR search in the `daily-briefing` skill; accept empty)
- Cursor transcript dir (optional — used by the `dream` skill; pre-fill the default derived from the repo path: `~/.cursor/projects/<slugified-repo-path>/agent-transcripts/`)

The default transcript dir for a repo at `/Users/foo/Workspace/bar` is `~/.cursor/projects/Users-foo-Workspace-bar/agent-transcripts/` — i.e. strip the leading slash and replace `/` with `-`.

### 3. Apply placeholders

Run `.claude/scripts/setup/apply-placeholders.sh "<name>" "<email>" "<gh_handle_or_empty>" "<transcript_dir>"`. Verify by reading the first 12 lines of `CLAUDE.md` and confirming `{{NAME}}` and `{{EMAIL}}` are both gone (don't show the content back to the user, just confirm).

### 4. Init settings + scheduler dirs

Run `.claude/scripts/setup/init-settings-local.sh`. No verification needed — the script's output is self-explanatory.

### 5. Voice transcription dependencies

Run `.claude/scripts/setup/check-voice-deps.sh` and parse the JSON output. For each missing dependency:

- **ffmpeg missing** → print `brew install ffmpeg`, wait for user to confirm installation. Re-run the check.
- **whisper-cli missing** → print `brew install whisper-cpp`, wait for user confirmation. Re-run the check.
- **model_path is null** → tell the user this is a 1.6 GB download from Hugging Face. Ask if they want you to download it now. If yes, run `.claude/scripts/setup/download-whisper-model.sh`. If no, tell them how to provide the model later (Amical install or manual placement at `~/.cache/whisper/ggml-large-v3-turbo.bin`) and note that voice transcription will error until they do.

If everything is present on first check, just report the versions/paths and move on.

### 6. Google Workspace (optional)

Ask whether to enable Google Workspace integration (Gmail, Calendar, Drive access via the `gws` CLI). If no, skip this step entirely.

If yes:

1. Check `gws` is installed: `command -v gws`. If not, print the install command (`npm install -g @googleworkspace/cli` plus Node and `gcloud` prerequisites) and abort this step with a message that the user should install gws then re-run `/setup`.
2. Ask the user for a config dir name. Suggest `gws-<nick>` where `<nick>` is the repo basename (e.g. `gws-personal-assistant`). They can override.
3. Run `.claude/scripts/setup/ensure-gws-config-dir.sh <dir_name>`. Relay the `gws auth setup` command the script prints to the user. Tell them to run it in a separate terminal, complete the OAuth flow with the Google account this assistant should act as, and come back.
4. Wait for the user to confirm OAuth is done.
5. Run `.claude/scripts/setup/verify-gws.sh "$HOME/.config/<dir_name>"`. Show the authenticated email and ask the user to confirm it's the right account.
6. Remember `<dir_name>` for the makefile generation step. If the user skipped this whole section, treat it as empty.

### 7. GitHub account pin (optional)

Only applicable if the user provided a GitHub handle in step 2 AND is running multiple `gh` accounts. Detect this by running `gh auth status` and counting the number of logged-in accounts.

- If 0 or 1 `gh` accounts: skip. The default `gh` auth is fine.
- If 2+ accounts: show the user the list and ask which one this assistant should use. `make run` will bake `gh auth token --user <chosen>` into the env so the assistant's `gh` calls act as that user regardless of which is "active" in `gh` globally.

Remember the chosen user for the makefile generation step. If skipped, treat as empty.

### 8. Telegram bot (optional)

Ask whether to enable a Telegram bot. If no, skip.

If yes:

1. Tell the user how to create the bot: open Telegram, DM [@BotFather](https://t.me/BotFather), send `/newbot`, pick a name and a unique username, copy the token it returns.
2. Wait for the user to paste the token. Validate it loosely (contains a colon, numeric prefix, base64-ish suffix).
3. Ask for a nickname (default: the repo's directory basename). The nickname becomes the suffix in `~/.claude/channels/telegram-<nick>/`.
4. Run `.claude/scripts/setup/wire-telegram-state.sh <nick> <token>`. If it refuses because the state dir already has a `.env`, ask the user whether to overwrite. If yes, re-run with `--force`. If no, abort this step.
5. Remember `<nick>` for the makefile step.

### 9. Generate the makefile

Run `.claude/scripts/setup/generate-makefile.sh <nick> <gws_config_dir_or_empty> <gh_user_or_empty>`. If the script refuses because a `makefile` already exists, show the existing makefile to the user and ask whether to overwrite. If yes, re-run with `--force`.

If the user skipped Telegram, they still need a `nick` for the make file (used only as a label and for the optional `telegram-<nick>/` state dir lookup). Use the repo basename.

Read the generated makefile and show it to the user so they understand what `make run` will do.

### 10. Fresh git history (optional)

Ask: "Wipe template git history and re-init? (recommended unless you're customizing this repo as a fork)". If yes, run `.claude/scripts/setup/fresh-git-init.sh`. Warn that this is destructive before running.

### 11. Next steps

Print a final summary block covering:

- How to launch: `make run`
- How to pair Telegram (if configured): DM the bot, receive 6-char code, run `/telegram:access pair <code>` then `/telegram:access policy allowlist` in the session
- How to test the daily briefing: `ask "what's on my plate today?"`
- Where to find `docs/multi-bot-telegram.md` if they're running multiple assistants

End by marking all todos complete and wishing them well. The user can exit the session with Ctrl-D and run `make run` to start their configured assistant.

## Notes for the agent

- The scripts are located relative to the repo root. Always invoke them as `.claude/scripts/setup/<name>.sh` (the repo root is the working directory when `/setup` runs).
- The scripts use positional args, not env vars. Quote all args that could contain spaces.
- Don't read the scripts' source unless debugging; trust their exit codes and stdout/stderr.
- If the user asks "what exactly is this going to do?", describe the flow above and the scripts involved, but don't overwhelm them with implementation details.
