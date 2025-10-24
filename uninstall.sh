#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SERVICE_NAME="rclone-bisync.service"
TIMER_NAME="rclone-bisync.timer"
CONFIG_ROOT="$HOME/.config/systemd/user"
CACHE_DIR="$HOME/.cache/rclone"
LOG_FILE="$CACHE_DIR/bisync.log"
REMOTE_NAME="protondrive"

log() {
    local color="$1"; shift
    printf "%b%s%b\n" "$color" "$*" "$NC"
}

confirm() {
    local prompt="$1" default="${2:-n}" response
    while true; do
        read -rp "$prompt [y/${default^^}]: " response || exit 1
        response="${response:-$default}"
        case "${response,,}" in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) echo "Please answer y or n." ;;
        esac
    done
}

require_systemd() {
    if ! command -v systemctl >/dev/null 2>&1; then
        log "$RED" "systemctl not found."
        exit 1
    fi
}

stop_units() {
    systemctl --user stop "$TIMER_NAME" >/dev/null 2>&1 || true
    systemctl --user stop "$SERVICE_NAME" >/dev/null 2>&1 || true
    systemctl --user disable "$TIMER_NAME" >/dev/null 2>&1 || true
    systemctl --user disable "$SERVICE_NAME" >/dev/null 2>&1 || true
    systemctl --user daemon-reload
    log "$GREEN" "Systemd units stopped and disabled."
}

remove_units() {
    rm -f "$CONFIG_ROOT/$SERVICE_NAME" "$CONFIG_ROOT/$TIMER_NAME"
    log "$GREEN" "Removed unit files from $CONFIG_ROOT."
}

cleanup_logs() {
    if [[ -f "$LOG_FILE" ]] && confirm "Delete log file at $LOG_FILE?" n; then
        rm -f "$LOG_FILE"
        log "$GREEN" "Removed log file."
    fi
}

cleanup_remote_marker() {
    if command -v rclone >/dev/null 2>&1 && rclone listremotes | grep -q "^${REMOTE_NAME}:$"; then
        if confirm "Remove remote RCLONE_TEST marker from ${REMOTE_NAME}:/ ?" n; then
            rclone delete "$REMOTE_NAME:/RCLONE_TEST" >/dev/null 2>&1 || true
            log "$GREEN" "Removed remote marker file."
        fi
    fi
}

main() {
    if [[ "$EUID" -eq 0 ]]; then
        log "$RED" "Run as regular user."
        exit 1
    fi

    require_systemd

    log "$YELLOW" "This will disable and remove Proton Drive bisync automation."
    if ! confirm "Continue with uninstallation?" n; then
        log "$BLUE" "Aborted."
        exit 0
    fi

    stop_units
    remove_units
    cleanup_logs
    cleanup_remote_marker

    log "$GREEN" "Uninstall complete."
    log "$BLUE" "To remove cached data run: rm -rf $CACHE_DIR"
}

main "$@"
