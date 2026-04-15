#!/usr/bin/env bash
# ============================================================
# ACFS Dashboard - Static HTML Generation & Serving
#
# Generates a local HTML dashboard using `acfs info --html`
# and optionally serves it via a temporary HTTP server.
#
# Usage:
#   acfs dashboard generate [--force]
#   acfs dashboard serve [--port PORT]
# ============================================================

set -euo pipefail

dashboard_sanitize_abs_nonroot_path() {
    local path_value="${1:-}"

    [[ -n "$path_value" ]] || return 1
    path_value="${path_value%/}"
    [[ -n "$path_value" ]] || return 1
    [[ "$path_value" == /* ]] || return 1
    [[ "$path_value" != "/" ]] || return 1
    printf '%s\n' "$path_value"
}

dashboard_resolve_current_home() {
    local current_user=""
    local home_candidate=""
    local passwd_entry=""

    home_candidate="$(dashboard_sanitize_abs_nonroot_path "${HOME:-}" 2>/dev/null || true)"
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
            home_candidate="$(dashboard_sanitize_abs_nonroot_path "$(printf '%s\n' "$passwd_entry" | cut -d: -f6)" 2>/dev/null || true)"
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

_DASHBOARD_CURRENT_HOME="$(dashboard_resolve_current_home 2>/dev/null || true)"
if [[ -n "$_DASHBOARD_CURRENT_HOME" ]]; then
    HOME="$_DASHBOARD_CURRENT_HOME"
    export HOME
fi

_DASHBOARD_EXPLICIT_ACFS_HOME="$(dashboard_sanitize_abs_nonroot_path "${ACFS_HOME:-}" 2>/dev/null || true)"
_DASHBOARD_DEFAULT_ACFS_HOME=""
[[ -n "$_DASHBOARD_CURRENT_HOME" ]] && _DASHBOARD_DEFAULT_ACFS_HOME="${_DASHBOARD_CURRENT_HOME}/.acfs"
ACFS_HOME="${_DASHBOARD_EXPLICIT_ACFS_HOME:-$_DASHBOARD_DEFAULT_ACFS_HOME}"
_DASHBOARD_SYSTEM_STATE_FILE="$(dashboard_sanitize_abs_nonroot_path "${ACFS_SYSTEM_STATE_FILE:-/var/lib/acfs/state.json}" 2>/dev/null || true)"
if [[ -z "$_DASHBOARD_SYSTEM_STATE_FILE" ]]; then
    _DASHBOARD_SYSTEM_STATE_FILE="/var/lib/acfs/state.json"
fi
_DASHBOARD_RESOLVED_ACFS_HOME=""
_DASHBOARD_RESOLVED_TARGET_USER=""
_DASHBOARD_RESOLVED_TARGET_HOME=""

dashboard_usage() {
    echo "Usage: acfs dashboard <command>"
    echo ""
    echo "Commands:"
    echo "  generate [--force]   Generate ~/.acfs/dashboard/index.html"
    echo "  serve [--port PORT] [--host HOST] [--public]  Start a temporary HTTP server for the dashboard"
    echo "  help                 Show this help"
}

dashboard_home_for_user() {
    local user="$1"
    local passwd_entry=""
    local home_candidate=""

    [[ -n "$user" ]] || return 1

    if command -v getent &>/dev/null; then
        passwd_entry=$(getent passwd "$user" 2>/dev/null || true)
        if [[ -n "$passwd_entry" ]]; then
            home_candidate="$(dashboard_sanitize_abs_nonroot_path "$(printf '%s\n' "$passwd_entry" | cut -d: -f6)" 2>/dev/null || true)"
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

dashboard_read_state_string() {
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

dashboard_read_target_home_from_state() {
    local state_file="$1"
    local target_home=""

    target_home="$(dashboard_read_state_string "$state_file" "target_home" 2>/dev/null || true)"
    [[ -n "$target_home" ]] || return 1
    [[ "$target_home" == /* ]] || return 1
    [[ "$target_home" != "/" ]] || return 1
    printf '%s\n' "${target_home%/}"
}

dashboard_candidate_has_acfs_data() {
    local candidate="$1"
    [[ -n "$candidate" ]] || return 1
    [[ -f "$candidate/state.json" || -f "$candidate/VERSION" || -d "$candidate/dashboard" || -d "$candidate/onboard" || -f "$candidate/scripts/lib/info.sh" ]]
}

dashboard_script_acfs_home() {
    local candidate=""
    candidate=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd) || return 1
    [[ "$(basename "$candidate")" == ".acfs" ]] || return 1
    printf '%s\n' "$candidate"
}

dashboard_resolve_acfs_home() {
    if [[ -n "$_DASHBOARD_RESOLVED_ACFS_HOME" ]]; then
        printf '%s\n' "$_DASHBOARD_RESOLVED_ACFS_HOME"
        return 0
    fi

    local candidate=""
    local target_home=""
    local target_user=""

    if [[ -n "$_DASHBOARD_EXPLICIT_ACFS_HOME" ]]; then
        _DASHBOARD_RESOLVED_ACFS_HOME="$_DASHBOARD_EXPLICIT_ACFS_HOME"
        printf '%s\n' "$_DASHBOARD_RESOLVED_ACFS_HOME"
        return 0
    fi

    candidate=$(dashboard_script_acfs_home 2>/dev/null || true)
    if dashboard_candidate_has_acfs_data "$candidate"; then
        _DASHBOARD_RESOLVED_ACFS_HOME="$candidate"
        printf '%s\n' "$_DASHBOARD_RESOLVED_ACFS_HOME"
        return 0
    fi

    if [[ -n "${SUDO_USER:-}" ]]; then
        target_home=$(dashboard_home_for_user "$SUDO_USER" 2>/dev/null || true)
        candidate="${target_home}/.acfs"
        if [[ -n "$target_home" ]] && dashboard_candidate_has_acfs_data "$candidate"; then
            _DASHBOARD_RESOLVED_ACFS_HOME="$candidate"
            printf '%s\n' "$_DASHBOARD_RESOLVED_ACFS_HOME"
            return 0
        fi
    fi

    target_home=$(dashboard_read_target_home_from_state "$_DASHBOARD_SYSTEM_STATE_FILE" 2>/dev/null || true)
    candidate="${target_home}/.acfs"
    if [[ -n "$target_home" ]] && dashboard_candidate_has_acfs_data "$candidate"; then
        _DASHBOARD_RESOLVED_ACFS_HOME="$candidate"
        printf '%s\n' "$_DASHBOARD_RESOLVED_ACFS_HOME"
        return 0
    fi

    target_user=$(dashboard_read_state_string "$_DASHBOARD_SYSTEM_STATE_FILE" "target_user" 2>/dev/null || true)
    if [[ -n "$target_user" ]]; then
        if [[ -z "$target_home" ]]; then
            target_home=$(dashboard_home_for_user "$target_user" 2>/dev/null || true)
        fi
        candidate="${target_home}/.acfs"
        if [[ -n "$target_home" ]] && dashboard_candidate_has_acfs_data "$candidate"; then
            _DASHBOARD_RESOLVED_ACFS_HOME="$candidate"
            printf '%s\n' "$_DASHBOARD_RESOLVED_ACFS_HOME"
            return 0
        fi
    fi

    if [[ -n "$ACFS_HOME" ]] && dashboard_candidate_has_acfs_data "$ACFS_HOME"; then
        _DASHBOARD_RESOLVED_ACFS_HOME="$ACFS_HOME"
        printf '%s\n' "$_DASHBOARD_RESOLVED_ACFS_HOME"
        return 0
    fi

    _DASHBOARD_RESOLVED_ACFS_HOME="$ACFS_HOME"
    printf '%s\n' "$_DASHBOARD_RESOLVED_ACFS_HOME"
}

dashboard_resolve_state_file() {
    local candidate=""

    if [[ -n "$ACFS_HOME" ]]; then
        candidate="${ACFS_HOME}/state.json"
    fi

    if [[ -n "$candidate" ]] && [[ -f "$candidate" ]]; then
        printf '%s\n' "$candidate"
        return 0
    fi

    if [[ -f "$_DASHBOARD_SYSTEM_STATE_FILE" ]]; then
        printf '%s\n' "$_DASHBOARD_SYSTEM_STATE_FILE"
        return 0
    fi

    printf '%s\n' "$candidate"
}

dashboard_prepare_context() {
    local state_file=""

    ACFS_HOME="$(dashboard_resolve_acfs_home)"
    state_file="$(dashboard_resolve_state_file)"

    if [[ -z "$_DASHBOARD_RESOLVED_TARGET_USER" ]]; then
        _DASHBOARD_RESOLVED_TARGET_USER="$(dashboard_read_state_string "$state_file" "target_user" 2>/dev/null || \
            dashboard_read_state_string "$_DASHBOARD_SYSTEM_STATE_FILE" "target_user" 2>/dev/null || true)"
    fi

    if [[ -z "$_DASHBOARD_RESOLVED_TARGET_HOME" ]]; then
        _DASHBOARD_RESOLVED_TARGET_HOME="$(dashboard_read_target_home_from_state "$state_file" 2>/dev/null || \
            dashboard_read_target_home_from_state "$_DASHBOARD_SYSTEM_STATE_FILE" 2>/dev/null || true)"
        if [[ -z "$_DASHBOARD_RESOLVED_TARGET_HOME" ]] && [[ -n "$_DASHBOARD_RESOLVED_TARGET_USER" ]]; then
            _DASHBOARD_RESOLVED_TARGET_HOME="$(dashboard_home_for_user "$_DASHBOARD_RESOLVED_TARGET_USER" 2>/dev/null || true)"
        fi
        if [[ -z "$_DASHBOARD_RESOLVED_TARGET_HOME" ]] && [[ "$ACFS_HOME" == */.acfs ]]; then
            _DASHBOARD_RESOLVED_TARGET_HOME="${ACFS_HOME%/.acfs}"
        fi
    fi
}

