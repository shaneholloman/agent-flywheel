#!/usr/bin/env bash
# ============================================================
# Unit tests for acfs swarm doctor preflight
# ============================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SWARM_DOCTOR_SH="$REPO_ROOT/scripts/lib/swarm_doctor.sh"

TESTS_PASSED=0
TESTS_FAILED=0
ARTIFACT_DIR="${ACFS_SWARM_DOCTOR_TEST_ARTIFACTS_DIR:-${TMPDIR:-/tmp}/acfs-swarm-doctor-test-artifacts-$(date +%Y%m%d-%H%M%S)-$$}"

mkdir -p "$ARTIFACT_DIR"

pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "PASS: $1"
}

fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "FAIL: $1"
    [[ -n "${2:-}" ]] && echo "  Reason: $2"
}

write_fixture() {
    local name="$1"
    local path="$ARTIFACT_DIR/$name.json"
    cat > "$path"
    printf '%s\n' "$path"
}

run_doctor_json() {
    local name="$1"
    local fixture="$2"
    local output status

    set +e
    output="$(bash "$SWARM_DOCTOR_SH" --json --status-file "$fixture" 2>&1)"
    status=$?
    set -e

    printf '%s\n' "$output" > "$ARTIFACT_DIR/$name.output.json"
    printf '%s\n' "$status" > "$ARTIFACT_DIR/$name.exit"
    printf '%s\n' "$output"
}

test_pass_fixture_exits_zero() {
    local fixture output status
    fixture="$(write_fixture pass_fixture <<'JSON'
{
  "schema_version": 1,
  "status": "pass",
  "host": {"status": "pass", "cpu_count": 64, "load_1m": 8, "mem_available_kb": 134217728, "disk_available_kb": 209715200, "warnings": []},
  "probes": {
    "agent_mail": {"status": "pass", "available": true, "healthy": true, "warnings": []},
    "beads": {"status": "pass", "available": true, "ready_count": 3, "in_progress_count": 0, "open_count": 7, "warnings": []},
    "bv": {"status": "pass", "available": true, "robot_ok": true, "warnings": []},
    "rch": {"status": "pass", "available": true, "status_json_ok": true, "warnings": []},
    "ntm": {"status": "pass", "available": true, "robot_status_ok": true, "tmux_available": true, "tmux_session_count": 2, "tmux_window_count": 8, "warnings": []}
  }
}
JSON
)"
    output="$(run_doctor_json pass_fixture "$fixture")"
    status="$(cat "$ARTIFACT_DIR/pass_fixture.exit")"

    [[ "$status" -eq 0 ]] || return 1
    jq -e '.status == "pass" and .summary.failed == 0 and (.checks | length) == 7' <<<"$output" >/dev/null || return 1

    pass "pass_fixture_exits_zero"
}

test_missing_required_tools_fail() {
    local fixture output status
    fixture="$(write_fixture missing_tools <<'JSON'
{
  "schema_version": 1,
  "status": "warn",
  "host": {"status": "pass", "cpu_count": 8, "load_1m": 1, "mem_available_kb": 33554432, "disk_available_kb": 104857600, "warnings": []},
  "probes": {
    "agent_mail": {"status": "warn", "available": false, "healthy": null, "warnings": ["Agent Mail CLI not found in PATH"]},
    "beads": {"status": "warn", "available": false, "ready_count": null, "in_progress_count": null, "open_count": null, "warnings": ["br not found in PATH"]},
    "bv": {"status": "warn", "available": false, "robot_ok": false, "warnings": ["bv not found in PATH"]},
    "rch": {"status": "warn", "available": false, "status_json_ok": false, "warnings": ["rch not found in PATH"]},
    "ntm": {"status": "warn", "available": false, "robot_status_ok": false, "tmux_available": false, "tmux_session_count": null, "tmux_window_count": null, "warnings": ["ntm not found in PATH"]}
  }
}
JSON
)"
    output="$(run_doctor_json missing_tools "$fixture")"
    status="$(cat "$ARTIFACT_DIR/missing_tools.exit")"

    [[ "$status" -eq 2 ]] || return 1
    jq -e '
      .status == "fail" and
      .summary.failed >= 5 and
      (.next_commands[] | select(. == "bv --robot-next")) and
      (.next_commands[] | select(. == "rch status"))
    ' <<<"$output" >/dev/null || return 1

    pass "missing_required_tools_fail"
}

