#!/usr/bin/env bash
# shellcheck disable=SC1091
# ============================================================
# AUTO-GENERATED FROM acfs.manifest.yaml - DO NOT EDIT
# Regenerate: bun run generate (from packages/manifest)
# ============================================================

set -euo pipefail

# Resolve relative helper paths first.
ACFS_GENERATED_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ensure logging functions available
if [[ -f "$ACFS_GENERATED_SCRIPT_DIR/../lib/logging.sh" ]]; then
    source "$ACFS_GENERATED_SCRIPT_DIR/../lib/logging.sh"
else
    # Fallback logging functions if logging.sh not found
    # Progress/status output should go to stderr so stdout stays clean for piping.
    log_step() { echo "[*] $*" >&2; }
    log_section() { echo "" >&2; echo "=== $* ===" >&2; }
    log_success() { echo "[OK] $*" >&2; }
    log_error() { echo "[ERROR] $*" >&2; }
    log_warn() { echo "[WARN] $*" >&2; }
    log_info() { echo "    $*" >&2; }
fi

# Source install helpers (run_as_*_shell, selection helpers)
if [[ -f "$ACFS_GENERATED_SCRIPT_DIR/../lib/install_helpers.sh" ]]; then
    source "$ACFS_GENERATED_SCRIPT_DIR/../lib/install_helpers.sh"
fi

