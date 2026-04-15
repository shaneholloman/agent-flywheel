#!/usr/bin/env bash
# shellcheck disable=SC1091
# ============================================================
# ACFS Installer - Dicklesworthstone Stack Library
# Installs all 19 Dicklesworthstone tools + utilities
# ============================================================

STACK_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ensure we have logging functions available
if [[ -z "${ACFS_BLUE:-}" ]]; then
    # shellcheck source=logging.sh
    source "$STACK_SCRIPT_DIR/logging.sh"
fi

# ============================================================
# Configuration
# ============================================================

# Tool commands for verification
declare -gA STACK_COMMANDS=(
    [ntm]="ntm"
    [mcp_agent_mail]="am"
    [ubs]="ubs"
    [bv]="bv"
    [br]="br"
    [cass]="cass"
    [cm]="cm"
    [caam]="caam"
    [slb]="slb"
    [ru]="ru"
    [dcg]="dcg"
    [rch]="rch"
    [pt]="pt"
    [fsfs]="fsfs"
    [sbh]="sbh"
    [casr]="casr"
    [dsr]="dsr"
    [asb]="asb"
    [pcr]="claude-post-compact-reminder"
)

# Tool display names
declare -gA STACK_NAMES=(
    [ntm]="NTM (Named Tmux Manager)"
    [mcp_agent_mail]="MCP Agent Mail"
    [ubs]="Ultimate Bug Scanner"
    [bv]="Beads Viewer"
    [br]="BR (Beads Rust)"
    [cass]="CASS (Coding Agent Session Search)"
    [cm]="CM (CASS Memory System)"
    [caam]="CAAM (Coding Agent Account Manager)"
    [slb]="SLB (Simultaneous Launch Button)"
    [ru]="RU (Repo Updater)"
    [dcg]="DCG (Destructive Command Guard)"
    [rch]="RCH (Remote Compilation Helper)"
    [pt]="PT (Process Triage)"
    [fsfs]="Frankensearch"
    [sbh]="SBH (Storage Ballast Helper)"
    [casr]="CASR (Cross-Agent Session Resumer)"
    [dsr]="DSR (Doodlestein Self-Releaser)"
    [asb]="ASB (Agent Settings Backup)"
    [pcr]="PCR (Post-Compact Reminder)"
)

# ============================================================
# Helper Functions
# ============================================================

# Check if a command exists
_stack_command_exists() {
    command -v "$1" &>/dev/null
}

# Check if we're in interactive mode (fallback if security.sh isn't loaded yet).
_stack_is_interactive() {
    if declare -f _acfs_is_interactive >/dev/null 2>&1; then
        _acfs_is_interactive
        return $?
    fi

    [[ "${ACFS_INTERACTIVE:-true}" == "true" ]] || return 1

    if [[ -e /dev/tty ]] && (exec 3<>/dev/tty) 2>/dev/null; then
        return 0
    fi

    [[ -t 0 ]]
}

# Get the sudo command if needed
_stack_get_sudo() {
    if [[ $EUID -eq 0 ]]; then
        echo ""
    else
        echo "sudo"
    fi
}

_stack_target_home() {
    local target_user="${1:-${TARGET_USER:-ubuntu}}"
    local passwd_entry=""
    local current_user=""

    if [[ -n "${TARGET_HOME:-}" ]] && [[ "${TARGET_HOME}" == /* ]] && [[ "${TARGET_HOME}" != "/" ]]; then
        printf '%s\n' "${TARGET_HOME%/}"
        return 0
    fi

    if [[ "$target_user" == "root" ]]; then
        printf '/root\n'
        return 0
    fi

    passwd_entry="$(getent passwd "$target_user" 2>/dev/null || true)"
    if [[ -n "$passwd_entry" ]]; then
        passwd_entry="$(printf '%s\n' "$passwd_entry" | cut -d: -f6)"
        if [[ -n "$passwd_entry" ]] && [[ "$passwd_entry" == /* ]] && [[ "$passwd_entry" != "/" ]]; then
            printf '%s\n' "${passwd_entry%/}"
            return 0
        fi
    fi

    current_user="$(whoami 2>/dev/null || true)"
    if [[ "$current_user" == "$target_user" ]] && [[ -n "${HOME:-}" ]] && [[ "${HOME}" == /* ]] && [[ "${HOME}" != "/" ]]; then
        printf '%s\n' "${HOME%/}"
        return 0
    fi

    if [[ "$target_user" =~ ^[a-z_][a-z0-9._-]*$ ]]; then
        printf '/home/%s\n' "$target_user"
        return 0
    fi

    return 1
}

_stack_validate_target_user() {
    local username="${1:-${TARGET_USER:-}}"
    local display="${username:-<empty>}"

    if [[ "$username" =~ ^[a-z_][a-z0-9._-]*$ ]]; then
        return 0
    fi

    log_error "Invalid TARGET_USER '$display' (expected: lowercase user name like 'ubuntu')"
    return 1
}

_stack_trim_ascii_whitespace() {
    local value="${1:-}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s\n' "$value"
}

_stack_strip_wrapping_quotes() {
    local value
    value="$(_stack_trim_ascii_whitespace "${1:-}")"
    if [[ "${#value}" -ge 2 ]]; then
        case "$value" in
            \"*\"|\'*\')
                if [[ "${value:0:1}" == "${value: -1}" ]]; then
                    value="${value:1:${#value}-2}"
                fi
                ;;
        esac
    fi
    printf '%s\n' "$value"
}

_stack_parse_env_assignment_rhs() {
    local raw="$1"
    local out=""
    local quote=""
    local prev=""
    local char=""
    local raw_len="${#raw}"
    local i=0

    while [[ "$i" -lt "$raw_len" ]]; do
        char="${raw:i:1}"
        if [[ -n "$quote" ]]; then
            out="${out}${char}"
            if [[ "$char" == "$quote" ]]; then
                quote=""
            fi
        else
            if [[ "$char" == '"' || "$char" == "'" ]]; then
                quote="$char"
                out="${out}${char}"
            elif [[ "$char" == "#" ]]; then
                if [[ -z "$prev" || "$prev" =~ [[:space:]] ]]; then
                    break
                fi
                out="${out}${char}"
            else
                out="${out}${char}"
            fi
        fi
        prev="$char"
        i=$((i + 1))
    done

    out="$(_stack_trim_ascii_whitespace "$out")"
    _stack_strip_wrapping_quotes "$out"
}

_stack_read_env_assignment_value() {
    local file="$1"
    local key="$2"
    local value=""

    [[ -f "$file" ]] || return 0
    value="$(grep -E "^[[:space:]]*(export[[:space:]]+)?${key}[[:space:]]*=" "$file" 2>/dev/null | tail -1 | sed -E "s/^[[:space:]]*(export[[:space:]]+)?${key}[[:space:]]*=[[:space:]]*//" || true)"
    [[ -n "$value" ]] || return 0
    _stack_parse_env_assignment_rhs "$value"
}

_stack_normalize_http_path() {
    local value="${1:-/mcp/}"
    case "$value" in
        mcp|/mcp|/mcp/) printf '/mcp/\n' ;;
        api|/api|/api/) printf '/api/\n' ;;
        *)
            [[ -n "$value" ]] || value="/mcp/"
            [[ "$value" == /* ]] || value="/${value}"
            [[ "$value" == */ ]] || value="${value}/"
            printf '%s\n' "$value"
            ;;
    esac
}

