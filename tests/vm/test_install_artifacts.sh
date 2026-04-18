#!/usr/bin/env bash
# ============================================================
# Tests for install log and summary artifacts (bd-31ps.3.3)
#
# Validates that:
# - Install log file exists and contains expected content
# - Summary JSON exists and has valid schema
# - All required fields are present and parseable
#
# Usage:
#   bash tests/vm/test_install_artifacts.sh [--user USER] [--home HOME]
#   bash tests/vm/test_install_artifacts.sh --standalone  # Quick local test
#
# Exit codes:
#   0 = All tests passed
#   1 = One or more tests failed
# ============================================================

set -euo pipefail

# Test configuration
TESTS_PASSED=0
TESTS_FAILED=0
TARGET_USER="${1:-ubuntu}"
TARGET_HOME="${2:-}"

resolve_target_home() {
    local target_user="${1:-ubuntu}"
    local passwd_entry=""

    if [[ "$target_user" == "root" ]]; then
        printf '/root\n'
        return 0
    fi

    passwd_entry="$(getent passwd "$target_user" 2>/dev/null || true)"
    if [[ -n "$passwd_entry" ]]; then
        passwd_entry="$(printf '%s\n' "$passwd_entry" | cut -d: -f6)"
        if [[ -n "$passwd_entry" ]] && [[ "$passwd_entry" == /* ]]; then
            printf '%s\n' "$passwd_entry"
            return 0
        fi
    fi

    if [[ "$target_user" == "$(whoami 2>/dev/null || true)" ]] && [[ -n "${HOME:-}" ]] && [[ "${HOME}" == /* ]] && [[ "${HOME}" != "/" ]]; then
        printf '%s\n' "${HOME%/}"
        return 0
    fi

    return 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --user) TARGET_USER="$2"; shift 2 ;;
        --home) TARGET_HOME="$2"; shift 2 ;;
        --standalone)
            # For quick local testing without full install
            TARGET_HOME="${HOME}"
            shift
            ;;
        *) shift ;;
    esac
done

if [[ -z "${TARGET_HOME:-}" ]]; then
    TARGET_HOME="$(resolve_target_home "$TARGET_USER" 2>/dev/null || true)"
fi

if [[ -z "${TARGET_HOME:-}" ]] || [[ "${TARGET_HOME}" != /* ]] || [[ "${TARGET_HOME}" == "/" ]]; then
    echo "Error: unable to resolve TARGET_HOME for '$TARGET_USER'; pass --home explicitly" >&2
    exit 1
fi

TARGET_HOME="${TARGET_HOME%/}"
ACFS_LOGS_DIR="${TARGET_HOME}/.acfs/logs"

# Logging
LOG_FILE="/tmp/acfs_install_artifacts_test_$(date +%Y%m%d_%H%M%S).log"

log() {
    local msg
    msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$msg"
    echo "$msg" >> "$LOG_FILE"
}

test_pass() {
    ((TESTS_PASSED++))
    log "PASS: $1"
}

test_fail() {
    ((TESTS_FAILED++))
    log "FAIL: $1"
    [[ -n "${2:-}" ]] && log "  Reason: $2"
}

# ============================================================
# Test: Log file exists
# ============================================================
test_log_file_exists() {
    local log_files
    log_files=$(find "$ACFS_LOGS_DIR" -name 'install-*.log' -type f 2>/dev/null | head -1)

    if [[ -z "$log_files" ]]; then
        test_fail "log_file_exists" "No install log file found in $ACFS_LOGS_DIR"
        return 1
    fi

    test_pass "log_file_exists ($log_files)"
    echo "$log_files"  # Return path for subsequent tests
}

# ============================================================
# Test: Log file has content
# ============================================================
test_log_file_content() {
    local log_file="$1"

    if [[ ! -s "$log_file" ]]; then
        test_fail "log_file_content" "Log file is empty: $log_file"
        return 1
    fi

    # Check for expected header
    if ! grep -q "=== ACFS Install Log ===" "$log_file" 2>/dev/null; then
        test_fail "log_file_content" "Log file missing header: $log_file"
        return 1
    fi

    # Check for timestamp
    if ! grep -q "Started:" "$log_file" 2>/dev/null; then
        test_fail "log_file_content" "Log file missing Started timestamp: $log_file"
        return 1
    fi

    local line_count
    line_count=$(wc -l < "$log_file")
    if [[ $line_count -lt 10 ]]; then
        test_fail "log_file_content" "Log file suspiciously short ($line_count lines): $log_file"
        return 1
    fi

    test_pass "log_file_content ($line_count lines)"
}

# ============================================================
# Test: Summary JSON exists
# ============================================================
test_summary_json_exists() {
    local summary_files
    summary_files=$(find "$ACFS_LOGS_DIR" -name 'install_summary_*.json' -type f 2>/dev/null | head -1)

    if [[ -z "$summary_files" ]]; then
        test_fail "summary_json_exists" "No summary JSON file found in $ACFS_LOGS_DIR"
        return 1
    fi

    test_pass "summary_json_exists ($summary_files)"
    echo "$summary_files"  # Return path for subsequent tests
}

# ============================================================
# Test: Summary JSON is valid JSON
# ============================================================
test_summary_json_valid() {
    local summary_file="$1"

    if ! command -v jq &>/dev/null; then
        test_fail "summary_json_valid" "jq not installed, cannot validate JSON"
        return 1
    fi

    if ! jq . "$summary_file" >/dev/null 2>&1; then
        test_fail "summary_json_valid" "Invalid JSON in $summary_file"
        return 1
    fi

    test_pass "summary_json_valid"
}

# ============================================================
# Test: Summary JSON has required fields
# ============================================================
test_summary_json_schema() {
    local summary_file="$1"

    # Required top-level fields
    local required_fields=(
        "schema_version"
        "status"
        "timestamp"
        "total_seconds"
        "environment"
        "phases"
    )

    for field in "${required_fields[@]}"; do
        if ! jq -e ".$field" "$summary_file" >/dev/null 2>&1; then
            test_fail "summary_json_schema" "Missing required field: $field"
            return 1
        fi
    done

    # Check schema_version is a number
    local schema_version
    schema_version=$(jq -r '.schema_version' "$summary_file")
    if ! [[ "$schema_version" =~ ^[0-9]+$ ]]; then
        test_fail "summary_json_schema" "schema_version is not a number: $schema_version"
        return 1
    fi

    # Check status is valid
    local status
    status=$(jq -r '.status' "$summary_file")
    case "$status" in
        success|failure) ;;
        *)
            test_fail "summary_json_schema" "Invalid status value: $status"
            return 1
            ;;
    esac

    # Check timestamp is ISO-8601 format
    local timestamp
    timestamp=$(jq -r '.timestamp' "$summary_file")
    if ! [[ "$timestamp" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]; then
        test_fail "summary_json_schema" "Invalid timestamp format: $timestamp"
        return 1
    fi

    # Check total_seconds is a number
    local total_seconds
    total_seconds=$(jq -r '.total_seconds' "$summary_file")
    if ! [[ "$total_seconds" =~ ^[0-9]+$ ]]; then
        test_fail "summary_json_schema" "total_seconds is not a number: $total_seconds"
        return 1
    fi

    # Check phases is an array
    local phases_type
    phases_type=$(jq -r '.phases | type' "$summary_file")
    if [[ "$phases_type" != "array" ]]; then
        test_fail "summary_json_schema" "phases is not an array: $phases_type"
        return 1
    fi

    test_pass "summary_json_schema (schema_version=$schema_version, status=$status)"
}

# ============================================================
# Test: Summary JSON environment fields
# ============================================================
test_summary_json_environment() {
    local summary_file="$1"

    # Required environment fields
    local env_fields=(
        "acfs_version"
        "mode"
        "ubuntu_version"
        "target_user"
        "target_home"
    )

    for field in "${env_fields[@]}"; do
        if ! jq -e ".environment.$field" "$summary_file" >/dev/null 2>&1; then
            test_fail "summary_json_environment" "Missing environment field: $field"
            return 1
        fi

        local value
        value=$(jq -r ".environment.$field" "$summary_file")
        if [[ -z "$value" || "$value" == "null" ]]; then
            test_fail "summary_json_environment" "Empty environment field: $field"
            return 1
        fi
    done

    # Check mode is valid
    local mode
    mode=$(jq -r '.environment.mode' "$summary_file")
    case "$mode" in
        vibe|safe|unknown) ;;
        *)
            test_fail "summary_json_environment" "Invalid mode value: $mode"
            return 1
            ;;
    esac

    test_pass "summary_json_environment (mode=$mode)"
}

# ============================================================
# Test: Summary JSON phases array
# ============================================================
test_summary_json_phases() {
    local summary_file="$1"

    local phase_count
    phase_count=$(jq '.phases | length' "$summary_file")

    # For a successful install, we expect at least some phases
    local status
    status=$(jq -r '.status' "$summary_file")
    if [[ "$status" == "success" && "$phase_count" -eq 0 ]]; then
        test_fail "summary_json_phases" "Successful install should have completed phases"
        return 1
    fi

    # Validate each phase has an id
    local invalid_phases
    invalid_phases=$(jq '[.phases[] | select(.id == null or .id == "")] | length' "$summary_file")
    if [[ "$invalid_phases" -gt 0 ]]; then
        test_fail "summary_json_phases" "$invalid_phases phase(s) missing 'id' field"
        return 1
    fi

    test_pass "summary_json_phases ($phase_count phases)"
}

# ============================================================
# Test: Log file and summary cross-reference
# ============================================================
test_log_summary_cross_reference() {
    local summary_file="$1"

    # Check if log_file field exists and points to a real file
    local log_file_ref
    log_file_ref=$(jq -r '.log_file // empty' "$summary_file")

    if [[ -n "$log_file_ref" && "$log_file_ref" != "null" ]]; then
        if [[ -f "$log_file_ref" ]]; then
            test_pass "log_summary_cross_reference (log_file=$log_file_ref)"
        else
            test_fail "log_summary_cross_reference" "Referenced log file not found: $log_file_ref"
            return 1
        fi
    else
        # log_file is optional, just note it
        test_pass "log_summary_cross_reference (log_file not set, optional)"
    fi
}

# ============================================================
# Main
# ============================================================
main() {
    log "============================================================"
    log "ACFS Install Artifacts Test"
    log "============================================================"
    log "Target user: $TARGET_USER"
    log "Target home: $TARGET_HOME"
    log "Logs dir: $ACFS_LOGS_DIR"
    log "Test log: $LOG_FILE"
    log ""

    # Check if logs directory exists
    if [[ ! -d "$ACFS_LOGS_DIR" ]]; then
        log "ERROR: ACFS logs directory not found: $ACFS_LOGS_DIR"
        log "This may indicate ACFS was not installed or logging is disabled."
        exit 1
    fi

    # Run log file tests
    log "--- Log File Tests ---"
    local log_file
    log_file=$(test_log_file_exists) || true
    if [[ -n "$log_file" && -f "$log_file" ]]; then
        test_log_file_content "$log_file"
    fi

    log ""
    log "--- Summary JSON Tests ---"
    local summary_file
    summary_file=$(test_summary_json_exists) || true
    if [[ -n "$summary_file" && -f "$summary_file" ]]; then
        test_summary_json_valid "$summary_file"
        test_summary_json_schema "$summary_file"
        test_summary_json_environment "$summary_file"
        test_summary_json_phases "$summary_file"
        test_log_summary_cross_reference "$summary_file"
    fi

    # Summary
    log ""
    log "============================================================"
    log "Results: $TESTS_PASSED passed, $TESTS_FAILED failed"
    log "Log file: $LOG_FILE"
    log "============================================================"

    # Log paths for debugging
    if [[ $TESTS_FAILED -gt 0 ]]; then
        log ""
        log "Artifacts for debugging:"
        log "  Log file: ${log_file:-not found}"
        log "  Summary JSON: ${summary_file:-not found}"
    fi

    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    fi
    exit 0
}

main "$@"
