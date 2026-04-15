#!/bin/bash
# ACFS Auto-Fix: Existing Installation Handling
# Handles upgrade, clean reinstall, or abort for existing ACFS installations
# Integrates with change recording system from autofix.sh

# Prevent multiple sourcing
[[ -n "${_ACFS_AUTOFIX_EXISTING_SOURCED:-}" ]] && return 0
_ACFS_AUTOFIX_EXISTING_SOURCED=1

# Source the core autofix module
_AUTOFIX_EXISTING_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=autofix.sh
source "${_AUTOFIX_EXISTING_DIR}/autofix.sh"

# =============================================================================
# Runtime Path Helpers
# =============================================================================

autofix_existing_runtime_home() {
    local runtime_home=""

    if declare -f autofix_runtime_home >/dev/null 2>&1; then
        runtime_home="$(autofix_runtime_home 2>/dev/null || true)"
    fi
    runtime_home="$(autofix_sanitize_abs_nonroot_path "$runtime_home" 2>/dev/null || true)"
    if [[ -n "$runtime_home" ]]; then
        printf '%s\n' "$runtime_home"
        return 0
    fi

    runtime_home="$(autofix_sanitize_abs_nonroot_path "${TARGET_HOME:-}" 2>/dev/null || true)"
    if [[ -n "$runtime_home" ]]; then
        printf '%s\n' "$runtime_home"
        return 0
    fi

    runtime_home="$(autofix_sanitize_abs_nonroot_path "${HOME:-}" 2>/dev/null || true)"
    if [[ -n "$runtime_home" ]]; then
        printf '%s\n' "$runtime_home"
        return 0
    fi

    return 1
}

autofix_existing_acfs_home() {
    local acfs_home=""
    local runtime_home=""

    runtime_home="$(autofix_existing_runtime_home 2>/dev/null || true)"
    if [[ -n "$runtime_home" ]]; then
        printf '%s/.acfs\n' "$runtime_home"
        return 0
    fi

    acfs_home="$(autofix_sanitize_abs_nonroot_path "${ACFS_HOME:-}" 2>/dev/null || true)"
    if [[ -n "$acfs_home" ]]; then
        printf '%s\n' "$acfs_home"
        return 0
    fi

    return 1
}

autofix_existing_installation_markers() {
    local runtime_home=""

    runtime_home="$(autofix_existing_runtime_home 2>/dev/null || true)"
    [[ -n "$runtime_home" ]] || return 1

    printf '%s\n' \
        "$runtime_home/.acfs_installed" \
        "$runtime_home/.acfs" \
        "$runtime_home/.config/acfs" \
        "/usr/local/bin/acfs" \
        "$runtime_home/.local/bin/acfs"
}

autofix_existing_artifacts() {
    local runtime_home=""
    local acfs_home=""

    runtime_home="$(autofix_existing_runtime_home 2>/dev/null || true)"
    acfs_home="$(autofix_existing_acfs_home 2>/dev/null || true)"
    [[ -n "$runtime_home" ]] || return 1
    [[ -n "$acfs_home" ]] || return 1

    printf '%s\n' \
        "$acfs_home" \
        "$runtime_home/.acfs_installed" \
        "$runtime_home/.config/acfs" \
        "$runtime_home/.local/bin/acfs"
}

autofix_existing_shell_configs() {
    local runtime_home=""

    runtime_home="$(autofix_existing_runtime_home 2>/dev/null || true)"
    [[ -n "$runtime_home" ]] || return 1

    printf '%s\n' \
        "$runtime_home/.bashrc" \
        "$runtime_home/.zshrc" \
        "$runtime_home/.profile" \
        "$runtime_home/.bash_profile"
}

# =============================================================================
# Detection Functions
# =============================================================================

