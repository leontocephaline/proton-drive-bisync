#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SERVICE_NAME="rclone-bisync.service"
TIMER_NAME="rclone-bisync.timer"
CONFIG_ROOT="$HOME/.config/systemd/user"
CACHE_DIR="$HOME/.cache/rclone"
RCLONE_REMOTE="protondrive"

log() {
    printf "%b%s%b\n" "$1" "$2" "$NC"
}

section() {
    printf "\n%b=== %s ===%b\n" "$BLUE" "$1" "$NC"
}

check_rclone() {
    section "rclone"
    if command -v rclone >/dev/null 2>&1; then
        local version
        version="$(rclone version --check=false | head -n 1)"
        log "$GREEN" "Found: $version"
    else
        log "$RED" "rclone not installed"
        return 1
    fi
}

check_remote() {
    section "Proton Drive remote"
    if rclone listremotes | grep -q "^${RCLONE_REMOTE}:$"; then
        log "$GREEN" "Remote '${RCLONE_REMOTE}' configured"
        if rclone lsd "${RCLONE_REMOTE}:/" >/dev/null 2>&1; then
            log "$GREEN" "Connectivity OK"
        else
            log "$RED" "Cannot list remote root"
            return 1
        fi
    else
        log "$RED" "Remote '${RCLONE_REMOTE}' missing"
        return 1
    fi
}

check_systemd_units() {
    section "systemd units"
    local service_path="$CONFIG_ROOT/$SERVICE_NAME"
    local timer_path="$CONFIG_ROOT/$TIMER_NAME"

    if [[ -f "$service_path" ]]; then
        log "$GREEN" "Service unit present: $service_path"
    else
        log "$RED" "Service unit missing"
    fi

    if [[ -f "$timer_path" ]]; then
        log "$GREEN" "Timer unit present: $timer_path"
    else
        log "$RED" "Timer unit missing"
    fi

    if systemctl --user is-enabled --quiet "$TIMER_NAME"; then
        log "$GREEN" "Timer enabled"
    else
        log "$YELLOW" "Timer not enabled"
    fi

    if systemctl --user is-active --quiet "$TIMER_NAME"; then
        log "$GREEN" "Timer active"
    else
        log "$YELLOW" "Timer inactive"
    fi
}

check_directories() {
    section "directories"
    local sync_dir
    sync_dir="$(systemctl --user cat "$SERVICE_NAME" 2>/dev/null | awk 'match($0,/bisync[[:space:]]+[^[:space:]]+:\/[[:space:]]+([^[:space:]]+)/,m){print m[1]}')"

    if [[ -n "$sync_dir" ]]; then
        if [[ -d "$sync_dir" ]]; then
            log "$GREEN" "Sync directory: $sync_dir"
            if [[ -f "$sync_dir/RCLONE_TEST" ]]; then
                log "$GREEN" "Local marker RCLONE_TEST present"
            else
                log "$YELLOW" "Local marker missing"
            fi
        else
            log "$RED" "Sync directory '$sync_dir' missing"
        fi
    else
        log "$YELLOW" "Unable to determine sync directory from unit"
    fi

    if [[ -d "$CACHE_DIR" ]]; then
        log "$GREEN" "Cache directory: $CACHE_DIR"
    else
        log "$YELLOW" "Cache directory not found"
    fi
}

check_logs() {
    section "logs"
    local log_file="$CACHE_DIR/bisync.log"
    if [[ -f "$log_file" ]]; then
        log "$GREEN" "Log file: $log_file"
        tail -n 5 "$log_file" | sed 's/^/    /'
    else
        log "$YELLOW" "Log file not created yet"
    fi
}

main() {
    check_rclone || true
    check_remote || true
    check_systemd_units || true
    check_directories || true
    check_logs || true
    printf "\n%bValidation complete.%b\n" "$GREEN" "$NC"
}

main "$@"