_stack_agent_mail_cli_path() {
    local target_home=""
    target_home="$(_stack_target_home "${TARGET_USER:-ubuntu}")"

    local preferred="$target_home/mcp_agent_mail/am"
    local primary_bin="${ACFS_BIN_DIR:-$target_home/.local/bin}/am"
    local fallback_bin="$target_home/.local/bin/am"

    if [[ -x "$preferred" ]]; then
        printf '%s\n' "$preferred"
        return 0
    fi
    if [[ -x "$primary_bin" ]]; then
        printf '%s\n' "$primary_bin"
        return 0
    fi
    if [[ "$fallback_bin" != "$primary_bin" ]] && [[ -x "$fallback_bin" ]]; then
        printf '%s\n' "$fallback_bin"
        return 0
    fi
    if _stack_command_exists am; then
        command -v am
        return 0
    fi

    return 1
}

_stack_repair_agent_mail_cli_symlink() {
    local target_home=""
    target_home="$(_stack_target_home "${TARGET_USER:-ubuntu}")"

    local am_src="$target_home/mcp_agent_mail/am"
    [[ -x "$am_src" ]] || return 1

    local primary_dir="${ACFS_BIN_DIR:-$target_home/.local/bin}"
    local fallback_dir="$target_home/.local/bin"
    local -a bin_dirs=("$primary_dir")

    if [[ "$fallback_dir" != "$primary_dir" ]]; then
        bin_dirs+=("$fallback_dir")
    fi

    local dir=""
    local repaired=0
    for dir in "${bin_dirs[@]}"; do
        [[ -n "$dir" ]] || continue
        _stack_run_as_user "mkdir -p '$dir' 2>/dev/null || true; if [[ -w '$dir' || ! -e '$dir/am' ]]; then ln -sf '$am_src' '$dir/am'; fi" || repaired=1
    done

    return "$repaired"
}

_stack_agent_mail_liveness() {
    curl -fsS --max-time 10 http://127.0.0.1:8765/health/liveness >/dev/null 2>&1 || \
        curl -fsS --max-time 10 http://127.0.0.1:8765/healthz >/dev/null 2>&1
}

_stack_agent_mail_readiness() {
    local readiness_body=""
    readiness_body="$(curl -fsS --max-time 10 http://127.0.0.1:8765/health 2>/dev/null)" || return 1
    printf '%s\n' "$readiness_body" | grep -Eq '"status"[[:space:]]*:[[:space:]]*"ready"'
}

