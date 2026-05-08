#!/usr/bin/env bash
# ============================================================
# ACFS Swarm Doctor - pre-swarm coordination preflight
#
# Consumes the local swarm status collector and turns it into a
# launch/no-launch decision with exact non-mutating remediation commands.
# ============================================================

set -euo pipefail

SWARM_DOCTOR_JSON=false
SWARM_DOCTOR_STATUS_FILE=""
SWARM_DOCTOR_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWARM_STATUS_SCRIPT="${ACFS_SWARM_STATUS_SCRIPT:-$SWARM_DOCTOR_SCRIPT_DIR/swarm_status.sh}"

swarm_doctor_usage() {
    cat <<'EOF'
Usage: acfs swarm doctor [OPTIONS]

Options:
  --json              Emit machine-readable JSON
  --status-file FILE  Read an existing swarm_status.json snapshot
  --help, -h          Show this help

Exit codes:
  0  Preflight passed
  1  Warnings should be reviewed before a large launch
  2  Hard blockers must be fixed before a large launch
EOF
}

swarm_doctor_parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json)
                SWARM_DOCTOR_JSON=true
                shift
                ;;
            --status-file)
                if [[ -z "${2:-}" || "$2" == -* ]]; then
                    echo "Error: --status-file requires a path" >&2
                    exit 2
                fi
                SWARM_DOCTOR_STATUS_FILE="$2"
                shift 2
                ;;
            --help|-h)
                swarm_doctor_usage
                exit 0
                ;;
            *)
                echo "Error: unknown option: $1" >&2
                echo "Run 'acfs swarm doctor --help' for usage." >&2
                exit 2
                ;;
        esac
    done
}

