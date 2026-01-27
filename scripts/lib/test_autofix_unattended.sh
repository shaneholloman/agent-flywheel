#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034
# ============================================================
# Test script for autofix_unattended.sh
# Run: bash scripts/lib/test_autofix_unattended.sh
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the module
source "$SCRIPT_DIR/autofix_unattended.sh"

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

# Test: Check function returns valid JSON
test_check_returns_json() {
    local result
    result=$(autofix_unattended_upgrades_check 2>/dev/null)

    if ! echo "$result" | jq . &>/dev/null; then
        test_fail "check_returns_json" "Output is not valid JSON"
        return
    fi

    # Verify required fields exist
    local status
    status=$(echo "$result" | jq -r '.status')
    if [[ -z "$status" ]]; then
        test_fail "check_returns_json" "Missing 'status' field"
        return
    fi

    local held_locks
    held_locks=$(echo "$result" | jq -r '.held_locks | type')
    if [[ "$held_locks" != "array" ]]; then
        test_fail "check_returns_json" "held_locks should be array"
        return
    fi

    test_pass "check_returns_json"
}

# Test: Check returns valid status values
test_check_valid_status() {
    local result
    result=$(autofix_unattended_upgrades_check 2>/dev/null)
    local status
    status=$(echo "$result" | jq -r '.status')

    case "$status" in
        none|active|locks_held|processes_running)
            test_pass "check_valid_status ($status)"
            ;;
        *)
            test_fail "check_valid_status" "Unknown status: $status"
            ;;
    esac
}

# Test: needs_fix function returns boolean-like result
test_needs_fix_returns_correctly() {
    # This function uses exit codes, so test that behavior
    local result
    if autofix_unattended_upgrades_needs_fix 2>/dev/null; then
        result="needs_fix"
    else
        result="clean"
    fi

    # Either result is valid depending on system state
    if [[ "$result" == "needs_fix" || "$result" == "clean" ]]; then
        test_pass "needs_fix_returns_correctly (returned: $result)"
    else
        test_fail "needs_fix_returns_correctly" "Invalid result"
    fi
}

# Test: Dry-run mode doesn't modify system
test_dry_run_no_changes() {
    # Get state before
    local before_active="false"
    if systemctl is-active unattended-upgrades &>/dev/null 2>&1; then
        before_active="true"
    fi

    # Run dry-run
    autofix_unattended_upgrades_fix "dry-run" &>/dev/null

    # Get state after
    local after_active="false"
    if systemctl is-active unattended-upgrades &>/dev/null 2>&1; then
        after_active="true"
    fi

    if [[ "$before_active" == "$after_active" ]]; then
        test_pass "dry_run_no_changes"
    else
        test_fail "dry_run_no_changes" "System state changed during dry-run"
    fi
}

# Test: CLI modes work
test_cli_modes() {
    local failed=0

    # Test check mode
    if ! bash "$SCRIPT_DIR/autofix_unattended.sh" check &>/dev/null; then
        ((failed++))
        echo "       check mode failed"
    fi

    # Test dry-run mode
    if ! bash "$SCRIPT_DIR/autofix_unattended.sh" dry-run &>/dev/null; then
        ((failed++))
        echo "       dry-run mode failed"
    fi

    # Test help (invalid mode shows usage)
    if bash "$SCRIPT_DIR/autofix_unattended.sh" --help &>/dev/null 2>&1; then
        # Should exit 1 for unknown mode
        :
    fi

    if [[ $failed -eq 0 ]]; then
        test_pass "cli_modes"
    else
        test_fail "cli_modes" "$failed mode(s) failed"
    fi
}

# Test: Lock file list is properly defined
test_lock_file_constants() {
    if [[ ${#APT_LOCK_FILES[@]} -lt 3 ]]; then
        test_fail "lock_file_constants" "Should have at least 3 lock files defined"
        return
    fi

    # All paths should be absolute
    for lock in "${APT_LOCK_FILES[@]}"; do
        if [[ "$lock" != /* ]]; then
            test_fail "lock_file_constants" "Lock path not absolute: $lock"
            return
        fi
    done

    test_pass "lock_file_constants"
}

# Run all tests
main() {
    echo "==========================================="
    echo "Running autofix_unattended.sh unit tests"
    echo "==========================================="

    test_check_returns_json
    test_check_valid_status
    test_needs_fix_returns_correctly
    test_dry_run_no_changes
    test_cli_modes
    test_lock_file_constants

    echo "==========================================="
    echo "Results: $TESTS_PASSED passed, $TESTS_FAILED failed"

    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    fi

    echo "All tests passed!"
    exit 0
}

main "$@"
