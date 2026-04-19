#!/bin/bash
# notebooklm-podcast.sh — Create a NotebookLM notebook from URLs and generate an Audio Overview.
#
# Usage:
#   ./notebooklm-podcast.sh <urls-file> [--dry-run]
#
# The urls-file should contain one URL per line (max ~20).
# --dry-run: stop after selecting Long length, before clicking Generate.
# Requires cmux with a saved NotebookLM session at ~/.cmux/sessions/notebooklm.json
#
# Output: prints the notebook URL on success.

set -euo pipefail

DRY_RUN=false
URLS_FILE=""

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    *) URLS_FILE="$arg" ;;
  esac
done

if [[ -z "$URLS_FILE" ]]; then
  echo "Usage: $0 <urls-file> [--dry-run]" >&2
  exit 1
fi

if [[ ! -f "$URLS_FILE" ]]; then
  echo "Error: file not found: $URLS_FILE" >&2
  exit 1
fi

URL_COUNT=$(wc -l < "$URLS_FILE" | tr -d ' ')
if (( URL_COUNT == 0 )); then
  echo "Error: urls file is empty" >&2
  exit 1
fi
if (( URL_COUNT > 25 )); then
  echo "Warning: $URL_COUNT URLs — NotebookLM may fail with >25 sources" >&2
fi

URLS=$(cat "$URLS_FILE")

# --- Helpers ---

wait_for() {
  # wait_for <seconds> <description>
  local secs=$1; shift
  echo "  waiting ${secs}s — $*" >&2
  sleep "$secs"
}

click() {
  # click <selector> [description]
  cmux browser "$S" click --selector "$1" >/dev/null
  echo "  clicked: ${2:-$1}" >&2
}

verify_text() {
  # verify_text <selector> <grep-pattern> <error-msg>
  local html
  html=$(cmux browser "$S" get html --selector "$1" 2>/dev/null)
  if ! echo "$html" | grep -q "$2"; then
    echo "Error: $3" >&2
    return 1
  fi
}

# --- Step 0: Ensure cmux is running ---

if ! pgrep -f "cmux" >/dev/null; then
  echo "Starting cmux..." >&2
  open -a cmux
  sleep 8
fi

# --- Step 1: Open browser & load session ---

echo "Opening browser..." >&2
S=$(cmux browser open 2>/dev/null | grep -o 'surface:[0-9]*')
echo "  surface: $S" >&2

cmux browser "$S" navigate about:blank >/dev/null
for f in ~/.cmux/sessions/*.json; do
  cmux browser "$S" state load "$f" >/dev/null
done
echo "  sessions loaded" >&2

# --- Step 2: Navigate to NotebookLM ---

echo "Navigating to NotebookLM..." >&2
cmux browser "$S" navigate https://notebooklm.google.com/ >/dev/null
wait_for 5 "page load"

# --- Step 3: Create new notebook ---

echo "Creating notebook..." >&2
# The "Create new notebook" button is visible in snapshots — find its ref
CREATE_REF=$(cmux browser "$S" snapshot --filter interactive 2>/dev/null \
  | grep -o 'button "Create new notebook" \[ref=[^]]*\]' \
  | grep -o 'ref=[^ ]*' | sed 's/ref=//;s/\]//')

if [[ -z "$CREATE_REF" ]]; then
  echo "Error: could not find 'Create new notebook' button" >&2
  exit 1
fi

cmux browser "$S" click "$CREATE_REF" >/dev/null
wait_for 4 "notebook creation"

# --- Step 4: Open upload dialog ---

echo "Opening source upload dialog..." >&2
# Find the "Opens the upload source dialog" button from snapshot
UPLOAD_REF=$(cmux browser "$S" snapshot --filter interactive 2>/dev/null \
  | grep -o 'button "Opens the upload source dialog" \[ref=[^]]*\]' \
  | grep -o 'ref=[^ ]*' | sed 's/ref=//;s/\]//')

if [[ -z "$UPLOAD_REF" ]]; then
  echo "Error: could not find upload source dialog button" >&2
  exit 1
fi

cmux browser "$S" click "$UPLOAD_REF" >/dev/null
wait_for 2 "dialog open"

# --- Step 5: Click Websites ---

echo "Selecting Websites tab..." >&2
click "[jslog='279308;track:generic_click,impression']" "Websites"
wait_for 2 "websites dialog"

# --- Step 6: Paste URLs ---

echo "Pasting $URL_COUNT URLs..." >&2
click "mat-dialog-container textarea" "textarea focus"
cmux browser "$S" fill --selector "mat-dialog-container textarea" --text "$URLS" >/dev/null
wait_for 1 "URLs pasted"

# --- Step 7: Click Insert ---

echo "Inserting sources..." >&2
click "[jslog='279307;track:generic_click,impression']" "Insert"
wait_for 12 "sources processing"

# --- Step 8: Open Studio > Audio Overview ---

echo "Opening Audio Overview..." >&2
# Click Studio tab
STUDIO_REF=$(cmux browser "$S" snapshot --filter interactive 2>/dev/null \
  | grep -o 'tab "Studio" \[ref=[^]]*\]' \
  | grep -o 'ref=[^ ]*' | sed 's/ref=//;s/\]//')

if [[ -z "$STUDIO_REF" ]]; then
  echo "Error: could not find Studio tab" >&2
  exit 1
fi

cmux browser "$S" click "$STUDIO_REF" >/dev/null
wait_for 2 "Studio panel"

# Click Audio Overview card (jslog-based, not in snapshot)
click "[jslog='261212;track:generic_click,impression']" "Audio Overview card"
wait_for 2 "customize dialog"

# --- Step 9: Select Long length ---

echo "Setting length to Long..." >&2
click "mat-button-toggle:nth-child(3) button" "Long toggle"

# Verify Long is selected
if ! verify_text "mat-button-toggle-group" "mat-button-toggle-checked.*Long\|aria-checked=\"true\".*Long" "Long toggle not selected"; then
  echo "  retrying Long click..." >&2
  wait_for 1 "retry"
  click "mat-button-toggle:nth-child(3) button" "Long toggle (retry)"
fi

# --- Step 10: Click Generate ---

if $DRY_RUN; then
  echo "" >&2
  echo "DRY RUN — stopping before Generate. Long is selected, dialog is open." >&2
  NOTEBOOK_URL=$(cmux browser "$S" url 2>/dev/null)
  echo "Notebook: $NOTEBOOK_URL" >&2
  echo "$NOTEBOOK_URL"
  exit 0
fi

echo "Generating podcast..." >&2
click "[jslog='281099;track:generic_click,impression']" "Generate"
wait_for 4 "generation start"

# --- Step 11: Get notebook URL ---

NOTEBOOK_URL=$(cmux browser "$S" url 2>/dev/null)
echo "" >&2
echo "Podcast is generating!" >&2
echo "Sources: $URL_COUNT" >&2
echo "Notebook: $NOTEBOOK_URL" >&2
echo "$NOTEBOOK_URL"
