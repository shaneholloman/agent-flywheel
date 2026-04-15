#!/usr/bin/env bash
# shellcheck disable=SC1091
# ============================================================
# ACFS Status - One-line health summary
# Quick check: runs in <100ms, no network calls by default
#
# Exit codes:
#   0 - Healthy (all core tools present, state valid)
#   1 - Warnings (some optional tools missing, outdated state)
#   2 - Errors (broken state, missing critical tools)
#
# Usage:
#   acfs status                # Human-readable one-liner
#   acfs status --json         # Machine-readable JSON
#   acfs status --short        # Minimal output for shell prompts
#   acfs status --check-updates  # Include network-based update check
# ============================================================

# --- Defaults ---
_STATUS_JSON=false
_STATUS_SHORT=false
_STATUS_CHECK_UPDATES=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_status_sanitize_abs_nonroot_path() {
    local path_value="${1:-}"

    [[ -n "$path_value" ]] || return 1
    path_value="${path_value%/}"
    [[ -n "$path_value" ]] || return 1
    [[ "$path_value" == /* ]] || return 1
    [[ "$path_value" != "/" ]] || return 1
    printf '%s\n' "$path_value"
}

_status_resolve_current_home() {
    local current_user=""
    local home_candidate=""
    local passwd_entry=""

    home_candidate="$(_status_sanitize_abs_nonroot_path "${HOME:-}" 2>/dev/null || true)"
    if [[ -n "$home_candidate" ]]; then
        printf '%s\n' "$home_candidate"
        return 0
    fi

    current_user="$(id -un 2>/dev/null || whoami 2>/dev/null || true)"
    if [[ "$current_user" == "root" ]]; then
        printf '/root\n'
        return 0
    fi

    if [[ -n "$current_user" ]] && command -v getent &>/dev/null; then
        passwd_entry="$(getent passwd "$current_user" 2>/dev/null || true)"
        if [[ -n "$passwd_entry" ]]; then
            home_candidate="$(_status_sanitize_abs_nonroot_path "$(printf '%s\n' "$passwd_entry" | cut -d: -f6)" 2>/dev/null || true)"
            if [[ -n "$home_candidate" ]]; then
                printf '%s\n' "$home_candidate"
                return 0
            fi
        fi
    fi

    if [[ "$current_user" =~ ^[a-z_][a-z0-9._-]*$ ]]; then
        printf '/home/%s\n' "$current_user"
        return 0
    fi

    return 1
}

_STATUS_CURRENT_HOME="$(_status_resolve_current_home 2>/dev/null || true)"
if [[ -n "$_STATUS_CURRENT_HOME" ]]; then
    HOME="$_STATUS_CURRENT_HOME"
    export HOME
fi

_STATUS_EXPLICIT_ACFS_HOME="$(_status_sanitize_abs_nonroot_path "${ACFS_HOME:-}" 2>/dev/null || true)"
_STATUS_DEFAULT_ACFS_HOME=""
[[ -n "$_STATUS_CURRENT_HOME" ]] && _STATUS_DEFAULT_ACFS_HOME="${_STATUS_CURRENT_HOME}/.acfs"
_ACFS_HOME="${_STATUS_EXPLICIT_ACFS_HOME:-$_STATUS_DEFAULT_ACFS_HOME}"
_STATUS_SYSTEM_STATE_FILE="$(_status_sanitize_abs_nonroot_path "${ACFS_SYSTEM_STATE_FILE:-/var/lib/acfs/state.json}" 2>/dev/null || true)"
if [[ -z "$_STATUS_SYSTEM_STATE_FILE" ]]; then
    _STATUS_SYSTEM_STATE_FILE="/var/lib/acfs/state.json"
fi
_STATUS_RESOLVED_ACFS_HOME=""

# --- Parse args ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --json)           _STATUS_JSON=true; shift ;;
        --short)          _STATUS_SHORT=true; shift ;;
        --check-updates)  _STATUS_CHECK_UPDATES=true; shift ;;
        --help|-h)
            echo "Usage: acfs status [--json] [--short] [--check-updates]"
            echo ""
            echo "Quick one-line health summary."
            echo ""
            echo "Options:"
            echo "  --json            Machine-readable JSON output"
            echo "  --short           Minimal output for shell prompt integration"
            echo "  --check-updates   Include network-based update checks (slower)"
            echo ""
            echo "Exit codes:"
            echo "  0  Healthy"
            echo "  1  Warnings (outdated, minor issues)"
            echo "  2  Errors (broken state, missing critical tools)"
            echo ""
            echo "Examples:"
            echo "  acfs status                     # Quick health check"
            echo "  acfs status --json              # JSON for scripts"
            echo "  acfs status --short             # For shell prompts"
            echo "  acfs status --check-updates     # Check for ACFS updates"
            echo ""
            echo "Shell prompt integration:"
            echo "  PROMPT='\$(acfs status --short 2>/dev/null) \w \$ '"
            exit 0
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            echo "Try 'acfs status --help' for usage." >&2
            exit 1
            ;;
    esac
done

_status_prepend_user_paths() {
    local base_home="$1"
    local dir=""
    local primary_bin_dir="${ACFS_BIN_DIR:-$base_home/.local/bin}"

    [[ -n "$base_home" ]] || return 0

    for dir in \
        "$primary_bin_dir" \
        "$base_home/.local/bin" \
        "$base_home/.acfs/bin" \
        "$base_home/.bun/bin" \
        "$base_home/.cargo/bin" \
        "$base_home/go/bin" \
        "$base_home/.atuin/bin"; do
        case ":$PATH:" in
            *":$dir:"*) ;;
            *) export PATH="$dir:$PATH" ;;
        esac
    done
}

_status_ensure_path() {
    _status_prepend_user_paths "$_STATUS_CURRENT_HOME"

    if [[ -n "${TARGET_HOME:-}" ]] && [[ "$TARGET_HOME" != "$_STATUS_CURRENT_HOME" ]]; then
        _status_prepend_user_paths "$TARGET_HOME"
    fi
}

_status_home_for_user() {
    local user="$1"
    local passwd_entry=""
    local home_candidate=""

    [[ -n "$user" ]] || return 1

    if command -v getent &>/dev/null; then
        passwd_entry=$(getent passwd "$user" 2>/dev/null || true)
        if [[ -n "$passwd_entry" ]]; then
            home_candidate="$(_status_sanitize_abs_nonroot_path "$(printf '%s\n' "$passwd_entry" | cut -d: -f6)" 2>/dev/null || true)"
            if [[ -n "$home_candidate" ]]; then
                printf '%s\n' "$home_candidate"
                return 0
            fi
        fi
    fi

    if [[ "$user" == "root" ]]; then
        echo "/root"
        return 0
    fi

    if [[ "$user" =~ ^[a-z_][a-z0-9._-]*$ ]]; then
        echo "/home/$user"
        return 0
    fi

    return 1
}

_status_read_state_string() {
    local state_file="$1"
    local key="$2"
    local value=""

    [[ -f "$state_file" ]] || return 1

    if command -v jq &>/dev/null; then
        value=$(jq -r --arg key "$key" '.[$key] // empty' "$state_file" 2>/dev/null || true)
    else
        value=$(sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" "$state_file" 2>/dev/null | head -n 1)
    fi

    [[ -n "$value" ]] && [[ "$value" != "null" ]] || return 1
    printf '%s\n' "$value"
}

_status_read_target_user_from_state() {
    local state_file="$1"
    _status_read_state_string "$state_file" "target_user"
}

_status_read_target_home_from_state() {
    local state_file="$1"
    local target_home=""

    target_home="$(_status_read_state_string "$state_file" "target_home" 2>/dev/null || true)"
    [[ -n "$target_home" ]] || return 1
    [[ "$target_home" == /* ]] || return 1
    [[ "$target_home" != "/" ]] || return 1
    printf '%s\n' "${target_home%/}"
}

_status_resolve_target_home() {
    local state_file="${1:-}"
    local target_home=""

    target_home=$(_status_read_target_home_from_state "$_STATUS_SYSTEM_STATE_FILE" 2>/dev/null || true)
    if [[ -z "$target_home" ]] && [[ -n "$state_file" ]]; then
        target_home=$(_status_read_target_home_from_state "$state_file" 2>/dev/null || true)
    fi

    [[ -n "$target_home" ]] || return 1
    printf '%s\n' "$target_home"
}

_status_script_acfs_home() {
    local candidate=""
    candidate=$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd) || return 1
    [[ "$(basename "$candidate")" == ".acfs" ]] || return 1
    printf '%s\n' "$candidate"
}

_status_resolve_acfs_home() {
    if [[ -n "$_STATUS_RESOLVED_ACFS_HOME" ]]; then
        printf '%s\n' "$_STATUS_RESOLVED_ACFS_HOME"
        return 0
    fi

    local candidate=""
    local target_home=""
    local target_user=""

    if [[ -n "$_STATUS_EXPLICIT_ACFS_HOME" ]]; then
        _STATUS_RESOLVED_ACFS_HOME="$_STATUS_EXPLICIT_ACFS_HOME"
        printf '%s\n' "$_STATUS_RESOLVED_ACFS_HOME"
        return 0
    fi

    candidate=$(_status_script_acfs_home 2>/dev/null || true)
    if [[ -n "$candidate" ]] && [[ -f "$candidate/state.json" || -f "$candidate/VERSION" || -d "$candidate/onboard" ]]; then
        _STATUS_RESOLVED_ACFS_HOME="$candidate"
        printf '%s\n' "$_STATUS_RESOLVED_ACFS_HOME"
        return 0
    fi

    if [[ -n "${SUDO_USER:-}" ]]; then
        target_home=$(_status_home_for_user "$SUDO_USER" 2>/dev/null || true)
        candidate="${target_home}/.acfs"
        if [[ -n "$target_home" ]] && [[ -f "$candidate/state.json" || -f "$candidate/VERSION" || -d "$candidate/onboard" ]]; then
            _STATUS_RESOLVED_ACFS_HOME="$candidate"
            printf '%s\n' "$_STATUS_RESOLVED_ACFS_HOME"
            return 0
        fi
    fi

    target_home=$(_status_read_target_home_from_state "$_STATUS_SYSTEM_STATE_FILE" 2>/dev/null || true)
    if [[ -n "$target_home" ]]; then
        candidate="${target_home}/.acfs"
        if [[ -f "$candidate/state.json" || -f "$candidate/VERSION" || -d "$candidate/onboard" ]]; then
            _STATUS_RESOLVED_ACFS_HOME="$candidate"
            printf '%s\n' "$_STATUS_RESOLVED_ACFS_HOME"
            return 0
        fi
    fi

    target_user=$(_status_read_target_user_from_state "$_STATUS_SYSTEM_STATE_FILE" 2>/dev/null || true)
    if [[ -n "$target_user" ]]; then
        target_home=$(_status_home_for_user "$target_user" 2>/dev/null || true)
        candidate="${target_home}/.acfs"
        if [[ -n "$target_home" ]] && [[ -f "$candidate/state.json" || -f "$candidate/VERSION" || -d "$candidate/onboard" ]]; then
            _STATUS_RESOLVED_ACFS_HOME="$candidate"
            printf '%s\n' "$_STATUS_RESOLVED_ACFS_HOME"
            return 0
        fi
    fi

    if [[ -n "$_ACFS_HOME" ]] && [[ -f "$_ACFS_HOME/state.json" || -f "$_ACFS_HOME/VERSION" || -d "$_ACFS_HOME/onboard" ]]; then
        _STATUS_RESOLVED_ACFS_HOME="$_ACFS_HOME"
        printf '%s\n' "$_STATUS_RESOLVED_ACFS_HOME"
        return 0
    fi

    _STATUS_RESOLVED_ACFS_HOME="$_ACFS_HOME"
    printf '%s\n' "$_STATUS_RESOLVED_ACFS_HOME"
}

_status_resolve_state_file() {
    local candidate=""

    if [[ -n "$_ACFS_HOME" ]]; then
        candidate="$_ACFS_HOME/state.json"
    fi

    if [[ -n "$candidate" ]] && [[ -f "$candidate" ]]; then
        printf '%s\n' "$candidate"
        return 0
    fi

    if [[ -f "$_STATUS_SYSTEM_STATE_FILE" ]]; then
        printf '%s\n' "$_STATUS_SYSTEM_STATE_FILE"
        return 0
    fi

    printf '%s\n' "$candidate"
}

_status_prepare_context() {
    _ACFS_HOME="$(_status_resolve_acfs_home)"
    local state_file=""
    state_file="$(_status_resolve_state_file)"

    if [[ -z "${TARGET_USER:-}" ]]; then
        TARGET_USER=$(_status_read_target_user_from_state "$state_file" 2>/dev/null || \
            _status_read_target_user_from_state "$_STATUS_SYSTEM_STATE_FILE" 2>/dev/null || true)
        [[ -n "${TARGET_USER:-}" ]] && export TARGET_USER
    fi

    if [[ -z "${TARGET_HOME:-}" ]]; then
        TARGET_HOME=$(_status_resolve_target_home "$state_file" 2>/dev/null || true)
    fi

    if [[ -z "${TARGET_HOME:-}" ]] && [[ -n "${TARGET_USER:-}" ]]; then
        TARGET_HOME=$(_status_home_for_user "$TARGET_USER" 2>/dev/null || true)
        [[ -n "${TARGET_HOME:-}" ]] && export TARGET_HOME
    fi

    [[ -n "${TARGET_HOME:-}" ]] && export TARGET_HOME

    _status_ensure_path
}

_status_prepare_context

_state_file="$(_status_resolve_state_file)"

_status_read_last_update_ts() {
    local state_file="$1"
    local ts=""
    local key=""

    [[ -f "$state_file" ]] || return 1

    if command -v jq &>/dev/null; then
        ts=$(jq -r '
            .last_updated //
            .last_completed_phase_ts //
            .updated_at //
            .last_update //
            .started_at //
            .install_date //
            empty
        ' "$state_file" 2>/dev/null) || true
    fi

    if [[ -z "$ts" || "$ts" == "null" ]]; then
        for key in last_updated last_completed_phase_ts updated_at last_update started_at install_date; do
            ts=$(sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" \
                "$state_file" 2>/dev/null | head -n1)
            if [[ -n "$ts" ]]; then
                break
            fi
        done
    fi

    [[ -n "$ts" ]] || return 1
    printf '%s\n' "$ts"
}

# --- Collect checks ---
_warnings=()
_errors=()
_tool_count=0

# Core tools: missing any of these is a warning
_CORE_TOOLS=(zsh git tmux bun cargo go rg claude)
# Optional tools: counted but not warned about
_OPTIONAL_TOOLS=(codex gemini gh uv fzf zoxide atuin bat lsd ntm bv br cass cm slb ubs dcg)

# 1. ACFS_HOME check
if [[ ! -d "$_ACFS_HOME" ]]; then
    _errors+=("ACFS_HOME missing")
fi

# 2. State file check
if [[ ! -f "$_state_file" ]]; then
    _errors+=("state file missing")
elif [[ ! -s "$_state_file" ]]; then
    _errors+=("state file empty")
elif command -v jq &>/dev/null && ! jq -e . "$_state_file" >/dev/null 2>&1; then
    _errors+=("state file invalid JSON")
fi

# 3. Count tools in PATH
for cmd in "${_CORE_TOOLS[@]}"; do
    if command -v "$cmd" &>/dev/null; then
        ((_tool_count++)) || true
    else
        _warnings+=("missing: $cmd")
    fi
done

for cmd in "${_OPTIONAL_TOOLS[@]}"; do
    if command -v "$cmd" &>/dev/null; then
        ((_tool_count++)) || true
    fi
done

# 4. Last update timestamp
_last_update_ts=""
_last_update_human=""
if [[ -f "$_state_file" ]]; then
    _last_update_ts=$(_status_read_last_update_ts "$_state_file" 2>/dev/null || true)
fi

if [[ -n "$_last_update_ts" ]]; then
    _last_epoch=$(date -d "$_last_update_ts" +%s 2>/dev/null) || _last_epoch=0
    _now_epoch=$(date +%s)
    if [[ "$_last_epoch" -gt 0 ]]; then
        _age_secs=$((_now_epoch - _last_epoch))
        if [[ $_age_secs -lt 3600 ]]; then
            _last_update_human="$((_age_secs / 60))m ago"
        elif [[ $_age_secs -lt 86400 ]]; then
            _last_update_human="$((_age_secs / 3600))h ago"
        else
            _last_update_human="$((_age_secs / 86400))d ago"
        fi
    fi
fi

# 5. Optional: network-based update check
_update_available=""
if [[ "$_STATUS_CHECK_UPDATES" == "true" ]]; then
    if [[ -n "$_ACFS_HOME" ]] && [[ -f "$_ACFS_HOME/VERSION" ]]; then
        _local_version=$(cat "$_ACFS_HOME/VERSION" 2>/dev/null) || _local_version=""
        _remote_version=$(timeout 5 curl -fsSL \
            "https://raw.githubusercontent.com/Dicklesworthstone/agentic_coding_flywheel_setup/main/VERSION" \
            2>/dev/null) || _remote_version=""
        if [[ -n "$_remote_version" ]] && [[ -n "$_local_version" ]] \
           && [[ "$_remote_version" != "$_local_version" ]]; then
            _update_available="${_local_version} -> ${_remote_version}"
            _warnings+=("update available: $_update_available")
        fi
    fi
fi

# --- Determine overall status ---
_exit_code=0
_status_word="OK"

if [[ ${#_errors[@]} -gt 0 ]]; then
    _exit_code=2
    _status_word="ERROR"
elif [[ ${#_warnings[@]} -gt 0 ]]; then
    _exit_code=1
    _status_word="WARN"
fi

# --- JSON escape helper (no jq dependency) ---
_json_escape() {
    local s="$1"
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\n'/\\n}
    s=${s//$'\r'/\\r}
    s=${s//$'\t'/\\t}
    printf '%s' "$s"
}

_status_print() {
    local color="$1"
    local message="$2"

    if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
        printf '%b%s\033[0m\n' "$color" "$message"
    else
        printf '%s\n' "$message"
    fi
}

# --- Output ---
if [[ "$_STATUS_JSON" == "true" ]]; then
    # Build JSON arrays without requiring jq
    _warn_items=""
    for w in "${_warnings[@]+"${_warnings[@]}"}"; do
        [[ -z "$w" ]] && continue
        [[ -n "$_warn_items" ]] && _warn_items+=","
        _warn_items+="\"$(_json_escape "$w")\""
    done

    _err_items=""
    for e in "${_errors[@]+"${_errors[@]}"}"; do
        [[ -z "$e" ]] && continue
        [[ -n "$_err_items" ]] && _err_items+=","
        _err_items+="\"$(_json_escape "$e")\""
    done

    _last_update_json="null"
    if [[ -n "$_last_update_ts" ]]; then
        _last_update_json="\"$(_json_escape "$_last_update_ts")\""
    fi

    _update_json=""
    if [[ -n "$_update_available" ]]; then
        _update_json=",\"update_available\":\"$(_json_escape "$_update_available")\""
    fi

    printf '{"status":"%s","tools":%d,"last_update":%s,"warnings":[%s],"errors":[%s]%s}\n' \
        "${_status_word,,}" "$_tool_count" "$_last_update_json" \
        "$_warn_items" "$_err_items" "$_update_json"

elif [[ "$_STATUS_SHORT" == "true" ]]; then
    # Minimal output for shell prompts
    case $_exit_code in
        0) echo "OK" ;;
        1) echo "WARN" ;;
        2) echo "ERR" ;;
    esac

else
    # Human-readable one-liner
    _msg="ACFS $_status_word: $_tool_count tools"
    [[ -n "$_last_update_human" ]] && _msg="$_msg, last update $_last_update_human"

    if [[ ${#_errors[@]} -gt 0 ]]; then
        _msg="$_msg, ${#_errors[@]} error(s)"
    fi

    if [[ ${#_warnings[@]} -gt 0 ]]; then
        _missing_count=0
        for w in "${_warnings[@]}"; do
            [[ "$w" == missing:* ]] && ((_missing_count++)) || true
        done
        [[ $_missing_count -gt 0 ]] && _msg="$_msg, $_missing_count missing tool(s)"
        [[ -n "$_update_available" ]] && _msg="$_msg, update available"
    fi

    case $_exit_code in
        0) _status_print '\033[0;32m' "$_msg" ;;
        1) _status_print '\033[0;33m' "$_msg" ;;
        2) _status_print '\033[0;31m' "$_msg" ;;
    esac
fi

exit $_exit_code
