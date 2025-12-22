#!/usr/bin/env bash
# shellcheck disable=SC1091
# ============================================================
# AUTO-GENERATED FROM acfs.manifest.yaml - DO NOT EDIT
# Regenerate: bun run generate (from packages/manifest)
# ============================================================

set -euo pipefail

# Ensure logging functions available
ACFS_GENERATED_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$ACFS_GENERATED_SCRIPT_DIR/../lib/logging.sh" ]]; then
    source "$ACFS_GENERATED_SCRIPT_DIR/../lib/logging.sh"
else
    # Fallback logging functions if logging.sh not found
    log_step() { echo "[*] $*"; }
    log_section() { echo ""; echo "=== $* ==="; }
    log_success() { echo "[OK] $*"; }
    log_error() { echo "[ERROR] $*" >&2; }
    log_warn() { echo "[WARN] $*" >&2; }
    log_info() { echo "    $*"; }
fi

# Source install helpers (run_as_*_shell, selection helpers)
if [[ -f "$ACFS_GENERATED_SCRIPT_DIR/../lib/install_helpers.sh" ]]; then
    source "$ACFS_GENERATED_SCRIPT_DIR/../lib/install_helpers.sh"
fi

# Source contract validation
if [[ -f "$ACFS_GENERATED_SCRIPT_DIR/../lib/contract.sh" ]]; then
    source "$ACFS_GENERATED_SCRIPT_DIR/../lib/contract.sh"
fi

# Optional security verification for upstream installer scripts.
# Scripts that need it should call: acfs_security_init
ACFS_SECURITY_READY=false
acfs_security_init() {
    if [[ "${ACFS_SECURITY_READY}" == "true" ]]; then
        return 0
    fi

    local security_lib="$ACFS_GENERATED_SCRIPT_DIR/../lib/security.sh"
    if [[ ! -f "$security_lib" ]]; then
        log_error "Security library not found: $security_lib"
        return 1
    fi

    # shellcheck source=../lib/security.sh
    # shellcheck disable=SC1091  # runtime relative source
    source "$security_lib"
    load_checksums || { log_error "Failed to load checksums.yaml"; return 1; }
    ACFS_SECURITY_READY=true
    return 0
}

# Category: filesystem
# Modules: 1

# Create workspace and ACFS directories
install_base_filesystem() {
    local module_id="base.filesystem"
    acfs_require_contract "module:${module_id}" || return 1
    log_step "Installing base.filesystem"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "dry-run: install: mkdir -p /data/projects /data/cache (root)"
    else
        if ! run_as_root_shell <<'INSTALL_BASE_FILESYSTEM'
mkdir -p /data/projects /data/cache
INSTALL_BASE_FILESYSTEM
        then
            log_error "base.filesystem: install command failed: mkdir -p /data/projects /data/cache"
            return 1
        fi
    fi
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "dry-run: install: chown -R \"\${TARGET_USER:-ubuntu}:\${TARGET_USER:-ubuntu}\" /data (root)"
    else
        if ! run_as_root_shell <<'INSTALL_BASE_FILESYSTEM'
chown -R "${TARGET_USER:-ubuntu}:${TARGET_USER:-ubuntu}" /data
INSTALL_BASE_FILESYSTEM
        then
            log_error "base.filesystem: install command failed: chown -R \"\${TARGET_USER:-ubuntu}:\${TARGET_USER:-ubuntu}\" /data"
            return 1
        fi
    fi
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "dry-run: install: mkdir -p \"\${TARGET_HOME:-/home/ubuntu}/.acfs\" (root)"
    else
        if ! run_as_root_shell <<'INSTALL_BASE_FILESYSTEM'
mkdir -p "${TARGET_HOME:-/home/ubuntu}/.acfs"
INSTALL_BASE_FILESYSTEM
        then
            log_error "base.filesystem: install command failed: mkdir -p \"\${TARGET_HOME:-/home/ubuntu}/.acfs\""
            return 1
        fi
    fi
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "dry-run: install: chown -R \"\${TARGET_USER:-ubuntu}:\${TARGET_USER:-ubuntu}\" \"\${TARGET_HOME:-/home/ubuntu}/.acfs\" (root)"
    else
        if ! run_as_root_shell <<'INSTALL_BASE_FILESYSTEM'
chown -R "${TARGET_USER:-ubuntu}:${TARGET_USER:-ubuntu}" "${TARGET_HOME:-/home/ubuntu}/.acfs"
INSTALL_BASE_FILESYSTEM
        then
            log_error "base.filesystem: install command failed: chown -R \"\${TARGET_USER:-ubuntu}:\${TARGET_USER:-ubuntu}\" \"\${TARGET_HOME:-/home/ubuntu}/.acfs\""
            return 1
        fi
    fi

    # Verify
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "dry-run: verify: test -d /data/projects (root)"
    else
        if ! run_as_root_shell <<'INSTALL_BASE_FILESYSTEM'
test -d /data/projects
INSTALL_BASE_FILESYSTEM
        then
            log_error "base.filesystem: verify failed: test -d /data/projects"
            return 1
        fi
    fi
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "dry-run: verify: test -d \"\${TARGET_HOME:-/home/ubuntu}/.acfs\" (root)"
    else
        if ! run_as_root_shell <<'INSTALL_BASE_FILESYSTEM'
test -d "${TARGET_HOME:-/home/ubuntu}/.acfs"
INSTALL_BASE_FILESYSTEM
        then
            log_error "base.filesystem: verify failed: test -d \"\${TARGET_HOME:-/home/ubuntu}/.acfs\""
            return 1
        fi
    fi

    log_success "base.filesystem installed"
}

# Install all filesystem modules
install_filesystem() {
    log_section "Installing filesystem modules"
    install_base_filesystem
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_filesystem
fi
