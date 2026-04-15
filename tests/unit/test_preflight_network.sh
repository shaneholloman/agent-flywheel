#!/usr/bin/env bash
# ============================================================
# Unit tests for scripts/preflight.sh network health checks
#
# Tests DNS resolution, GitHub reachability, installer URLs,
# and APT mirror checks with simulated failures.
#
# Run with: bash tests/unit/test_preflight_network.sh
#
# Related beads:
#   - bd-31ps.7.3: Tests: preflight network health
# ============================================================

set -uo pipefail

# Get the absolute path to the scripts directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source the test harness
source "$REPO_ROOT/tests/vm/lib/test_harness.sh"

# Log file
LOG_FILE="/tmp/acfs_preflight_test_$(date +%Y%m%d_%H%M%S).log"

# Redirect all output to log file as well
exec > >(tee -a "$LOG_FILE") 2>&1

# ============================================================
# Test Helpers
# ============================================================

# Create a mock command in a temporary PATH
create_mock_command() {
    local cmd_name="$1"
    local exit_code="$2"
    local output="${3:-}"

    local mock_dir="/tmp/preflight_test_mocks_$$"
    mkdir -p "$mock_dir"

    cat > "$mock_dir/$cmd_name" <<EOF
#!/bin/bash
${output:+echo "$output"}
exit $exit_code
EOF
    chmod +x "$mock_dir/$cmd_name"

    echo "$mock_dir"
}

# Remove mock commands
cleanup_mocks() {
    rm -rf "/tmp/preflight_test_mocks_"* 2>/dev/null || true
}