# Run a command as target user
_stack_run_as_user() {
    local target_user="${TARGET_USER:-ubuntu}"
    local target_home=""
    _stack_validate_target_user "$target_user" || return 1
    target_home="$(_stack_target_home "$target_user" 2>/dev/null || true)"
    if [[ -z "$target_home" ]] || [[ "$target_home" == "/" ]] || [[ "$target_home" != /* ]]; then
        log_error "Invalid TARGET_HOME for '$target_user': ${target_home:-<empty>} (must be an absolute path and cannot be '/')"
        return 1
    fi
    if [[ -n "${ACFS_BIN_DIR:-}" ]] && { [[ "${ACFS_BIN_DIR}" == "/" ]] || [[ "${ACFS_BIN_DIR}" != /* ]]; }; then
        log_error "ACFS_BIN_DIR must be an absolute path and cannot be '/' (got: ${ACFS_BIN_DIR:-<empty>})"
        return 1
    fi
    local target_path_prefix="${ACFS_BIN_DIR:-$target_home/.local/bin}:$target_home/.local/bin:$target_home/.acfs/bin:$target_home/.cargo/bin:$target_home/.bun/bin:$target_home/.atuin/bin:$target_home/go/bin"
    local cmd="$1"
    local target_user_q=""
    local target_home_q=""
    local acfs_bin_dir_q=""
    local wrapped_cmd=""

    printf -v target_user_q '%q' "$target_user"
    printf -v target_home_q '%q' "$target_home"
    if [[ -n "${ACFS_BIN_DIR:-}" ]]; then
        printf -v acfs_bin_dir_q '%q' "$ACFS_BIN_DIR"
    fi

    wrapped_cmd="export TARGET_USER=$target_user_q TARGET_HOME=$target_home_q HOME=$target_home_q;"
    if [[ -n "$acfs_bin_dir_q" ]]; then
        wrapped_cmd+=" export ACFS_BIN_DIR=$acfs_bin_dir_q;"
    fi
    wrapped_cmd+=" export PATH=\"$target_path_prefix:\$PATH\"; set -o pipefail; $cmd"

    if [[ "$(whoami)" == "$target_user" ]]; then
        bash -c "$wrapped_cmd"
        return $?
    fi

    if command -v sudo &>/dev/null; then
        sudo -u "$target_user" -H bash -c "$wrapped_cmd"
        return $?
    fi

    if command -v runuser &>/dev/null; then
        runuser -u "$target_user" -- bash -c "$wrapped_cmd"
        return $?
    fi

    # Avoid login shells: profile files are not a stable API and can break non-interactive runs.
    su "$target_user" -c "bash -c $(printf %q "$wrapped_cmd")"
}

# Load security helpers + checksums.yaml (fail closed if unavailable).
STACK_SECURITY_READY=false
_stack_require_security() {
    if [[ "${STACK_SECURITY_READY}" == "true" ]]; then
        return 0
    fi

    if [[ ! -f "$STACK_SCRIPT_DIR/security.sh" ]]; then
        log_warn "Security library not found ($STACK_SCRIPT_DIR/security.sh); refusing to run upstream installer scripts"
        return 1
    fi

    # shellcheck source=security.sh
    source "$STACK_SCRIPT_DIR/security.sh"
    if ! load_checksums; then
        log_warn "checksums.yaml not available; refusing to run upstream installer scripts"
        return 1
    fi

    STACK_SECURITY_READY=true
    return 0
}

# Run an installer script as target user with checksum verification.
# Some upstream installers use environment variables instead of CLI flags for
# non-interactive mode, so allow one optional inline env assignment like VAR=value.
_stack_run_verified_installer_with_env() {
    if [[ $# -lt 1 ]]; then
        log_warn "_stack_run_verified_installer_with_env requires at least a tool name"
        return 1
    fi

    local tool="$1"
    local bash_env_assignment="${2:-}"
    if [[ $# -ge 2 ]]; then
        shift 2
    else
        set --
    fi

    if ! _stack_require_security; then
        return 1
    fi

    local url="${KNOWN_INSTALLERS[$tool]:-}"
    local expected_sha256
    expected_sha256="$(get_checksum "$tool")"

    if [[ -z "$url" ]]; then
        log_warn "No installer URL configured for $tool (KNOWN_INSTALLERS)"
        return 1
    fi
    if [[ -z "$expected_sha256" ]]; then
        log_warn "No checksum recorded for $tool; refusing to run unverified installer"
        return 1
    fi
    if [[ -n "$bash_env_assignment" ]] && [[ ! "$bash_env_assignment" =~ ^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+$ ]]; then
        log_warn "Invalid inline env assignment for $tool installer: $bash_env_assignment"
        return 1
    fi

    local -a quoted_args=()
    local arg
    for arg in "$@"; do
        quoted_args+=("$(printf '%q' "$arg")")
    done

    local cmd="source '$STACK_SCRIPT_DIR/security.sh'; verify_checksum '$url' '$expected_sha256' '$tool' | "
    if [[ -n "$bash_env_assignment" ]]; then
        cmd+="$bash_env_assignment "
    fi
    cmd+="bash -s --"
    if [[ ${#quoted_args[@]} -gt 0 ]]; then
        cmd+=" ${quoted_args[*]}"
    fi

    _stack_run_as_user "$cmd"
}

_stack_run_verified_installer() {
    if [[ $# -lt 1 ]]; then
        log_warn "_stack_run_verified_installer requires a tool name"
        return 1
    fi

    local tool="$1"
    if [[ $# -ge 1 ]]; then
        shift
    else
        set --
    fi
    _stack_run_verified_installer_with_env "$tool" "" "$@"
}

_stack_run_installer() {
    if [[ $# -lt 1 ]]; then
        log_warn "_stack_run_installer requires a tool name"
        return 1
    fi

    local tool="$1"
    if [[ $# -ge 1 ]]; then
        shift
    else
        set --
    fi
    _stack_run_verified_installer "$tool" "$@"
}

# Check whether the local Agent Mail HTTP service is healthy.
_stack_agent_mail_healthy() {
    _stack_agent_mail_liveness
}

_stack_agent_mail_ready() {
    local check_cmd
    check_cmd="$(cat <<'EOF'
set -euo pipefail
preferred_am="$HOME/mcp_agent_mail/am"
if [[ -x "$preferred_am" ]]; then
    am_bin="$preferred_am"
elif command -v am >/dev/null 2>&1; then
    am_bin="$(command -v am)"
else
    exit 1
fi

if ! curl -fsS --max-time 10 http://127.0.0.1:8765/health/liveness >/dev/null 2>&1 && \
   ! curl -fsS --max-time 10 http://127.0.0.1:8765/healthz >/dev/null 2>&1; then
    exit 1
fi

readiness_body="$(curl -fsS --max-time 10 http://127.0.0.1:8765/health 2>/dev/null)" || exit 1
printf '%s\n' "$readiness_body" | grep -Eq '"status"[[:space:]]*:[[:space:]]*"ready"' || exit 1

runtime_dir="/run/user/$(id -u)"
if [[ -d "$runtime_dir" ]]; then
    export XDG_RUNTIME_DIR="$runtime_dir"
    if [[ -S "$runtime_dir/bus" ]]; then
        export DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_dir/bus"
    fi
fi

if command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1; then
    systemctl --user is-active --quiet agent-mail.service >/dev/null 2>&1
fi
EOF
)"

    _stack_run_as_user "$check_cmd"
}

# Write and enable the managed Agent Mail user service for the target user.
_stack_configure_agent_mail_service() {
    local service_cmd
    service_cmd="$(cat <<'EOF'
set -euo pipefail

trim_ascii_whitespace() {
    local value="${1:-}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s\n' "$value"
}

strip_wrapping_quotes() {
    local value
    value="$(trim_ascii_whitespace "${1:-}")"
    if [[ "${#value}" -ge 2 ]]; then
        case "$value" in
            \"*\"|\'*\')
                if [[ "${value:0:1}" == "${value: -1}" ]]; then
                    value="${value:1:${#value}-2}"
                fi
                ;;
        esac
    fi
    printf '%s\n' "$value"
}

parse_env_assignment_rhs() {
    local raw="$1"
    local out=""
    local quote=""
    local prev=""
    local char=""
    local raw_len="${#raw}"
    local i=0

    while [[ "$i" -lt "$raw_len" ]]; do
        char="${raw:i:1}"
        if [[ -n "$quote" ]]; then
            out="${out}${char}"
            if [[ "$char" == "$quote" ]]; then
                quote=""
            fi
        else
            if [[ "$char" == '"' || "$char" == "'" ]]; then
                quote="$char"
                out="${out}${char}"
            elif [[ "$char" == "#" ]]; then
                if [[ -z "$prev" || "$prev" =~ [[:space:]] ]]; then
                    break
                fi
                out="${out}${char}"
            else
                out="${out}${char}"
            fi
        fi
        prev="$char"
        i=$((i + 1))
    done

    out="$(trim_ascii_whitespace "$out")"
    strip_wrapping_quotes "$out"
}

read_env_assignment_value() {
    local file="$1"
    local key="$2"
    local value=""

    [[ -f "$file" ]] || return 0
    value="$(grep -E "^[[:space:]]*(export[[:space:]]+)?${key}[[:space:]]*=" "$file" 2>/dev/null | tail -1 | sed -E "s/^[[:space:]]*(export[[:space:]]+)?${key}[[:space:]]*=[[:space:]]*//" || true)"
    [[ -n "$value" ]] || return 0
    parse_env_assignment_rhs "$value"
}

normalize_http_path() {
    local value="${1:-/mcp/}"
    case "$value" in
        mcp|/mcp|/mcp/) printf '/mcp/\n' ;;
        api|/api|/api/) printf '/api/\n' ;;
        *)
            [[ -n "$value" ]] || value="/mcp/"
            [[ "$value" == /* ]] || value="/${value}"
            [[ "$value" == */ ]] || value="${value}/"
            printf '%s\n' "$value"
            ;;
    esac
}

