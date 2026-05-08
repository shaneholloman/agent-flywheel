#!/usr/bin/env bash
# ============================================================
# Unit tests for acfs swarm inventory
# ============================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SWARM_INV_SH="$REPO_ROOT/scripts/lib/swarm_inventory.sh"

TESTS_PASSED=0
TESTS_FAILED=0
ARTIFACT_DIR="${ACFS_SWARM_INV_TEST_ARTIFACTS_DIR:-${TMPDIR:-/tmp}/acfs-swarm-inventory-test-artifacts-$(date +%Y%m%d-%H%M%S)-$$}"

mkdir -p "$ARTIFACT_DIR"

pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "PASS: $1"
}

fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "FAIL: $1"
    [[ -n "${2:-}" ]] && echo "  Reason: $2"
    return 0
}

write_fixture() {
    local name="$1"
    local path="$ARTIFACT_DIR/$name.json"
    cat > "$path"
    printf '%s\n' "$path"
}

sample_inventory_fixture() {
    write_fixture sample_inventory <<'JSON'
{
  "schema_version": 1,
  "updated_at": "2026-05-08T00:00:00Z",
  "defaults": {
    "workload": "standard",
    "stale_after_hours": 24,
    "support_bundle_detail": "redacted"
  },
  "fleet_note": "benign unknown top-level field",
  "hosts": [
    {
      "id": "local",
      "display_name": "Local ACFS host",
      "role": "swarm-controller",
      "status": "active",
      "manual_tags": ["primary", "ntm"],
      "last_probe_at": "2099-01-01T00:00:00Z",
      "probe_source": "manual",
      "resources": {"cpu_count": 64, "mem_total_mib": 262144, "disk_available_mib": 524288},
      "capacity": {"workload": "standard", "recommended_agents": 25, "safe_agents": 44, "source": "acfs capacity --json --recommend-ntm"},
      "rch": {"worker": false, "controller": true, "workers_total": 8, "workers_healthy": 8},
      "ntm": {"can_launch": true, "preferred_labels": ["swarm-25"]},
      "ru": {"can_sync_repos": true},
      "notes": "operator note",
      "rack": "a1"
    },
    {
      "id": "rch-worker-a",
      "display_name": "RCH worker A",
      "role": "rch-worker",
      "status": "active",
      "last_probe_at": "2099-01-01T00:00:00Z",
      "resources": {"cpu_count": 32, "mem_total_mib": 131072, "disk_available_mib": 262144},
      "capacity": {"workload": "heavy", "recommended_agents": 0, "safe_agents": 0, "source": "reserved for RCH"},
      "rch": {"worker": true, "controller": false, "slots_total": 12, "slots_available": 10},
      "ntm": {"can_launch": false, "preferred_labels": []},
      "ru": {"can_sync_repos": false}
    },
    {
      "id": "disabled-staging",
      "display_name": "Disabled staging host",
      "role": "disabled",
      "status": "disabled",
      "last_probe_at": null,
      "resources": {},
      "capacity": {"recommended_agents": 20, "safe_agents": 30},
      "rch": {},
      "ntm": {"can_launch": false},
      "ru": {"can_sync_repos": false}
    }
  ]
}
JSON
}

empty_inventory_fixture() {
    write_fixture empty_inventory <<'JSON'
{
  "schema_version": 1,
  "updated_at": "2026-05-08T00:00:00Z",
  "defaults": {"workload": "standard", "stale_after_hours": 24},
  "hosts": []
}
JSON
}

sensitive_inventory_fixture() {
    write_fixture sensitive_inventory <<'JSON'
{
  "schema_version": 1,
  "updated_at": "2026-05-08T00:00:00Z",
  "defaults": {"workload": "standard", "stale_after_hours": 24},
  "hosts": [
    {
      "id": "local",
      "hostname": "secret.internal",
      "role": "swarm-controller",
      "status": "active",
      "last_probe_at": null,
      "resources": {},
      "capacity": {},
      "rch": {},
      "ntm": {},
      "ru": {}
    }
  ]
}
JSON
}

duplicate_inventory_fixture() {
    write_fixture duplicate_inventory <<'JSON'
{
  "schema_version": 1,
  "updated_at": "2026-05-08T00:00:00Z",
  "defaults": {"workload": "standard", "stale_after_hours": 24},
  "hosts": [
    {"id":"local","role":"swarm-controller","status":"active","last_probe_at":null,"resources":{},"capacity":{},"rch":{},"ntm":{},"ru":{}},
    {"id":"local","role":"swarm-worker","status":"active","last_probe_at":null,"resources":{},"capacity":{},"rch":{},"ntm":{},"ru":{}}
  ]
}
JSON
}

run_inventory_json() {
    local name="$1"
    shift
    local output status

    set +e
    output="$(bash "$SWARM_INV_SH" --json "$@" 2>&1)"
    status=$?
    set -e

    printf '%s\n' "$output" > "$ARTIFACT_DIR/$name.output.json"
    printf '%s\n' "$status" > "$ARTIFACT_DIR/$name.exit"
    printf '%s\n' "$output"
}