# Run preflight.sh with modified PATH for mocking
# Usage: run_preflight_with_mocks [mock_dir] [args...]
# If no args provided, defaults to --json
# Use "none" for args to run without any arguments
run_preflight_with_mocks() {
    local mock_dir="${1:-}"
    shift || true
    local args=("$@")

    # Default to --json if no args provided
    if [[ ${#args[@]} -eq 0 ]]; then
        args=("--json")
    elif [[ "${args[0]}" == "none" ]]; then
        args=()
    fi

    if [[ -n "$mock_dir" ]]; then
        PATH="$mock_dir:$PATH" "$REPO_ROOT/scripts/preflight.sh" "${args[@]}" 2>&1
    else
        "$REPO_ROOT/scripts/preflight.sh" "${args[@]}" 2>&1
    fi
}

# Extract check result from JSON output
get_check_status() {
    local json="$1"
    local message_pattern="$2"

    echo "$json" | jq -r ".checks[] | select(.message | test(\"$message_pattern\")) | .status" 2>/dev/null | head -1
}

# ============================================================
# Test Cases
# ============================================================

test_preflight_passes_on_healthy_system() {
    harness_section "Test: Preflight passes on healthy system"

    local output
    output=$(run_preflight_with_mocks "" "--json")
    local exit_code=$?

    harness_assert_eq "0" "$exit_code" "Exit code should be 0 on healthy system"

    # Check that DNS check passed
    local dns_status
    dns_status=$(get_check_status "$output" "DNS:")
    if [[ "$dns_status" == "pass" ]]; then
        harness_pass "DNS check passed"
    else
        harness_fail "DNS check did not pass" "status: $dns_status"
    fi

    # Check that GitHub network check passed
    local github_status
    github_status=$(get_check_status "$output" "github.com reachable")
    if [[ "$github_status" == "pass" ]]; then
        harness_pass "GitHub reachability check passed"
    else
        harness_fail "GitHub reachability check did not pass" "status: $github_status"
    fi

    # Check that installer URLs check passed
    local installer_status
    installer_status=$(get_check_status "$output" "installer URLs")
    if [[ "$installer_status" == "pass" ]]; then
        harness_pass "Installer URLs check passed"
    else
        harness_fail "Installer URLs check did not pass" "status: $installer_status"
    fi

    # Capture output for debugging
    harness_capture_output "preflight_healthy_output" "$output"
}

test_preflight_json_output_valid() {
    harness_section "Test: Preflight JSON output is valid"

    local output
    output=$(run_preflight_with_mocks "" "--json")

    # Validate JSON structure
    if echo "$output" | jq -e '.errors >= 0 and .warnings >= 0 and .checks != null' >/dev/null 2>&1; then
        harness_pass "JSON output has valid structure"
    else
        harness_fail "JSON output has invalid structure"
        harness_capture_output "invalid_json" "$output"
        return 1
    fi

    # Check that checks array is not empty
    local check_count
    check_count=$(echo "$output" | jq '.checks | length')
    if [[ "$check_count" -gt 0 ]]; then
        harness_pass "JSON output has $check_count checks"
    else
        harness_fail "JSON output has no checks"
        return 1
    fi
}

test_preflight_cpu_check_present() {
    harness_section "Test: CPU check is present in output"

    local output
    output=$(run_preflight_with_mocks "" "--json")

    local cpu_status
    cpu_status=$(get_check_status "$output" "CPU:")

    if [[ -n "$cpu_status" ]]; then
        harness_pass "CPU check is present (status: $cpu_status)"
    else
        harness_fail "CPU check is missing from output"
        harness_capture_output "missing_cpu_check" "$output"
        return 1
    fi

    # Verify CPU message format includes core count
    local cpu_message
    cpu_message=$(echo "$output" | jq -r '.checks[] | select(.message | test("CPU:")) | .message')
    if [[ "$cpu_message" =~ [0-9]+\ core ]]; then
        harness_pass "CPU check shows core count: $cpu_message"
    else
        harness_fail "CPU check message format unexpected" "$cpu_message"
    fi
}

test_preflight_dns_check_present() {
    harness_section "Test: DNS check is present in output"

    local output
    output=$(run_preflight_with_mocks "" "--json")

    local dns_status
    dns_status=$(get_check_status "$output" "DNS:")

    if [[ -n "$dns_status" ]]; then
        harness_pass "DNS check is present (status: $dns_status)"
    else
        harness_fail "DNS check is missing from output"
        harness_capture_output "missing_dns_check" "$output"
        return 1
    fi
}

test_preflight_apt_mirror_check_present() {
    harness_section "Test: APT mirror check is present"

    # Only run on apt-based systems
    if ! command -v apt-get &>/dev/null; then
        harness_skip "APT mirror check" "Not an apt-based system"
        return 0
    fi

    local output
    output=$(run_preflight_with_mocks "" "--json")

    local apt_status
    apt_status=$(get_check_status "$output" "APT mirror")

    if [[ -n "$apt_status" ]]; then
        harness_pass "APT mirror check is present (status: $apt_status)"
    else
        harness_fail "APT mirror check is missing from output"
        harness_capture_output "missing_apt_check" "$output"
        return 1
    fi
}

test_preflight_text_output_format() {
    harness_section "Test: Preflight text output format"

    local output
    output=$(run_preflight_with_mocks "" none)

    # Strip ANSI escape codes for easier pattern matching (perl handles this better than sed)
    local stripped_output
    stripped_output=$(echo "$output" | perl -pe 's/\e\[[0-9;]*m//g')

    # Check for expected header
    if echo "$stripped_output" | grep -q "ACFS Pre-Flight Check"; then
        harness_pass "Text output has header"
    else
        harness_fail "Text output missing header"
    fi

    # Check for check marks or status indicators (after stripping ANSI)
    if echo "$stripped_output" | grep -qE '\[✓\]|\[!\]|\[✗\]'; then
        harness_pass "Text output has status indicators"
    else
        harness_fail "Text output missing status indicators"
    fi

    # Check for summary
    if echo "$stripped_output" | grep -qE 'Result:|error|warning'; then
        harness_pass "Text output has summary"
    else
        harness_fail "Text output missing summary"
    fi
}

test_preflight_quiet_mode() {
    harness_section "Test: Preflight quiet mode produces no output"

    local output
    output=$(run_preflight_with_mocks "" "--quiet")
    local exit_code=$?

    # Quiet mode should produce no output
    if [[ -z "$output" ]] || [[ "$output" =~ ^[[:space:]]*$ ]]; then
        harness_pass "Quiet mode produces no output"
    else
        harness_fail "Quiet mode produced unexpected output" "${output:0:100}..."
    fi

    harness_assert_eq "0" "$exit_code" "Quiet mode exit code should be 0 on healthy system"
}

test_preflight_root_resolves_target_home_for_disk_and_conflicts() {
    harness_section "Test: Root preflight uses resolved target home"

    if ! command -v sudo &>/dev/null || ! sudo -n true 2>/dev/null; then
        harness_skip "Root preflight target-home resolution" "passwordless sudo unavailable"
        return 0
    fi

    local temp_root=""
    temp_root="$(mktemp -d)"

    local mock_dir="$temp_root/mockbin"
    local root_home="$temp_root/root-home"
    local target_home="$temp_root/custom-home"
    local capture_file="$temp_root/df_args.txt"
    mkdir -p "$mock_dir" "$root_home" "$target_home/.acfs"
    cat > "$target_home/.acfs/state.json" <<'EOF'
{"target_user":"customuser"}
EOF

    cat > "$mock_dir/df" <<EOF
#!/usr/bin/env bash
echo "\$*" > "$capture_file"
printf 'Filesystem 1024-blocks Used Available Capacity Mounted on\nmock 100 0 41943040 0%% /srv\n'
EOF
    chmod +x "$mock_dir/df"

    cat > "$mock_dir/getent" <<EOF
#!/usr/bin/env bash
if [[ "\$1" == "passwd" ]] && [[ "\$2" == "customuser" ]]; then
    echo "customuser:x:1000:1000::$target_home:/bin/bash"
    exit 0
fi
exec /usr/bin/getent "\$@"
EOF
    chmod +x "$mock_dir/getent"

    local output=""
    local exit_code=0
    output=$(sudo -n env PATH="$mock_dir:/usr/bin:/bin" HOME="$root_home" TARGET_HOME="/" TARGET_USER=customuser \
        bash "$REPO_ROOT/scripts/preflight.sh" --json 2>&1) || exit_code=$?

    local df_args=""
    if [[ -f "$capture_file" ]]; then
        df_args="$(cat "$capture_file")"
    fi

    if [[ "$df_args" == *"$target_home"* ]]; then
        harness_pass "Disk check uses getent-resolved target home under root"
    else
        harness_fail "Disk check uses getent-resolved target home under root" "df args: $df_args"
    fi

    local acfs_status=""
    acfs_status=$(get_check_status "$output" "Existing ACFS installation")
    if [[ "$acfs_status" == "warn" ]]; then
        harness_pass "Conflict checks inspect the resolved target home under root"
    else
        harness_fail "Conflict checks inspect the resolved target home under root" "status: $acfs_status output: $output"
    fi

    if [[ "$exit_code" =~ ^[01]$ ]]; then
        harness_pass "Root preflight completed with a valid exit code"
    else
        harness_fail "Root preflight completed with a valid exit code" "exit: $exit_code"
    fi

    rm -rf "$temp_root"
}

test_dns_check_hosts() {
    harness_section "Test: DNS check tests expected hosts"

    # Parse the preflight.sh script to verify expected hosts are checked
    local expected_hosts=("github.com" "archive.ubuntu.com" "raw.githubusercontent.com")

    for host in "${expected_hosts[@]}"; do
        if grep -q "\"$host\"" "$REPO_ROOT/scripts/preflight.sh"; then
            harness_pass "DNS check includes $host"
        else
            harness_fail "DNS check missing $host"
        fi
    done
}

test_installer_urls_checked() {
    harness_section "Test: Installer URLs are checked"

    # Parse the preflight.sh script to verify expected URLs
    local expected_patterns=("bun.sh" "astral.sh" "rustup.rs" "githubusercontent.com")

    for pattern in "${expected_patterns[@]}"; do
        if grep -q "$pattern" "$REPO_ROOT/scripts/preflight.sh"; then
            harness_pass "Installer check includes $pattern"
        else
            harness_fail "Installer check missing $pattern"
        fi
    done
}

test_preflight_exit_code_on_warnings() {
    harness_section "Test: Preflight exit code is 0 with warnings only"

    # Run preflight - on a typical dev machine there may be warnings
    # but no critical failures
    local output
    output=$(run_preflight_with_mocks "" "--json")
    local exit_code=$?

    local errors
    errors=$(echo "$output" | jq '.errors // 0')

    if [[ "$errors" -eq 0 ]]; then
        harness_assert_eq "0" "$exit_code" "Exit code should be 0 when no errors"
    else
        harness_assert_eq "1" "$exit_code" "Exit code should be 1 when errors present"
    fi
}

test_preflight_nonroot_ignores_slash_home_override_for_disk_check() {
    harness_section "Test: Non-root preflight repairs slash HOME/TARGET_HOME"

    local temp_root=""
    temp_root="$(mktemp -d)"

    local mock_dir="$temp_root/mockbin"
    local resolved_home="$temp_root/current-home"
    local capture_file="$temp_root/df_args.txt"
    local current_user=""
    current_user="$(id -un)"
    mkdir -p "$mock_dir" "$resolved_home"

    cat > "$mock_dir/df" <<EOF
#!/usr/bin/env bash
echo "\$*" > "$capture_file"
printf 'Filesystem 1024-blocks Used Available Capacity Mounted on\nmock 100 0 41943040 0%% /srv\n'
EOF
    chmod +x "$mock_dir/df"

    cat > "$mock_dir/getent" <<EOF
#!/usr/bin/env bash
if [[ "\$1" == "passwd" ]] && [[ "\$2" == "$current_user" ]]; then
    echo "$current_user:x:1000:1000::$resolved_home:/bin/bash"
    exit 0
fi
exec /usr/bin/getent "\$@"
EOF
    chmod +x "$mock_dir/getent"

    local output=""
    local exit_code=0
    output=$(PATH="$mock_dir:/usr/bin:/bin" HOME="/" TARGET_HOME="/" \
        bash "$REPO_ROOT/scripts/preflight.sh" --json 2>&1) || exit_code=$?

    local df_args=""
    if [[ -f "$capture_file" ]]; then
        df_args="$(cat "$capture_file")"
    fi

    if [[ "$df_args" == *"$resolved_home"* ]]; then
        harness_pass "Disk check ignores slash HOME/TARGET_HOME for non-root runs"
    else
        harness_fail "Disk check ignores slash HOME/TARGET_HOME for non-root runs" "df args: $df_args output: $output"
    fi

    if [[ "$exit_code" =~ ^[01]$ ]]; then
        harness_pass "Non-root slash-home preflight completed with a valid exit code"
    else
        harness_fail "Non-root slash-home preflight completed with a valid exit code" "exit: $exit_code"
    fi
}

test_deb822_format_support() {
    harness_section "Test: DEB822 format support in APT mirror check"

    # Check that the preflight script handles DEB822 format
    if grep -q "URIs:" "$REPO_ROOT/scripts/preflight.sh" && \
       grep -q "\.sources" "$REPO_ROOT/scripts/preflight.sh"; then
        harness_pass "Script handles DEB822 format (.sources files)"
    else
        harness_fail "Script missing DEB822 format support"
    fi

    # Check for fallback to traditional format
    if grep -q "sources.list" "$REPO_ROOT/scripts/preflight.sh"; then
        harness_pass "Script handles traditional sources.list format"
    else
        harness_fail "Script missing traditional format support"
    fi
}

test_network_timeout_settings() {
    harness_section "Test: Network checks have reasonable timeouts"

    # Check that curl commands have timeout flags
    if grep -qE 'curl.*--max-time|curl.*-m ' "$REPO_ROOT/scripts/preflight.sh"; then
        harness_pass "Curl commands have max-time setting"
    else
        harness_fail "Curl commands missing timeout settings"
    fi

    if grep -qE 'curl.*--connect-timeout' "$REPO_ROOT/scripts/preflight.sh"; then
        harness_pass "Curl commands have connect-timeout setting"
    else
        harness_fail "Curl commands missing connect-timeout settings"
    fi
}

# ============================================================
# Main
# ============================================================

main() {
    harness_init "Preflight Network Health Tests"

    harness_info "Log file: $LOG_FILE"

    # Run tests
    test_preflight_passes_on_healthy_system
    test_preflight_json_output_valid
    test_preflight_cpu_check_present
    test_preflight_dns_check_present
    test_preflight_apt_mirror_check_present
    test_preflight_text_output_format
    test_preflight_quiet_mode
    test_preflight_root_resolves_target_home_for_disk_and_conflicts
    test_preflight_nonroot_ignores_slash_home_override_for_disk_check
    test_dns_check_hosts
    test_installer_urls_checked
    test_preflight_exit_code_on_warnings
    test_deb822_format_support
    test_network_timeout_settings

    # Cleanup
    cleanup_mocks

    # Summary
    harness_section "Test Summary"
    harness_info "Log written to: $LOG_FILE"

    harness_summary
}

main "$@"
