#!/bin/bash
# ACFS Auto-Fix Change Recording and Undo System
# Tracks all auto-fix actions with selective undo capability
# Implements crash-safe persistence with fsync, integrity verification, and automatic rollback

# Prevent multiple sourcing
[[ -n "${_ACFS_AUTOFIX_SOURCED:-}" ]] && return 0
_ACFS_AUTOFIX_SOURCED=1

# =============================================================================
# State Directory Configuration
# =============================================================================

autofix_sanitize_abs_nonroot_path() {
    local path="${1:-}"

    [[ -n "$path" ]] || return 1
    [[ "$path" == /* ]] || return 1
    [[ "$path" != "/" ]] || return 1

    printf '%s\n' "${path%/}"
}

autofix_validate_target_user() {
    local user="${1:-}"
    [[ -n "$user" ]] || return 1
    [[ "$user" =~ ^[a-z_][a-z0-9._-]*$ ]]
}

autofix_home_for_user() {
    local user="${1:-}"
    local passwd_home=""

    autofix_validate_target_user "$user" || [[ "$user" == "root" ]] || return 1

    if [[ "$user" == "root" ]]; then
        printf '/root\n'
        return 0
    fi

    passwd_home="$(getent passwd "$user" 2>/dev/null | cut -d: -f6 | head -n1 || true)"
    if passwd_home="$(autofix_sanitize_abs_nonroot_path "$passwd_home" 2>/dev/null)"; then
        printf '%s\n' "$passwd_home"
        return 0
    fi

    if [[ "$(whoami 2>/dev/null || true)" == "$user" ]]; then
        passwd_home="$(autofix_sanitize_abs_nonroot_path "${HOME:-}" 2>/dev/null || true)"
        if [[ -n "$passwd_home" ]]; then
            printf '%s\n' "$passwd_home"
            return 0
        fi
    fi

    printf '/home/%s\n' "$user"
}

autofix_resolve_current_home() {
    local resolved_home=""
    local current_user=""

    resolved_home="$(autofix_sanitize_abs_nonroot_path "${HOME:-}" 2>/dev/null || true)"
    if [[ -n "$resolved_home" ]]; then
        printf '%s\n' "$resolved_home"
        return 0
    fi

    current_user="$(whoami 2>/dev/null || id -un 2>/dev/null || true)"
    if [[ -n "$current_user" ]]; then
        resolved_home="$(autofix_home_for_user "$current_user" 2>/dev/null || true)"
        if [[ -n "$resolved_home" ]]; then
            printf '%s\n' "$resolved_home"
            return 0
        fi
    fi

    return 1
}

autofix_runtime_home() {
    local runtime_home=""
    local target_user="${TARGET_USER:-}"

    runtime_home="$(autofix_sanitize_abs_nonroot_path "${TARGET_HOME:-}" 2>/dev/null || true)"
    if [[ -n "$runtime_home" ]]; then
        printf '%s\n' "$runtime_home"
        return 0
    fi

    if autofix_validate_target_user "$target_user"; then
        runtime_home="$(autofix_home_for_user "$target_user" 2>/dev/null || true)"
        if [[ -n "$runtime_home" ]]; then
            printf '%s\n' "$runtime_home"
            return 0
        fi
    fi

    if autofix_validate_target_user "${SUDO_USER:-}"; then
        runtime_home="$(autofix_home_for_user "$SUDO_USER" 2>/dev/null || true)"
        if [[ -n "$runtime_home" ]]; then
            printf '%s\n' "$runtime_home"
            return 0
        fi
    fi

    autofix_resolve_current_home
}

autofix_refresh_state_paths() {
    local runtime_home=""
    local state_dir=""

    state_dir="$(autofix_sanitize_abs_nonroot_path "${ACFS_STATE_DIR:-}" 2>/dev/null || true)"
    if [[ -z "$state_dir" ]]; then
        runtime_home="$(autofix_runtime_home 2>/dev/null || true)"
        if [[ -n "$runtime_home" ]]; then
            state_dir="$runtime_home/.acfs/autofix"
        else
            state_dir="/tmp/acfs-autofix.$(id -u 2>/dev/null || echo unknown)"
        fi
    fi

    ACFS_STATE_DIR="$state_dir"
    ACFS_CHANGES_FILE="${ACFS_STATE_DIR}/changes.jsonl"
    ACFS_UNDOS_FILE="${ACFS_STATE_DIR}/undos.jsonl"
    ACFS_BACKUPS_DIR="${ACFS_STATE_DIR}/backups"
    ACFS_LOCK_FILE="${ACFS_STATE_DIR}/.lock"
    ACFS_INTEGRITY_FILE="${ACFS_STATE_DIR}/.integrity"
}

autofix_refresh_state_paths

# In-memory change records
declare -gA ACFS_CHANGE_RECORDS  # id -> JSON record (global; file may be sourced inside a function)
declare -ga ACFS_CHANGE_ORDER    # Ordered list of change IDs (global)

# Session management
ACFS_SESSION_ID=""
ACFS_AUTOFIX_INITIALIZED=false
ACFS_AUTOFIX_LOCK_FD=""

# =============================================================================
# Logging Helpers (avoid dependency on logging.sh)
# =============================================================================

_autofix_log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case "$level" in
        ERROR) echo "[$timestamp] ERROR: $message" >&2 ;;
        WARN)  echo "[$timestamp] WARN:  $message" >&2 ;;
        INFO)  echo "[$timestamp] INFO:  $message" >&2 ;;
        DEBUG) [[ "${ACFS_DEBUG:-}" == "true" ]] && echo "[$timestamp] DEBUG: $message" || true ;;
    esac
}

log_error() { _autofix_log ERROR "$@"; }
log_warn()  { _autofix_log WARN "$@"; }
log_info()  { _autofix_log INFO "$@"; }
log_debug() { _autofix_log DEBUG "$@"; }

# =============================================================================
# Crash-Safe I/O Functions
# =============================================================================

# Explicitly sync a file to disk
fsync_file() {
    local file_path="$1"

    # Method 1: Use Python for true fsync (most reliable)
    # Pass path via sys.argv to avoid shell injection with special characters
    if command -v python3 &>/dev/null; then
        python3 - "$file_path" <<'PYEOF' 2>/dev/null && return 0
import os, sys
file_path = sys.argv[1]
fd = os.open(file_path, os.O_RDONLY)
os.fsync(fd)
os.close(fd)
# Also sync the directory to ensure filename is durable
dir_fd = os.open(os.path.dirname(file_path), os.O_RDONLY)
os.fsync(dir_fd)
os.close(dir_fd)
PYEOF
    fi

    # Method 2: Use dd with fsync flag
    if dd --help 2>&1 | grep -q 'fsync'; then
        dd if=/dev/null of="$file_path" oflag=append,fsync conv=notrunc bs=1 count=0 2>/dev/null
        return $?
    fi

    # Method 3: Fallback to sync (less precise, syncs everything)
    sync
    return 0
}

# Sync a directory's metadata
fsync_directory() {
    local dir_path="$1"

    # Pass path via sys.argv to avoid shell injection with special characters
    if command -v python3 &>/dev/null; then
        python3 - "$dir_path" <<'PYEOF' 2>/dev/null && return 0
import os, sys
dir_path = sys.argv[1]
fd = os.open(dir_path, os.O_RDONLY)
os.fsync(fd)
os.close(fd)
PYEOF
    fi

    sync
    return 0
}

# Atomically write content to a file with fsync
write_atomic() {
    local target_file="$1"
    local content="$2"

    local target_dir
    target_dir=$(dirname "$target_file")
    local temp_file
    temp_file=$(mktemp -p "$target_dir" ".tmp.XXXXXX" 2>/dev/null) || {
        log_error "Failed to create temp file for atomic write: $target_file"
        return 1
    }
    # Use ${temp_file:-} to avoid "unbound variable" under set -u when the
    # RETURN trap leaks to a calling scope (bash < 5.1 bug, or functrace).
    trap 'rm -f "${temp_file:-}" 2>/dev/null || true; trap - RETURN' RETURN

    # Write content to temp file
    if ! printf '%s\n' "$content" > "$temp_file"; then
        log_error "Failed to write temp file: $temp_file"
        return 1
    fi

    # Sync temp file content to disk
    if ! fsync_file "$temp_file"; then
        log_warn "Failed to fsync temp file: $temp_file"
    fi

    # Atomic rename
    if ! mv "$temp_file" "$target_file"; then
        log_error "Failed to move temp file into place: $target_file"
        return 1
    fi

    # Sync directory to ensure rename is durable
    if ! fsync_directory "$target_dir"; then
        log_warn "Failed to fsync directory: $target_dir"
    fi

    return 0
}

# Atomically append to a file with fsync
append_atomic() {
    local target_file="$1"
    local content="$2"

    local target_dir
    target_dir=$(dirname "$target_file")
    local temp_file
    temp_file=$(mktemp -p "$target_dir" ".tmp.XXXXXX" 2>/dev/null) || {
        log_error "Failed to create temp file for atomic append: $target_file"
        return 1
    }
    # Use ${temp_file:-} to avoid "unbound variable" under set -u when the
    # RETURN trap leaks to a calling scope (bash < 5.1 bug, or functrace).
    trap 'rm -f "${temp_file:-}" 2>/dev/null || true; trap - RETURN' RETURN

    # Copy existing content + new line to temp
    if [[ -f "$target_file" ]]; then
        cat "$target_file" > "$temp_file" || { 
            log_error "Failed to copy existing content to temp file: $temp_file"
            return 1
        }
    fi
    if ! printf '%s\n' "$content" >> "$temp_file"; then
        log_error "Failed to append content to temp file: $temp_file"
        return 1
    fi

    # Sync and rename
    if ! fsync_file "$temp_file"; then
        log_warn "Failed to fsync temp file: $temp_file"
    fi

    if ! mv "$temp_file" "$target_file"; then
        log_error "Failed to move temp file into place: $target_file"
        return 1
    fi

    if ! fsync_directory "$target_dir"; then
        log_warn "Failed to fsync directory: $target_dir"
    fi

    return 0
}

# =============================================================================
# Integrity Verification
# =============================================================================

# Compute checksum for a change record (excluding the checksum field itself)
compute_record_checksum() {
    local record="$1"

    # Remove the record_checksum field before computing
    local record_without_checksum
    record_without_checksum=$(echo "$record" | jq -c 'del(.record_checksum)')

    echo "$record_without_checksum" | sha256sum | cut -d' ' -f1
}

autofix_path_fingerprint() {
    local input="${1:-}"

    if command -v sha256sum &>/dev/null; then
        printf '%s' "$input" | sha256sum | cut -d' ' -f1
        return 0
    fi

    if command -v shasum &>/dev/null; then
        printf '%s' "$input" | shasum -a 256 | cut -d' ' -f1
        return 0
    fi

    cksum <<<"$input" | awk '{print $1}'
}

autofix_trim_leading_whitespace() {
    local value="${1:-}"
    value="${value#"${value%%[![:space:]]*}"}"
    printf '%s\n' "$value"
}

autofix_is_manual_undo_command() {
    local undo_command=""

    undo_command="$(autofix_trim_leading_whitespace "${1:-}")"
    [[ -z "$undo_command" || "$undo_command" == \#* ]]
}

autofix_manual_undo_instructions() {
    local undo_command=""

    undo_command="$(autofix_trim_leading_whitespace "${1:-}")"
    undo_command="${undo_command#\#}"
    autofix_trim_leading_whitespace "$undo_command"
}

autofix_normalize_backups_json() {
    local backups_json="${1:-[]}"

    printf '%s' "$backups_json" | jq -c '
        (if . == null then []
         elif type == "array" then .
         elif type == "object" then [.]
         else error("backups must be an array or object")
         end) as $normalized
        | if all($normalized[]?; type == "object" and (.backup? != null)) then
              $normalized
          else
              error("backup entries must be objects containing .backup")
          end
    ' 2>/dev/null
}

autofix_record_is_reversible() {
    local record_json="$1"
    local undo_command=""
    local reversible="true"

    undo_command="$(printf '%s' "$record_json" | jq -r '.undo_command // ""' 2>/dev/null || true)"
    if autofix_is_manual_undo_command "$undo_command"; then
        return 1
    fi

    reversible="$(printf '%s' "$record_json" | jq -r '.reversible // true' 2>/dev/null || printf 'true\n')"
    [[ "$reversible" == "true" ]]
}

autofix_backup_restore_command() {
    local backup_json="$1"
    local original_path=""
    local backup_path=""
    local parent_dir=""
    local restore_command=""

    original_path="$(printf '%s' "$backup_json" | jq -r '.original // empty' 2>/dev/null || true)"
    backup_path="$(printf '%s' "$backup_json" | jq -r '.backup // empty' 2>/dev/null || true)"
    [[ -n "$original_path" && -n "$backup_path" ]] || return 1

    parent_dir="$(dirname "$original_path")"
    printf -v restore_command 'rm -rf %q && mkdir -p %q && cp -a %q %q' \
        "$original_path" "$parent_dir" "$backup_path" "$original_path"
    printf '%s\n' "$restore_command"
}

autofix_undone_ids_json() {
    if [[ -f "$ACFS_UNDOS_FILE" ]] && [[ -s "$ACFS_UNDOS_FILE" ]]; then
        jq -s '[.[].undone // empty]' "$ACFS_UNDOS_FILE" 2>/dev/null || printf '[]\n'
        return 0
    fi

    printf '[]\n'
}

autofix_active_backup_paths() {
    local undone_ids_json="[]"

    [[ -f "$ACFS_CHANGES_FILE" ]] || return 0
    [[ -s "$ACFS_CHANGES_FILE" ]] || return 0

    undone_ids_json="$(autofix_undone_ids_json)"
    jq -r --argjson undone "$undone_ids_json" '
        select((.id // "") as $id | (($undone | index($id)) | not))
        | (.backups // [] | if type == "array" then . elif type == "object" then [.] else [] end)[]
        | select(type == "object" and (.backup? != null))
        | .backup // empty
    ' "$ACFS_CHANGES_FILE" 2>/dev/null | awk 'NF' | sort -u
}

# Verify integrity of the state files
verify_state_integrity() {
    log_debug "[INTEGRITY] Verifying state file integrity..."

    local errors=0

    # Check changes file
    if [[ -f "$ACFS_CHANGES_FILE" ]]; then
        local line_num=0
        while IFS= read -r line; do
            ((line_num++)) || true

            # Skip empty lines
            [[ -z "$line" ]] && continue

            # Verify JSON is valid
            if ! echo "$line" | jq -e . >/dev/null 2>&1; then
                log_error "[INTEGRITY] Invalid JSON at line $line_num in changes.jsonl"
                ((errors++)) || true
                continue
            fi

            # Verify record checksum if present
            local stored_checksum
            stored_checksum=$(echo "$line" | jq -r '.record_checksum // empty')
            if [[ -n "$stored_checksum" ]]; then
                local computed_checksum
                computed_checksum=$(compute_record_checksum "$line")
                if [[ "$stored_checksum" != "$computed_checksum" ]]; then
                    log_error "[INTEGRITY] Checksum mismatch at line $line_num"
                    log_error "  Stored:   $stored_checksum"
                    log_error "  Computed: $computed_checksum"
                    ((errors++)) || true
                fi
            fi
        done < "$ACFS_CHANGES_FILE"
    fi

    # Check undos file
    if [[ -f "$ACFS_UNDOS_FILE" ]]; then
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            if ! echo "$line" | jq -e . >/dev/null 2>&1; then
                log_error "[INTEGRITY] Invalid JSON in undos.jsonl"
                ((errors++)) || true
            fi
        done < "$ACFS_UNDOS_FILE"
    fi

    # Verify active backup paths match their recorded checksums
    if [[ -f "$ACFS_CHANGES_FILE" ]]; then
        local backup_infos
        local undone_ids_json="[]"
        undone_ids_json="$(autofix_undone_ids_json)"
        backup_infos=$(jq -s --argjson undone "$undone_ids_json" '
            [
              .[]
              | select((.id // "") as $id | (($undone | index($id)) | not))
              | (.backups // [] | if type == "array" then . elif type == "object" then [.] else [] end)[]
              | select(type == "object" and (.backup? != null))
            ]
        ' "$ACFS_CHANGES_FILE" 2>/dev/null)
        if [[ -n "$backup_infos" ]] && [[ "$backup_infos" != "[]" ]]; then
            local backup_info backup_path expected_checksum actual_checksum
            while IFS= read -r backup_info; do
                backup_path=$(echo "$backup_info" | jq -r '.backup')
                expected_checksum=$(echo "$backup_info" | jq -r '.checksum')

                if [[ -e "$backup_path" ]]; then
                    actual_checksum=$(calculate_backup_checksum "$backup_path" 2>/dev/null || true)
                    if [[ -z "$actual_checksum" ]]; then
                        log_error "[INTEGRITY] Could not checksum backup path: $backup_path"
                        ((errors++)) || true
                        continue
                    fi
                    if [[ "$actual_checksum" != "$expected_checksum" ]]; then
                        log_error "[INTEGRITY] Backup path corrupted: $backup_path"
                        ((errors++)) || true
                    fi
                else
                    log_error "[INTEGRITY] Backup path missing: $backup_path"
                    ((errors++)) || true
                fi
            done < <(echo "$backup_infos" | jq -c '.[]')
        fi
    fi

    if [[ $errors -gt 0 ]]; then
        log_error "[INTEGRITY] Found $errors integrity errors"
        return 1
    fi

    log_debug "[INTEGRITY] All state files verified OK"
    return 0
}

# Attempt to repair corrupted state files
repair_state_files() {
    log_info "[REPAIR] Attempting to repair state files..."

    local repaired=0

    # Repair changes file - keep only valid JSON lines with valid record checksums
    if [[ -f "$ACFS_CHANGES_FILE" ]]; then
        local temp_file
        temp_file=$(mktemp -p "$(dirname "$ACFS_CHANGES_FILE")" ".tmp.XXXXXX" 2>/dev/null) || {
            log_error "Failed to create temp file for changes repair"
            return 1
        }
        trap 'rm -f "${temp_file:-}" 2>/dev/null || true; trap - RETURN' RETURN
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            if echo "$line" | jq -e . >/dev/null 2>&1; then
                local stored_checksum computed_checksum
                stored_checksum=$(echo "$line" | jq -r '.record_checksum // empty' 2>/dev/null)
                if [[ -n "$stored_checksum" ]]; then
                    computed_checksum=$(compute_record_checksum "$line")
                    if [[ "$stored_checksum" != "$computed_checksum" ]]; then
                        log_warn "[REPAIR] Discarding checksum-corrupt line: ${line:0:50}..."
                        ((++repaired))
                        continue
                    fi
                fi
                printf '%s\n' "$line" >> "$temp_file"
            else
                log_warn "[REPAIR] Discarding invalid line: ${line:0:50}..."
                ((++repaired))
            fi
        done < "$ACFS_CHANGES_FILE"

        if [[ $repaired -gt 0 ]]; then
            mv "$temp_file" "$ACFS_CHANGES_FILE"
            fsync_file "$ACFS_CHANGES_FILE"
            log_info "[REPAIR] Removed $repaired invalid lines from changes.jsonl"
        else
            rm -f "$temp_file" 2>/dev/null || true
        fi
    fi

    # Same for undos file
    if [[ -f "$ACFS_UNDOS_FILE" ]]; then
        local temp_file repaired_undos=0
        temp_file=$(mktemp -p "$(dirname "$ACFS_UNDOS_FILE")" ".tmp.XXXXXX" 2>/dev/null) || {
            log_error "Failed to create temp file for undos repair"
            return 1
        }
        trap 'rm -f "${temp_file:-}" 2>/dev/null || true; trap - RETURN' RETURN
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            if echo "$line" | jq -e . >/dev/null 2>&1; then
                printf '%s\n' "$line" >> "$temp_file"
            else
                log_warn "[REPAIR] Discarding invalid undo line: ${line:0:50}..."
                ((++repaired_undos))
            fi
        done < "$ACFS_UNDOS_FILE"

        if [[ $repaired_undos -gt 0 ]]; then
            mv "$temp_file" "$ACFS_UNDOS_FILE"
            fsync_file "$ACFS_UNDOS_FILE"
            log_info "[REPAIR] Removed $repaired_undos invalid lines from undos.jsonl"
        else
            rm -f "$temp_file"
        fi
    fi

    log_info "[REPAIR] State file repair complete"
}

# Update the integrity checkpoint file
update_integrity_file() {
    local changes_checksum=""
    local undos_checksum=""
    local backup_count=0

    if [[ -f "$ACFS_CHANGES_FILE" ]]; then
        changes_checksum=$(sha256sum "$ACFS_CHANGES_FILE" | cut -d' ' -f1)
    fi

    if [[ -f "$ACFS_UNDOS_FILE" ]]; then
        undos_checksum=$(sha256sum "$ACFS_UNDOS_FILE" | cut -d' ' -f1)
    fi

    if [[ -d "$ACFS_BACKUPS_DIR" ]]; then
        backup_count=$(find "$ACFS_BACKUPS_DIR" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
    fi

    local integrity_record
    integrity_record=$(jq -n \
        --arg ts "$(date -Iseconds)" \
        --arg changes "$changes_checksum" \
        --arg undos "$undos_checksum" \
        --argjson backups "$backup_count" \
        '{
            timestamp: $ts,
            changes_file_checksum: $changes,
            undos_file_checksum: $undos,
            backup_file_count: $backups
        }')

    write_atomic "$ACFS_INTEGRITY_FILE" "$integrity_record"
}

# =============================================================================
# State Initialization
# =============================================================================

# Initialize state directory
init_autofix_state() {
    autofix_refresh_state_paths
    mkdir -p "$ACFS_STATE_DIR" || { log_error "Failed to create state directory: $ACFS_STATE_DIR"; return 1; }
    mkdir -p "$ACFS_BACKUPS_DIR" || { log_error "Failed to create backups directory: $ACFS_BACKUPS_DIR"; return 1; }
    touch "$ACFS_CHANGES_FILE" || { log_error "Failed to create changes file: $ACFS_CHANGES_FILE"; return 1; }
    touch "$ACFS_UNDOS_FILE" || { log_error "Failed to create undos file: $ACFS_UNDOS_FILE"; return 1; }

    # Verify integrity on startup
    if ! verify_state_integrity; then
        log_warn "[AUTO-FIX] State integrity check failed, repairing..."
        repair_state_files
    fi

    ACFS_AUTOFIX_INITIALIZED=true
}

# =============================================================================
# Session Management
# =============================================================================

# Start a new auto-fix session
start_autofix_session() {
    autofix_refresh_state_paths
    if [[ "$ACFS_AUTOFIX_INITIALIZED" != "true" ]]; then
        init_autofix_state
    fi

    ACFS_SESSION_ID="sess_$(date +%Y%m%d_%H%M%S)_$$"
    log_info "[AUTO-FIX] Starting session: $ACFS_SESSION_ID"

    # Acquire lock (prevent concurrent modifications)
    # NOTE: On bash 5.3+, `exec N>file` under set -e exits the script
    # before `if` can catch the failure. We test in a subshell first,
    # then only exec in the main shell if the subshell succeeded.
    ACFS_AUTOFIX_LOCK_FD=""
    if (exec 200>"$ACFS_LOCK_FILE") 2>/dev/null; then
        exec 200>"$ACFS_LOCK_FILE"
        ACFS_AUTOFIX_LOCK_FD=200
    elif (exec 199>"$ACFS_LOCK_FILE") 2>/dev/null; then
        exec 199>"$ACFS_LOCK_FILE"
        ACFS_AUTOFIX_LOCK_FD=199
    fi
    if [[ -n "$ACFS_AUTOFIX_LOCK_FD" ]]; then
        if ! flock -n "$ACFS_AUTOFIX_LOCK_FD"; then
            log_error "Another ACFS process is running auto-fix operations"
            return 1
        fi
    else
        log_error "Could not acquire autofix lock; aborting to avoid concurrent state corruption"
        return 1
    fi

    # Write session start marker
    write_atomic "$ACFS_STATE_DIR/.session" "{\"id\": \"$ACFS_SESSION_ID\", \"start\": \"$(date -Iseconds)\", \"pid\": $$}"

    # Reset in-memory state
    ACFS_CHANGE_RECORDS=()
    ACFS_CHANGE_ORDER=()

    return 0
}

# End auto-fix session
end_autofix_session() {
    log_info "[AUTO-FIX] Ending session: $ACFS_SESSION_ID (${#ACFS_CHANGE_ORDER[@]} changes)"

    # Update integrity file
    update_integrity_file

    # Remove session marker
    rm -f "$ACFS_STATE_DIR/.session"

    # Release lock (use whichever FD was acquired in start_autofix_session)
    if [[ -n "${ACFS_AUTOFIX_LOCK_FD:-}" ]]; then
        flock -u "$ACFS_AUTOFIX_LOCK_FD" 2>/dev/null || true
        ACFS_AUTOFIX_LOCK_FD=""
    fi
}

# =============================================================================
# Backup Functions
# =============================================================================

# Calculate a deterministic checksum for a file or directory path
calculate_backup_checksum() {
    local target_path="$1"

    if [[ -f "$target_path" ]]; then
        if command -v sha256sum &>/dev/null; then
            sha256sum "$target_path" | cut -d' ' -f1
            return $?
        fi
        if command -v shasum &>/dev/null; then
            shasum -a 256 "$target_path" | cut -d' ' -f1
            return $?
        fi
        return 1
    fi

    if [[ -d "$target_path" ]]; then
        if command -v sha256sum &>/dev/null; then
            tar --sort=name --mtime='UTC 1970-01-01' --owner=0 --group=0 --numeric-owner \
                -cf - -C "$target_path" . 2>/dev/null | sha256sum | cut -d' ' -f1
            return $?
        fi
        if command -v shasum &>/dev/null; then
            tar --sort=name --mtime='UTC 1970-01-01' --owner=0 --group=0 --numeric-owner \
                -cf - -C "$target_path" . 2>/dev/null | shasum -a 256 | cut -d' ' -f1
            return $?
        fi
    fi

    return 1
}

# Create a verified backup of a file with fsync
create_backup() {
    local original_path="$1"
    local _reason="${2:-autofix}"  # Reserved for future use in backup metadata
    local filename=""
    local path_fingerprint=""
    local backup_prefix=""
    local backup_index=1
    local backup_path=""

    if [[ ! -e "$original_path" ]]; then
        echo ""  # Return empty if file doesn't exist
        return 0
    fi

    filename=$(basename "$original_path")
    path_fingerprint="$(autofix_path_fingerprint "$original_path" | cut -c1-12)"
    backup_prefix="${filename}.${path_fingerprint}.${ACFS_SESSION_ID}"
    backup_path="${ACFS_BACKUPS_DIR}/${backup_prefix}.${backup_index}.backup"
    while [[ -e "$backup_path" ]]; do
        backup_index=$((backup_index + 1))
        backup_path="${ACFS_BACKUPS_DIR}/${backup_prefix}.${backup_index}.backup"
    done

    # Copy with metadata preservation
    if [[ -d "$original_path" ]]; then
        cp -a "$original_path" "$backup_path" || {
            log_error "Failed to create directory backup: $original_path"
            return 1
        }
    else
        cp -p "$original_path" "$backup_path" || {
            log_error "Failed to create file backup: $original_path"
            return 1
        }
    fi

    # Explicit fsync to ensure backup is durable
    if [[ -f "$backup_path" ]]; then
        if ! fsync_file "$backup_path"; then
            log_error "Failed to fsync backup file: $backup_path"
            rm -f "$backup_path"
            return 1
        fi
    elif [[ -d "$backup_path" ]]; then
        if ! fsync_directory "$backup_path"; then
            log_warn "Failed to fsync backup directory metadata: $backup_path"
        fi
    fi

    # Compute checksum for verification
    local checksum
    checksum=$(calculate_backup_checksum "$backup_path") || {
        log_error "Failed to compute checksum for backup: $backup_path"
        return 1
    }

    # Verify backup by comparing checksums
    local original_checksum
    original_checksum=$(calculate_backup_checksum "$original_path") || {
        log_error "Failed to compute checksum for original path: $original_path"
        return 1
    }
    if [[ "$checksum" != "$original_checksum" ]]; then
        log_error "Backup verification failed: checksum mismatch"
        log_error "  Original: $original_checksum"
        log_error "  Backup:   $checksum"
        if [[ -e "$backup_path" ]]; then
            rm -rf "$backup_path"
        fi
        return 1
    fi

    log_debug "[BACKUP] Created: $backup_path (checksum: ${checksum:0:16}...)"

    # Return JSON with backup info (compact for embedding in records)
    jq -cn \
        --arg orig "$original_path" \
        --arg back "$backup_path" \
        --arg sum "$checksum" \
        --arg ts "$(date -Iseconds)" \
        '{original: $orig, backup: $back, checksum: $sum, created_at: $ts}'
}

# Verify a backup file's integrity
verify_backup_integrity() {
    local backup_json="$1"

    local backup_path
    backup_path=$(echo "$backup_json" | jq -r '.backup')
    local expected_checksum
    expected_checksum=$(echo "$backup_json" | jq -r '.checksum')

    if [[ ! -e "$backup_path" ]]; then
        log_error "Backup file missing: $backup_path"
        return 1
    fi

    if [[ -z "$expected_checksum" ]] || [[ "$expected_checksum" == "null" ]]; then
        log_warn "Backup checksum missing for: $backup_path"
        return 0
    fi

    local actual_checksum
    actual_checksum=$(calculate_backup_checksum "$backup_path") || {
        log_error "Failed to checksum backup path: $backup_path"
        return 1
    }
    if [[ "$actual_checksum" != "$expected_checksum" ]]; then
        log_error "Backup corrupted: $backup_path"
        log_error "  Expected: $expected_checksum"
        log_error "  Actual:   $actual_checksum"
        return 1
    fi

    log_debug "[VERIFY] Backup OK: $backup_path"
    return 0
}

# =============================================================================
# Change Recording
# =============================================================================

# Record a change with all metadata
record_change() {
    local category="$1"
    local description="$2"
    local undo_command="$3"
    local requires_root="${4:-false}"
    local severity="${5:-info}"
    local files_json="${6:-[]}"  # JSON array of affected files
    local backups_json="${7:-[]}"  # JSON array from create_backup
    local depends_on="${8:-[]}"  # JSON array of dependency change IDs
    local reversible="${9:-}"

    backups_json="$(autofix_normalize_backups_json "$backups_json")" || {
        log_error "Invalid backups JSON supplied for change: $description"
        return 1
    }
    if [[ -z "$reversible" ]]; then
        if autofix_is_manual_undo_command "$undo_command"; then
            reversible="false"
        else
            reversible="true"
        fi
    fi

    # Ensure state is initialized
    if [[ "$ACFS_AUTOFIX_INITIALIZED" != "true" ]]; then
        init_autofix_state || return 1
    fi

    # Generate unique ID
    local seq_num=0
    if [[ -f "$ACFS_CHANGES_FILE" ]]; then
        seq_num=$(wc -l < "$ACFS_CHANGES_FILE" 2>/dev/null) || seq_num=0
    fi
    local change_id
    change_id="chg_$(printf '%04d' $((seq_num + 1)))"
    local timestamp
    timestamp=$(date -Iseconds)

    # Build JSON record (without checksum first) - compact for JSONL
    local record
    record=$(jq -cn \
        --arg id "$change_id" \
        --arg ts "$timestamp" \
        --arg cat "$category" \
        --arg desc "$description" \
        --arg undo "$undo_command" \
        --argjson root "$requires_root" \
        --arg sev "$severity" \
        --argjson files "$files_json" \
        --argjson backups "$backups_json" \
        --argjson deps "$depends_on" \
        --arg sess "$ACFS_SESSION_ID" \
        --argjson reversible "$reversible" \
        '{
          id: $id,
          timestamp: $ts,
          category: $cat,
          description: $desc,
          undo_command: $undo,
          undo_requires_root: $root,
          severity: $sev,
          files_affected: $files,
          backups: $backups,
          depends_on: $deps,
          session_id: $sess,
          reversible: $reversible,
          undone: false
        }')

    # Compute and add record checksum (compact for JSONL)
    local record_checksum
    record_checksum=$(compute_record_checksum "$record")
    record=$(echo "$record" | jq -c --arg sum "$record_checksum" '. + {record_checksum: $sum}')

    # Store in memory
    ACFS_CHANGE_RECORDS["$change_id"]="$record"
    ACFS_CHANGE_ORDER+=("$change_id")

    # Persist atomically with fsync
    append_atomic "$ACFS_CHANGES_FILE" "$record"

    log_info "[AUTO-FIX] [$change_id] $description"

    echo "$change_id"  # Return ID for reference
}

# =============================================================================
# Undo Functions
# =============================================================================

# Check whether a change has already been undone
is_change_undone() {
    local change_id="$1"
    [[ -f "$ACFS_UNDOS_FILE" ]] || return 1
    jq -e --arg id "$change_id" 'select(.undone == $id)' "$ACFS_UNDOS_FILE" >/dev/null 2>&1
}

# Undo a specific change
undo_change() {
    local change_id="$1"
    local force="${2:-false}"
    local skip_deps="${3:-false}"

    if [[ -z "${ACFS_AUTOFIX_LOCK_FD:-}" ]]; then
        log_error "Undo requested without active auto-fix lock"
        return 1
    fi

    # Load from file if not in memory
    if [[ -z "${ACFS_CHANGE_RECORDS["$change_id"]:-}" ]]; then
        local record
        record=$(grep -F "\"id\":\"$change_id\"" "$ACFS_CHANGES_FILE" | tail -1)
        if [[ -z "$record" ]]; then
            log_error "Unknown change ID: $change_id"
            return 1
        fi
        ACFS_CHANGE_RECORDS["$change_id"]="$record"
    fi

    local record="${ACFS_CHANGE_RECORDS["$change_id"]}"

    # Verify record integrity
    local stored_checksum
    stored_checksum=$(echo "$record" | jq -r '.record_checksum // empty')
    if [[ -n "$stored_checksum" ]]; then
        local computed_checksum
        computed_checksum=$(compute_record_checksum "$record")
        if [[ "$stored_checksum" != "$computed_checksum" ]]; then
            log_error "Record integrity check failed for $change_id"
            if [[ "$force" != "true" ]]; then
                return 1
            fi
            log_warn "Forcing undo despite integrity failure"
        fi
    fi

    # Check if already undone
    if is_change_undone "$change_id"; then
        log_warn "Change $change_id has already been undone"
        return 0
    fi

    # Check dependencies (things that depend on this must be undone first)
    if [[ "$skip_deps" != "true" ]]; then
        local dependents
        # Use more precise grep to avoid partial matches (e.g. chg_0001 matching chg_00010)
        dependents=$(grep -E "\"depends_on\":\[([^]]*)?\"$change_id\"" "$ACFS_CHANGES_FILE" 2>/dev/null | jq -r '.id' 2>/dev/null || true)
        for dep in $dependents; do
            if ! is_change_undone "$dep"; then
                log_error "Cannot undo $change_id: $dep depends on it and hasn't been undone"
                log_error "Undo $dep first, or use --force"
                if [[ "$force" != "true" ]]; then
                    return 1
                fi
            fi
        done
    fi

    local undo_cmd
    undo_cmd=$(echo "$record" | jq -r '.undo_command')
    local requires_root
    requires_root=$(echo "$record" | jq -r '.undo_requires_root')
    local description
    description=$(echo "$record" | jq -r '.description')

    log_info "[UNDO] Reverting: $description"

    if ! autofix_record_is_reversible "$record"; then
        local manual_instructions=""
        manual_instructions="$(autofix_manual_undo_instructions "$undo_cmd")"
        log_error "Change $change_id is not automatically reversible"
        if [[ -n "$manual_instructions" ]]; then
            log_error "Manual undo instructions: $manual_instructions"
        fi
        return 1
    fi

    # Verify backups are intact
    local backup
    while IFS= read -r backup; do
        [[ -z "$backup" ]] && continue
        if ! verify_backup_integrity "$backup"; then
            if [[ "$force" != "true" ]]; then
                log_error "Backup verification failed. Use --force to override."
                return 1
            fi
            log_warn "Forcing undo despite backup verification failure"
        fi
    done < <(echo "$record" | jq -c '(.backups // [] | if type == "array" then . elif type == "object" then [.] else [] end)[] | select(type == "object" and (.backup? != null))' 2>/dev/null)

    # Execute undo
    local undo_exit_code=0
    if [[ "$requires_root" == "true" ]]; then
        local sudo_cmd=""
        [[ $EUID -ne 0 ]] && command -v sudo &>/dev/null && sudo_cmd="sudo"
        $sudo_cmd bash -c "$undo_cmd" || undo_exit_code=$?
    else
        bash -c "$undo_cmd" || undo_exit_code=$?
    fi

    if [[ $undo_exit_code -ne 0 ]]; then
        log_error "Undo command failed with exit code $undo_exit_code"
        return 1
    fi

    # Mark as undone (append to file atomically)
    local undo_record
    undo_record=$(jq -cn \
        --arg id "$change_id" \
        --arg ts "$(date -Iseconds)" \
        --argjson code "$undo_exit_code" \
        '{undone: $id, timestamp: $ts, exit_code: $code}')

    append_atomic "$ACFS_UNDOS_FILE" "$undo_record"
    ACFS_CHANGE_RECORDS["$change_id"]="$(echo "$record" | jq -c '.undone = true')"

    log_info "[UNDO] Successfully reverted: $change_id"
    return 0
}

# Rollback all changes on failure
rollback_all_on_failure() {
    local exit_code="$1"

    if [[ "$exit_code" -eq 0 ]]; then
        return 0
    fi

    if [[ ${#ACFS_CHANGE_ORDER[@]} -eq 0 ]]; then
        return 0
    fi

    echo ""
    log_warn "========================================================================"
    log_warn "  INSTALLATION FAILED! Rolling back auto-fix changes..."
    log_warn "========================================================================"
    echo ""

    local rollback_failed=0

    # Undo in reverse order
    for ((i=${#ACFS_CHANGE_ORDER[@]}-1; i>=0; i--)); do
        local change_id="${ACFS_CHANGE_ORDER[$i]}"
        local record="${ACFS_CHANGE_RECORDS["$change_id"]}"
        local desc
        desc=$(echo "$record" | jq -r '.description')

        log_info "Rolling back: $desc"
        if ! undo_change "$change_id" true true; then
            log_warn "  Failed to rollback $change_id (continuing anyway)"
            ((rollback_failed++)) || true
        fi
    done

    echo ""
    if [[ $rollback_failed -eq 0 ]]; then
        log_info "Rollback complete. System restored to pre-installation state."
    else
        log_warn "Rollback completed with $rollback_failed failures."
        log_warn "  Some changes may not have been reverted."
        log_warn "  Check: $ACFS_CHANGES_FILE"
    fi
}

# =============================================================================
# Undo Summary and Display
# =============================================================================

# Print summary of all changes made
print_undo_summary() {
    local change_count=${#ACFS_CHANGE_ORDER[@]}

    if [[ $change_count -eq 0 ]]; then
        return 0
    fi

    echo ""
    echo "========================================================================"
    echo "  ACFS Auto-Fix Summary"
    echo "========================================================================"
    echo "  Session: $ACFS_SESSION_ID"
    echo "  Changes: $change_count"
    echo "========================================================================"
    echo ""

    printf "%-10s %-12s %-10s %-50s\n" "ID" "Category" "Status" "Description"
    printf "%-10s %-12s %-10s %-50s\n" "----------" "------------" "----------" "--------------------------------------------------"

    for change_id in "${ACFS_CHANGE_ORDER[@]}"; do
        local record="${ACFS_CHANGE_RECORDS["$change_id"]}"
        local desc
        desc=$(echo "$record" | jq -r '.description' | cut -c1-50)
        local cat
        cat=$(echo "$record" | jq -r '.category')
        local status="active"
        if ! autofix_record_is_reversible "$record"; then
            status="manual"
        fi
        printf "%-10s %-12s %-10s %-50s\n" "$change_id" "$cat" "$status" "$desc"
    done

    echo ""
    echo "------------------------------------------------------------------------"
    echo " Undo Commands:"
    echo "   Single change:  acfs undo <change_id>"
    echo "   All changes:    acfs undo --all"
    echo "   List changes:   acfs undo --list"
    echo "   Dry run:        acfs undo --dry-run <change_id>"
    echo "   By category:    acfs undo --category nvm"
    echo "   Verify state:   acfs undo --verify"
    echo "------------------------------------------------------------------------"
    echo ""
    echo "State directory: $ACFS_STATE_DIR"
    echo ""
}

# =============================================================================
# ACFS Undo Command Implementation
# =============================================================================

# Implementation of "acfs undo" subcommand
acfs_undo_command() {
    local dry_run=false
    local force=false
    local all=false
    local list_only=false
    local verify_only=false
    local category=""
    local change_ids=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run) dry_run=true; shift ;;
            --force) force=true; shift ;;
            --all) all=true; shift ;;
            --list) list_only=true; shift ;;
            --verify) verify_only=true; shift ;;
            --category)
                if [[ -z "${2:-}" || "$2" == -* ]]; then
                    log_error "--category requires a value"
                    return 1
                fi
                category="$2"
                shift 2
                ;;
            chg_*) change_ids+=("$1"); shift ;;
            *) log_error "Unknown option: $1"; return 1 ;;
        esac
    done

    # Initialize if needed
    if [[ "$ACFS_AUTOFIX_INITIALIZED" != "true" ]]; then
        init_autofix_state
    fi

    # Verify mode
    if [[ "$verify_only" == "true" ]]; then
        echo "Verifying state file integrity..."
        if verify_state_integrity; then
            echo "All state files OK"
            return 0
        else
            echo "Integrity errors found (see above)"
            return 1
        fi
    fi

    # List mode
    if [[ "$list_only" == "true" ]]; then
        if [[ ! -f "$ACFS_CHANGES_FILE" ]] || [[ ! -s "$ACFS_CHANGES_FILE" ]]; then
            echo "No recorded changes found."
            return 0
        fi
        echo "Recorded changes:"
        local undone_ids_json="[]"
        local list_output=""
        undone_ids_json="$(autofix_undone_ids_json)"
        list_output="$(jq -r --argjson undone "$undone_ids_json" '
            [
              .id,
              .category,
              (
                (.id // "") as $id
                | ((.undo_command // "") | gsub("^\\s+"; "")) as $undo
                | if ($undone | index($id)) then "undone"
                  elif (((.reversible // true) == false) or ($undo == "") or ($undo | startswith("#"))) then "manual"
                  else "active"
                  end
              ),
              .description
            ] | @tsv
        ' "$ACFS_CHANGES_FILE")"
        if command -v column >/dev/null 2>&1; then
            printf '%s\n' "$list_output" | column -t -s $'\t'
        else
            printf '%s\n' "$list_output"
        fi
        return 0
    fi

    # Build list of changes to undo
    local undone_ids_json="[]"
    undone_ids_json="$(autofix_undone_ids_json)"
    if [[ "$all" == "true" ]]; then
        mapfile -t change_ids < <(jq -r --argjson undone "$undone_ids_json" 'select((.id // "") as $id | (($undone | index($id)) | not)) | .id' "$ACFS_CHANGES_FILE" | sort -r)
    elif [[ -n "$category" ]]; then
        mapfile -t change_ids < <(jq -r --argjson undone "$undone_ids_json" --arg category "$category" 'select((.id // "") as $id | (($undone | index($id)) | not)) | select(.category == $category) | .id' "$ACFS_CHANGES_FILE" | sort -r)
    fi

    if [[ ${#change_ids[@]} -eq 0 ]]; then
        log_error "No changes specified. Use --list to see available changes."
        return 1
    fi

    # Dry run mode
    if [[ "$dry_run" == "true" ]]; then
        echo "Dry run: Would undo the following changes:"
        for change_id in "${change_ids[@]}"; do
            local record
            record=$(grep -F "\"id\":\"$change_id\"" "$ACFS_CHANGES_FILE" | tail -1)
            local desc
            desc=$(echo "$record" | jq -r '.description')
            local undo
            undo=$(echo "$record" | jq -r '.undo_command')
            echo "  $change_id: $desc"
            if autofix_record_is_reversible "$record"; then
                echo "    Command: $undo"
            else
                local instructions=""
                instructions="$(autofix_manual_undo_instructions "$undo")"
                echo "    Manual: ${instructions:-No automatic undo available}"
            fi
        done
        return 0
    fi

    # Actually undo
    if ! start_autofix_session; then
        log_error "Failed to start undo session"
        return 1
    fi

    local failed=0
    for change_id in "${change_ids[@]}"; do
        if ! undo_change "$change_id" "$force"; then
            failed=$((failed + 1))
        fi
    done

    end_autofix_session

    if [[ $failed -gt 0 ]]; then
        log_warn "$failed undo operations failed"
        return 1
    fi

    log_info "All requested changes have been undone"
    return 0
}

# =============================================================================
# Cleanup Functions
# =============================================================================

# Remove backups older than N days
cleanup_old_backups() {
    local days="${1:-30}"
    local backup_entry=""
    local -A active_backup_set=()

    log_info "Cleaning up backups older than $days days..."

    while IFS= read -r backup_entry; do
        [[ -n "$backup_entry" ]] || continue
        active_backup_set["$backup_entry"]=1
    done < <(autofix_active_backup_paths 2>/dev/null || true)

    local deleted=0
    while IFS= read -r -d '' backup_entry; do
        if [[ -n "${active_backup_set[$backup_entry]:-}" ]]; then
            continue
        fi
        rm -rf "$backup_entry"
        ((deleted++)) || true
    done < <(find "$ACFS_BACKUPS_DIR" -mindepth 1 -maxdepth 1 -mtime +"$days" -print0 2>/dev/null)

    log_info "Deleted $deleted old backup entries"

    # Update integrity file after cleanup
    update_integrity_file
}

# =============================================================================
# Exported Functions for Use by Other Scripts
# =============================================================================

# These are the main entry points for other ACFS scripts:
# - start_autofix_session: Call at start of installation
# - end_autofix_session: Call at end of installation
# - create_backup: Create a backup before modifying a file
# - record_change: Record a change with undo information
# - rollback_all_on_failure: Call in EXIT trap to rollback on failure
# - print_undo_summary: Display summary of changes at end
# - acfs_undo_command: Handle "acfs undo" subcommand
