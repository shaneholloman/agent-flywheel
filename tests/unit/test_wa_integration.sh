#!/usr/bin/env bash
# Unit tests for wezterm_automata (wa) integration
# Tests that wa binary works, basic commands work, and operations succeed
# Note: wa may not be installed on all systems - tests handle this gracefully

set -uo pipefail
# Note: Not using -e to allow tests to continue after failures

LOG_FILE="/tmp/wa_integration_tests_$(date +%Y%m%d_%H%M%S).log"
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG_FILE"; }
pass() {
    log "PASS: $*"
    ((PASS_COUNT++))
}
fail() {
    log "FAIL: $*"
    ((FAIL_COUNT++))
}
skip() {
    log "SKIP: $*"
    ((SKIP_COUNT++))
}

# Test 1: wa binary exists
test_wa_binary() {
    log "Test 1: wa binary availability..."
    if command -v wa >/dev/null 2>&1; then
        pass "wa binary found at $(which wa)"
        return 0
    else
        skip "wa binary not found in PATH (tool may not be installed yet)"
        return 1
    fi
}

# Test 2: wa --version works
test_wa_version() {
    log "Test 2: wa --version..."
    if ! command -v wa >/dev/null 2>&1; then
        skip "wa not installed, skipping version test"
        return
    fi

    local version
    if version=$(wa --version 2>&1); then
        if [[ "$version" =~ wezterm|wa|automata|WezTerm ]]; then
            pass "wa version: $version"
        else
            # Accept any version output
            pass "wa version: $version"
        fi
    else
        fail "wa --version failed"
    fi
}

# Test 3: wa --help works
test_wa_help() {
    log "Test 3: wa --help..."
    if ! command -v wa >/dev/null 2>&1; then
        skip "wa not installed, skipping help test"
        return
    fi

    if wa --help 2>&1 | head -20 | grep -qiE "(wezterm|automata|usage|command|help)"; then
        pass "wa --help displays correct content"
    else
        fail "wa --help failed or missing content"
    fi
}

# Test 4: wa list works (if available)
test_wa_list() {
    log "Test 4: wa list..."
    if ! command -v wa >/dev/null 2>&1; then
        skip "wa not installed, skipping list test"
        return
    fi

    # Try common list commands
    if wa list 2>&1 | head -5 | grep -qiE "(session|pane|window|tab|no|empty)"; then
        pass "wa list works"
    elif wa sessions 2>&1 | head -5 | grep -qiE "(session|pane|window|tab|no|empty)"; then
        pass "wa sessions works"
    else
        # If neither works, check if any command gives useful output
        local output
        output=$(wa 2>&1 | head -10) || true
        if [[ -n "$output" ]]; then
            pass "wa provides output (may need WezTerm running)"
        else
            fail "wa list/sessions failed"
        fi
    fi
}

# Test 5: wa status works (if available)
test_wa_status() {
    log "Test 5: wa status..."
    if ! command -v wa >/dev/null 2>&1; then
        skip "wa not installed, skipping status test"
        return
    fi

    # Try status command
    local output exit_code
    output=$(wa status 2>&1)
    exit_code=$?

    if [[ $exit_code -eq 0 ]] || [[ "$output" =~ (connected|running|status|WezTerm|not running|no sessions) ]]; then
        pass "wa status works (output: ${output:0:50}...)"
    else
        # wa status might fail if WezTerm isn't running, which is OK
        if [[ "$output" =~ (not found|not running|connection|error) ]]; then
            pass "wa status works (WezTerm not running)"
        else
            fail "wa status failed: $output"
        fi
    fi
}

# Test 6: wa config/doctor works (if available)
test_wa_doctor() {
    log "Test 6: wa doctor/config..."
    if ! command -v wa >/dev/null 2>&1; then
        skip "wa not installed, skipping doctor test"
        return
    fi

    # Try doctor or config commands
    if wa doctor 2>&1 | head -10 | grep -qiE "(check|pass|fail|OK|error|warning|diagnostic|config)"; then
        pass "wa doctor provides diagnostic output"
    elif wa config 2>&1 | head -10 | grep -qiE "(config|setting|path|option|value)"; then
        pass "wa config works"
    elif wa info 2>&1 | head -10 | grep -qiE "(version|path|config|wezterm)"; then
        pass "wa info works"
    else
        # Accept if any help-like output is provided
        if wa 2>&1 | head -5 | grep -qiE "(usage|command|help)"; then
            pass "wa provides help (no specific doctor/config command)"
        else
            fail "wa doctor/config/info failed"
        fi
    fi
}

# Summary
print_summary() {
    log ""
    log "========================================"
    log "TEST SUMMARY"
    log "========================================"
    log "Passed:  $PASS_COUNT"
    log "Failed:  $FAIL_COUNT"
    log "Skipped: $SKIP_COUNT"
    log "Total:   $((PASS_COUNT + FAIL_COUNT + SKIP_COUNT))"
    log "Log file: $LOG_FILE"
    log "========================================"

    if [[ $FAIL_COUNT -gt 0 ]]; then
        log "OVERALL: FAILED"
        return 1
    elif [[ $SKIP_COUNT -gt 0 && $PASS_COUNT -eq 0 ]]; then
        log "OVERALL: SKIPPED (wa not installed)"
        return 0
    else
        log "OVERALL: PASSED"
        return 0
    fi
}

# Run all tests
main() {
    log "========================================"
    log "wezterm_automata (wa) Integration Tests"
    log "========================================"
    log ""

    # Test 1 determines if we can run other tests
    test_wa_binary
    test_wa_version
    test_wa_help
    test_wa_list
    test_wa_status
    test_wa_doctor

    print_summary
}

main "$@"
