#!/usr/bin/env bash
# Unit tests for remote_compilation_helper (rch) integration
# Tests that rch binary works, daemon commands work, and basic operations succeed

set -uo pipefail
# Note: Not using -e to allow tests to continue after failures

LOG_FILE="/tmp/rch_integration_tests_$(date +%Y%m%d_%H%M%S).log"
PASS_COUNT=0
FAIL_COUNT=0

log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG_FILE"; }
pass() {
    log "PASS: $*"
    ((PASS_COUNT++))
}
fail() {
    log "FAIL: $*"
    ((FAIL_COUNT++))
}

# Test 1: rch binary exists
test_rch_binary() {
    log "Test 1: rch binary availability..."
    if command -v rch >/dev/null 2>&1; then
        pass "rch binary found at $(which rch)"
    else
        fail "rch binary not found in PATH"
    fi
}

# Test 2: rch --version works
test_rch_version() {
    log "Test 2: rch --version..."
    local version
    if version=$(rch --version 2>&1); then
        if [[ "$version" =~ rch|Remote ]]; then
            pass "rch version: $version"
        else
            fail "Unexpected version format: $version"
        fi
    else
        fail "rch --version failed"
    fi
}

# Test 3: rch --help works
test_rch_help() {
    log "Test 3: rch --help..."
    if rch --help 2>&1 | grep -q "Remote Compilation"; then
        pass "rch --help displays correct content"
    else
        fail "rch --help failed or missing content"
    fi
}

# Test 4: rch status works
test_rch_status() {
    log "Test 4: rch status..."
    # rch status may return empty output with exit code 0 when no active jobs
    local output exit_code
    output=$(rch status 2>&1)
    exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        if [[ -z "$output" ]]; then
            pass "rch status works (no active jobs)"
        elif [[ "$output" =~ (daemon|worker|Workers|Daemon|job|Job|idle|Idle) ]]; then
            pass "rch status works"
        else
            pass "rch status works (returned: ${output:0:50}...)"
        fi
    else
        fail "rch status failed with exit code $exit_code"
    fi
}

# Test 5: rch doctor works
test_rch_doctor() {
    log "Test 5: rch doctor..."
    # rch doctor outputs "Diagnostic Report" with checkmarks (✓) or x marks
    if rch doctor 2>&1 | head -20 | grep -qiE "(Diagnostic|Report|check|pass|fail|OK|Error|Warning|✓|✗|Prerequisites|Configuration)"; then
        pass "rch doctor provides diagnostic output"
    else
        fail "rch doctor failed or no output"
    fi
}

# Test 6: rch config show works
test_rch_config() {
    log "Test 6: rch config show..."
    if rch config show 2>&1 | grep -qE "(config|Config|path|Path|worker|Worker|enabled|disabled)"; then
        pass "rch config show works"
    else
        fail "rch config show failed"
    fi
}

# Test 7: rch workers list works
test_rch_workers() {
    log "Test 7: rch workers list..."
    # This might return empty list or show workers
    if rch workers list 2>&1; then
        pass "rch workers list works"
    else
        fail "rch workers list failed"
    fi
}

# Summary
print_summary() {
    log ""
    log "========================================"
    log "TEST SUMMARY"
    log "========================================"
    log "Passed: $PASS_COUNT"
    log "Failed: $FAIL_COUNT"
    log "Total:  $((PASS_COUNT + FAIL_COUNT))"
    log "Log file: $LOG_FILE"
    log "========================================"

    if [[ $FAIL_COUNT -gt 0 ]]; then
        log "OVERALL: FAILED"
        return 1
    else
        log "OVERALL: PASSED"
        return 0
    fi
}

# Run all tests
main() {
    log "========================================"
    log "Remote Compilation Helper (rch) Integration Tests"
    log "========================================"
    log ""

    test_rch_binary
    test_rch_version
    test_rch_help
    test_rch_status
    test_rch_doctor
    test_rch_config
    test_rch_workers

    print_summary
}

main "$@"
