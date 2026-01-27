#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034,SC2317
# ============================================================
# Test script for autofix_version_managers.sh
# Run: bash scripts/lib/test_autofix_version_managers.sh
#
# Related beads:
#   - bd-19y9.3.2: Implement auto-fix for nvm/pyenv conflicts
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the module
source "$SCRIPT_DIR/autofix_version_managers.sh"

TESTS_PASSED=0
TESTS_FAILED=0

test_pass() {
    local name="$1"
    echo -e "\033[32m[PASS]\033[0m $name"
    ((++TESTS_PASSED))
}

test_fail() {
    local name="$1"
    local reason="${2:-}"
    echo -e "\033[31m[FAIL]\033[0m $name"
    [[ -n "$reason" ]] && echo "       Reason: $reason"
    ((++TESTS_FAILED))
}

# Safe cleanup function
cleanup_test_dir() {
    local test_dir="$1"
    if [[ -d "$test_dir" ]]; then
        rm -rf "$test_dir"
    fi
}

# ============================================================
# NVM Tests
# ============================================================

# Test: NVM check when no NVM exists
test_nvm_check_no_installation() {
    local test_id="nvm_check_none"
    local test_dir="/tmp/test_autofix_${test_id}_$$"
    mkdir -p "$test_dir"

    # Override HOME to isolated test directory
    local old_home="$HOME"
    HOME="$test_dir"
    unset NVM_DIR

    local result
    result=$(autofix_nvm_check)

    HOME="$old_home"
    cleanup_test_dir "$test_dir"

    local status
    status=$(echo "$result" | jq -r '.status')

    if [[ "$status" != "none" ]]; then
        test_fail "nvm_check_no_installation" "Expected status 'none', got '$status'"
        return
    fi

    test_pass "nvm_check_no_installation"
}

# Test: NVM check when NVM_DIR is set
test_nvm_check_env_set() {
    local test_id="nvm_check_env"
    local test_dir="/tmp/test_autofix_${test_id}_$$"
    mkdir -p "$test_dir/.nvm"

    local old_home="$HOME"
    local old_nvm_dir="${NVM_DIR:-}"
    HOME="$test_dir"
    NVM_DIR="$test_dir/.nvm"

    local result
    result=$(autofix_nvm_check)

    HOME="$old_home"
    [[ -n "$old_nvm_dir" ]] && NVM_DIR="$old_nvm_dir" || unset NVM_DIR
    cleanup_test_dir "$test_dir"

    local status
    status=$(echo "$result" | jq -r '.status')

    # Should detect as installed (directory exists)
    if [[ "$status" != "installed" ]]; then
        test_fail "nvm_check_env_set" "Expected status 'installed', got '$status'"
        return
    fi

    test_pass "nvm_check_env_set"
}

# Test: NVM check detects shell configs
test_nvm_check_shell_configs() {
    local test_id="nvm_check_configs"
    local test_dir="/tmp/test_autofix_${test_id}_$$"
    mkdir -p "$test_dir/.nvm"

    # Create bashrc with NVM references
    cat > "$test_dir/.bashrc" << 'EOF'
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
EOF

    local old_home="$HOME"
    HOME="$test_dir"
    unset NVM_DIR

    local result
    result=$(autofix_nvm_check)

    HOME="$old_home"
    cleanup_test_dir "$test_dir"

    local config_count
    config_count=$(echo "$result" | jq -r '.shell_configs | length')

    if [[ "$config_count" -lt 1 ]]; then
        test_fail "nvm_check_shell_configs" "Expected at least 1 shell config, got $config_count"
        return
    fi

    test_pass "nvm_check_shell_configs"
}

# Test: NVM dry-run mode
test_nvm_fix_dry_run() {
    local test_id="nvm_fix_dry"
    local test_dir="/tmp/test_autofix_${test_id}_$$"
    mkdir -p "$test_dir/.nvm"

    cat > "$test_dir/.bashrc" << 'EOF'
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
EOF

    local old_home="$HOME"
    HOME="$test_dir"
    unset NVM_DIR

    # Run dry-run
    local output
    output=$(autofix_nvm_fix "dry-run" 2>&1)

    # Directory should still exist
    if [[ ! -d "$test_dir/.nvm" ]]; then
        HOME="$old_home"
        cleanup_test_dir "$test_dir"
        test_fail "nvm_fix_dry_run" "Directory was removed in dry-run mode"
        return
    fi

    # Config should be unchanged
    if ! grep -q "NVM_DIR" "$test_dir/.bashrc"; then
        HOME="$old_home"
        cleanup_test_dir "$test_dir"
        test_fail "nvm_fix_dry_run" "Config was modified in dry-run mode"
        return
    fi

    HOME="$old_home"
    cleanup_test_dir "$test_dir"

    test_pass "nvm_fix_dry_run"
}

# ============================================================
# Pyenv Tests
# ============================================================

# Test: Pyenv check when no pyenv exists
test_pyenv_check_no_installation() {
    local test_id="pyenv_check_none"
    local test_dir="/tmp/test_autofix_${test_id}_$$"
    mkdir -p "$test_dir"

    local old_home="$HOME"
    HOME="$test_dir"
    unset PYENV_ROOT

    local result
    result=$(autofix_pyenv_check)

    HOME="$old_home"
    cleanup_test_dir "$test_dir"

    local status
    status=$(echo "$result" | jq -r '.status')

    if [[ "$status" != "none" ]]; then
        test_fail "pyenv_check_no_installation" "Expected status 'none', got '$status'"
        return
    fi

    test_pass "pyenv_check_no_installation"
}

