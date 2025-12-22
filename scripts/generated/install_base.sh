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

# Category: base
# Modules: 1

# Base packages + sane defaults
install_base_system() {
    local module_id="base.system"
    acfs_require_contract "module:${module_id}" || return 1
    log_step "Installing base.system"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "dry-run: install: apt-get update -y (root)"
    else
        if ! run_as_root_shell <<'INSTALL_BASE_SYSTEM'
apt-get update -y
INSTALL_BASE_SYSTEM
        then
            log_error "base.system: install command failed: apt-get update -y"
            return 1
        fi
    fi
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "dry-run: install: apt-get install -y curl git ca-certificates unzip tar xz-utils jq build-essential gnupg lsb-release (root)"
    else
        if ! run_as_root_shell <<'INSTALL_BASE_SYSTEM'
apt-get install -y curl git ca-certificates unzip tar xz-utils jq build-essential gnupg lsb-release
INSTALL_BASE_SYSTEM
        then
            log_error "base.system: install command failed: apt-get install -y curl git ca-certificates unzip tar xz-utils jq build-essential gnupg lsb-release"
            return 1
        fi
    fi

    # Verify
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "dry-run: verify: curl --version (root)"
    else
        if ! run_as_root_shell <<'INSTALL_BASE_SYSTEM'
curl --version
INSTALL_BASE_SYSTEM
        then
            log_error "base.system: verify failed: curl --version"
            return 1
        fi
    fi
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "dry-run: verify: git --version (root)"
    else
        if ! run_as_root_shell <<'INSTALL_BASE_SYSTEM'
git --version
INSTALL_BASE_SYSTEM
        then
            log_error "base.system: verify failed: git --version"
            return 1
        fi
    fi
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "dry-run: verify: jq --version (root)"
    else
        if ! run_as_root_shell <<'INSTALL_BASE_SYSTEM'
jq --version
INSTALL_BASE_SYSTEM
        then
            log_error "base.system: verify failed: jq --version"
            return 1
        fi
    fi
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "dry-run: verify: gpg --version (root)"
    else
        if ! run_as_root_shell <<'INSTALL_BASE_SYSTEM'
gpg --version
INSTALL_BASE_SYSTEM
        then
            log_error "base.system: verify failed: gpg --version"
            return 1
        fi
    fi

    log_success "base.system installed"
}

# Install all base modules
install_base() {
    log_section "Installing base modules"
    install_base_system
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_base
fi
