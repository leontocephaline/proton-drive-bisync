#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SERVICE_NAME="rclone-bisync.service"
TIMER_NAME="rclone-bisync.timer"
CACHE_DIR="$HOME/.cache/rclone"
LOG_FILE="$CACHE_DIR/bisync.log"
REMOTE_NAME="protondrive"

log() {
    printf "%b%s%b\n" "$1" "$2" "$NC"
}

section() {
    printf "\n%b--- %s ---%b\n" "$BLUE" "$1" "$NC"
}

check_timer() {
    section "Timer status"
    if systemctl --user is-active --quiet "$TIMER_NAME"; then
        log "$GREEN" "Timer active"
    else
        log "$RED" "Timer inactive"
    fi

    local next
    next="$(systemctl --user list-timers | awk '/rclone-bisync\.timer/ {print $3" "$4" "$5; exit}')"
    if [[ -n "$next" ]]; then
        log "$GREEN" "Next run: $next"
    else
        log "$YELLOW" "Next run not scheduled"
    fi
}

check_last_run() {
    section "Last run"
    if [[ -f "$LOG_FILE" ]]; then
        local last_line
        last_line="$(grep -E 'NOTICE|INFO|ERROR' "$LOG_FILE" | tail -n 1)"
        if [[ -n "$last_line" ]]; then
            log "$GREEN" "Last log entry: $last_line"
        else
            log "$YELLOW" "Log file exists but contains no entries"
        fi
    else
        log "$YELLOW" "Log file $LOG_FILE not found"
    fi
}

check_remote_marker() {
    section "Remote marker"
    if command -v rclone >/dev/null 2>&1 && rclone listremotes | grep -q "^${REMOTE_NAME}:$"; then
        if rclone ls "${REMOTE_NAME}:/" | grep -q "RCLONE_TEST"; then
            log "$GREEN" "Marker file present on remote"
        else
            log "$YELLOW" "Marker file missing remotely"
        fi
    else
        log "$YELLOW" "Remote ${REMOTE_NAME} unavailable"
    fi
}

check_queue() {
    section "Queued jobs"
    systemctl --user list-jobs | awk 'NR==1 || /rclone-bisync/'
}

main() {
    check_timer || true
    check_last_run || true
    check_remote_marker || true
    check_queue || true
    printf "\n%bHealth check complete.%b\n" "$GREEN" "$NC"
}

main "$@"