test_partial_state_warns() {
    local fixture output status
    fixture="$(write_fixture partial_state <<'JSON'
{
  "schema_version": 1,
  "status": "warn",
  "host": {"status": "pass", "cpu_count": 16, "load_1m": 4, "mem_available_kb": 6291456, "disk_available_kb": 62914560, "warnings": []},
  "probes": {
    "agent_mail": {"status": "pass", "available": true, "healthy": true, "warnings": []},
    "beads": {"status": "pass", "available": true, "ready_count": 4, "in_progress_count": 2, "open_count": 11, "warnings": []},
    "bv": {"status": "pass", "available": true, "robot_ok": true, "warnings": []},
    "rch": {"status": "pass", "available": true, "status_json_ok": true, "warnings": []},
    "ntm": {"status": "warn", "available": true, "robot_status_ok": false, "tmux_available": true, "tmux_session_count": 1, "tmux_window_count": 4, "warnings": ["ntm --robot-status failed or timed out"]}
  }
}
JSON
)"
    output="$(run_doctor_json partial_state "$fixture")"
    status="$(cat "$ARTIFACT_DIR/partial_state.exit")"

    [[ "$status" -eq 1 ]] || return 1
    jq -e '
      .status == "warn" and
      (.checks[] | select(.id == "ntm" and .status == "warn")) and
      (.checks[] | select(.id == "active_work" and .status == "warn")) and
      (.next_commands[] | select(. == "br list --status in_progress --json"))
    ' <<<"$output" >/dev/null || return 1

    pass "partial_state_warns"
}

test_human_output_lists_next_commands() {
    local fixture output status
    fixture="$(write_fixture human_fail <<'JSON'
{
  "schema_version": 1,
  "status": "warn",
  "host": {"status": "pass", "cpu_count": 8, "load_1m": 1, "mem_available_kb": 33554432, "disk_available_kb": 104857600, "warnings": []},
  "probes": {
    "agent_mail": {"status": "warn", "available": false, "healthy": null, "warnings": []},
    "beads": {"status": "pass", "available": true, "ready_count": 1, "in_progress_count": 0, "open_count": 2, "warnings": []},
    "bv": {"status": "pass", "available": true, "robot_ok": true, "warnings": []},
    "rch": {"status": "pass", "available": true, "status_json_ok": true, "warnings": []},
    "ntm": {"status": "pass", "available": true, "robot_status_ok": true, "tmux_available": true, "warnings": []}
  }
}
JSON
)"

    set +e
    output="$(bash "$SWARM_DOCTOR_SH" --status-file "$fixture" 2>&1)"
    status=$?
    set -e
    printf '%s\n' "$output" > "$ARTIFACT_DIR/human_fail.output.txt"

    [[ "$status" -eq 2 ]] || return 1
    grep -Fq "ACFS Swarm Doctor" <<<"$output" || return 1
    grep -Fq "Next commands:" <<<"$output" || return 1
    grep -Fq "mcp-agent-mail doctor check --json" <<<"$output" || return 1

    pass "human_output_lists_next_commands"
}

run_test() {
    local name="$1"
    if "$name"; then
        return 0
    fi
    fail "$name"
}

main() {
    command -v jq >/dev/null 2>&1 || {
        echo "jq is required for swarm doctor tests" >&2
        exit 1
    }

    run_test test_pass_fixture_exits_zero
    run_test test_missing_required_tools_fail
    run_test test_partial_state_warns
    run_test test_human_output_lists_next_commands

    echo "Results: $TESTS_PASSED passed, $TESTS_FAILED failed"
    echo "Artifacts: $ARTIFACT_DIR"
    [[ $TESTS_FAILED -eq 0 ]]
}

main "$@"