sqlite_user_table_count() {
    local db_path="$1"
    [[ -f "$db_path" ]] || {
        printf '0\n'
        return 0
    }
    if command -v python3 >/dev/null 2>&1; then
        python3 - "$db_path" <<'PY'
import sqlite3
import sys

db_path = sys.argv[1]
try:
    conn = sqlite3.connect(db_path)
    cur = conn.execute("SELECT count(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")
    row = cur.fetchone()
    print(int(row[0]) if row and row[0] is not None else 0)
except Exception:
    print(0)
PY
        return 0
    fi
    if command -v sqlite3 >/dev/null 2>&1; then
        sqlite3 "$db_path" "SELECT count(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';" 2>/dev/null || printf '0\n'
        return 0
    fi
    printf '0\n'
}

am_bin=""
preferred_am="$HOME/mcp_agent_mail/am"
if [[ -x "$preferred_am" ]]; then
    am_bin="$preferred_am"
else
    am_bin="$(command -v am 2>/dev/null || true)"
fi
[[ -n "$am_bin" ]] || {
    echo "am CLI missing after install" >&2
    exit 1
}

primary_bin_dir="${ACFS_BIN_DIR:-$HOME/.local/bin}"
fallback_bin_dir="$HOME/.local/bin"
mkdir -p "$primary_bin_dir" 2>/dev/null || true
if [[ -x "$preferred_am" ]]; then
    ln -sf "$preferred_am" "$primary_bin_dir/am" 2>/dev/null || true
    if [[ "$fallback_bin_dir" != "$primary_bin_dir" ]]; then
        mkdir -p "$fallback_bin_dir" 2>/dev/null || true
        ln -sf "$preferred_am" "$fallback_bin_dir/am" 2>/dev/null || true
    fi
    am_bin="$preferred_am"
fi

storage_root="$HOME/.mcp_agent_mail_git_mailbox_repo"
unit_dir="$HOME/.config/systemd/user"
unit_file="$unit_dir/agent-mail.service"
db_path="$storage_root/storage.sqlite3"
db_url="sqlite:///${db_path}"
env_file=""
for candidate in "$HOME/.config/mcp-agent-mail/config.env" "$HOME/.config/mcp-agent-mail/.env"; do
    if [[ -f "$candidate" ]]; then
        env_file="$candidate"
        break
    fi
done

cfg_db_url=""
cfg_storage_root=""
cfg_http_path=""
if [[ -n "$env_file" ]]; then
    cfg_db_url="$(read_env_assignment_value "$env_file" "DATABASE_URL")"
    cfg_storage_root="$(read_env_assignment_value "$env_file" "STORAGE_ROOT")"
    cfg_http_path="$(read_env_assignment_value "$env_file" "HTTP_PATH")"
fi

