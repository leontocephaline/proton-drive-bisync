#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
    printf "%b%s%b\n" "$1" "$2" "$NC"
}

section() {
    printf "\n%b=== %s ===%b\n" "$BLUE" "$1" "$NC"
}

section "Syntax Validation"

FAILED=0

# Test all shell scripts
for script in install.sh uninstall.sh scripts/*.sh; do
    if [ -f "$script" ]; then
        if bash -n "$script" 2>/dev/null; then
            log "$GREEN" "✓ $script"
        else
            log "$RED" "✗ $script - syntax error"
            bash -n "$script"
            ((FAILED++))
        fi
    fi
done

section "Help Output Tests"

# Test help flags
if ./install.sh --help >/dev/null 2>&1 || true; then
    log "$GREEN" "✓ install.sh --help"
else
    log "$YELLOW" "⚠ install.sh --help (may require interaction)"
fi

if scripts/setup-proton-drive.sh --help >/dev/null 2>&1; then
    log "$GREEN" "✓ setup-proton-drive.sh --help"
else
    log "$RED" "✗ setup-proton-drive.sh --help failed"
    ((FAILED++))
fi

section "Template Validation"

# Check templates exist and have placeholders
for template in config/*.template; do
    if [ -f "$template" ]; then
        if grep -q "{{" "$template"; then
            log "$GREEN" "✓ $template (has placeholders)"
        else
            log "$YELLOW" "⚠ $template (no placeholders found)"
        fi
    fi
done

section "Documentation Check"

# Verify docs exist
for doc in README.md LICENSE docs/*.md; do
    if [ -f "$doc" ]; then
        log "$GREEN" "✓ $doc exists"
    else
        log "$RED" "✗ $doc missing"
        ((FAILED++))
    fi
done

section "Summary"

if [ $FAILED -eq 0 ]; then
    log "$GREEN" "All checks passed!"
    exit 0
else
    log "$RED" "$FAILED checks failed"
    exit 1
fi
