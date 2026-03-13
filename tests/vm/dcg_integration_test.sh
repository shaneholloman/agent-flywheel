#!/usr/bin/env bash
# DCG Integration Test
# Tests DCG installation, hook registration, and basic functionality
# Run in Docker: ./dcg_integration_test.sh [--verbose]

set -euo pipefail

# Source test harness
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/test_harness.sh"

# ============================================================
# TEST CONFIGURATION
# ============================================================
TEST_NAME="DCG Integration Test"
VERBOSE="${1:-}"

# ============================================================
# TEST FUNCTIONS
# ============================================================

test_dcg_binary_installed() {
    harness_subsection "Testing DCG binary installation..."

    if command -v dcg &>/dev/null; then
        local dcg_path
        dcg_path=$(command -v dcg)
        local dcg_version
        dcg_version=$(dcg --version 2>/dev/null | head -1 || echo "unknown")
        harness_pass "DCG binary found at: $dcg_path"
        harness_info "DCG version: $dcg_version"
        return 0
    else
        harness_fail "DCG binary not found in PATH"
        harness_info "PATH=$PATH"
        return 1
    fi
}

test_dcg_hook_registered() {
    harness_subsection "Testing DCG hook registration..."

    # Check via dcg doctor (uses text output since --format json isn't fully supported)
    local doctor_output
    doctor_output=$(dcg doctor 2>&1) || true

    if echo "$doctor_output" | grep -qi "hook wiring.*OK"; then
        harness_pass "DCG hook is registered"
        return 0
    else
        harness_fail "DCG hook is NOT registered"
        harness_info "dcg doctor output:"
        echo "$doctor_output" | while read -r line; do harness_info "  $line"; done || true
        return 1
    fi
}

test_dcg_blocks_dangerous_command() {
    harness_subsection "Testing DCG blocks dangerous commands..."

    # Test that dcg test identifies dangerous commands
    local test_output
    test_output=$(dcg test 'git reset --hard HEAD' 2>&1) || true

    if echo "$test_output" | grep -qiE "deny|block|dangerous"; then
        harness_pass "DCG correctly identifies dangerous command"
        if [[ "$VERBOSE" == "--verbose" ]]; then
            harness_info "Output: $test_output"
        fi
        return 0
    else
        harness_fail "DCG did not block dangerous command"
        harness_info "Output: $test_output"
        return 1
    fi
}

test_dcg_allows_safe_command() {
    harness_subsection "Testing DCG allows safe commands..."

    local test_output
    test_output=$(dcg test 'git status' 2>&1) || true

    if echo "$test_output" | grep -qi "allow"; then
        harness_pass "DCG correctly allows safe command"
        return 0
    else
        harness_fail "DCG incorrectly blocked safe command"
        harness_info "Output: $test_output"
        return 1
    fi
}

test_dcg_packs_available() {
    harness_subsection "Testing DCG packs are available..."

    local pack_output
    pack_output=$(dcg packs 2>&1) || true

    local pass_count=0
    local fail_count=0

    # Check for core packs
    if echo "$pack_output" | grep -q "core.git"; then
        harness_pass "Core git pack available"
        pass_count=$((pass_count + 1))
    else
        harness_fail "Core git pack NOT found"
        fail_count=$((fail_count + 1))
    fi

    if echo "$pack_output" | grep -q "core.filesystem"; then
        harness_pass "Core filesystem pack available"
        pass_count=$((pass_count + 1))
    else
        harness_fail "Core filesystem pack NOT found"
        fail_count=$((fail_count + 1))
    fi

    [[ $fail_count -eq 0 ]]
}

test_dcg_explain_works() {
    harness_subsection "Testing DCG explain functionality..."

    local explain_output
    explain_output=$(dcg test 'git reset --hard' --explain 2>&1) || true

    if echo "$explain_output" | grep -qiE "reason|pattern|pack"; then
        harness_pass "DCG explain provides detailed output"
        if [[ "$VERBOSE" == "--verbose" ]]; then
            harness_info "Explain output: $explain_output"
        fi
        return 0
    else
        harness_fail "DCG explain did not provide expected details"
        harness_info "Output: $explain_output"
        return 1
    fi
}

test_dcg_config_file() {
    harness_subsection "Testing DCG configuration file..."

    local config_path="${HOME}/.config/dcg/config.toml"

    if [[ -f "$config_path" ]]; then
        harness_pass "DCG config file exists at $config_path"
        harness_capture_file "$config_path" "DCG config"
        return 0
    else
        harness_skip "DCG config file not found (optional)" "Using defaults"
        return 0
    fi
}

test_dcg_doctor_comprehensive() {
    harness_subsection "Running DCG doctor for comprehensive health check..."

    local doctor_output
    local exit_code=0
    doctor_output=$(dcg doctor 2>&1) || exit_code=$?

    harness_capture_output "dcg_doctor_output" "$doctor_output"

    if [[ $exit_code -eq 0 ]]; then
        harness_pass "DCG doctor completed successfully"
        return 0
    else
        harness_warn "DCG doctor reported issues (exit code: $exit_code)"
        harness_info "See captured output for details"
        return 0  # Not a fatal test failure
    fi
}

# ============================================================
# MAIN TEST RUNNER
# ============================================================

main() {
    harness_init "$TEST_NAME"

    harness_section "DCG Binary Installation"
    test_dcg_binary_installed || true

    harness_section "DCG Hook Registration"
    test_dcg_hook_registered || true

    harness_section "DCG Command Blocking"
    test_dcg_blocks_dangerous_command || true
    test_dcg_allows_safe_command || true

    harness_section "DCG Pack System"
    test_dcg_packs_available || true

    harness_section "DCG Explain Feature"
    test_dcg_explain_works || true

    harness_section "DCG Configuration"
    test_dcg_config_file || true
    test_dcg_doctor_comprehensive || true

    harness_summary
}

main "$@"
