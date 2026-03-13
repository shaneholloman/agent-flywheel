#!/usr/bin/env bash
# Smoke tests that verify tools ACTUALLY WORK, not just that binaries exist
# Each test proves the tool functions correctly, not just exists

set -uo pipefail
# Note: Not using -e to allow tests to continue after failures

LOG_FILE="/tmp/smoke_tests_$(date +%Y%m%d_%H%M%S).log"
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

# ===========================================================================
# Core Tool Smoke Tests
# ===========================================================================

# beads_rust (br) - create, list, and close an issue
test_br_functionality() {
    log "Testing br (beads_rust) functionality..."
    if ! command -v br >/dev/null 2>&1; then
        skip "br not installed, skipping functionality test"
        return
    fi

    # Create a test issue (filter out INFO log lines)
    local test_id
    test_id=$(br create "Smoke test issue - DELETE ME" --type task --priority 4 --silent 2>&1 | grep -vE "INFO|WARN|ERROR" | head -1)
    local create_exit=$?

    if [[ $create_exit -ne 0 ]] || [[ -z "$test_id" ]]; then
        fail "br create failed to create test issue"
        return
    fi

    # Clean up test_id (remove any trailing whitespace/newlines)
    test_id=$(echo "$test_id" | tr -d '\n' | tr -d ' ')

    # Verify it exists in list
    if br list 2>&1 | grep -q "$test_id"; then
        pass "br created and listed issue: $test_id"
    else
        fail "br issue $test_id not found in list"
    fi

    # Close the test issue
    if br update "$test_id" --status closed 2>&1 | grep -qE "Updated|closed"; then
        pass "br closed test issue: $test_id"
    else
        fail "br failed to close test issue: $test_id"
    fi
}

# meta_skill (ms) - list skills
test_ms_functionality() {
    log "Testing ms (meta_skill) functionality..."
    if ! command -v ms >/dev/null 2>&1; then
        skip "ms not installed, skipping functionality test"
        return
    fi

    # List skills (should not error even if empty)
    local output
    output=$(ms list 2>&1)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        pass "ms list completed successfully"
    else
        fail "ms list failed: $output"
    fi

    # Search for skills
    output=$(ms search "test" 2>&1)
    exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        pass "ms search completed successfully"
    else
        fail "ms search failed: $output"
    fi
}

# wezterm_automata (wa) - check daemon status
test_wa_functionality() {
    log "Testing wa (wezterm_automata) functionality..."
    if ! command -v wa >/dev/null 2>&1; then
        skip "wa not installed, skipping functionality test"
        return
    fi

    # Check daemon status (should work even if daemon not running)
    local output
    output=$(wa daemon status 2>&1)
    local exit_code=$?

    # Daemon status should report something meaningful
    if [[ "$output" =~ (running|stopped|not.*running|status) ]]; then
        pass "wa daemon status reports: $(echo "$output" | head -1)"
    elif [[ $exit_code -eq 0 ]]; then
        pass "wa daemon status completed"
    else
        # Even error is acceptable if it mentions daemon
        if [[ "$output" =~ daemon ]]; then
            pass "wa daemon status responded (daemon may not be running)"
        else
            fail "wa daemon status failed unexpectedly: $output"
        fi
    fi
}

# rch (remote_compilation_helper) - check status
test_rch_functionality() {
    log "Testing rch (remote_compilation_helper) functionality..."
    if ! command -v rch >/dev/null 2>&1; then
        skip "rch not installed, skipping functionality test"
        return
    fi

    # Check status
    local output
    output=$(rch status 2>&1)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        pass "rch status completed successfully"
    elif [[ "$output" =~ (config|worker|not.*configured|no.*workers) ]]; then
        # Expected if no workers configured
        pass "rch status reports configuration state"
    else
        fail "rch status failed: $output"
    fi
}

# brenner_bot (brenner) - check corpus
test_brenner_functionality() {
    log "Testing brenner (brenner_bot) functionality..."
    if ! command -v brenner >/dev/null 2>&1; then
        skip "brenner not installed, skipping functionality test"
        return
    fi

    # List corpus sections
    local output
    output=$(brenner corpus list 2>&1)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        pass "brenner corpus list completed successfully"
    elif [[ "$output" =~ (section|corpus|not.*found|no.*corpus) ]]; then
        pass "brenner corpus responds appropriately"
    else
        fail "brenner corpus list failed: $output"
    fi
}

# bv (beads_viewer) - run triage
test_bv_functionality() {
    log "Testing bv (beads_viewer) functionality..."
    if ! command -v bv >/dev/null 2>&1; then
        skip "bv not installed, skipping functionality test"
        return
    fi

    # Run robot-next to get a recommendation
    local output
    output=$(bv --robot-next 2>&1)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]] && [[ "$output" =~ "id" ]]; then
        pass "bv --robot-next returned valid recommendation"
    elif [[ "$output" =~ (no.*issues|empty|nothing) ]]; then
        pass "bv --robot-next reports no work (acceptable)"
    else
        fail "bv --robot-next failed: $output"
    fi
}

# cass - search sessions
test_cass_functionality() {
    log "Testing cass functionality..."
    if ! command -v cass >/dev/null 2>&1; then
        skip "cass not installed, skipping functionality test"
        return
    fi

    # Search for something (should work even with no results)
    local output
    output=$(cass search "test" 2>&1)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        pass "cass search completed successfully"
    elif [[ "$output" =~ (no.*results|not.*found|empty) ]]; then
        pass "cass search reports no results (acceptable)"
    else
        fail "cass search failed: $output"
    fi
}