if [[ -n "$cfg_storage_root" ]]; then
    cfg_storage_root="${cfg_storage_root/#\~/$HOME}"
    case "$cfg_storage_root" in
        /*) storage_root="$cfg_storage_root" ;;
    esac
fi

db_path="$storage_root/storage.sqlite3"
db_url="sqlite:///${db_path}"

if [[ -n "$cfg_db_url" ]]; then
    cfg_db_path="$(printf '%s\n' "$cfg_db_url" | sed -n 's|^sqlite[^:]*:///||p')"
    cfg_db_path="${cfg_db_path/#\~/$HOME}"
    if [[ -n "$cfg_db_path" && "$cfg_db_path" != ":memory:" && "$cfg_db_path" != "/:memory:" ]]; then
        db_path="$cfg_db_path"
        db_url="$cfg_db_url"
        storage_root="$(dirname "$cfg_db_path")"
    fi
fi

install_storage_root="$HOME/mcp_agent_mail"
install_db="$install_storage_root/storage.sqlite3"
default_legacy_db="$HOME/.mcp_agent_mail_git_mailbox_repo/storage.sqlite3"
selected_tables="$(sqlite_user_table_count "$db_path")"
if [[ -f "$install_db" ]]; then
    install_tables="$(sqlite_user_table_count "$install_db")"
    if [[ "$install_tables" -gt 0 ]] && [[ "$selected_tables" -eq 0 ]] && {
        [[ -z "$cfg_storage_root" && -z "$cfg_db_url" ]] || [[ "$db_path" == "$default_legacy_db" ]];
    }; then
        storage_root="$install_storage_root"
        db_path="$install_db"
        db_url="sqlite:///${install_db}"
    fi
fi

# Detect MCP base path: Rust am uses /mcp/, Python mcp_agent_mail uses /api/
if "$am_bin" --version 2>/dev/null | grep -q '^am '; then
    am_mcp_path="/mcp/"
else
    am_mcp_path="/api/"
fi
if [[ -n "$cfg_http_path" ]]; then
    am_mcp_path="$(normalize_http_path "$cfg_http_path")"
fi

mkdir -p "$storage_root" "$unit_dir"
env_file_line=""
if [[ -n "$env_file" ]]; then
    env_file_line="EnvironmentFile=-$env_file"
fi
cat > "$unit_file" <<UNIT_EOF
[Unit]
Description=MCP Agent Mail Server
After=network.target

[Service]
Type=simple
WorkingDirectory=$storage_root
${env_file_line}
Environment=RUST_LOG=info
Environment=STORAGE_ROOT=$storage_root
Environment=DATABASE_URL=$db_url
Environment=HTTP_ALLOW_LOCALHOST_UNAUTHENTICATED=true
ExecStartPre=$am_bin migrate
ExecStart=$am_bin serve-http --no-tui --host 127.0.0.1 --port 8765 --path $am_mcp_path
Restart=always
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=default.target
UNIT_EOF

runtime_dir="/run/user/$(id -u)"
if [[ -d "$runtime_dir" ]]; then
    export XDG_RUNTIME_DIR="$runtime_dir"
    if [[ -S "$runtime_dir/bus" ]]; then
        export DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_dir/bus"
    fi
fi

fallback_pid_file="$storage_root/agent-mail.pid"
fallback_log_file="$storage_root/agent-mail.log"

stop_agent_mail_fallback() {
    if [[ -f "$fallback_pid_file" ]]; then
        existing_pid="$(cat "$fallback_pid_file" 2>/dev/null || true)"
        if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" 2>/dev/null && \
           ps -p "$existing_pid" -o args= 2>/dev/null | grep -Fq "$am_bin serve-http"; then
            kill "$existing_pid" >/dev/null 2>&1 || true
            for _ in {1..10}; do
                if ! kill -0 "$existing_pid" 2>/dev/null; then
                    break
                fi
                sleep 1
            done
            if kill -0 "$existing_pid" 2>/dev/null; then
                kill -9 "$existing_pid" >/dev/null 2>&1 || true
            fi
        fi
        rm -f "$fallback_pid_file"
    fi
}

launch_agent_mail_fallback() {
    if {
        curl -fsS --max-time 5 http://127.0.0.1:8765/health/liveness >/dev/null 2>&1 || \
        curl -fsS --max-time 5 http://127.0.0.1:8765/healthz >/dev/null 2>&1;
    } && curl -fsS --max-time 5 http://127.0.0.1:8765/health 2>/dev/null | grep -Eq '"status"[[:space:]]*:[[:space:]]*"ready"'; then
        return 0
    fi

    if [[ -f "$fallback_pid_file" ]]; then
        existing_pid="$(cat "$fallback_pid_file" 2>/dev/null || true)"
        if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" 2>/dev/null && \
           ps -p "$existing_pid" -o args= 2>/dev/null | grep -Fq "$am_bin serve-http"; then
            stop_agent_mail_fallback
        else
            rm -f "$fallback_pid_file"
        fi
    fi

    nohup env \
        RUST_LOG=info \
        STORAGE_ROOT="$storage_root" \
        DATABASE_URL="$db_url" \
        HTTP_ALLOW_LOCALHOST_UNAUTHENTICATED=true \
        "$am_bin" migrate \
        >>"$fallback_log_file" 2>&1 < /dev/null || true

    nohup env \
        RUST_LOG=info \
        STORAGE_ROOT="$storage_root" \
        DATABASE_URL="$db_url" \
        HTTP_ALLOW_LOCALHOST_UNAUTHENTICATED=true \
        "$am_bin" serve-http --no-tui --host 127.0.0.1 --port 8765 --path "$am_mcp_path" \
        >>"$fallback_log_file" 2>&1 < /dev/null &
    echo $! > "$fallback_pid_file"
}

if command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1; then
    stop_agent_mail_fallback
    systemctl --user daemon-reload >/dev/null 2>&1 || true
    if ! systemctl --user enable --now agent-mail.service >/dev/null 2>&1; then
        systemctl --user restart agent-mail.service >/dev/null 2>&1
    fi
    active_waited=0
    active_max_wait=10
    until systemctl --user is-active --quiet agent-mail.service >/dev/null 2>&1; do
        if [[ "$active_waited" -ge "$active_max_wait" ]]; then
            break
        fi
        sleep 1
        active_waited=$((active_waited + 1))
    done
    systemctl --user is-active --quiet agent-mail.service >/dev/null 2>&1
else
    echo "Agent Mail: systemctl --user unavailable, using background fallback" >&2
    launch_agent_mail_fallback
fi
EOF
)"

    _stack_run_as_user "$service_cmd"
}

# Wait for the managed Agent Mail service to become healthy.
_stack_wait_for_agent_mail_health() {
    local waited=0
    local max_wait=30

    until _stack_agent_mail_healthy && _stack_agent_mail_readiness; do
        if [[ "$waited" -ge "$max_wait" ]]; then
            return 1
        fi
        sleep 2
        waited=$((waited + 2))
    done

    return 0
}

# Check if a stack tool is installed
_stack_is_installed() {
    local tool="$1"
    local cmd="${STACK_COMMANDS[$tool]}"

    if [[ -z "$cmd" ]]; then
        return 1
    fi

    # Check in common locations
    local target_user="${TARGET_USER:-ubuntu}"
    local target_home=""
    target_home="$(_stack_target_home "$target_user")"

    # Check PATH
    if _stack_command_exists "$cmd"; then
        return 0
    fi

    # Check user's local bin
    if [[ -x "$target_home/.local/bin/$cmd" ]]; then
        return 0
    fi

    # Check user's bin
    if [[ -x "$target_home/bin/$cmd" ]]; then
        return 0
    fi

    return 1
}

# PCR is only fully installed once both the hook binary and Claude settings entry exist.
_stack_pcr_installed() {
    local target_home=""
    target_home="$(_stack_target_home "${TARGET_USER:-ubuntu}")"
    local hook_script="$target_home/.local/bin/claude-post-compact-reminder"
    local settings_file="$target_home/.claude/settings.json"
    local alt_settings_file="$target_home/.config/claude/settings.json"

    [[ -x "$hook_script" ]] || return 1

    if [[ -f "$settings_file" ]] && grep -q "claude-post-compact-reminder" "$settings_file" 2>/dev/null; then
        return 0
    fi

    if [[ -f "$alt_settings_file" ]] && grep -q "claude-post-compact-reminder" "$alt_settings_file" 2>/dev/null; then
        return 0
    fi

    return 1
}

# Some stack tools are only "ready" when their managed service or config is in place.
_stack_tool_ready() {
    local tool="$1"

    case "$tool" in
        mcp_agent_mail)
            _stack_is_installed "$tool" && _stack_agent_mail_ready
            ;;
        pcr)
            _stack_pcr_installed
            ;;
        *)
            _stack_is_installed "$tool"
            ;;
    esac
}

# ============================================================
# Individual Tool Installers
# ============================================================

# Install NTM (Named Tmux Manager)
# Agent orchestration cockpit
install_ntm() {
    local tool="ntm"

    if _stack_is_installed "$tool"; then
        log_detail "${STACK_NAMES[$tool]} already installed"
        return 0
    fi

    log_detail "Installing ${STACK_NAMES[$tool]}..."

    if _stack_run_installer "$tool"; then
        if _stack_is_installed "$tool"; then
            log_success "${STACK_NAMES[$tool]} installed"
            return 0
        fi
    fi

    log_warn "${STACK_NAMES[$tool]} installation may have failed"
    return 1
}

# Install MCP Agent Mail
# Agent coordination server
install_mcp_agent_mail() {
    local tool="mcp_agent_mail"
    local target_user="${TARGET_USER:-ubuntu}"
    local target_home=""
    target_home="$(_stack_target_home "$target_user")"
    local target_dir="$target_home/mcp_agent_mail"

    if _stack_tool_ready "$tool"; then
        log_detail "${STACK_NAMES[$tool]} already installed and healthy"
        return 0
    fi

    if _stack_is_installed "$tool"; then
        log_detail "${STACK_NAMES[$tool]} already installed; ensuring managed service"
    else
        log_detail "Installing ${STACK_NAMES[$tool]}..."
        if ! _stack_run_installer "$tool" --dest "$target_dir" --yes; then
            log_warn "${STACK_NAMES[$tool]} installation may have failed"
            return 1
        fi
    fi

    if _stack_repair_agent_mail_cli_symlink; then
        log_detail "${STACK_NAMES[$tool]}: ensured am resolves to $target_dir/am"
    fi

    if ! _stack_is_installed "$tool"; then
        log_warn "${STACK_NAMES[$tool]} CLI missing after install"
        return 1
    fi

    if ! _stack_configure_agent_mail_service; then
        log_warn "${STACK_NAMES[$tool]} installed but managed service setup failed"
        return 1
    fi

    if ! _stack_wait_for_agent_mail_health; then
        log_warn "${STACK_NAMES[$tool]} installed but service did not become healthy on http://127.0.0.1:8765"
        return 1
    fi

    log_success "${STACK_NAMES[$tool]} installed and running on http://127.0.0.1:8765"
    return 0
}

# Install Ultimate Bug Scanner (UBS)
# Bug scanning with guardrails
install_ubs() {
    local tool="ubs"

    if _stack_is_installed "$tool"; then
        log_detail "${STACK_NAMES[$tool]} already installed"
        return 0
    fi

    log_detail "Installing ${STACK_NAMES[$tool]}..."

    # UBS uses --easy-mode for simplified setup
    # Also add --yes for non-interactive installs if needed by UBS installer
    local -a args=(--easy-mode)
    if ! _stack_is_interactive; then
        args+=(--yes)
    fi

    if _stack_run_installer "$tool" "${args[@]}"; then
        if _stack_is_installed "$tool"; then
            log_success "${STACK_NAMES[$tool]} installed"
            return 0
        fi
    fi

    log_warn "${STACK_NAMES[$tool]} installation may have failed"
    return 1
}

# Install Beads Viewer (BV)
# Task management TUI
install_bv() {
    local tool="bv"

    if _stack_is_installed "$tool"; then
        log_detail "${STACK_NAMES[$tool]} already installed"
        return 0
    fi

    log_detail "Installing ${STACK_NAMES[$tool]}..."

    if _stack_run_installer "$tool"; then
        if _stack_is_installed "$tool"; then
            log_success "${STACK_NAMES[$tool]} installed"
            return 0
        fi
    fi

    log_warn "${STACK_NAMES[$tool]} installation may have failed"
    return 1
}

# Install Beads Rust (BR)
# Local-first issue tracker CLI
install_beads_rust() {
    local tool="br"

    if _stack_is_installed "$tool"; then
        log_detail "${STACK_NAMES[$tool]} already installed"
        return 0
    fi

    log_detail "Installing ${STACK_NAMES[$tool]}..."

    if _stack_run_installer "$tool"; then
        if _stack_is_installed "$tool"; then
            log_success "${STACK_NAMES[$tool]} installed"
            return 0
        fi
    fi

    log_warn "${STACK_NAMES[$tool]} installation may have failed"
    return 1
}

# Install CASS (Coding Agent Session Search)
# Unified session search
install_cass() {
    local tool="cass"

    if _stack_is_installed "$tool"; then
        log_detail "${STACK_NAMES[$tool]} already installed"
        return 0
    fi

    log_detail "Installing ${STACK_NAMES[$tool]}..."

    # CASS uses --easy-mode --verify for simplified setup with verification
    if _stack_run_installer "$tool" --easy-mode --verify; then
        if _stack_is_installed "$tool"; then
            log_success "${STACK_NAMES[$tool]} installed"
            return 0
        fi
    fi

    log_warn "${STACK_NAMES[$tool]} installation may have failed"
    return 1
}

# Install CM (CASS Memory System)
# Procedural memory for agents
install_cm() {
    local tool="cm"

    if _stack_is_installed "$tool"; then
        log_detail "${STACK_NAMES[$tool]} already installed"
        return 0
    fi

    log_detail "Installing ${STACK_NAMES[$tool]}..."

    # CM uses --easy-mode --verify for simplified setup with verification
    if _stack_run_installer "$tool" --easy-mode --verify; then
        if _stack_is_installed "$tool"; then
            log_success "${STACK_NAMES[$tool]} installed"
            return 0
        fi
    fi

    log_warn "${STACK_NAMES[$tool]} installation may have failed"
    return 1
}

# Install CAAM (Coding Agent Account Manager)
# Auth switching
install_caam() {
    local tool="caam"

    if _stack_is_installed "$tool"; then
        log_detail "${STACK_NAMES[$tool]} already installed"
        return 0
    fi

    log_detail "Installing ${STACK_NAMES[$tool]}..."

    if _stack_run_installer "$tool"; then
        if _stack_is_installed "$tool"; then
            log_success "${STACK_NAMES[$tool]} installed"
            return 0
        fi
    fi

    log_warn "${STACK_NAMES[$tool]} installation may have failed"
    return 1
}

# Install SLB (Simultaneous Launch Button)
# Two-person rule for dangerous commands
install_slb() {
    local tool="slb"

    if _stack_is_installed "$tool"; then
        log_detail "${STACK_NAMES[$tool]} already installed"
        return 0
    fi

    log_detail "Installing ${STACK_NAMES[$tool]}..."

    # SLB upstream installer is broken due to module path mismatch
    # Build from source instead
    local slb_build_cmd
    slb_build_cmd="$(cat <<'EOF'
set -euo pipefail
mkdir -p "$HOME/go/bin"
SLB_TMP="$(mktemp -d "${TMPDIR:-/tmp}/slb_build.XXXXXX")"
trap 'rm -rf "$SLB_TMP"' EXIT
cd "$SLB_TMP"
git clone --depth 1 https://github.com/Dicklesworthstone/simultaneous_launch_button.git .
go build -o "$HOME/go/bin/slb" ./cmd/slb

# Add ~/go/bin to PATH if not already present
if ! grep -q 'export PATH=.*\$HOME/go/bin' ~/.zshrc 2>/dev/null; then
  echo '' >> ~/.zshrc
  echo '# Go binaries' >> ~/.zshrc
  echo 'export PATH="$HOME/go/bin:$PATH"' >> ~/.zshrc
fi
EOF
)"

    if _stack_run_as_user "$slb_build_cmd"; then
        if _stack_is_installed "$tool"; then
            log_success "${STACK_NAMES[$tool]} installed"
            return 0
        fi
    fi

    log_warn "${STACK_NAMES[$tool]} installation may have failed"
    return 1
}

# Install RU (Repo Updater)
# Multi-repo sync + AI automation
install_ru() {
    local tool="ru"

    if _stack_is_installed "$tool"; then
        log_detail "${STACK_NAMES[$tool]} already installed"
        return 0
    fi

    log_detail "Installing ${STACK_NAMES[$tool]}..."

    # RU uses an environment variable, not CLI flags, for unattended install.
    if _stack_run_verified_installer_with_env "$tool" "RU_NON_INTERACTIVE=1"; then
        if _stack_is_installed "$tool"; then
            log_success "${STACK_NAMES[$tool]} installed"
            return 0
        fi
    fi

    log_warn "${STACK_NAMES[$tool]} installation may have failed"
    return 1
}

# Install DCG (Destructive Command Guard)
# Blocks dangerous commands
install_dcg() {
    local tool="dcg"

    if _stack_is_installed "$tool"; then
        log_detail "${STACK_NAMES[$tool]} already installed"
        return 0
    fi

    log_detail "Installing ${STACK_NAMES[$tool]}..."

    # DCG uses --easy-mode
    local -a args=(--easy-mode)
    if ! _stack_is_interactive; then
        args+=(--yes)
    fi

    if _stack_run_installer "$tool" "${args[@]}"; then
        if _stack_is_installed "$tool"; then
            log_success "${STACK_NAMES[$tool]} installed"
            
            # Register hook if Claude Code is present
            if _stack_command_exists claude; then
                log_detail "Registering DCG hook..."
                _stack_run_as_user "dcg install --force" || log_warn "Failed to register DCG hook"
            fi
            return 0
        fi
    fi

    log_warn "${STACK_NAMES[$tool]} installation may have failed"
    return 1
}

# Install RCH (Remote Compilation Helper)
# Build offloading daemon
install_rch() {
    local tool="rch"

    if _stack_is_installed "$tool"; then
        log_detail "${STACK_NAMES[$tool]} already installed"
        return 0
    fi

    log_detail "Installing ${STACK_NAMES[$tool]}..."

    if _stack_run_installer "$tool"; then
        if _stack_is_installed "$tool"; then
            log_success "${STACK_NAMES[$tool]} installed"
            return 0
        fi
    fi

    log_warn "${STACK_NAMES[$tool]} installation may have failed"
    return 1
}

# Install PT (Process Triage)
# Bayesian process cleanup
install_pt() {
    local tool="pt"

    if _stack_is_installed "$tool"; then
        log_detail "${STACK_NAMES[$tool]} already installed"
        return 0
    fi

    log_detail "Installing ${STACK_NAMES[$tool]}..."

    if _stack_run_installer "$tool"; then
        if _stack_is_installed "$tool"; then
            log_success "${STACK_NAMES[$tool]} installed"
            return 0
        fi
    fi

    log_warn "${STACK_NAMES[$tool]} installation may have failed"
    return 1
}

# Install Frankensearch (fsfs)
# Hybrid search engine
install_fsfs() {
    local tool="fsfs"

    if _stack_is_installed "$tool"; then
        log_detail "${STACK_NAMES[$tool]} already installed"
        return 0
    fi

    log_detail "Installing ${STACK_NAMES[$tool]}..."

    if _stack_run_verified_installer "$tool" --easy-mode; then
        if _stack_is_installed "$tool"; then
            log_success "${STACK_NAMES[$tool]} installed"
            return 0
        fi
    fi

    log_warn "${STACK_NAMES[$tool]} installation may have failed"
    return 1
}

# Install SBH (Storage Ballast Helper)
# Disk pressure defense daemon
install_sbh() {
    local tool="sbh"

    if _stack_is_installed "$tool"; then
        log_detail "${STACK_NAMES[$tool]} already installed"
        return 0
    fi

    log_detail "Installing ${STACK_NAMES[$tool]}..."

    if _stack_run_installer "$tool"; then
        if _stack_is_installed "$tool"; then
            log_success "${STACK_NAMES[$tool]} installed"
            return 0
        fi
    fi

    log_warn "${STACK_NAMES[$tool]} installation may have failed"
    return 1
}

# Install CASR (Cross-Agent Session Resumer)
# Cross-provider session handoff
install_casr() {
    local tool="casr"

    if _stack_is_installed "$tool"; then
        log_detail "${STACK_NAMES[$tool]} already installed"
        return 0
    fi

    log_detail "Installing ${STACK_NAMES[$tool]}..."

    if _stack_run_installer "$tool"; then
        if _stack_is_installed "$tool"; then
            log_success "${STACK_NAMES[$tool]} installed"
            return 0
        fi
    fi

    log_warn "${STACK_NAMES[$tool]} installation may have failed"
    return 1
}

# Install DSR (Doodlestein Self-Releaser)
# Fallback release infrastructure
install_dsr() {
    local tool="dsr"

    if _stack_is_installed "$tool"; then
        log_detail "${STACK_NAMES[$tool]} already installed"
        return 0
    fi

    log_detail "Installing ${STACK_NAMES[$tool]}..."

    if _stack_run_verified_installer "$tool" --easy-mode; then
        if _stack_is_installed "$tool"; then
            log_success "${STACK_NAMES[$tool]} installed"
            return 0
        fi
    fi

    log_warn "${STACK_NAMES[$tool]} installation may have failed"
    return 1
}

# Install ASB (Agent Settings Backup)
# Agent config backup tool
install_asb() {
    local tool="asb"

    if _stack_is_installed "$tool"; then
        log_detail "${STACK_NAMES[$tool]} already installed"
        return 0
    fi

    log_detail "Installing ${STACK_NAMES[$tool]}..."

    if _stack_run_installer "$tool"; then
        if _stack_is_installed "$tool"; then
            log_success "${STACK_NAMES[$tool]} installed"
            return 0
        fi
    fi

    log_warn "${STACK_NAMES[$tool]} installation may have failed"
    return 1
}

# Install PCR (Post-Compact Reminder)
# Claude Code hook for AGENTS.md re-read after compaction
install_pcr() {
    local tool="pcr"
    if _stack_pcr_installed; then
        log_detail "${STACK_NAMES[$tool]} already installed"
        return 0
    fi

    if ! _stack_command_exists claude; then
        log_detail "Skipping ${STACK_NAMES[$tool]} because Claude Code is not installed"
        return 0
    fi

    log_detail "Installing ${STACK_NAMES[$tool]}..."

    if _stack_run_installer "$tool" --yes; then
        if _stack_pcr_installed; then
            log_success "${STACK_NAMES[$tool]} installed"
            return 0
        fi
    fi

    log_warn "${STACK_NAMES[$tool]} installation may have failed"
    return 1
}

# ============================================================
# Verification Functions
# ============================================================

# Verify all stack tools are installed
verify_stack() {
    local all_pass=true
    local installed_count=0
    local total_count=${#STACK_COMMANDS[@]}

    log_detail "Verifying Dicklesworthstone stack..."

    for tool in ntm mcp_agent_mail ubs bv br cass cm caam slb ru dcg rch pt fsfs sbh casr dsr asb pcr; do
        local cmd="${STACK_COMMANDS[$tool]}"
        local name="${STACK_NAMES[$tool]}"

        if _stack_tool_ready "$tool"; then
            log_detail "  $cmd: installed"
            ((installed_count += 1))
        else
            log_warn "  Not ready: $cmd ($name)"
            all_pass=false
        fi
    done

    if [[ "$all_pass" == "true" ]]; then
        log_success "All $total_count stack tools verified"
        return 0
    else
        log_warn "Stack: $installed_count/$total_count tools installed"
        return 1
    fi
}

# Check if stack tools respond to --help
verify_stack_help() {
    local failures=()

    log_detail "Testing stack tools --help..."

    for tool in ntm mcp_agent_mail ubs bv br cass cm caam slb ru dcg rch pt fsfs sbh casr dsr asb pcr; do
        local cmd="${STACK_COMMANDS[$tool]}"

        if _stack_is_installed "$tool"; then
            if ! _stack_run_as_user "$cmd --help >/dev/null 2>&1"; then
                failures+=("$cmd")
            fi
        fi
    done

    if [[ ${#failures[@]} -gt 0 ]]; then
        log_warn "Stack tools --help failed: ${failures[*]}"
        return 1
    fi

    log_success "All stack tools respond to --help"
    return 0
}

# Get versions of installed stack tools (for doctor output)
get_stack_versions() {
    echo "Dicklesworthstone Stack Versions:"

    for tool in ntm mcp_agent_mail ubs bv br cass cm caam slb ru dcg rch pt fsfs sbh casr dsr asb pcr; do
        local cmd="${STACK_COMMANDS[$tool]}"
        local name="${STACK_NAMES[$tool]}"

        if _stack_is_installed "$tool"; then
            local version
            version=$(_stack_run_as_user "$cmd --version 2>/dev/null" || echo "installed")
            echo "  $cmd: $version"
        fi
    done
}

# ============================================================
# Main Installation Function
# ============================================================

# Install all stack tools (called by install.sh)
install_all_stack() {
    log_step "7/8" "Installing Dicklesworthstone stack..."

    # Install in recommended order (original 10 tools)
    install_ntm
    install_mcp_agent_mail
    install_ubs
    install_bv
    install_beads_rust
    install_cass
    install_cm
    install_caam
    install_slb
    install_ru
    install_dcg

    # Additional tools (8 new integrations)
    install_rch
    install_pt
    install_fsfs
    install_sbh
    install_casr
    install_dsr
    install_asb
    install_pcr

    # Verify installation
    verify_stack

    log_success "Dicklesworthstone stack installation complete"
}

# ============================================================
# Module can be sourced or run directly
# ============================================================

# If run directly (not sourced), execute main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_all_stack "$@"
fi
