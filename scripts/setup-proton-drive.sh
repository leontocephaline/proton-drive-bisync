#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_TEMPLATE_DIR="$PROJECT_ROOT/config"
CONFIG_ROOT="$HOME/.config/systemd/user"
SERVICE_NAME="rclone-bisync.service"
TIMER_NAME="rclone-bisync.timer"
DEFAULT_REMOTE="protondrive"
DEFAULT_SYNC_DIR="$HOME/Documents/Proton"
DEFAULT_INTERVAL="30min"
DEFAULT_CACHE_DIR="$HOME/.cache/rclone"

RCLONE_REMOTE=""
SYNC_DIR=""
SYNC_INTERVAL=""
CACHE_DIR=""
RCLONE_BIN=""
NON_INTERACTIVE=0
ENABLE_AFTER_RENDER=1

log() {
    printf "%b%s%b\n" "$1" "$2" "$NC"
}

fatal() {
    log "$RED" "$1"
    exit 1
}

usage() {
    cat <<'EOF'
Usage: setup-proton-drive.sh [options]
  --remote NAME        rclone remote name (default: protondrive)
  --sync-dir PATH      local sync directory
  --interval DURATION  timer interval (default: 30min)
  --cache-dir PATH     cache/log directory (default: ~/.cache/rclone)
  --rclone-bin PATH    path to rclone executable
  --non-interactive    never prompt; use provided or default values
  --disable-enable     do not enable/start timer after writing units
  --help               show this help text
EOF
}