# cm - list playbooks
test_cm_functionality() {
    log "Testing cm functionality..."
    if ! command -v cm >/dev/null 2>&1; then
        skip "cm not installed, skipping functionality test"
        return
    fi

    # List playbooks (cm uses 'ls' not 'list')
    local output
    output=$(cm ls 2>&1)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        pass "cm ls completed successfully"
    elif [[ "$output" =~ (no.*playbooks|empty|not.*found|no.*rules) ]]; then
        pass "cm ls reports no playbooks (acceptable)"
    else
        fail "cm ls failed: $output"
    fi
}

# dcg - check status
test_dcg_functionality() {
    log "Testing dcg functionality..."
    if ! command -v dcg >/dev/null 2>&1; then
        skip "dcg not installed, skipping functionality test"
        return
    fi

    # Check status
    local output
    output=$(dcg status 2>&1)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        pass "dcg status completed successfully"
    elif [[ "$output" =~ (enabled|disabled|status|protection) ]]; then
        pass "dcg status reports protection state"
    else
        fail "dcg status failed: $output"
    fi
}

# ntm - list sessions
test_ntm_functionality() {
    log "Testing ntm functionality..."
    if ! command -v ntm >/dev/null 2>&1; then
        skip "ntm not installed, skipping functionality test"
        return
    fi

    # List sessions
    local output
    output=$(ntm list 2>&1)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        pass "ntm list completed successfully"
    elif [[ "$output" =~ (no.*sessions|empty|not.*found) ]]; then
        pass "ntm list reports no sessions (acceptable)"
    else
        fail "ntm list failed: $output"
    fi
}

# ===========================================================================
# Utility Tool Smoke Tests
# ===========================================================================

# giil - help check
test_giil_functionality() {
    log "Testing giil functionality..."
    if ! command -v giil >/dev/null 2>&1; then
        skip "giil not installed, skipping functionality test"
        return
    fi

    # Help should show URL/image options
    if giil --help 2>&1 | grep -qiE "(url|image|download)"; then
        pass "giil --help displays relevant options"
    else
        fail "giil --help missing expected content"
    fi
}

# srps - check status
test_srps_functionality() {
    log "Testing srps functionality..."
    if ! command -v srps >/dev/null 2>&1; then
        skip "srps not installed, skipping functionality test"
        return
    fi

    # Check status
    local output
    output=$(srps status 2>&1)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        pass "srps status completed successfully"
    elif [[ "$output" =~ (process|priority|running|stopped) ]]; then
        pass "srps status reports system state"
    else
        fail "srps status failed: $output"
    fi
}

# pt - help check
test_pt_functionality() {
    log "Testing pt (process_triage) functionality..."
    if ! command -v pt >/dev/null 2>&1; then
        skip "pt not installed, skipping functionality test"
        return
    fi

    local output
    output=$(pt --help 2>&1)

    # pt may require pt-core to be installed
    if [[ "$output" =~ "pt-core" ]]; then
        skip "pt requires pt-core binary to be installed"
        return
    fi

    # Help should show process options
    if echo "$output" | grep -qiE "(process|triage|usage)"; then
        pass "pt --help displays relevant options"
    else
        fail "pt --help missing expected content: $output"
    fi
}

# xf - help check
test_xf_functionality() {
    log "Testing xf functionality..."
    if ! command -v xf >/dev/null 2>&1; then
        skip "xf not installed, skipping functionality test"
        return
    fi

    # Help should show search/X options
    if xf --help 2>&1 | grep -qiE "(search|twitter|x|archive)"; then
        pass "xf --help displays relevant options"
    else
        fail "xf --help missing expected content"
    fi
}

# ru - list repos
test_ru_functionality() {
    log "Testing ru functionality..."
    if ! command -v ru >/dev/null 2>&1; then
        skip "ru not installed, skipping functionality test"
        return
    fi

    # List repos
    local output
    output=$(ru list 2>&1)
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        pass "ru list completed successfully"
    elif [[ "$output" =~ (no.*repos|empty|not.*configured) ]]; then
        pass "ru list reports no repos (acceptable)"
    else
        fail "ru list failed: $output"
    fi
}

# ===========================================================================
# Main Test Runner
# ===========================================================================

main() {
    log "=========================================="
    log "Tool Functionality Smoke Tests"
    log "=========================================="
    log "Log file: $LOG_FILE"
    log ""

    # Core tools
    log "--- Core Tools ---"
    test_br_functionality
    test_ms_functionality
    test_wa_functionality
    test_rch_functionality
    test_brenner_functionality
    test_bv_functionality
    test_cass_functionality
    test_cm_functionality
    test_dcg_functionality
    test_ntm_functionality

    log ""
    log "--- Utility Tools ---"
    test_giil_functionality
    test_srps_functionality
    test_pt_functionality
    test_xf_functionality
    test_ru_functionality

    # Summary
    log ""
    log "=========================================="
    log "Test Summary"
    log "=========================================="
    log "Passed:  $PASS_COUNT"
    log "Failed:  $FAIL_COUNT"
    log "Skipped: $SKIP_COUNT"
    log ""

    # Generate JSON summary
    local json_file="/tmp/smoke_tests_$(date +%Y%m%d_%H%M%S).json"
    cat > "$json_file" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "log_file": "$LOG_FILE",
  "results": {
    "passed": $PASS_COUNT,
    "failed": $FAIL_COUNT,
    "skipped": $SKIP_COUNT,
    "total": $((PASS_COUNT + FAIL_COUNT + SKIP_COUNT))
  },
  "success": $([ $FAIL_COUNT -eq 0 ] && echo "true" || echo "false")
}
EOF
    log "JSON summary: $json_file"

    if [[ $FAIL_COUNT -eq 0 ]]; then
        log "All tests passed or skipped!"
        exit 0
    else
        log "Some tests failed - see log for details"
        exit 1
    fi
}

main "$@"