find_info_script() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Prefer the repo-local helper when running from a checkout so dashboard
    # generation follows the code under test, not a stale installed copy.
    if [[ -f "$script_dir/info.sh" ]]; then
        echo "$script_dir/info.sh"
        return 0
    fi

    if [[ -n "$ACFS_HOME" ]] && [[ -f "$ACFS_HOME/scripts/lib/info.sh" ]]; then
        echo "$ACFS_HOME/scripts/lib/info.sh"
        return 0
    fi

    return 1
}

validate_port() {
    local port="${1:-}"
    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        return 1
    fi

    (( port >= 1 && port <= 65535 ))
}

dashboard_generate() {
    local force=false

    dashboard_prepare_context

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force)
                force=true
                ;;
            --help|-h)
                dashboard_usage
                return 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                return 1
                ;;
        esac
        shift
    done

    if [[ -z "$ACFS_HOME" ]]; then
        echo "Error: ACFS home not found" >&2
        echo "Provide ACFS_SYSTEM_STATE_FILE with target_home, or re-run the installer." >&2
        return 1
    fi

    local dashboard_dir="${ACFS_HOME}/dashboard"
    local html_file="${dashboard_dir}/index.html"
    local timestamp_file="${dashboard_dir}/.last_generated"

    mkdir -p "$dashboard_dir"

    if [[ "$force" != "true" && -f "$html_file" ]]; then
        local last_gen now age
        last_gen="$(cat "$timestamp_file" 2>/dev/null || echo 0)"
        if [[ ! "$last_gen" =~ ^[0-9]+$ ]]; then
            last_gen=0
        fi
        now="$(date +%s)"
        age=$((now - last_gen))

        if [[ $age -ge 0 && $age -lt 3600 ]]; then
            echo "Dashboard is recent ($((age / 60)) minutes old). Use --force to regenerate."
            echo "Dashboard path: $html_file"
            return 0
        fi
    fi

    local info_script
    if ! info_script="$(find_info_script)"; then
        echo "Error: info.sh not found" >&2
        echo "Re-run the ACFS installer to get the latest scripts." >&2
        return 1
    fi

    echo "Generating dashboard..."
    local tmp_file=""
    tmp_file=$(mktemp "${dashboard_dir}/index.html.tmp.XXXXXX") || {
        echo "Error: could not create temporary dashboard file" >&2
        return 1
    }

    cleanup_tmp_file() {
        if [[ -n "$tmp_file" && -e "$tmp_file" ]]; then
            rm -f "$tmp_file"
        fi
    }

    trap cleanup_tmp_file RETURN

    if ! bash "$info_script" --html > "$tmp_file"; then
        echo "Error: dashboard generation failed" >&2
        return 1
    fi

    mv "$tmp_file" "$html_file"
    tmp_file=""
    trap - RETURN
    date +%s > "$timestamp_file"

    echo "Dashboard generated: $html_file"
    echo "Open with: open \"$html_file\" (macOS) or xdg-open \"$html_file\" (Linux)"
}