# When running a generated installer directly (not sourced by install.sh),
# set sane defaults and derive ACFS paths from the script location so
# contract validation passes and local assets are discoverable.
if [[ "${BASH_SOURCE[0]}" = "${0}" ]]; then
    # Match install.sh defaults
    if [[ -z "${TARGET_USER:-}" ]]; then
        if [[ $EUID -eq 0 ]] && [[ -z "${SUDO_USER:-}" ]]; then
            _ACFS_DETECTED_USER="ubuntu"
        else
            _ACFS_DETECTED_USER="${SUDO_USER:-$(whoami)}"
        fi
        TARGET_USER="$_ACFS_DETECTED_USER"
    fi
    unset _ACFS_DETECTED_USER

    if declare -f _acfs_validate_target_user >/dev/null 2>&1; then
        _acfs_validate_target_user "${TARGET_USER}" "TARGET_USER" || exit 1
    elif [[ -z "${TARGET_USER:-}" ]] || [[ ! "${TARGET_USER}" =~ ^[a-z_][a-z0-9._-]*$ ]]; then
        log_error "Invalid TARGET_USER '${TARGET_USER:-<empty>}' (expected: lowercase user name like 'ubuntu')"
        exit 1
    fi

    MODE="${MODE:-vibe}"

    if [[ -z "${TARGET_HOME:-}" ]]; then
        if declare -f _acfs_resolve_target_home >/dev/null 2>&1; then
            TARGET_HOME="$(_acfs_resolve_target_home "${TARGET_USER}" || true)"
        else
            if [[ "${TARGET_USER}" == "root" ]]; then
                TARGET_HOME="/root"
            else
                _acfs_passwd_entry="$(getent passwd "${TARGET_USER}" 2>/dev/null || true)"
                if [[ -n "$_acfs_passwd_entry" ]]; then
                    _acfs_passwd_entry="$(printf '%s\n' "$_acfs_passwd_entry" | cut -d: -f6)"
                    if [[ -n "$_acfs_passwd_entry" ]] && [[ "$_acfs_passwd_entry" == /* ]] && [[ "$_acfs_passwd_entry" != "/" ]]; then
                        TARGET_HOME="${_acfs_passwd_entry%/}"
                    fi
                elif [[ "$(id -un 2>/dev/null || true)" == "${TARGET_USER}" ]] && [[ -n "${HOME:-}" ]] && [[ "${HOME}" == /* ]] && [[ "${HOME}" != "/" ]]; then
                    TARGET_HOME="${HOME%/}"
                fi
                unset _acfs_passwd_entry
            fi
        fi
    fi

    if [[ -z "${TARGET_HOME:-}" ]] || [[ "${TARGET_HOME}" == "/" ]] || [[ "${TARGET_HOME}" != /* ]]; then
        log_error "Invalid TARGET_HOME for '${TARGET_USER}': ${TARGET_HOME:-<empty>} (must be an absolute path and cannot be '/')"
        exit 1
    fi

    # Derive "bootstrap" paths from the repo layout (scripts/generated/.. -> repo root).
    if [[ -z "${ACFS_BOOTSTRAP_DIR:-}" ]]; then
        ACFS_BOOTSTRAP_DIR="$(cd "$ACFS_GENERATED_SCRIPT_DIR/../.." && pwd)"
    fi

    ACFS_BIN_DIR="${ACFS_BIN_DIR:-$TARGET_HOME/.local/bin}"
    if [[ -z "${ACFS_BIN_DIR:-}" ]] || [[ "${ACFS_BIN_DIR}" == "/" ]] || [[ "${ACFS_BIN_DIR}" != /* ]]; then
        log_error "ACFS_BIN_DIR must be an absolute path and cannot be '/' (got: ${ACFS_BIN_DIR:-<empty>})"
        exit 1
    fi
    ACFS_LIB_DIR="${ACFS_LIB_DIR:-$ACFS_BOOTSTRAP_DIR/scripts/lib}"
    ACFS_GENERATED_DIR="${ACFS_GENERATED_DIR:-$ACFS_BOOTSTRAP_DIR/scripts/generated}"
    ACFS_ASSETS_DIR="${ACFS_ASSETS_DIR:-$ACFS_BOOTSTRAP_DIR/acfs}"
    ACFS_CHECKSUMS_YAML="${ACFS_CHECKSUMS_YAML:-$ACFS_BOOTSTRAP_DIR/checksums.yaml}"
    ACFS_MANIFEST_YAML="${ACFS_MANIFEST_YAML:-$ACFS_BOOTSTRAP_DIR/acfs.manifest.yaml}"

    export TARGET_USER TARGET_HOME MODE ACFS_BIN_DIR
    export ACFS_BOOTSTRAP_DIR ACFS_LIB_DIR ACFS_GENERATED_DIR ACFS_ASSETS_DIR ACFS_CHECKSUMS_YAML ACFS_MANIFEST_YAML
fi

# Source contract validation
if [[ -f "$ACFS_GENERATED_SCRIPT_DIR/../lib/contract.sh" ]]; then
    source "$ACFS_GENERATED_SCRIPT_DIR/../lib/contract.sh"
fi

# Optional security verification for upstream installer scripts.
# Scripts that need it should call: acfs_security_init
ACFS_SECURITY_READY=false
acfs_security_init() {
    if [[ "${ACFS_SECURITY_READY}" = "true" ]]; then
        return 0
    fi

    local security_lib="$ACFS_GENERATED_SCRIPT_DIR/../lib/security.sh"
    if [[ ! -f "$security_lib" ]]; then
        log_error "Security library not found: $security_lib"
        return 1
    fi

    # Use ACFS_CHECKSUMS_YAML if set by install.sh bootstrap (overrides security.sh default)
    if [[ -n "${ACFS_CHECKSUMS_YAML:-}" ]]; then
        export CHECKSUMS_FILE="${ACFS_CHECKSUMS_YAML}"
    fi

    # shellcheck source=../lib/security.sh
    # shellcheck disable=SC1091  # runtime relative source
    source "$security_lib"
    load_checksums || { log_error "Failed to load checksums.yaml"; return 1; }
    ACFS_SECURITY_READY=true
    return 0
}

# Category: agents
# Modules: 4

# Claude Code
install_agents_claude() {
    local module_id="agents.claude"
    acfs_require_contract "module:${module_id}" || return 1
    log_step "Installing agents.claude"

    if [[ "${DRY_RUN:-false}" = "true" ]]; then
        log_info "dry-run: verified installer: agents.claude"
    else
        if ! {
            # Try security-verified install (no unverified fallback; fail closed)
            local install_success=false

            if acfs_security_init; then
                # Check if KNOWN_INSTALLERS is available as an associative array (declare -A)
                # The grep ensures we specifically have an associative array, not just any variable
                if declare -p KNOWN_INSTALLERS 2>/dev/null | grep -q 'declare -A'; then
                    local tool="claude"
                    local url=""
                    local expected_sha256=""

                    # Safe access with explicit empty default
                    url="${KNOWN_INSTALLERS[$tool]:-}"
                    if ! expected_sha256="$(get_checksum "$tool")"; then
                        log_error "agents.claude: get_checksum failed for tool '$tool'"
                        expected_sha256=""
                    fi

                    if [[ -n "$url" ]] && [[ -n "$expected_sha256" ]]; then
                        if verify_checksum "$url" "$expected_sha256" "$tool" | run_as_target_runner 'bash' '-s' '--' 'latest'; then
                            install_success=true
                        else
                            log_error "agents.claude: verify_checksum or installer execution failed"
                        fi
                    else
                        if [[ -z "$url" ]]; then
                            log_error "agents.claude: KNOWN_INSTALLERS[$tool] not found"
                        fi
                        if [[ -z "$expected_sha256" ]]; then
                            log_error "agents.claude: checksum for '$tool' not found"
                        fi
                    fi
                else
                    log_error "agents.claude: KNOWN_INSTALLERS array not available"
                fi
            else
                log_error "agents.claude: acfs_security_init failed - check security.sh and checksums.yaml"
            fi

            # Verified install is required - no fallback
            if [[ "$install_success" = "true" ]]; then
                true
            else
                log_error "Verified install failed for agents.claude"
                false
            fi
        }; then
            log_error "agents.claude: verified installer failed"
            return 1
        fi
    fi
    if [[ "${DRY_RUN:-false}" = "true" ]]; then
        log_info "dry-run: install: for candidate in \"\$HOME/.claude/bin/claude\" \"\$HOME/.claude/local/bin/claude\" \"\$HOME/.bun/bin/claude\"; do (target_user)"
    else
        if ! run_as_target_shell <<'INSTALL_AGENTS_CLAUDE'
claude_candidate=""
for candidate in "$HOME/.claude/bin/claude" "$HOME/.claude/local/bin/claude" "$HOME/.bun/bin/claude"; do
  if [[ -x "$candidate" ]]; then
    claude_candidate="$candidate"
    break
  fi
done
if [[ -z "$claude_candidate" ]] && [[ -d "$HOME/.claude" ]]; then
  claude_candidate="$(find "$HOME/.claude" -maxdepth 4 -type f -name claude -perm -111 -print -quit 2>/dev/null || true)"
fi
if [[ -z "$claude_candidate" ]] || [[ ! -x "$claude_candidate" ]]; then
  echo "Claude Code: installed but no runnable claude binary found" >&2
  exit 1
fi
acfs_link_primary_bin_command "$claude_candidate" "claude"
INSTALL_AGENTS_CLAUDE
        then
            log_error "agents.claude: install command failed: for candidate in \"\$HOME/.claude/bin/claude\" \"\$HOME/.claude/local/bin/claude\" \"\$HOME/.bun/bin/claude\"; do"
            return 1
        fi
    fi

    # Verify
    if [[ "${DRY_RUN:-false}" = "true" ]]; then
        log_info "dry-run: verify: \"\$target_bin/claude\" --version || \"\$target_bin/claude\" --help (target_user)"
    else
        if ! run_as_target_shell <<'INSTALL_AGENTS_CLAUDE'
target_bin="${ACFS_BIN_DIR:-$HOME/.local/bin}"
"$target_bin/claude" --version || "$target_bin/claude" --help
INSTALL_AGENTS_CLAUDE
        then
            log_error "agents.claude: verify failed: \"\$target_bin/claude\" --version || \"\$target_bin/claude\" --help"
            return 1
        fi
    fi

    log_success "agents.claude installed"
}

# OpenAI Codex CLI
install_agents_codex() {
    local module_id="agents.codex"
    acfs_require_contract "module:${module_id}" || return 1
    log_step "Installing agents.codex"

    if [[ "${DRY_RUN:-false}" = "true" ]]; then
        log_info "dry-run: install: if ! ~/.bun/bin/bun install -g --trust @openai/codex@latest; then (target_user)"
    else
        if ! run_as_target_shell <<'INSTALL_AGENTS_CODEX'
if ! ~/.bun/bin/bun install -g --trust @openai/codex@latest; then
  echo "WARN: Codex CLI latest tag install failed; retrying @openai/codex" >&2
  ~/.bun/bin/bun install -g --trust @openai/codex
fi
INSTALL_AGENTS_CODEX
        then
            log_error "agents.codex: install command failed: if ! ~/.bun/bin/bun install -g --trust @openai/codex@latest; then"
            return 1
        fi
    fi
    if [[ "${DRY_RUN:-false}" = "true" ]]; then
        log_info "dry-run: install: trap 'rm -f \"\$wrapper_tmp\"' EXIT (target_user)"
    else
        if ! run_as_target_shell <<'INSTALL_AGENTS_CODEX'
wrapper_tmp="$(mktemp "${TMPDIR:-/tmp}/acfs-codex-wrapper.XXXXXX")"
trap 'rm -f "$wrapper_tmp"' EXIT
cat > "$wrapper_tmp" << 'WRAPPER'
#!/bin/bash
exec "$HOME/.bun/bin/bun" "$HOME/.bun/bin/codex" "$@"
WRAPPER
acfs_install_executable_into_primary_bin "$wrapper_tmp" "codex"
INSTALL_AGENTS_CODEX
        then
            log_error "agents.codex: install command failed: trap 'rm -f \"\$wrapper_tmp\"' EXIT"
            return 1
        fi
    fi

    # Verify
    if [[ "${DRY_RUN:-false}" = "true" ]]; then
        log_info "dry-run: verify: \"\$target_bin/codex\" --version || \"\$target_bin/codex\" --help (target_user)"
    else
        if ! run_as_target_shell <<'INSTALL_AGENTS_CODEX'
target_bin="${ACFS_BIN_DIR:-$HOME/.local/bin}"
"$target_bin/codex" --version || "$target_bin/codex" --help
INSTALL_AGENTS_CODEX
        then
            log_error "agents.codex: verify failed: \"\$target_bin/codex\" --version || \"\$target_bin/codex\" --help"
            return 1
        fi
    fi

    log_success "agents.codex installed"
}

# Google Gemini CLI
install_agents_gemini() {
    local module_id="agents.gemini"
    acfs_require_contract "module:${module_id}" || return 1
    log_step "Installing agents.gemini"

    if [[ "${DRY_RUN:-false}" = "true" ]]; then
        log_info "dry-run: install: ~/.bun/bin/bun install -g --trust @google/gemini-cli@latest (target_user)"
    else
        if ! run_as_target_shell <<'INSTALL_AGENTS_GEMINI'
~/.bun/bin/bun install -g --trust @google/gemini-cli@latest
INSTALL_AGENTS_GEMINI
        then
            log_error "agents.gemini: install command failed: ~/.bun/bin/bun install -g --trust @google/gemini-cli@latest"
            return 1
        fi
    fi
    if [[ "${DRY_RUN:-false}" = "true" ]]; then
        log_info "dry-run: install: trap 'rm -f \"\$wrapper_tmp\"' EXIT (target_user)"
    else
        if ! run_as_target_shell <<'INSTALL_AGENTS_GEMINI'
wrapper_tmp="$(mktemp "${TMPDIR:-/tmp}/acfs-gemini-wrapper.XXXXXX")"
trap 'rm -f "$wrapper_tmp"' EXIT
cat > "$wrapper_tmp" << 'WRAPPER'
#!/bin/bash
exec "$HOME/.bun/bin/bun" "$HOME/.bun/bin/gemini" "$@"
WRAPPER
acfs_install_executable_into_primary_bin "$wrapper_tmp" "gemini"
INSTALL_AGENTS_GEMINI
        then
            log_error "agents.gemini: install command failed: trap 'rm -f \"\$wrapper_tmp\"' EXIT"
            return 1
        fi
    fi
    if [[ "${DRY_RUN:-false}" = "true" ]]; then
        log_info "dry-run: install: if [[ ! -f \"\$security_lib\" ]]; then (target_user)"
    else
        if ! run_as_target_shell <<'INSTALL_AGENTS_GEMINI'
security_lib="${ACFS_LIB_DIR:-$HOME/.acfs/scripts/lib}/security.sh"
if [[ ! -f "$security_lib" ]]; then
  echo "agents.gemini: security library not found at $security_lib" >&2
  exit 1
fi
if [[ -n "${ACFS_CHECKSUMS_YAML:-}" ]]; then
  export CHECKSUMS_FILE="$ACFS_CHECKSUMS_YAML"
fi
# shellcheck disable=SC1090,SC1091
source "$security_lib"
load_checksums
if ! compgen -G "$HOME/.nvm/versions/node/*/bin/node" > /dev/null; then
  nvm_url="${KNOWN_INSTALLERS[nvm]:-}"
  nvm_sha256="$(get_checksum nvm)"
  if [[ -z "$nvm_url" || -z "$nvm_sha256" ]]; then
    echo "agents.gemini: missing verified installer metadata for nvm" >&2
    exit 1
  fi
  verify_checksum "$nvm_url" "$nvm_sha256" "nvm" | bash
  export NVM_DIR="$HOME/.nvm"
  if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
    echo "agents.gemini: nvm.sh not found at $NVM_DIR/nvm.sh" >&2
    exit 1
  fi
  . "$NVM_DIR/nvm.sh"
  nvm install node
  nvm alias default node
fi
nvm_node_bin="$(compgen -G "$HOME/.nvm/versions/node/*/bin" | sort -V | tail -n 1)"
if [[ -z "$nvm_node_bin" ]]; then
  echo "agents.gemini: nvm Node.js bin not found after install" >&2
  exit 1
fi
export PATH="$nvm_node_bin:$PATH"
patch_url="${KNOWN_INSTALLERS[gemini_patch]:-}"
patch_sha256="$(get_checksum gemini_patch)"
if [[ -z "$patch_url" || -z "$patch_sha256" ]]; then
  echo "agents.gemini: missing verified installer metadata for gemini_patch" >&2
  exit 1
fi
verify_checksum "$patch_url" "$patch_sha256" "gemini_patch" | bash
INSTALL_AGENTS_GEMINI
        then
            log_error "agents.gemini: install command failed: if [[ ! -f \"\$security_lib\" ]]; then"
            return 1
        fi
    fi

    # Verify
    if [[ "${DRY_RUN:-false}" = "true" ]]; then
        log_info "dry-run: verify: \"\$target_bin/gemini\" --version || \"\$target_bin/gemini\" --help (target_user)"
    else
        if ! run_as_target_shell <<'INSTALL_AGENTS_GEMINI'
target_bin="${ACFS_BIN_DIR:-$HOME/.local/bin}"
"$target_bin/gemini" --version || "$target_bin/gemini" --help
INSTALL_AGENTS_GEMINI
        then
            log_error "agents.gemini: verify failed: \"\$target_bin/gemini\" --version || \"\$target_bin/gemini\" --help"
            return 1
        fi
    fi

    log_success "agents.gemini installed"
}

# OpenCode (multi-provider agent harness)
install_agents_opencode() {
    local module_id="agents.opencode"
    acfs_require_contract "module:${module_id}" || return 1
    log_step "Installing agents.opencode"

    if [[ "${DRY_RUN:-false}" = "true" ]]; then
        log_info "dry-run: verified installer: agents.opencode"
    else
        if ! {
            # Try security-verified install (no unverified fallback; fail closed)
            local install_success=false

            if acfs_security_init; then
                # Check if KNOWN_INSTALLERS is available as an associative array (declare -A)
                # The grep ensures we specifically have an associative array, not just any variable
                if declare -p KNOWN_INSTALLERS 2>/dev/null | grep -q 'declare -A'; then
                    local tool="opencode"
                    local url=""
                    local expected_sha256=""

                    # Safe access with explicit empty default
                    url="${KNOWN_INSTALLERS[$tool]:-}"
                    if ! expected_sha256="$(get_checksum "$tool")"; then
                        log_error "agents.opencode: get_checksum failed for tool '$tool'"
                        expected_sha256=""
                    fi

                    if [[ -n "$url" ]] && [[ -n "$expected_sha256" ]]; then
                        if verify_checksum "$url" "$expected_sha256" "$tool" | run_as_target_runner 'bash' '-s'; then
                            install_success=true
                        else
                            log_error "agents.opencode: verify_checksum or installer execution failed"
                        fi
                    else
                        if [[ -z "$url" ]]; then
                            log_error "agents.opencode: KNOWN_INSTALLERS[$tool] not found"
                        fi
                        if [[ -z "$expected_sha256" ]]; then
                            log_error "agents.opencode: checksum for '$tool' not found"
                        fi
                    fi
                else
                    log_error "agents.opencode: KNOWN_INSTALLERS array not available"
                fi
            else
                log_error "agents.opencode: acfs_security_init failed - check security.sh and checksums.yaml"
            fi

            # Verified install is required - no fallback
            if [[ "$install_success" = "true" ]]; then
                true
            else
                log_error "Verified install failed for agents.opencode"
                false
            fi
        }; then
            log_warn "agents.opencode: verified installer failed"
            if type -t record_skipped_tool >/dev/null 2>&1; then
              record_skipped_tool "agents.opencode" "verified installer failed"
            elif type -t state_tool_skip >/dev/null 2>&1; then
              state_tool_skip "agents.opencode"
            fi
            return 0
        fi
    fi

    # Verify
    if [[ "${DRY_RUN:-false}" = "true" ]]; then
        log_info "dry-run: verify: opencode --version || opencode --help (target_user)"
    else
        if ! run_as_target_shell <<'INSTALL_AGENTS_OPENCODE'
opencode --version || opencode --help
INSTALL_AGENTS_OPENCODE
        then
            log_warn "agents.opencode: verify failed: opencode --version || opencode --help"
            if type -t record_skipped_tool >/dev/null 2>&1; then
              record_skipped_tool "agents.opencode" "verify failed: opencode --version || opencode --help"
            elif type -t state_tool_skip >/dev/null 2>&1; then
              state_tool_skip "agents.opencode"
            fi
            return 0
        fi
    fi

    log_success "agents.opencode installed"
}

# Install all agents modules
install_agents() {
    log_section "Installing agents modules"
    install_agents_claude
    install_agents_codex
    install_agents_gemini
    install_agents_opencode
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" = "${0}" ]]; then
    install_agents
fi