# Detect existing ACFS installation
# Returns: space-separated list of found markers (empty if none)
detect_existing_acfs() {
    local -a found_markers=()
    local marker=""

    while IFS= read -r marker; do
        [[ -n "$marker" ]] || continue
        if [[ -e "$marker" ]]; then
            found_markers+=("$marker")
        fi
    done < <(autofix_existing_installation_markers 2>/dev/null || true)

    if [[ ${#found_markers[@]} -gt 0 ]]; then
        echo "${found_markers[*]}"
        return 0
    fi

    return 1
}

# Get installed ACFS version
get_installed_version() {
    local version_output=""
    local version=""
    local acfs_home=""
    local runtime_home=""

    # Method 1: Try acfs --version command
    if command -v acfs &>/dev/null; then
        version_output=$(acfs --version 2>/dev/null | head -1)
        if [[ -n "$version_output" ]]; then
            # Extract version number (e.g., "ACFS v0.4.0" -> "0.4.0")
            version=$(echo "$version_output" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            if [[ -n "$version" ]]; then
                printf '%s\n' "$version"
                return 0
            fi
        fi
    fi

    # Method 2: Check version file
    acfs_home="$(autofix_existing_acfs_home 2>/dev/null || true)"
    if [[ -n "$acfs_home" ]] && [[ -f "$acfs_home/version" ]]; then
        cat "$acfs_home/version"
        return 0
    fi

    # Method 3: Check installed marker file for version info
    runtime_home="$(autofix_existing_runtime_home 2>/dev/null || true)"
    if [[ -n "$runtime_home" ]] && [[ -f "$runtime_home/.acfs_installed" ]]; then
        version=$(grep -oE 'version=[0-9]+\.[0-9]+\.[0-9]+' "$runtime_home/.acfs_installed" 2>/dev/null | cut -d= -f2)
        if [[ -n "$version" ]]; then
            printf '%s\n' "$version"
            return 0
        fi
    fi

    printf 'unknown\n'
}

# Check if installation appears corrupted/partial
detect_installation_state() {
    local markers
    markers=$(detect_existing_acfs 2>/dev/null) || true

    if [[ -z "$markers" ]]; then
        echo "none"
        return
    fi

    local has_config=false
    local has_binary=false
    local has_marker=false

    for marker in $markers; do
        case "$marker" in
            */.acfs|*/.config/acfs) has_config=true ;;
            */bin/acfs) has_binary=true ;;
            */.acfs_installed) has_marker=true ;;
        esac
    done

    # Determine state
    if $has_config && $has_binary && $has_marker; then
        echo "complete"
    elif $has_marker && ! $has_config && ! $has_binary; then
        echo "marker_only"
    elif ! $has_marker && ($has_config || $has_binary); then
        echo "partial"
    else
        echo "partial"
    fi
}

# Returns JSON with installation details
autofix_existing_acfs_check() {
    local markers
    markers=$(detect_existing_acfs 2>/dev/null) || markers=""

    local version
    version=$(get_installed_version)

    local state
    state=$(detect_installation_state)

    local markers_json
    if [[ -n "$markers" ]]; then
        # shellcheck disable=SC2086
        markers_json=$(printf '%s\n' $markers | jq -R . | jq -s .)
    else
        markers_json="[]"
    fi

    jq -n \
        --arg state "$state" \
        --arg version "$version" \
        --argjson markers "$markers_json" \
        '{state: $state, version: $version, markers: $markers}'
}

# Quick check - returns 0 if existing installation found, 1 if clean
autofix_existing_acfs_needs_handling() {
    local markers
    markers=$(detect_existing_acfs 2>/dev/null) || true

    [[ -n "$markers" ]]
}

# Fix function for handle_autofix dispatch pattern
# In fix/--yes mode, defaults to upgrade; in dry-run, shows what would happen
autofix_existing_fix() {
    local mode="${1:-fix}"

    if [[ "$mode" == "dry-run" ]]; then
        log_info "[DRY-RUN] Would handle existing ACFS installation"
        log_info "  - Check installed version"
        log_info "  - Offer upgrade or clean reinstall option"
        return 0
    fi

    # In fix mode: use upgrade strategy
    if handle_existing_installation "${ACFS_VERSION:-unknown}" "upgrade"; then
        return 0
    else
        log_error "Failed to handle existing installation"
        return 1
    fi
}

# =============================================================================
# Version Comparison Utilities
# =============================================================================

# Compare two semantic versions
# Returns: -1 if v1 < v2, 0 if v1 == v2, 1 if v1 > v2
version_compare() {
    local v1="$1"
    local v2="$2"

    # Handle unknown versions
    if [[ "$v1" == "unknown" || "$v2" == "unknown" ]]; then
        echo "0"
        return
    fi

    # Split into arrays
    IFS='.' read -ra V1_PARTS <<< "$v1"
    IFS='.' read -ra V2_PARTS <<< "$v2"

    # Compare each part
    for i in 0 1 2; do
        local p1="${V1_PARTS[$i]:-0}"
        local p2="${V2_PARTS[$i]:-0}"

        if ((p1 < p2)); then
            echo "-1"
            return
        elif ((p1 > p2)); then
            echo "1"
            return
        fi
    done

    echo "0"
}

# Check if migration is required between versions
version_requires_migration() {
    local from="$1"
    local to="$2"

    if [[ "$from" == "unknown" ]]; then
        return 0  # Unknown version always needs migration check
    fi

    # Compare major versions
    local from_major="${from%%.*}"
    local to_major="${to%%.*}"

    if [[ "$from_major" != "$to_major" ]]; then
        return 0  # Major version change requires migration
    fi

    return 1
}

# =============================================================================
# Migration Functions
# =============================================================================

# Run migrations from one version to another
run_migrations() {
    local from="$1"
    local to="$2"
    local runtime_home=""
    local acfs_home=""
    local legacy_config=""
    local settings_path=""
    local legacy_json_config=""
    local migrated_json_config=""
    local files_json=""

    log_info "[MIGRATE] Running migrations from $from to $to"

    runtime_home="$(autofix_existing_runtime_home 2>/dev/null || true)"
    acfs_home="$(autofix_existing_acfs_home 2>/dev/null || true)"
    [[ -n "$runtime_home" ]] || return 1
    [[ -n "$acfs_home" ]] || return 1

    # Migration: v0.x -> v1.x: Move config from ~/.acfs_config to ~/.acfs/config
    legacy_config="$runtime_home/.acfs_config"
    settings_path="$acfs_home/config/settings.toml"
    if [[ -f "$legacy_config" ]] && [[ ! -f "$settings_path" ]]; then
        log_info "[MIGRATE] Moving legacy config to new location"
        mkdir -p "$acfs_home/config"
        mv "$legacy_config" "$settings_path"
        files_json="$(jq -cn --arg old "$legacy_config" --arg new "$settings_path" '[$old, $new]')"

        record_change \
            "acfs" \
            "Migrated legacy config file to new location" \
            "mv '$settings_path' '$legacy_config'" \
            false \
            "info" \
            "$files_json" \
            '[]' \
            '[]'
    fi

    # Migration: Convert JSON config to TOML (if present)
    legacy_json_config="$acfs_home/config.json"
    migrated_json_config="$acfs_home/config.json.migrated"
    if [[ -f "$legacy_json_config" ]] && [[ ! -f "$migrated_json_config" ]]; then
        log_info "[MIGRATE] Backing up legacy JSON config"
        mv "$legacy_json_config" "$migrated_json_config"
        files_json="$(jq -cn --arg path "$legacy_json_config" '[$path]')"

        record_change \
            "acfs" \
            "Backed up legacy JSON config" \
            "mv '$migrated_json_config' '$legacy_json_config'" \
            false \
            "info" \
            "$files_json" \
            '[]' \
            '[]'
    fi

    # Migration: Ensure .local/bin exists and is in PATH
    if [[ ! -d "$runtime_home/.local/bin" ]]; then
        log_info "[MIGRATE] Creating ~/.local/bin directory"
        mkdir -p "$runtime_home/.local/bin"
    fi

    log_info "[MIGRATE] Migrations complete"
    return 0
}

# Update PATH entries in shell configs
update_path_entries() {
    local config=""
    local backup=""
    local files_json=""

    while IFS= read -r config; do
        [[ -n "$config" ]] || continue
        if [[ -f "$config" ]]; then
            # Check if ACFS path entry exists
            if ! grep -q "# ACFS PATH" "$config"; then
                log_info "[UPGRADE] Adding PATH entry to $config"

                # Create backup
                backup=$(create_backup "$config" "upgrade-path-entry")
                files_json="$(jq -cn --arg path "$config" '[$path]')"

                # Append PATH entry
                {
                    echo ''
                    echo '# ACFS PATH'
                    echo 'export PATH="$HOME/.local/bin:$PATH" # ACFS'
                } >> "$config"

                record_change \
                    "acfs" \
                    "Added PATH entry to $config" \
                    "# Remove PATH entry from $config manually if needed" \
                    false \
                    "info" \
                    "$files_json" \
                    "$(echo "$backup" | jq -c '[.]' 2>/dev/null || echo '[]')" \
                    '[]'
            fi
        fi
    done < <(autofix_existing_shell_configs 2>/dev/null || true)
}

# =============================================================================
# Upgrade Implementation
# =============================================================================

# Upgrade existing installation (preserve config)
upgrade_existing_installation() {
    local current_version="$1"
    local new_version="$2"
    local acfs_home=""
    local runtime_home=""
    local config_backup=""

    log_info "[UPGRADE] Starting upgrade from $current_version to $new_version"

    runtime_home="$(autofix_existing_runtime_home 2>/dev/null || true)"
    acfs_home="$(autofix_existing_acfs_home 2>/dev/null || true)"
    [[ -n "$runtime_home" ]] || return 1
    [[ -n "$acfs_home" ]] || return 1

    # Step 1: Backup current config (for safety)
    if [[ -d "$acfs_home" ]]; then
        config_backup=$(create_backup "$acfs_home/config" "upgrade-config-backup")
        if [[ -n "$config_backup" ]]; then
            log_info "[UPGRADE] Config backed up: $(echo "$config_backup" | jq -r '.backup' 2>/dev/null || echo "$config_backup")"
        fi
    fi

    # Step 2: Check for migration requirements
    if version_requires_migration "$current_version" "$new_version"; then
        log_info "[UPGRADE] Migration required from $current_version to $new_version"
        if ! run_migrations "$current_version" "$new_version"; then
            log_error "[UPGRADE] Migration failed"
            return 1
        fi
    fi

    # Step 3: Record upgrade change
    record_change \
        "acfs" \
        "Upgraded ACFS from $current_version to $new_version" \
        "# Downgrade not supported - restore from backup if needed" \
        false \
        "info" \
        '[]' \
        '[]' \
        '[]'

    # Step 4: Update version file
    mkdir -p "$acfs_home"
    echo "$new_version" > "$acfs_home/version"

    # Step 5: Update PATH entries if needed
    update_path_entries

    log_info "[UPGRADE] Upgrade preparation complete"
    log_info "[UPGRADE] Installation will continue with updated binaries"

    return 0
}

# =============================================================================
# Clean Reinstall Implementation
# =============================================================================

# Create comprehensive backup of existing installation
create_installation_backup() {
    local backup_dir
    local runtime_home=""
    local artifact=""
    local dest=""
    local dest_rel=""
    local checksum=""
    local items_json=""
    local backup_item=""
    local -a backed_up_items=()

    runtime_home="$(autofix_existing_runtime_home 2>/dev/null || true)"
    [[ -n "$runtime_home" ]] || return 1
    backup_dir="$runtime_home/.acfs-backup-$(date +%Y%m%d_%H%M%S)"

    log_info "[CLEAN] Creating backup at $backup_dir"
    mkdir -p "$backup_dir"

    local backup_manifest="$backup_dir/manifest.json"

    while IFS= read -r artifact; do
        [[ -n "$artifact" ]] || continue
        if [[ -e "$artifact" ]]; then
            log_info "[CLEAN] Backing up: $artifact"
            case "$artifact" in
                "$runtime_home")
                    dest_rel=".acfs-home"
                    ;;
                "$runtime_home"/*)
                    dest_rel="${artifact#$runtime_home/}"
                    ;;
                /*)
                    dest_rel="${artifact#/}"
                    ;;
                *)
                    dest_rel="$artifact"
                    ;;
            esac
            dest="$backup_dir/$dest_rel"
            mkdir -p "$(dirname "$dest")"

            if [[ -d "$artifact" ]]; then
                if ! cp -rp "$artifact" "$dest" 2>/dev/null; then
                    log_error "[CLEAN] Failed to back up directory: $artifact"
                    return 1
                fi
            else
                if ! cp -p "$artifact" "$dest" 2>/dev/null; then
                    log_error "[CLEAN] Failed to back up file: $artifact"
                    return 1
                fi
            fi

            # Calculate checksum if it's a file
            checksum=""
            if [[ -f "$artifact" ]]; then
                checksum=$(sha256sum "$artifact" 2>/dev/null | cut -d' ' -f1)
            fi

            backup_item="$(jq -cn --arg original "$artifact" --arg backup "$dest" --arg checksum "$checksum" '{original: $original, backup: $backup, checksum: $checksum}')"
            backed_up_items+=("$backup_item")
        fi
    done < <(autofix_existing_artifacts 2>/dev/null || true)

    # Write manifest
    items_json=$(printf '%s\n' "${backed_up_items[@]}" | jq -s '.')

    jq -n \
        --arg created "$(date -Iseconds)" \
        --argjson items "$items_json" \
        '{created: $created, backed_up_items: $items}' > "$backup_manifest"

    echo "$backup_dir"
}

# Remove all ACFS artifacts
remove_acfs_artifacts() {
    local artifact=""

    while IFS= read -r artifact; do
        [[ -n "$artifact" ]] || continue
        if [[ -e "$artifact" ]]; then
            log_info "[CLEAN] Removing: $artifact"
            rm -rf "$artifact"
        fi
    done < <(autofix_existing_artifacts 2>/dev/null || true)
}

# Clean ACFS entries from shell configs
clean_shell_configs() {
    local config=""
    local config_backup=""
    local temp_file=""
    local orig_mode=""

    while IFS= read -r config; do
        [[ -n "$config" ]] || continue
        if [[ -f "$config" ]]; then
            # Check if config has ACFS-related content
            if grep -qE '# ACFS|\.acfs|acfs_' "$config" 2>/dev/null; then
                # Backup config first
                config_backup=$(create_backup "$config" "clean-shell-config")

                if [[ -n "$config_backup" ]]; then
                    log_info "[CLEAN] Cleaning ACFS entries from $config"

                    # Create temp file in same directory to preserve permissions on mv
                    temp_file=$(mktemp -p "$(dirname "$config")" ".acfs-clean.XXXXXX")

                    # Preserve original permissions by copying mode
                    orig_mode=$(stat -c '%a' "$config" 2>/dev/null || stat -f '%Lp' "$config" 2>/dev/null)

                    grep -vE '# ACFS|\.acfs|acfs_' "$config" > "$temp_file" || true

                    # Restore original permissions before move
                    [[ -n "$orig_mode" ]] && chmod "$orig_mode" "$temp_file"

                    mv "$temp_file" "$config"
                fi
            fi
        fi
    done < <(autofix_existing_shell_configs 2>/dev/null || true)
}

# Perform clean reinstall
clean_reinstall() {
    log_warn "[CLEAN] Starting clean reinstall - this will remove existing installation"

    # Step 1: Create comprehensive backup
    local backup_dir
    local artifacts_json=""
    if ! backup_dir=$(create_installation_backup); then
        log_error "[CLEAN] Backup creation failed; aborting clean reinstall"
        return 1
    fi

    # Step 2: Record the clean reinstall change
    artifacts_json=$(autofix_existing_artifacts 2>/dev/null | jq -R . | jq -s '.')

    record_change \
        "acfs" \
        "Clean reinstall - removed existing ACFS installation" \
        "# Restore from backup: $backup_dir" \
        false \
        "warning" \
        "$artifacts_json" \
        "[{\"backup_dir\": \"$backup_dir\"}]" \
        '[]'

    # Step 3: Remove existing installation
    remove_acfs_artifacts

    # Step 4: Clean shell configs
    clean_shell_configs

    log_info "[CLEAN] Clean removal complete"
    log_info "[CLEAN] Backup saved to: $backup_dir"
    log_info "[CLEAN] Proceeding with fresh installation..."

    return 0
}

# =============================================================================
# Main Handler
# =============================================================================

# Handle existing installation (interactive mode)
# Arguments:
#   $1 - new version being installed
#   $2 - mode: "interactive" (default), "upgrade", "clean", "abort"
# Returns:
#   0 - continue with installation
#   1 - abort installation
handle_existing_installation() {
    local new_version="${1:-${ACFS_VERSION:-unknown}}"
    local mode="${2:-interactive}"

    # Check for existing installation
    local markers
    if ! markers=$(detect_existing_acfs); then
        log_debug "[EXISTING] No existing installation detected"
        return 0  # No existing installation, continue
    fi

    local current_version
    current_version=$(get_installed_version)

    local state
    state=$(detect_installation_state)

    # Non-interactive modes
    case "$mode" in
        upgrade)
            upgrade_existing_installation "$current_version" "$new_version"
            return $?
            ;;
        clean)
            clean_reinstall
            return $?
            ;;
        abort)
            log_info "Aborting installation per request."
            return 1
            ;;
    esac

    # Interactive mode - show info and prompt
    log_warn "════════════════════════════════════════════════════════════"
    log_warn "  Existing ACFS installation detected!"
    log_warn "════════════════════════════════════════════════════════════"
    log_warn ""
    log_warn "  Current version: $current_version"
    log_warn "  New version:     $new_version"
    log_warn "  State:           $state"
    log_warn ""
    log_warn "  Found markers:"
    # shellcheck disable=SC2086
    for marker in $markers; do
        log_warn "    - $marker"
    done
    log_warn ""

    echo ""
    echo "How would you like to proceed?"
    echo ""
    echo "  1) Upgrade (Recommended) - Keep config, update binaries"
    echo "  2) Clean reinstall - Backup and start fresh"
    echo "  3) Abort - Exit without changes"
    echo ""

    local choice
    read -rp "Enter choice [1-3]: " choice < /dev/tty

    case "$choice" in
        1)
            upgrade_existing_installation "$current_version" "$new_version"
            return $?
            ;;
        2)
            clean_reinstall
            return $?
            ;;
        3|*)
            log_info "Aborting installation."
            return 1
            ;;
    esac
}

# Non-interactive upgrade check (for CI/automated runs)
# Returns 0 if should proceed with install, 1 if should abort
autofix_existing_should_proceed() {
    local new_version="${1:-${ACFS_VERSION:-unknown}}"
    local force="${2:-false}"

    if ! autofix_existing_acfs_needs_handling; then
        return 0  # No existing installation, proceed
    fi

    local current_version
    current_version=$(get_installed_version)

    # If force mode, always proceed with upgrade
    if [[ "$force" == "true" ]]; then
        log_info "[AUTO] Force mode - proceeding with upgrade"
        upgrade_existing_installation "$current_version" "$new_version"
        return $?
    fi

    # Compare versions
    local cmp
    cmp=$(version_compare "$current_version" "$new_version")

    case "$cmp" in
        -1)
            # Current < New: upgrade available
            log_info "[AUTO] Newer version available ($current_version -> $new_version)"
            return 0  # Proceed with upgrade
            ;;
        0)
            # Same version
            log_info "[AUTO] Same version already installed ($current_version)"
            return 1  # Skip installation
            ;;
        1)
            # Current > New: downgrade not supported
            log_warn "[AUTO] Installed version ($current_version) is newer than target ($new_version)"
            return 1  # Abort
            ;;
    esac
}

# =============================================================================
# Verification
# =============================================================================

# Verify installation is complete and functional
verify_installation() {
    log_info "[VERIFY] Checking installation..."

    local errors=0
    local runtime_home=""
    local acfs_home=""

    runtime_home="$(autofix_existing_runtime_home 2>/dev/null || true)"
    acfs_home="$(autofix_existing_acfs_home 2>/dev/null || true)"

    # Check config directory
    if [[ -z "$acfs_home" ]] || [[ ! -d "$acfs_home" ]]; then
        log_warn "[VERIFY] Config directory missing"
        ((errors++)) || true
    fi

    # Check version file
    if [[ -z "$acfs_home" ]] || [[ ! -f "$acfs_home/version" ]]; then
        log_warn "[VERIFY] Version file missing"
        ((errors++)) || true
    fi

    # Check .local/bin exists
    if [[ -z "$runtime_home" ]] || [[ ! -d "$runtime_home/.local/bin" ]]; then
        log_warn "[VERIFY] ~/.local/bin directory missing"
        ((errors++)) || true
    fi

    if [[ $errors -gt 0 ]]; then
        log_warn "[VERIFY] Found $errors issues"
        return 1
    fi

    log_info "[VERIFY] Installation verified successfully"
    return 0
}

# =============================================================================
# CLI Interface
# =============================================================================

# Run when script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-check}" in
        check)
            autofix_existing_acfs_check
            ;;
        needs-handling)
            if autofix_existing_acfs_needs_handling; then
                echo "true"
                exit 0
            else
                echo "false"
                exit 1
            fi
            ;;
        handle)
            handle_existing_installation "${2:-}" "${3:-interactive}"
            ;;
        upgrade)
            handle_existing_installation "${2:-}" "upgrade"
            ;;
        clean)
            handle_existing_installation "${2:-}" "clean"
            ;;
        verify)
            verify_installation
            ;;
        version)
            get_installed_version
            ;;
        *)
            echo "Usage: $0 {check|needs-handling|handle|upgrade|clean|verify|version}"
            echo ""
            echo "Commands:"
            echo "  check          Output JSON status of existing installation"
            echo "  needs-handling Exit 0 if existing installation found, 1 if clean"
            echo "  handle [ver]   Interactive handling of existing installation"
            echo "  upgrade [ver]  Non-interactive upgrade"
            echo "  clean [ver]    Non-interactive clean reinstall"
            echo "  verify         Verify installation is complete"
            echo "  version        Show installed version"
            exit 1
            ;;
    esac
fi