dashboard_serve() {
    local port=8080
    local host="127.0.0.1"

    dashboard_prepare_context

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --port)
                if [[ -z "${2:-}" || "$2" == -* ]]; then
                    echo "Error: --port requires a port number" >&2
                    return 1
                fi
                if ! validate_port "$2"; then
                    echo "Error: port must be an integer between 1 and 65535" >&2
                    return 1
                fi
                port="$2"
                shift 2
                continue
                ;;
            --host)
                if [[ -z "${2:-}" || "$2" == -* ]]; then
                    echo "Error: --host requires a host/address (e.g. 127.0.0.1 or 0.0.0.0)" >&2
                    return 1
                fi
                host="$2"
                shift 2
                continue
                ;;
            --public)
                host="0.0.0.0"
                ;;
            --help|-h)
                echo "Usage: acfs dashboard serve [--port PORT] [--host HOST] [--public]"
                echo ""
                echo "Starts a temporary HTTP server to view the dashboard."
                echo "Default port: 8080"
                echo "Default host: 127.0.0.1 (local only)"
                echo ""
                echo "Notes:"
                echo "  - Local-only is safer on VPS (prevents accidental internet exposure)."
                echo "  - Use --public to bind 0.0.0.0 (all interfaces)."
                return 0
                ;;
            *)
                # Allow port as positional argument
                if [[ "$1" =~ ^[0-9]+$ ]]; then
                    if ! validate_port "$1"; then
                        echo "Error: port must be an integer between 1 and 65535" >&2
                        return 1
                    fi
                    port="$1"
                else
                    echo "Unknown option: $1" >&2
                    return 1
                fi
                ;;
        esac
        shift
    done

    if ! validate_port "$port"; then
        echo "Error: port must be an integer between 1 and 65535" >&2
        return 1
    fi

    if [[ -z "$ACFS_HOME" ]]; then
        echo "Error: ACFS home not found" >&2
        echo "Provide ACFS_SYSTEM_STATE_FILE with target_home, or re-run the installer." >&2
        return 1
    fi

    local dashboard_dir="${ACFS_HOME}/dashboard"
    local html_file="${dashboard_dir}/index.html"

    # Auto-generate dashboard if missing
    if [[ ! -f "$html_file" ]]; then
        echo "Dashboard not found. Generating..."
        dashboard_generate --force
    fi

    # Get IP for display
    local ip
    if command -v hostname &>/dev/null; then
        ip=$(hostname -I 2>/dev/null | awk '{print $1}') || ip="<your-server-ip>"
    else
        ip="<your-server-ip>"
    fi
    # Fallback if hostname -I returned empty
    [[ -z "$ip" ]] && ip="<your-server-ip>"

    # Prefer the invoking user for SSH tunnel instructions (handles `sudo acfs ...`).
    local ssh_user=""
    if [[ -n "$_DASHBOARD_RESOLVED_TARGET_USER" ]]; then
        ssh_user="$_DASHBOARD_RESOLVED_TARGET_USER"
    elif [[ -n "${SUDO_USER:-}" ]] && [[ "${SUDO_USER}" != "root" ]]; then
        ssh_user="$SUDO_USER"
    else
        ssh_user="$(whoami 2>/dev/null || echo "ubuntu")"
    fi

    # Check if port is in use
    if command -v lsof &>/dev/null && lsof -i :"$port" &>/dev/null; then
        echo "Warning: Port $port appears to be in use." >&2
        echo "Try a different port: acfs dashboard serve --port 8081" >&2
        return 1
    fi

    # Show banner
    if [[ "$host" == "127.0.0.1" || "$host" == "localhost" ]]; then
        cat <<EOF