test_report_summarizes_launch_targets() {
    local inventory output
    inventory="$(sample_inventory_fixture)"
    output="$(run_inventory_json report report --inventory "$inventory")"
    [[ "$(cat "$ARTIFACT_DIR/report.exit")" -eq 0 ]] || return 1

    jq -e '
      .status == "pass" and
      .summary.hosts_total == 3 and
      .summary.active == 2 and
      .summary.disabled == 1 and
      .summary.rch_workers == 1 and
      .summary.recommended_agents_total == 25 and
      .summary.safe_agents_total == 44 and
      .summary.unknown_field_count == 2 and
      (.recommended_launch_targets | length == 1) and
      .recommended_launch_targets[0].id == "local"
    ' <<< "$output" >/dev/null || return 1

    pass "report_summarizes_launch_targets"
}

test_empty_inventory_warns_without_failing_validation() {
    local inventory output
    inventory="$(empty_inventory_fixture)"
    output="$(run_inventory_json empty report --inventory "$inventory")"
    [[ "$(cat "$ARTIFACT_DIR/empty.exit")" -eq 1 ]] || return 1

    jq -e '
      .status == "warn" and
      .summary.hosts_total == 0 and
      (.warnings[0] | contains("inventory has no hosts")) and
      (.next_commands | index("acfs swarm inventory import --input hosts.inventory.json"))
    ' <<< "$output" >/dev/null || return 1

    pass "empty_inventory_warns_without_failing_validation"
}

test_import_export_preserve_unknown_fields() {
    local inventory imported exported output
    inventory="$(sample_inventory_fixture)"
    imported="$ARTIFACT_DIR/imported/hosts.inventory.json"
    exported="$ARTIFACT_DIR/exported.inventory.json"

    output="$(run_inventory_json import import --input "$inventory" --output "$imported")"
    [[ "$(cat "$ARTIFACT_DIR/import.exit")" -eq 0 ]] || return 1
    jq -e '.status == "pass" and .summary.imported_hosts == 3 and .summary.unknown_field_count == 2' <<< "$output" >/dev/null || return 1
    jq -e '.fleet_note == "benign unknown top-level field" and .hosts[0].rack == "a1"' "$imported" >/dev/null || return 1

    output="$(run_inventory_json export export --inventory "$imported" --output "$exported")"
    [[ "$(cat "$ARTIFACT_DIR/export.exit")" -eq 0 ]] || return 1
    jq -e '.status == "pass" and .summary.exported_hosts == 3 and .summary.unknown_field_count == 2' <<< "$output" >/dev/null || return 1
    jq -e '.fleet_note == "benign unknown top-level field" and .hosts[0].rack == "a1"' "$exported" >/dev/null || return 1

    pass "import_export_preserve_unknown_fields"
}

test_validate_rejects_sensitive_fields() {
    local inventory output
    inventory="$(sensitive_inventory_fixture)"
    output="$(run_inventory_json sensitive validate --inventory "$inventory")"
    [[ "$(cat "$ARTIFACT_DIR/sensitive.exit")" -eq 2 ]] || return 1

    jq -e '
      .status == "fail" and
      (.errors[] | select(.code == "forbidden_sensitive_field" and .path == "hosts[0].hostname")) and
      (.forbidden_sensitive_field_paths | index("hosts[0].hostname"))
    ' <<< "$output" >/dev/null || return 1

    pass "validate_rejects_sensitive_fields"
}

test_duplicate_ids_write_validate_artifacts() {
    local inventory artifact_dir output
    inventory="$(duplicate_inventory_fixture)"
    artifact_dir="$ARTIFACT_DIR/duplicate-artifacts"
    output="$(run_inventory_json duplicate validate --inventory "$inventory" --artifact-dir "$artifact_dir")"
    [[ "$(cat "$ARTIFACT_DIR/duplicate.exit")" -eq 2 ]] || return 1

    jq -e '.status == "fail" and (.errors[] | select(.code == "duplicate_host_id"))' <<< "$output" >/dev/null || return 1
    [[ -f "$artifact_dir/swarm_inventory.validate.error.json" ]] || return 1
    [[ -f "$artifact_dir/swarm_inventory.validate.log" ]] || return 1
    jq -e '.error_code == "duplicate_host_id"' "$artifact_dir/swarm_inventory.validate.error.json" >/dev/null || return 1

    pass "duplicate_ids_write_validate_artifacts"
}

test_malformed_report_writes_error_artifacts() {
    local inventory artifact_dir output
    inventory="$ARTIFACT_DIR/malformed.json"
    artifact_dir="$ARTIFACT_DIR/malformed-artifacts"
    printf '{not valid json\n' > "$inventory"

    output="$(run_inventory_json malformed report --inventory "$inventory" --artifact-dir "$artifact_dir")"
    [[ "$(cat "$ARTIFACT_DIR/malformed.exit")" -eq 2 ]] || return 1
    jq -e '.status == "fail" and .error_code == "malformed_json"' <<< "$output" >/dev/null || return 1
    [[ -f "$artifact_dir/swarm_inventory.report.error.json" ]] || return 1
    [[ -f "$artifact_dir/swarm_inventory.report.log" ]] || return 1

    pass "malformed_report_writes_error_artifacts"
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
        echo "jq is required for swarm inventory tests" >&2
        exit 1
    }

    run_test test_report_summarizes_launch_targets
    run_test test_empty_inventory_warns_without_failing_validation
    run_test test_import_export_preserve_unknown_fields
    run_test test_validate_rejects_sensitive_fields
    run_test test_duplicate_ids_write_validate_artifacts
    run_test test_malformed_report_writes_error_artifacts

    echo "Results: $TESTS_PASSED passed, $TESTS_FAILED failed"
    echo "Artifacts: $ARTIFACT_DIR"
    [[ $TESTS_FAILED -eq 0 ]]
}

main "$@"