# Test: Pyenv check when PYENV_ROOT is set
test_pyenv_check_env_set() {
    local test_id="pyenv_check_env"
    local test_dir="/tmp/test_autofix_${test_id}_$$"
    mkdir -p "$test_dir/.pyenv/bin"

    local old_home="$HOME"
    local old_pyenv_root="${PYENV_ROOT:-}"
    HOME="$test_dir"
    PYENV_ROOT="$test_dir/.pyenv"

    local result
    result=$(autofix_pyenv_check)

    HOME="$old_home"
    [[ -n "$old_pyenv_root" ]] && PYENV_ROOT="$old_pyenv_root" || unset PYENV_ROOT
    cleanup_test_dir "$test_dir"

    local status
    status=$(echo "$result" | jq -r '.status')

    if [[ "$status" != "installed" ]]; then
        test_fail "pyenv_check_env_set" "Expected status 'installed', got '$status'"
        return
    fi

    test_pass "pyenv_check_env_set"
}

# Test: Pyenv check detects shell configs
test_pyenv_check_shell_configs() {
    local test_id="pyenv_check_configs"
    local test_dir="/tmp/test_autofix_${test_id}_$$"
    mkdir -p "$test_dir/.pyenv"

    cat > "$test_dir/.bashrc" << 'EOF'
export PYENV_ROOT="$HOME/.pyenv"
eval "$(pyenv init -)"
EOF

    local old_home="$HOME"
    HOME="$test_dir"
    unset PYENV_ROOT

    local result
    result=$(autofix_pyenv_check)

    HOME="$old_home"
    cleanup_test_dir "$test_dir"

    local config_count
    config_count=$(echo "$result" | jq -r '.shell_configs | length')

    if [[ "$config_count" -lt 1 ]]; then
        test_fail "pyenv_check_shell_configs" "Expected at least 1 shell config, got $config_count"
        return
    fi

    test_pass "pyenv_check_shell_configs"
}

# Test: Pyenv dry-run mode
test_pyenv_fix_dry_run() {
    local test_id="pyenv_fix_dry"
    local test_dir="/tmp/test_autofix_${test_id}_$$"
    mkdir -p "$test_dir/.pyenv"

    cat > "$test_dir/.bashrc" << 'EOF'
export PYENV_ROOT="$HOME/.pyenv"
eval "$(pyenv init -)"
EOF

    local old_home="$HOME"
    HOME="$test_dir"
    unset PYENV_ROOT

    # Run dry-run
    local output
    output=$(autofix_pyenv_fix "dry-run" 2>&1)

    # Directory should still exist
    if [[ ! -d "$test_dir/.pyenv" ]]; then
        HOME="$old_home"
        cleanup_test_dir "$test_dir"
        test_fail "pyenv_fix_dry_run" "Directory was removed in dry-run mode"
        return
    fi

    # Config should be unchanged
    if ! grep -q "PYENV_ROOT" "$test_dir/.bashrc"; then
        HOME="$old_home"
        cleanup_test_dir "$test_dir"
        test_fail "pyenv_fix_dry_run" "Config was modified in dry-run mode"
        return
    fi

    HOME="$old_home"
    cleanup_test_dir "$test_dir"

    test_pass "pyenv_fix_dry_run"
}

# ============================================================
# Combined Tests
# ============================================================

# Test: Combined check returns expected structure
test_combined_check_structure() {
    local test_id="combined_check"
    local test_dir="/tmp/test_autofix_${test_id}_$$"
    mkdir -p "$test_dir"

    local old_home="$HOME"
    HOME="$test_dir"
    unset NVM_DIR PYENV_ROOT

    local result
    result=$(autofix_version_managers_check)

    HOME="$old_home"
    cleanup_test_dir "$test_dir"

    # Verify structure
    if ! echo "$result" | jq -e '.nvm' >/dev/null 2>&1; then
        test_fail "combined_check_structure" "Missing nvm key"
        return
    fi

    if ! echo "$result" | jq -e '.pyenv' >/dev/null 2>&1; then
        test_fail "combined_check_structure" "Missing pyenv key"
        return
    fi

    # Use 'has' to check for key presence since has_conflicts may be false
    if ! echo "$result" | jq -e 'has("has_conflicts")' >/dev/null 2>&1; then
        test_fail "combined_check_structure" "Missing has_conflicts key"
        return
    fi

    test_pass "combined_check_structure"
}

# ============================================================
# Main Test Runner
# ============================================================

main() {
    echo "============================================="
    echo "Running autofix_version_managers.sh unit tests"
    echo "============================================="

    # NVM tests
    test_nvm_check_no_installation
    test_nvm_check_env_set
    test_nvm_check_shell_configs
    test_nvm_fix_dry_run

    # Pyenv tests
    test_pyenv_check_no_installation
    test_pyenv_check_env_set
    test_pyenv_check_shell_configs
    test_pyenv_fix_dry_run

    # Combined tests
    test_combined_check_structure

    echo "============================================="
    echo "Results: $TESTS_PASSED passed, $TESTS_FAILED failed"

    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    fi

    echo "All tests passed!"
    exit 0
}

main "$@"