╭─────────────────────────────────────────────────────────────╮
│  📊 ACFS Dashboard Server                                   │
├─────────────────────────────────────────────────────────────┤
│  Local URL:   http://localhost:${port} (server-side only)      │
│                                                             │
│  Press Ctrl+C to stop                                       │
│                                                             │
│  ⚠️  This is a temporary server.                            │
│  It stops when you close this terminal.                     │
│                                                             │
│  To view from your laptop (recommended):                     │
│    ssh -L ${port}:localhost:${port} ${ssh_user}@${ip}                │
│    then open: http://localhost:${port}                         │
╰─────────────────────────────────────────────────────────────╯

EOF
    else
        cat <<EOF

╭─────────────────────────────────────────────────────────────╮
│  📊 ACFS Dashboard Server                                   │
├─────────────────────────────────────────────────────────────┤
│  Local URL:   http://localhost:${port}                         │
│  Network URL: http://${ip}:${port}
│                                                             │
│  Press Ctrl+C to stop                                       │
│                                                             │
│  ⚠️  This is a temporary server.                            │
│  It stops when you close this terminal.                     │
╰─────────────────────────────────────────────────────────────╯

EOF
    fi

    # Start server
    cd "$dashboard_dir" || {
        echo "Error: Cannot cd to $dashboard_dir" >&2
        return 1
    }

    if command -v python3 &>/dev/null; then
        python3 -m http.server --bind "$host" "$port"
    elif command -v python &>/dev/null; then
        python -m http.server --bind "$host" "$port"
    else
        echo "Error: Python not found. Cannot start HTTP server." >&2
        echo "Install Python or open the dashboard directly: $html_file" >&2
        return 1
    fi
}

dashboard_main() {
    local cmd="${1:-help}"
    shift 1 2>/dev/null || true

    case "$cmd" in
        generate)
            dashboard_generate "$@"
            ;;
        serve)
            dashboard_serve "$@"
            ;;
        help|-h|--help)
            dashboard_usage
            ;;
        *)
            echo "Unknown command: $cmd" >&2
            dashboard_usage >&2
            return 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    dashboard_main "$@"
fi
