#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_NAME="Proton Drive Bisync"
MIN_RCLONE_VERSION="1.71.0"
DEFAULT_SYNC_DIR="$HOME/Documents/Proton"
DEFAULT_BACKUP_DIR="$HOME/Documents/Proton_backup"
DEFAULT_SYNC_INTERVAL="30min"
CACHE_DIR="$HOME/.cache/rclone"
SERVICE_NAME="rclone-bisync.service"
TIMER_NAME="rclone-bisync.timer"
CONFIG_ROOT="$HOME/.config/systemd/user"
RCLONE_REMOTE="protondrive"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_TEMPLATE_DIR="$PROJECT_ROOT/config"
SCRIPTS_DIR="$PROJECT_ROOT/scripts"

log() {
    local color="$1"; shift
    printf "%b%s%b\n" "$color" "$*" "$NC"
}

confirm() {
    local prompt="$1" default="${2:-y}"
    local response
    while true; do
        read -rp "$prompt [${default^^}/n]: " response
        response="${response:-$default}"
        case "${response,,}" in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) echo "Please answer y or n." ;;
        esac
    done
}

version_ge() {
    printf '%s\n%s\n' "$2" "$1" | sort -C -V
}

ensure_rclone() {
    if ! command -v rclone >/dev/null 2>&1; then
        log "$RED" "rclone not found."
        if confirm "Install the latest rclone now?"; then
            curl https://rclone.org/install.sh | sudo bash
        else
            log "$RED" "Installation aborted. Install rclone manually from https://rclone.org/downloads/."
            exit 1
        fi
    fi

    local installed_version
    installed_version="$(rclone version --check=false | head -n 1 | grep -oE 'v([0-9]+\.)+[0-9]+' | sed 's/^v//')"
    log "$BLUE" "rclone version detected: ${installed_version:-unknown}"

    if [[ -n "$installed_version" ]] && ! version_ge "$installed_version" "$MIN_RCLONE_VERSION"; then
        log "$RED" "rclone $MIN_RCLONE_VERSION or newer is required."
        if confirm "Upgrade rclone now?"; then
            curl https://rclone.org/install.sh | sudo bash
        else
            exit 1
        fi
    fi
}

ensure_systemd() {
    if ! command -v systemctl >/dev/null 2>&1; then
        log "$RED" "systemd is required for automation."
        exit 1
    fi

    if ! systemctl --user status >/dev/null 2>&1; then
        log "$YELLOW" "systemd user instance is not active."
        log "$YELLOW" "Start it with: systemctl --user status"
    fi
}

configure_remote() {
    if rclone listremotes | grep -q "^${RCLONE_REMOTE}:$"; then
        log "$GREEN" "Found existing '${RCLONE_REMOTE}' remote."
        if confirm "Reuse existing '${RCLONE_REMOTE}' configuration?" y; then
            return
        fi
        log "$YELLOW" "Reconfiguring existing remote..."
        rclone config reconnect "${RCLONE_REMOTE}:"
    else
        log "$YELLOW" "No Proton Drive remote found. Starting rclone config..."
        log "$BLUE" "When prompted, choose 'Proton Drive (protondrive)'."
        rclone config create "$RCLONE_REMOTE" protondrive
    fi

    log "$BLUE" "Testing remote connectivity..."
    if ! rclone lsd "${RCLONE_REMOTE}:/" >/dev/null 2>&1; then
        log "$RED" "Unable to access Proton Drive via rclone."
        exit 1
    fi
    log "$GREEN" "Proton Drive remote validated."
}

prompt_directories() {
    local input

    read -rp "Local sync directory [$DEFAULT_SYNC_DIR]: " input
    SYNC_DIR="${input:-$DEFAULT_SYNC_DIR}"
    SYNC_DIR="${SYNC_DIR/#\~/$HOME}"

    read -rp "Local backup directory [$DEFAULT_BACKUP_DIR]: " input
    BACKUP_DIR="${input:-$DEFAULT_BACKUP_DIR}"
    BACKUP_DIR="${BACKUP_DIR/#\~/$HOME}"

    mkdir -p "$SYNC_DIR" "$BACKUP_DIR" "$CACHE_DIR"
    log "$GREEN" "Directories ready."
}