confirm() {
    local prompt="$1" default="${2:-y}" reply
    if (( NON_INTERACTIVE )); then
        [[ "${default,,}" == "y" ]]
        return
    fi
    while true; do
        read -rp "$prompt [${default^^}/n]: " reply || exit 1
        reply="${reply:-$default}"
        case "${reply,,}" in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) echo "Please answer y or n." ;;
        esac
    done
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --remote)
                [[ $# -ge 2 ]] || fatal "--remote requires a value"
                RCLONE_REMOTE="$2"
                shift 2
                ;;
            --sync-dir)
                [[ $# -ge 2 ]] || fatal "--sync-dir requires a value"
                SYNC_DIR="$2"
                shift 2
                ;;
            --interval)
                [[ $# -ge 2 ]] || fatal "--interval requires a value"
                SYNC_INTERVAL="$2"
                shift 2
                ;;
            --cache-dir)
                [[ $# -ge 2 ]] || fatal "--cache-dir requires a value"
                CACHE_DIR="$2"
                shift 2
                ;;
            --rclone-bin)
                [[ $# -ge 2 ]] || fatal "--rclone-bin requires a value"
                RCLONE_BIN="$2"
                shift 2
                ;;
            --non-interactive)
                NON_INTERACTIVE=1
                shift
                ;;
            --disable-enable)
                ENABLE_AFTER_RENDER=0
                shift
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                fatal "Unknown option: $1"
                ;;
        esac
    done
}

load_existing() {
    local service_path="$CONFIG_ROOT/$SERVICE_NAME"
    local timer_path="$CONFIG_ROOT/$TIMER_NAME"

    if [[ -f "$service_path" ]]; then
        local flattened
        flattened="$(sed 's/\\$//' "$service_path" | tr '\n' ' ')"
        if [[ -z "$RCLONE_BIN" ]]; then
            RCLONE_BIN="$(printf '%s' "$flattened" | awk 'match($0,/ExecStart=([^ ]+)/,m){print m[1]}')"
        fi
        if [[ -z "$RCLONE_REMOTE" ]]; then
            RCLONE_REMOTE="$(printf '%s' "$flattened" | awk 'match($0,/bisync[[:space:]]+([^[:space:]]+):\//,m){print m[1]}')"
        fi
        if [[ -z "$SYNC_DIR" ]]; then
            SYNC_DIR="$(printf '%s' "$flattened" | awk 'match($0,/bisync[[:space:]]+[^[:space:]]+:\/[[:space:]]+([^[:space:]]+)/,m){print m[1]}')"
        fi
        if [[ -z "$CACHE_DIR" ]]; then
            local log_file
            log_file="$(printf '%s' "$flattened" | awk 'match($0,/--log-file[[:space:]]+([^[:space:]]+)/,m){print m[1]}')"
            [[ -n "$log_file" ]] && CACHE_DIR="${log_file%/bisync.log}"
        fi
    fi

    if [[ -f "$timer_path" && -z "$SYNC_INTERVAL" ]]; then
        SYNC_INTERVAL="$(awk -F'=' '/^OnUnitActiveSec=/{print $2; exit}' "$timer_path")"
    fi
}

ensure_defaults() {
    if [[ -z "$RCLONE_BIN" ]]; then
        if command -v rclone >/dev/null 2>&1; then
            RCLONE_BIN="$(command -v rclone)"
        else
            fatal "rclone binary not found; specify with --rclone-bin"
        fi
    fi

    if [[ -z "$RCLONE_REMOTE" ]]; then
        if (( NON_INTERACTIVE )); then
            RCLONE_REMOTE="$DEFAULT_REMOTE"
        else
            read -rp "rclone remote name [$DEFAULT_REMOTE]: " RCLONE_REMOTE
            RCLONE_REMOTE="${RCLONE_REMOTE:-$DEFAULT_REMOTE}"
        fi
    fi

    if [[ -z "$SYNC_DIR" ]]; then
        local default="$DEFAULT_SYNC_DIR"
        if (( NON_INTERACTIVE )); then
            SYNC_DIR="$default"
        else
            read -rp "Local sync directory [$default]: " SYNC_DIR
            SYNC_DIR="${SYNC_DIR:-$default}"
        fi
    fi

    if [[ -z "$CACHE_DIR" ]]; then
        local default="$DEFAULT_CACHE_DIR"
        if (( NON_INTERACTIVE )); then
            CACHE_DIR="$default"
        else
            read -rp "Cache/log directory [$default]: " CACHE_DIR
            CACHE_DIR="${CACHE_DIR:-$default}"
        fi
    fi

    if [[ -z "$SYNC_INTERVAL" ]]; then
        local default="$DEFAULT_INTERVAL"
        if (( NON_INTERACTIVE )); then
            SYNC_INTERVAL="$default"
        else
            read -rp "Bisync interval [$default]: " SYNC_INTERVAL
            SYNC_INTERVAL="${SYNC_INTERVAL:-$default}"
        fi
    fi

    SYNC_DIR="${SYNC_DIR/#\~/$HOME}"
    CACHE_DIR="${CACHE_DIR/#\~/$HOME}"
}

validate_remote() {
    if ! rclone listremotes | grep -q "^${RCLONE_REMOTE}:$"; then
        fatal "Remote '${RCLONE_REMOTE}' not found. Configure it with 'rclone config'."
    fi
}

render_units() {
    mkdir -p "$CONFIG_ROOT" "${CACHE_DIR}"

    sed \
        -e "s|{{SYNC_DIR}}|$SYNC_DIR|g" \
        -e "s|{{RCLONE_REMOTE}}|$RCLONE_REMOTE|g" \
        -e "s|{{RCLONE_BIN}}|$RCLONE_BIN|g" \
        -e "s|{{CACHE_DIR}}|$CACHE_DIR|g" \
        "$CONFIG_TEMPLATE_DIR/rclone-bisync.service.template" > "$CONFIG_ROOT/$SERVICE_NAME"

    sed \
        -e "s|{{SYNC_INTERVAL}}|$SYNC_INTERVAL|g" \
        "$CONFIG_TEMPLATE_DIR/rclone-bisync.timer.template" > "$CONFIG_ROOT/$TIMER_NAME"
}

reload_systemd() {
    systemctl --user daemon-reload
    if (( ENABLE_AFTER_RENDER )); then
        systemctl --user enable "$TIMER_NAME"
        systemctl --user start "$TIMER_NAME"
    else
        log "$YELLOW" "Units written but not enabled. Enable manually with systemctl --user enable $TIMER_NAME"
    fi
}

summary() {
    log "$GREEN" "Configuration complete."
    log "$BLUE" "Remote: $RCLONE_REMOTE"
    log "$BLUE" "Sync directory: $SYNC_DIR"
    log "$BLUE" "Interval: $SYNC_INTERVAL"
    log "$BLUE" "Cache: $CACHE_DIR"
    if (( ENABLE_AFTER_RENDER )); then
        systemctl --user status "$TIMER_NAME" --no-pager || true
    fi
}

main() {
    parse_args "$@"
    load_existing
    ensure_defaults
    validate_remote
    render_units
    reload_systemd
    summary
}

main "$@"
