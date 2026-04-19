#!/bin/bash
# Claude Code schedule dispatcher.
# Runs every 15 minutes via launchd. Discovers .claude/schedules/*.md task files,
# checks whether each is due, deduplicates, and executes via the Claude CLI.

WORKDIR="$(cd "$(dirname "$0")/../.." && pwd)"
SCHEDULES_DIR="${WORKDIR}/.claude/schedules"
LAST_RUN_DIR="${SCHEDULES_DIR}/.last-run"
LOGS_DIR="${SCHEDULES_DIR}/logs"
CLAUDE_BIN="/opt/homebrew/bin/claude"
LOCK_FILE="/tmp/claude-scheduler.lock"

# ---------------------------------------------------------------------------
# Lock — prevent overlapping runs
# ---------------------------------------------------------------------------
# Clean up non-directory lock (e.g. leftover from flock-based version)
if [[ -e "${LOCK_FILE}" && ! -d "${LOCK_FILE}" ]]; then
    rm -f "${LOCK_FILE}"
fi
# Remove stale lock: directory exists but stored PID is not running
if [[ -d "${LOCK_FILE}" ]]; then
    stored_pid=$(cat "${LOCK_FILE}/pid" 2>/dev/null)
    if [[ -n "${stored_pid}" ]] && ! kill -0 "${stored_pid}" 2>/dev/null; then
        rm -f "${LOCK_FILE}/pid"
        rmdir "${LOCK_FILE}" 2>/dev/null || true
    fi
fi
mkdir "${LOCK_FILE}" 2>/dev/null || exit 0
echo $$ > "${LOCK_FILE}/pid"
trap 'rm -f "${LOCK_FILE}/pid"; rmdir "${LOCK_FILE}" 2>/dev/null || true' EXIT

# ---------------------------------------------------------------------------
# Bootstrap directories
# ---------------------------------------------------------------------------
mkdir -p "${LAST_RUN_DIR}"
mkdir -p "${LOGS_DIR}"