initial_sync() {
    if ! confirm "Perform an initial resync now?" y; then
        log "$YELLOW" "Skipping initial sync. Run 'rclone bisync --resync' manually before enabling automation."
        return
    fi

    log "$BLUE" "Executing dry-run resync for review..."
    rclone bisync "${RCLONE_REMOTE}:/" "$SYNC_DIR" \
        --resync \
        --create-empty-src-dirs \
        --compare size,modtime \
        --max-delete 10 \
        --conflict-resolve newer \
        --conflict-loser num \
        --dry-run \
        -v

    if ! confirm "Proceed with live resync?" y; then
        log "$YELLOW" "Initial sync skipped. Complete it manually before automation."
        return
    fi

    rclone bisync "${RCLONE_REMOTE}:/" "$SYNC_DIR" \
        --resync \
        --create-empty-src-dirs \
        --compare size,modtime \
        --max-delete 10 \
        --conflict-resolve newer \
        --conflict-loser num \
        -v

    touch "$SYNC_DIR/RCLONE_TEST"
    rclone copy "$SYNC_DIR/RCLONE_TEST" "${RCLONE_REMOTE}:/" >/dev/null 2>&1 || true

    log "$GREEN" "Initial sync complete."
}

prompt_interval() {
    local input
    read -rp "Bisync interval [$DEFAULT_SYNC_INTERVAL]: " input
    SYNC_INTERVAL="${input:-$DEFAULT_SYNC_INTERVAL}"
    log "$GREEN" "Interval set to $SYNC_INTERVAL."
}

install_systemd_units() {
    mkdir -p "$CONFIG_ROOT"

    local rclone_bin
    rclone_bin="$(command -v rclone)"

    local service_template="$CONFIG_TEMPLATE_DIR/rclone-bisync.service.template"
    local timer_template="$CONFIG_TEMPLATE_DIR/rclone-bisync.timer.template"

    if [[ ! -f "$service_template" || ! -f "$timer_template" ]]; then
        log "$RED" "Missing systemd templates."
        exit 1
    fi

    sed \
        -e "s|{{SYNC_DIR}}|$SYNC_DIR|g" \
        -e "s|{{RCLONE_REMOTE}}|$RCLONE_REMOTE|g" \
        -e "s|{{RCLONE_BIN}}|$rclone_bin|g" \
        -e "s|{{CACHE_DIR}}|$CACHE_DIR|g" \
        "$service_template" > "$CONFIG_ROOT/$SERVICE_NAME"

    sed \
        -e "s|{{SYNC_INTERVAL}}|$SYNC_INTERVAL|g" \
        "$timer_template" > "$CONFIG_ROOT/$TIMER_NAME"

    systemctl --user daemon-reload
    systemctl --user enable "$TIMER_NAME"
    systemctl --user start "$TIMER_NAME"

    log "$GREEN" "Systemd units installed to $CONFIG_ROOT."
}

verify_install() {
    if systemctl --user is-active --quiet "$TIMER_NAME"; then
        log "$GREEN" "Timer active."
        local next_run
        next_run="$(systemctl --user list-timers | awk '/rclone-bisync\.timer/ {print $3" "$4" "$5; exit}')"
        [[ -n "$next_run" ]] && log "$BLUE" "Next sync scheduled: $next_run"
    else
        log "$YELLOW" "Timer not active; inspect with: systemctl --user status $TIMER_NAME"
    fi

    if [[ -f "$SYNC_DIR/RCLONE_TEST" ]] && rclone ls "${RCLONE_REMOTE}:/" | grep -q "RCLONE_TEST"; then
        log "$GREEN" "Safety check file present locally and remotely."
    else
        log "$YELLOW" "Safety check file missing. Run a manual sync to create it."
    fi

    log "$BLUE" "Logs: tail -f $CACHE_DIR/bisync.log"
    log "$BLUE" "Manual run: systemctl --user start $SERVICE_NAME"
}

main() {
    if [[ "${EUID}" -eq 0 ]]; then
        log "$RED" "Run as regular user."
        exit 1
    fi

    log "$GREEN" "=== $PROJECT_NAME Installer ==="

    ensure_rclone
    ensure_systemd
    configure_remote
    prompt_directories
    initial_sync
    prompt_interval
    install_systemd_units
    verify_install

    log "$GREEN" "Installation complete. Files in $SYNC_DIR will stay synced with Proton Drive."
}

main "$@"