swarm_doctor_binary_path() {
    local name="${1:-}"
    local path_value=""

    [[ -n "$name" ]] || return 1
    case "$name" in
        .|..|*/*) return 1 ;;
    esac

    path_value="$(command -v "$name" 2>/dev/null || true)"
    [[ -n "$path_value" && -x "$path_value" ]] || return 1
    printf '%s\n' "$path_value"
}

swarm_doctor_collect_status_json() {
    if [[ -n "$SWARM_DOCTOR_STATUS_FILE" ]]; then
        if [[ ! -f "$SWARM_DOCTOR_STATUS_FILE" ]]; then
            echo "Error: status file not found: $SWARM_DOCTOR_STATUS_FILE" >&2
            return 2
        fi
        cat "$SWARM_DOCTOR_STATUS_FILE"
        return 0
    fi

    if [[ ! -f "$SWARM_STATUS_SCRIPT" ]]; then
        echo "Error: swarm_status.sh not found" >&2
        return 2
    fi

    bash "$SWARM_STATUS_SCRIPT" --json
}

swarm_doctor_jq_filter() {
    cat <<'JQ'
def n($v): if ($v == null) then 0 else $v end;
def b($v): $v == true;
def check($id; $status; $summary; $details; $commands):
  {
    id: $id,
    status: $status,
    summary: $summary,
    details: $details,
    commands: $commands
  };

. as $s
| ($s.probes.agent_mail // {}) as $am
| ($s.probes.beads // {}) as $beads
| ($s.probes.bv // {}) as $bv
| ($s.probes.rch // {}) as $rch
| ($s.probes.ntm // {}) as $ntm
| ($s.host // {}) as $host
| (n($host.mem_available_kb) / 1048576) as $mem_gib
| (n($host.disk_available_kb) / 1048576) as $disk_gib
| (n($host.cpu_count)) as $cpu_count
| (n($host.load_1m)) as $load_1m
| [
    check(
      "agent_mail";
      (if (b($am.available) | not) then "fail"
       elif ($am.healthy == false) then "fail"
       elif ($am.status == "pass") then "pass"
       else "warn" end);
      (if (b($am.available) | not) then "Agent Mail CLI is unavailable"
       elif ($am.healthy == false) then "Agent Mail health check is failing"
       elif ($am.status == "pass") then "Agent Mail health is usable"
       else "Agent Mail health is uncertain" end);
      ($am.warnings // []);
      ["mcp-agent-mail doctor check --json", "acfs swarm status --json"]
    ),
    check(
      "beads";
      (if (b($beads.available) | not) then "fail"
       elif ($beads.status == "pass") then "pass"
       else "fail" end);
      (if (b($beads.available) | not) then "br is unavailable"
       elif ($beads.status == "pass") then "Beads JSON commands are usable"
       else "Beads JSON commands failed or timed out" end);
      ($beads.warnings // []);
      ["br ready --json", "br list --status in_progress --json"]
    ),
    check(
      "bv";
      (if (b($bv.available) | not) then "fail"
       elif (b($bv.robot_ok)) then "pass"
       else "fail" end);
      (if (b($bv.available) | not) then "bv is unavailable"
       elif (b($bv.robot_ok)) then "bv robot mode is usable"
       else "bv robot mode failed or timed out" end);
      ($bv.warnings // []);
      ["bv --robot-next", "bv --robot-triage"]
    ),
    check(
      "rch";
      (if (b($rch.available) | not) then "fail"
       elif (b($rch.status_json_ok)) then "pass"
       else "fail" end);
      (if (b($rch.available) | not) then "RCH is unavailable for CPU-heavy build/test offload"
       elif (b($rch.status_json_ok)) then "RCH status JSON is usable"
       else "RCH status JSON failed or timed out" end);
      ($rch.warnings // []);
      ["rch status", "rch workers probe --all", "rch exec -- cargo test"]
    ),
    check(
      "ntm";
      (if (b($ntm.available) | not) then "fail"
       elif (b($ntm.robot_status_ok)) then "pass"
       elif (b($ntm.tmux_available)) then "warn"
       else "fail" end);
      (if (b($ntm.available) | not) then "NTM is unavailable"
       elif (b($ntm.robot_status_ok)) then "NTM robot status is usable"
       elif (b($ntm.tmux_available)) then "NTM robot status is uncertain, but tmux is available"
       else "NTM and tmux are unavailable" end);
      ($ntm.warnings // []);
      ["ntm --robot-status", "tmux list-sessions -F '#S #{session_windows}'"]
    ),
    check(
      "resource_pressure";
      (if ($mem_gib < 2 or $disk_gib < 10) then "fail"
       elif (($cpu_count > 0 and $load_1m > ($cpu_count * 1.5)) or $mem_gib < 8 or $disk_gib < 50) then "warn"
       else "pass" end);
      (if ($mem_gib < 2) then "Available memory is below 2 GiB"
       elif ($disk_gib < 10) then "Available disk is below 10 GiB"
       elif ($cpu_count > 0 and $load_1m > ($cpu_count * 1.5)) then "Load average is high for the CPU count"
       elif ($mem_gib < 8) then "Available memory is low for a large swarm"
       elif ($disk_gib < 50) then "Available disk is low for a large swarm"
       else "Local resource pressure is acceptable" end);
      ($host.warnings // []);
      ["acfs capacity --recommend-ntm", "acfs swarm status --json"]
    ),
    check(
      "active_work";
      (if n($beads.in_progress_count) > 0 then "warn" else "pass" end);
      (if n($beads.in_progress_count) > 0 then "There are active in-progress beads; inspect for stale work before launch" else "No in-progress Beads work reported" end);
      [];
      ["br list --status in_progress --json", "mcp-agent-mail fetch-inbox --limit 20"]
    )
  ] as $checks
| {
    schema_version: 1,
    generated_at: (now | todateiso8601),
    status:
      (if any($checks[]; .status == "fail") then "fail"
       elif any($checks[]; .status == "warn") then "warn"
       else "pass" end),
    exit_code:
      (if any($checks[]; .status == "fail") then 2
       elif any($checks[]; .status == "warn") then 1
       else 0 end),
    source_status: ($s.status // "unknown"),
    summary: {
      failed: ([$checks[] | select(.status == "fail")] | length),
      warnings: ([$checks[] | select(.status == "warn")] | length),
      passed: ([$checks[] | select(.status == "pass")] | length)
    },
    checks: $checks,
    next_commands: ([$checks[] | select(.status != "pass") | .commands[]] | unique)
  }
JQ
}

swarm_doctor_build_report() {
    local jq_bin=""
    local status_json=""

    jq_bin="$(swarm_doctor_binary_path jq 2>/dev/null || true)"
    if [[ -z "$jq_bin" ]]; then
        printf '{"schema_version":1,"status":"fail","exit_code":2,"summary":{"failed":1,"warnings":0,"passed":0},"checks":[{"id":"jq","status":"fail","summary":"jq is required for swarm doctor JSON evaluation","details":[],"commands":["sudo apt-get install -y jq"]}],"next_commands":["sudo apt-get install -y jq"]}\n'
        return 0
    fi

    status_json="$(swarm_doctor_collect_status_json)" || return $?
    printf '%s' "$status_json" | "$jq_bin" "$(swarm_doctor_jq_filter)"
}

swarm_doctor_emit_human() {
    local report="$1"
    local jq_bin="$2"

    echo "ACFS Swarm Doctor"
    echo "Status: $("${jq_bin}" -r '.status' <<<"$report")"
    echo ""
    echo "Checks:"
    "${jq_bin}" -r '.checks[] | "  \(.status | ascii_upcase): \(.id) - \(.summary)"' <<<"$report"

    if [[ "$("${jq_bin}" -r '.next_commands | length' <<<"$report")" != "0" ]]; then
        echo ""
        echo "Next commands:"
        "${jq_bin}" -r '.next_commands[] | "  " + .' <<<"$report"
    fi
}

swarm_doctor_main() {
    swarm_doctor_parse_args "$@"

    local report=""
    local jq_bin=""
    local exit_code=2
    local build_status=0

    set +e
    report="$(swarm_doctor_build_report)"
    build_status=$?
    set -e
    if [[ $build_status -ne 0 ]]; then
        return "$build_status"
    fi

    jq_bin="$(swarm_doctor_binary_path jq 2>/dev/null || true)"
    if [[ -z "$jq_bin" ]]; then
        printf '%s\n' "$report"
        return 2
    fi

    exit_code="$("$jq_bin" -r '.exit_code // 2' <<<"$report" 2>/dev/null || echo 2)"

    if [[ "$SWARM_DOCTOR_JSON" == true ]]; then
        printf '%s\n' "$report"
    else
        swarm_doctor_emit_human "$report" "$jq_bin"
    fi

    return "$exit_code"
}

swarm_doctor_main "$@"