# ---------------------------------------------------------------------------
# Discover task files
# ---------------------------------------------------------------------------
shopt -s nullglob
task_files=("${SCHEDULES_DIR}"/*.md)
shopt -u nullglob

if [[ ${#task_files[@]} -eq 0 ]]; then
    exit 0
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Extract a frontmatter field value: parse_field <field> <file>
parse_field() {
    local field="$1"
    local file="$2"
    awk -v field="${field}" '
        /^---$/ { count++; next }
        count == 1 && $0 ~ "^" field ":" {
            sub("^" field ":[ \t]*", "")
            print
            exit
        }
        count >= 2 { exit }
    ' "${file}"
}

# Extract body (everything after second ---)
parse_body() {
    local file="$1"
    awk '
        /^---$/ { count++; next }
        count >= 2 { print }
    ' "${file}"
}

# Extract body from a command file (may or may not have YAML frontmatter)
parse_command_body() {
    local file="$1"
    local first_line
    first_line=$(head -1 "${file}")
    if [[ "${first_line}" == "---" ]]; then
        parse_body "${file}"
    else
        cat "${file}"
    fi
}

# ISO week number (1-53)
iso_week() {
    date +%V
}

# Current day-of-week lowercase: monday, tuesday, ...
current_dow() {
    date +%A | tr '[:upper:]' '[:lower:]'
}

# Returns 0 if task is due given its schedule string and current time window
is_due() {
    local schedule="$1"

    local now_hhmm
    now_hhmm=$(date +%H%M)
    local now_dow
    now_dow=$(current_dow)
    local is_weekday=0
    case "${now_dow}" in
        monday|tuesday|wednesday|thursday|friday) is_weekday=1 ;;
    esac

    # Parse schedule type and time
    local sched_type sched_day sched_time sched_hhmm

    if [[ "${schedule}" =~ ^weekly[[:space:]]+([a-z]+)[[:space:]]+([0-9]{2}:[0-9]{2})$ ]]; then
        sched_type="weekly"
        sched_day="${BASH_REMATCH[1]}"
        sched_time="${BASH_REMATCH[2]}"
    elif [[ "${schedule}" =~ ^daily[[:space:]]+([0-9]{2}:[0-9]{2})$ ]]; then
        sched_type="daily"
        sched_time="${BASH_REMATCH[1]}"
    elif [[ "${schedule}" =~ ^weekday[[:space:]]+([0-9]{2}:[0-9]{2})$ ]]; then
        sched_type="weekday"
        sched_time="${BASH_REMATCH[1]}"
    else
        echo "  [warn] unrecognised schedule format: ${schedule}" >&2
        return 1
    fi

    # Convert HH:MM -> HHMM for comparison
    sched_hhmm="${sched_time/:/}"

    # Compute window: scheduled time up to +14 minutes
    local sched_h sched_m sched_total now_total window_end
    sched_h=$(( 10#${sched_hhmm:0:2} ))
    sched_m=$(( 10#${sched_hhmm:2:2} ))
    sched_total=$(( sched_h * 60 + sched_m ))

    local now_h now_m
    now_h=$(( 10#${now_hhmm:0:2} ))
    now_m=$(( 10#${now_hhmm:2:2} ))
    now_total=$(( now_h * 60 + now_m ))

    window_end=$(( sched_total + 14 ))

    # Check time window
    if [[ ${now_total} -lt ${sched_total} || ${now_total} -gt ${window_end} ]]; then
        return 1
    fi

    # Check day constraints
    case "${sched_type}" in
        weekly)
            [[ "${now_dow}" == "${sched_day}" ]] || return 1
            ;;
        weekday)
            [[ ${is_weekday} -eq 1 ]] || return 1
            ;;
        daily)
            : # any day
            ;;
    esac

    return 0
}

# Returns 0 if the scheduled time has already passed today/this-week
# (but is outside the normal is_due window). Used for catch-up runs
# when the laptop was off during the scheduled window.
is_past_due() {
    local schedule="$1"

    local now_hhmm now_dow is_weekday
    now_hhmm=$(date +%H%M)
    now_dow=$(current_dow)
    is_weekday=0
    case "${now_dow}" in
        monday|tuesday|wednesday|thursday|friday) is_weekday=1 ;;
    esac

    local sched_type sched_day sched_time sched_hhmm

    if [[ "${schedule}" =~ ^weekly[[:space:]]+([a-z]+)[[:space:]]+([0-9]{2}:[0-9]{2})$ ]]; then
        sched_type="weekly"
        sched_day="${BASH_REMATCH[1]}"
        sched_time="${BASH_REMATCH[2]}"
    elif [[ "${schedule}" =~ ^daily[[:space:]]+([0-9]{2}:[0-9]{2})$ ]]; then
        sched_type="daily"
        sched_time="${BASH_REMATCH[1]}"
    elif [[ "${schedule}" =~ ^weekday[[:space:]]+([0-9]{2}:[0-9]{2})$ ]]; then
        sched_type="weekday"
        sched_time="${BASH_REMATCH[1]}"
    else
        return 1
    fi

    sched_hhmm="${sched_time/:/}"

    # Must be PAST the scheduled time (beyond the 14-min window)
    local sched_h sched_m sched_total now_h now_m now_total window_end
    sched_h=$(( 10#${sched_hhmm:0:2} ))
    sched_m=$(( 10#${sched_hhmm:2:2} ))
    sched_total=$(( sched_h * 60 + sched_m ))
    now_h=$(( 10#${now_hhmm:0:2} ))
    now_m=$(( 10#${now_hhmm:2:2} ))
    now_total=$(( now_h * 60 + now_m ))
    window_end=$(( sched_total + 14 ))

    # Only catch up if we're AFTER the normal window
    [[ ${now_total} -gt ${window_end} ]] || return 1

    # Check day constraints
    case "${sched_type}" in
        weekly)
            [[ "${now_dow}" == "${sched_day}" ]] || return 1
            ;;
        weekday)
            [[ ${is_weekday} -eq 1 ]] || return 1
            ;;
    esac

    return 0
}

# Returns 0 if already ran this period (should skip)
already_ran() {
    local name="$1"
    local schedule="$2"
    local marker="${LAST_RUN_DIR}/${name}"

    [[ -f "${marker}" ]] || return 1

    local recorded
    recorded=$(cat "${marker}")

    if [[ "${schedule}" =~ ^weekly ]]; then
        local current_week
        current_week="$(date +%G)-W$(iso_week)"
        [[ "${recorded}" == "${current_week}" ]]
    else
        # daily / weekday — compare by date
        local today
        today=$(date +%Y-%m-%d)
        [[ "${recorded}" == "${today}" ]]
    fi
}

# Write the dedup marker after a successful run
mark_ran() {
    local name="$1"
    local schedule="$2"
    local marker="${LAST_RUN_DIR}/${name}"

    if [[ "${schedule}" =~ ^weekly ]]; then
        echo "$(date +%G)-W$(iso_week)" > "${marker}"
    else
        date +%Y-%m-%d > "${marker}"
    fi
}

# Send a Telegram message via Bot API using curl.
# Reads the bot token from $HOME/.claude/channels/telegram/.env.
# Silent failure — logs a warning but does not abort the task.
send_telegram() {
    local task_name="$1"
    local message="$2"

    local env_file="${HOME}/.claude/channels/telegram/.env"
    if [[ ! -f "${env_file}" ]]; then
        echo "[scheduler] [warn] Telegram .env not found at ${env_file} — skipping notification" >&2
        return 0
    fi

    local token
    token=$(awk -F= '/^TELEGRAM_BOT_TOKEN=/ { print $2; exit }' "${env_file}" | tr -d '[:space:]')
    if [[ -z "${token}" ]]; then
        echo "[scheduler] [warn] TELEGRAM_BOT_TOKEN not set in ${env_file} — skipping notification" >&2
        return 0
    fi

    local chat_id="5453788502"
    # Prepend task name as header and truncate to Telegram's 4096-char limit
    local full_message="*${task_name}*

${message}"
    full_message="${full_message:0:4096}"

    curl -s -X POST "https://api.telegram.org/bot${token}/sendMessage" \
        --data-urlencode "chat_id=${chat_id}" \
        --data-urlencode "text=${full_message}" \
        --data-urlencode "parse_mode=Markdown" \
        -o /dev/null \
    || echo "[scheduler] [warn] Telegram curl request failed for task: ${task_name}" >&2

    return 0
}

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------
for task_file in "${task_files[@]}"; do
    name=$(parse_field "name" "${task_file}")
    schedule=$(parse_field "schedule" "${task_file}")
    budget=$(parse_field "budget" "${task_file}")
    notify=$(parse_field "notify" "${task_file}")
    command_ref=$(parse_field "command" "${task_file}")

    # Validate required fields
    if [[ -z "${name}" || -z "${schedule}" ]]; then
        echo "[scheduler] skipping ${task_file}: missing name or schedule" >&2
        continue
    fi

    # Default budget
    [[ -z "${budget}" ]] && budget="1.00"

    # Sanitise name for use in filenames (replace spaces/slashes with dashes)
    safe_name="${name//[^a-zA-Z0-9_-]/-}"

    # Check if due (includes catch-up for missed schedules after wake)
    if ! is_due "${schedule}" && ! is_past_due "${schedule}"; then
        continue
    fi

    # Dedup check
    if already_ran "${safe_name}" "${schedule}"; then
        continue
    fi

    # Build prompt
    if [[ -n "${command_ref}" ]]; then
        # Resolve command file
        command_file="${WORKDIR}/.claude/commands/${command_ref}.md"
        if [[ ! -f "${command_file}" ]]; then
            echo "[scheduler] [warn] command file not found: ${command_file} — skipping ${name}" >&2
            continue
        fi
        command_body=$(parse_command_body "${command_file}")
        if [[ -z "${command_body}" ]]; then
            echo "[scheduler] [warn] command file is empty: ${command_file} — skipping ${name}" >&2
            continue
        fi
        # Optionally prepend schedule's own body as context preamble
        schedule_body=$(parse_body "${task_file}")
        if [[ -n "${schedule_body}" ]]; then
            body="${schedule_body}

${command_body}"
        else
            body="${command_body}"
        fi
    else
        body=$(parse_body "${task_file}")
    fi

    # Guard: skip if body is empty
    if [[ -z "${body}" ]]; then
        echo "[scheduler] [warn] empty body for task: ${name} — skipping" >&2
        continue
    fi

    # Log file
    timestamp=$(date +%Y-%m-%d-%H%M)
    log_file="${LOGS_DIR}/${safe_name}-${timestamp}.log"

    echo "[scheduler] running task: ${name}" | tee -a "${log_file}"

    # Execute — cd to WORKDIR so relative paths inside prompts work
    # Capture Claude's output separately for clean Telegram notifications
    claude_output_file="${LOGS_DIR}/${safe_name}-${timestamp}.out"
    (
        cd "${WORKDIR}" || exit 1
        "${CLAUDE_BIN}" \
            -p "${body}" \
            --permission-mode bypassPermissions \
            --no-session-persistence \
            --max-budget-usd "${budget}" \
            --output-format text \
            < /dev/null
    ) > "${claude_output_file}" 2>> "${log_file}"

    exit_code=$?
    # Append Claude's output to the full log
    cat "${claude_output_file}" >> "${log_file}"

    if [[ ${exit_code} -eq 0 ]]; then
        mark_ran "${safe_name}" "${schedule}"
        echo "[scheduler] task complete: ${name} (exit 0)" | tee -a "${log_file}"

        # Send Telegram notification with Claude's output only
        if [[ "${notify}" == "telegram" ]]; then
            claude_output=$(cat "${claude_output_file}")
            send_telegram "${name}" "${claude_output}"
        fi
    else
        echo "[scheduler] task failed: ${name} (exit ${exit_code})" | tee -a "${log_file}"
    fi
    rm -f "${claude_output_file}"
done
