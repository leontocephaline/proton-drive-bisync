#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

GIST_URL="https://gist.github.com/526cc5cafefdefd264c8422deb897e39.git"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_RESULTS_DIR="$PROJECT_ROOT/test-results"

DISTROS=(
    "ubuntu:24.04"
    "debian:12"
    "fedora:40"
    "quay.io/toolbx/arch-toolbox:latest"
    "alpine:latest"
)

log() {
    printf "%b[%s]%b %s\n" "$1" "$(date '+%H:%M:%S')" "$NC" "$2" >&2
}

section() {
    printf "\n%b=== %s ===%b\n" "$BLUE" "$1" "$NC" >&2
}

check_distrobox() {
    if ! command -v distrobox >/dev/null 2>&1; then
        log "$RED" "distrobox not found. Install with: sudo apt install distrobox (or equivalent)"
        exit 1
    fi
    log "$GREEN" "distrobox detected"
}

check_podman_or_docker() {
    if command -v podman >/dev/null 2>&1; then
        log "$GREEN" "Using podman as container backend"
        return 0
    elif command -v docker >/dev/null 2>&1; then
        log "$GREEN" "Using docker as container backend"
        return 0
    else
        log "$RED" "Neither podman nor docker found. Install one to use distrobox."
        exit 1
    fi
}

create_test_container() {
    local distro="$1"
    local container_name="proton-test-${distro//[:\/]/-}"
    
    log "$YELLOW" "Creating distrobox for $distro..."
    
    if distrobox list 2>/dev/null | awk 'NR>1 {print $1}' | grep -Fxq "$container_name"; then
        log "$YELLOW" "Container $container_name exists, removing..."
        distrobox rm -f "$container_name" >/dev/null 2>&1 || true
    fi
    
    local tmp_log
    tmp_log="$(mktemp)"
    if ! distrobox create --name "$container_name" --image "$distro" --yes >"$tmp_log" 2>&1; then
        log "$RED" "Failed to create $container_name. See $tmp_log"
        cat "$tmp_log"
        rm -f "$tmp_log"
        return 1
    fi
    rm -f "$tmp_log"

    log "$GREEN" "Container $container_name ready."
    echo "$container_name"
}

run_test_in_container() {
    local container_name="$1"
    local distro="$2"
    local result_file="$TEST_RESULTS_DIR/${container_name}.log"
    
    mkdir -p "$TEST_RESULTS_DIR"
    
    log "$BLUE" "Testing in $container_name ($distro)..."
    
    # Start the container and get its ID
    log "$BLUE" "Starting container..."
    local cid
    if ! cid=$(podman start "$container_name" 2>&1); then
        log "$RED" "Failed to start container: $cid"
        echo "ERROR: Failed to start $container_name: $cid" > "$result_file"
        return 1
    fi
    
    # Wait for container to fully start and distrobox setup to complete
    log "$BLUE" "Waiting for container initialization..."
    sleep 10
    
    # Wait for apt/dnf locks to clear (distrobox may be installing packages)
    local retries=12
    while [ $retries -gt 0 ]; do
        if podman exec "$container_name" bash -c 'command -v git >/dev/null 2>&1' 2>/dev/null; then
            break
        fi
        sleep 5
        ((retries--))
    done
    
    # Get the running container ID
    cid=$(podman ps --filter "name=$container_name" --format "{{.ID}}" | head -n1)
    
    if [ -z "$cid" ]; then
        log "$RED" "Container not running after start"
        echo "ERROR: Container $container_name not running" > "$result_file"
        return 1
    fi
    
    log "$BLUE" "Running tests (container: $cid)..."
    
    local test_passed=true
    
    {
        echo "=== Testing $distro (container: $cid) ==="
        
        # Test 1: Clone gist and validate syntax
        if timeout 300 podman exec "$cid" bash -c '
            set -ex
            cd /tmp
            rm -rf proton-drive-bisync
            git clone https://gist.github.com/526cc5cafefdefd264c8422deb897e39.git proton-drive-bisync || exit 1
            cd proton-drive-bisync
            chmod +x install.sh uninstall.sh
            chmod +x scripts/*.sh
            bash -n install.sh && bash -n uninstall.sh && bash -n scripts/*.sh
            echo "=== SYNTAX CHECK PASSED ==="
        '; then
            echo "✓ Syntax validation passed"
        else
            echo "✗ Syntax validation failed"
            test_passed=false
        fi
        
        # Test 2: Check help output
        if timeout 60 podman exec "$cid" bash -c '
            cd /tmp/proton-drive-bisync
            ./install.sh --help 2>&1 || true
            scripts/setup-proton-drive.sh --help
            echo "=== HELP OUTPUT OK ==="
        '; then
            echo "✓ Help output OK"
        else
            echo "✗ Help output failed"
            test_passed=false
        fi
        
        # Test 3: Test systemd unit rendering (without installing)
        if timeout 60 podman exec "$cid" bash -c '
            cd /tmp/proton-drive-bisync
            # Test unit rendering with dummy values
            scripts/setup-proton-drive.sh \
              --remote testremote \
              --sync-dir /tmp/test-sync \
              --interval 15min \
              --disable-enable \
              --non-interactive 2>&1 || exit 1
            # Verify units were created
            test -f ~/.config/systemd/user/rclone-bisync.service || exit 1
            test -f ~/.config/systemd/user/rclone-bisync.timer || exit 1
            # Validate systemd unit syntax
            systemd-analyze verify ~/.config/systemd/user/rclone-bisync.service 2>&1 || true
            echo "=== UNIT RENDERING OK ==="
        '; then
            echo "✓ Systemd unit rendering OK"
        else
            echo "✗ Unit rendering failed"
            test_passed=false
        fi
        
        echo "=== TEST COMPLETE ==="
    } > "$result_file" 2>&1
    
    if [ "$test_passed" = true ]; then
        log "$GREEN" "✓ $distro: PASSED"
        return 0
    else
        log "$RED" "✗ $distro: FAILED (see $result_file)"
        return 1
    fi
}

cleanup_container() {
    local container_name="$1"
    log "$YELLOW" "Cleaning up $container_name..."
    distrobox rm -f "$container_name" || true
}

run_all_tests() {
    local passed=0
    local failed=0
    
    section "Starting distro compatibility tests"
    
    for distro in "${DISTROS[@]}"; do
        local container_name
        if ! container_name=$(create_test_container "$distro"); then
            ((failed++))
            continue
        fi
        
        if run_test_in_container "$container_name" "$distro"; then
            ((passed++))
        else
            ((failed++))
        fi
        
        cleanup_container "$container_name"
    done
    
    section "Test Summary"
    log "$GREEN" "Passed: $passed"
    log "$RED" "Failed: $failed"
    
    if [ "$failed" -eq 0 ]; then
        log "$GREEN" "All tests passed!"
        return 0
    else
        log "$RED" "Some tests failed. Check logs in $TEST_RESULTS_DIR"
        return 1
    fi
}

show_results() {
    section "Test Results"
    for result_file in "$TEST_RESULTS_DIR"/*.log; do
        if [ -f "$result_file" ]; then
            echo ""
            log "$BLUE" "=== $(basename "$result_file") ==="
            tail -n 20 "$result_file"
        fi
    done
}

main() {
    check_distrobox
    check_podman_or_docker
    
    if run_all_tests; then
        show_results
        exit 0
    else
        show_results
        exit 1
    fi
}

main "$@"
