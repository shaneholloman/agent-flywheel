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

# Category: acfs
# Modules: 5

# Agent workspace with tmux session and project folder
install_acfs_workspace() {
    local module_id="acfs.workspace"
    acfs_require_contract "module:${module_id}" || return 1
    log_step "Installing acfs.workspace"

    if [[ "${DRY_RUN:-false}" = "true" ]]; then
        log_info "dry-run: install: mkdir -p /data/projects/my_first_project (target_user)"
    else
        if ! run_as_target_shell <<'INSTALL_ACFS_WORKSPACE'
# Create project directory
mkdir -p /data/projects/my_first_project
cd /data/projects/my_first_project
git init 2>/dev/null || true
INSTALL_ACFS_WORKSPACE
        then
            log_warn "acfs.workspace: install command failed: mkdir -p /data/projects/my_first_project"
            if type -t record_skipped_tool >/dev/null 2>&1; then
              record_skipped_tool "acfs.workspace" "install command failed: mkdir -p /data/projects/my_first_project"
            elif type -t state_tool_skip >/dev/null 2>&1; then
              state_tool_skip "acfs.workspace"
            fi
            return 0
        fi
    fi
    if [[ "${DRY_RUN:-false}" = "true" ]]; then
        log_info "dry-run: install: mkdir -p ~/.acfs (target_user)"
    else
        if ! run_as_target_shell <<'INSTALL_ACFS_WORKSPACE'
# Create workspace instructions file
mkdir -p ~/.acfs
printf '%s\n' "" \
  "  ACFS AGENT WORKSPACE - QUICK REFERENCE" \
  "  --------------------------------------" \
  "" \
  "  RECONNECT AFTER SSH:" \
  "    tmux attach -t agents    OR just type:  agents" \
  "" \
  "  WINDOWS (Ctrl-b + number):" \
  "    0:welcome  - This instructions window" \
  "    1:claude   - Claude Code (Anthropic)" \
  "    2:codex    - Codex CLI (OpenAI)" \
  "    3:gemini   - Gemini CLI (Google)" \
  "" \
  "  TMUX BASICS:" \
  "    Ctrl-b d        - Detach (keep session running)" \
  "    Ctrl-b c        - Create new window" \
  "    Ctrl-b n/p      - Next/previous window" \
  "    Ctrl-b [0-9]    - Switch to window number" \
  "" \
  "  START AN AGENT:" \
  "    claude          - Start Claude Code" \
  "    codex           - Start Codex CLI" \
  "    gemini          - Start Gemini CLI" \
  "" \
  "  PROJECT: /data/projects/my_first_project" \
  "  (Rename with: mv /data/projects/my_first_project /data/projects/NEW_NAME)" \
  "" > ~/.acfs/workspace-instructions.txt
INSTALL_ACFS_WORKSPACE
        then
            log_warn "acfs.workspace: install command failed: mkdir -p ~/.acfs"
            if type -t record_skipped_tool >/dev/null 2>&1; then
              record_skipped_tool "acfs.workspace" "install command failed: mkdir -p ~/.acfs"
            elif type -t state_tool_skip >/dev/null 2>&1; then
              state_tool_skip "acfs.workspace"
            fi
            return 0
        fi
    fi
    if [[ "${DRY_RUN:-false}" = "true" ]]; then
        log_info "dry-run: install: if ! tmux has-session -t \"\$SESSION_NAME\" 2>/dev/null; then (target_user)"
    else
        if ! run_as_target_shell <<'INSTALL_ACFS_WORKSPACE'
# Create tmux session with agent panes (if not already running)
SESSION_NAME="agents"
if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  # Create session with first window for instructions
  tmux new-session -d -s "$SESSION_NAME" -n "welcome" -c /data/projects/my_first_project

  # Add agent windows
  tmux new-window -t "$SESSION_NAME" -n "claude" -c /data/projects/my_first_project
  tmux new-window -t "$SESSION_NAME" -n "codex" -c /data/projects/my_first_project
  tmux new-window -t "$SESSION_NAME" -n "gemini" -c /data/projects/my_first_project

  # Send instructions to welcome window
  tmux send-keys -t "$SESSION_NAME:welcome" "cat ~/.acfs/workspace-instructions.txt" Enter

  # Select the welcome window
  tmux select-window -t "$SESSION_NAME:welcome"
fi
INSTALL_ACFS_WORKSPACE
        then
            log_warn "acfs.workspace: install command failed: if ! tmux has-session -t \"\$SESSION_NAME\" 2>/dev/null; then"
            if type -t record_skipped_tool >/dev/null 2>&1; then
              record_skipped_tool "acfs.workspace" "install command failed: if ! tmux has-session -t \"\$SESSION_NAME\" 2>/dev/null; then"
            elif type -t state_tool_skip >/dev/null 2>&1; then
              state_tool_skip "acfs.workspace"
            fi
            return 0
        fi
    fi
    if [[ "${DRY_RUN:-false}" = "true" ]]; then
        log_info "dry-run: install: if [[ ! -f ~/.zshrc.local ]] || ! grep -q \"alias agents=\" ~/.zshrc.local; then (target_user)"
    else
        if ! run_as_target_shell <<'INSTALL_ACFS_WORKSPACE'
# Add agents alias to zshrc.local if not already present
if [[ ! -f ~/.zshrc.local ]] || ! grep -q "alias agents=" ~/.zshrc.local; then
  touch ~/.zshrc.local 2>/dev/null || true
  echo '' >> ~/.zshrc.local
  echo '# ACFS agents workspace alias' >> ~/.zshrc.local
  echo 'alias agents="tmux attach -t agents 2>/dev/null || tmux new-session -s agents -c /data/projects"' >> ~/.zshrc.local
fi
INSTALL_ACFS_WORKSPACE
        then
            log_warn "acfs.workspace: install command failed: if [[ ! -f ~/.zshrc.local ]] || ! grep -q \"alias agents=\" ~/.zshrc.local; then"
            if type -t record_skipped_tool >/dev/null 2>&1; then
              record_skipped_tool "acfs.workspace" "install command failed: if [[ ! -f ~/.zshrc.local ]] || ! grep -q \"alias agents=\" ~/.zshrc.local; then"
            elif type -t state_tool_skip >/dev/null 2>&1; then
              state_tool_skip "acfs.workspace"
            fi
            return 0
        fi
    fi

    # Verify
    if [[ "${DRY_RUN:-false}" = "true" ]]; then
        log_info "dry-run: verify: test -d /data/projects/my_first_project (target_user)"
    else
        if ! run_as_target_shell <<'INSTALL_ACFS_WORKSPACE'
test -d /data/projects/my_first_project
INSTALL_ACFS_WORKSPACE
        then
            log_warn "acfs.workspace: verify failed: test -d /data/projects/my_first_project"
            if type -t record_skipped_tool >/dev/null 2>&1; then
              record_skipped_tool "acfs.workspace" "verify failed: test -d /data/projects/my_first_project"
            elif type -t state_tool_skip >/dev/null 2>&1; then
              state_tool_skip "acfs.workspace"
            fi
            return 0
        fi
    fi
    if [[ "${DRY_RUN:-false}" = "true" ]]; then
        log_info "dry-run: verify: grep -q \"alias agents=\" ~/.zshrc.local || grep -q \"alias agents=\" ~/.zshrc (target_user)"
    else
        if ! run_as_target_shell <<'INSTALL_ACFS_WORKSPACE'
grep -q "alias agents=" ~/.zshrc.local || grep -q "alias agents=" ~/.zshrc
INSTALL_ACFS_WORKSPACE
        then
            log_warn "acfs.workspace: verify failed: grep -q \"alias agents=\" ~/.zshrc.local || grep -q \"alias agents=\" ~/.zshrc"
            if type -t record_skipped_tool >/dev/null 2>&1; then
              record_skipped_tool "acfs.workspace" "verify failed: grep -q \"alias agents=\" ~/.zshrc.local || grep -q \"alias agents=\" ~/.zshrc"
            elif type -t state_tool_skip >/dev/null 2>&1; then
              state_tool_skip "acfs.workspace"
            fi
            return 0
        fi
    fi

    log_success "acfs.workspace installed"
}

# Onboarding TUI tutorial
install_acfs_onboard() {
    local module_id="acfs.onboard"
    acfs_require_contract "module:${module_id}" || return 1
    log_step "Installing acfs.onboard"

    if [[ "${DRY_RUN:-false}" = "true" ]]; then
        log_info "dry-run: install: trap 'rm -f \"\$onboard_tmp\"' EXIT (target_user)"
    else
        if ! run_as_target_shell <<'INSTALL_ACFS_ONBOARD'
onboard_tmp="$(mktemp "${TMPDIR:-/tmp}/acfs-onboard.XXXXXX")"
trap 'rm -f "$onboard_tmp"' EXIT
# Install onboard script
if [[ -n "${ACFS_BOOTSTRAP_DIR:-}" ]] && [[ -f "${ACFS_BOOTSTRAP_DIR}/packages/onboard/onboard.sh" ]]; then
  cp "${ACFS_BOOTSTRAP_DIR}/packages/onboard/onboard.sh" "$onboard_tmp"
elif [[ -f "packages/onboard/onboard.sh" ]]; then
  cp "packages/onboard/onboard.sh" "$onboard_tmp"
else
  ACFS_RAW="${ACFS_RAW:-https://raw.githubusercontent.com/Dicklesworthstone/agentic_coding_flywheel_setup/${ACFS_REF:-main}}"
  CURL_ARGS=(-fsSL)
  if curl --help all 2>/dev/null | grep -q -- '--proto'; then
    CURL_ARGS=(--proto '=https' --proto-redir '=https' -fsSL)
  fi
  curl "${CURL_ARGS[@]}" "${ACFS_RAW}/packages/onboard/onboard.sh" -o "$onboard_tmp"
fi
acfs_install_executable_into_primary_bin "$onboard_tmp" "onboard"
INSTALL_ACFS_ONBOARD
        then
            log_error "acfs.onboard: install command failed: trap 'rm -f \"\$onboard_tmp\"' EXIT"
            return 1
        fi
    fi

    # Verify
    if [[ "${DRY_RUN:-false}" = "true" ]]; then
        log_info "dry-run: verify: onboard --help || command -v onboard (target_user)"
    else
        if ! run_as_target_shell <<'INSTALL_ACFS_ONBOARD'
onboard --help || command -v onboard
INSTALL_ACFS_ONBOARD
        then
            log_error "acfs.onboard: verify failed: onboard --help || command -v onboard"
            return 1
        fi
    fi

    log_success "acfs.onboard installed"
}

# ACFS update command wrapper
install_acfs_update() {
    local module_id="acfs.update"
    acfs_require_contract "module:${module_id}" || return 1
    log_step "Installing acfs.update"

    if [[ "${DRY_RUN:-false}" = "true" ]]; then
        log_info "dry-run: install: mkdir -p ~/.acfs/scripts (target_user)"
    else
        if ! run_as_target_shell <<'INSTALL_ACFS_UPDATE'
mkdir -p ~/.acfs/scripts
INSTALL_ACFS_UPDATE
        then
            log_error "acfs.update: install command failed: mkdir -p ~/.acfs/scripts"
            return 1
        fi
    fi
    if [[ "${DRY_RUN:-false}" = "true" ]]; then
        log_info "dry-run: install: if [[ -n \"\${ACFS_BOOTSTRAP_DIR:-}\" ]] && [[ -f \"\${ACFS_BOOTSTRAP_DIR}/scripts/lib/nightly_update.sh\" ]]; then (target_user)"
    else
        if ! run_as_target_shell <<'INSTALL_ACFS_UPDATE'
# Install acfs-update wrapper
if [[ -n "${ACFS_BOOTSTRAP_DIR:-}" ]] && [[ -f "${ACFS_BOOTSTRAP_DIR}/scripts/lib/nightly_update.sh" ]]; then
  cp "${ACFS_BOOTSTRAP_DIR}/scripts/lib/nightly_update.sh" ~/.acfs/scripts/nightly-update.sh
elif [[ -f "scripts/lib/nightly_update.sh" ]]; then
  cp "scripts/lib/nightly_update.sh" ~/.acfs/scripts/nightly-update.sh
else
  ACFS_RAW="${ACFS_RAW:-https://raw.githubusercontent.com/Dicklesworthstone/agentic_coding_flywheel_setup/${ACFS_REF:-main}}"
  CURL_ARGS=(-fsSL)
  if curl --help all 2>/dev/null | grep -q -- '--proto'; then
    CURL_ARGS=(--proto '=https' --proto-redir '=https' -fsSL)
  fi
  curl "${CURL_ARGS[@]}" "${ACFS_RAW}/scripts/lib/nightly_update.sh" -o ~/.acfs/scripts/nightly-update.sh
fi
chmod +x ~/.acfs/scripts/nightly-update.sh
INSTALL_ACFS_UPDATE
        then
            log_error "acfs.update: install command failed: if [[ -n \"\${ACFS_BOOTSTRAP_DIR:-}\" ]] && [[ -f \"\${ACFS_BOOTSTRAP_DIR}/scripts/lib/nightly_update.sh\" ]]; then"
            return 1
        fi
    fi
    if [[ "${DRY_RUN:-false}" = "true" ]]; then
        log_info "dry-run: install: trap 'rm -f \"\$update_tmp\"' EXIT (target_user)"
    else
        if ! run_as_target_shell <<'INSTALL_ACFS_UPDATE'
update_tmp="$(mktemp "${TMPDIR:-/tmp}/acfs-update-wrapper.XXXXXX")"
trap 'rm -f "$update_tmp"' EXIT
if [[ -n "${ACFS_BOOTSTRAP_DIR:-}" ]] && [[ -f "${ACFS_BOOTSTRAP_DIR}/scripts/acfs-update" ]]; then
  cp "${ACFS_BOOTSTRAP_DIR}/scripts/acfs-update" "$update_tmp"
elif [[ -f "scripts/acfs-update" ]]; then
  cp "scripts/acfs-update" "$update_tmp"
else
  ACFS_RAW="${ACFS_RAW:-https://raw.githubusercontent.com/Dicklesworthstone/agentic_coding_flywheel_setup/${ACFS_REF:-main}}"
  CURL_ARGS=(-fsSL)
  if curl --help all 2>/dev/null | grep -q -- '--proto'; then
    CURL_ARGS=(--proto '=https' --proto-redir '=https' -fsSL)
  fi
  curl "${CURL_ARGS[@]}" "${ACFS_RAW}/scripts/acfs-update" -o "$update_tmp"
fi
acfs_install_executable_into_primary_bin "$update_tmp" "acfs-update"
INSTALL_ACFS_UPDATE
        then
            log_error "acfs.update: install command failed: trap 'rm -f \"\$update_tmp\"' EXIT"
            return 1
        fi
    fi

    # Verify
    if [[ "${DRY_RUN:-false}" = "true" ]]; then
        log_info "dry-run: verify: acfs-update --help || command -v acfs-update (target_user)"
    else
        if ! run_as_target_shell <<'INSTALL_ACFS_UPDATE'
acfs-update --help || command -v acfs-update
INSTALL_ACFS_UPDATE
        then
            log_error "acfs.update: verify failed: acfs-update --help || command -v acfs-update"
            return 1
        fi
    fi

    log_success "acfs.update installed"
}

# Nightly auto-update timer (systemd)
install_acfs_nightly() {
    local module_id="acfs.nightly"
    acfs_require_contract "module:${module_id}" || return 1
    log_step "Installing acfs.nightly"

    if [[ "${DRY_RUN:-false}" = "true" ]]; then
        log_info "dry-run: install: mkdir -p ~/.acfs/scripts ~/.config/systemd/user (target_user)"
    else
        if ! run_as_target_shell <<'INSTALL_ACFS_NIGHTLY'
mkdir -p ~/.acfs/scripts ~/.config/systemd/user
INSTALL_ACFS_NIGHTLY
        then
            log_warn "acfs.nightly: install command failed: mkdir -p ~/.acfs/scripts ~/.config/systemd/user"
            if type -t record_skipped_tool >/dev/null 2>&1; then
              record_skipped_tool "acfs.nightly" "install command failed: mkdir -p ~/.acfs/scripts ~/.config/systemd/user"
            elif type -t state_tool_skip >/dev/null 2>&1; then
              state_tool_skip "acfs.nightly"
            fi
            return 0
        fi
    fi
    if [[ "${DRY_RUN:-false}" = "true" ]]; then
        log_info "dry-run: install: if [[ -n \"\${ACFS_BOOTSTRAP_DIR:-}\" ]] && [[ -f \"\${ACFS_BOOTSTRAP_DIR}/scripts/lib/nightly_update.sh\" ]]; then (target_user)"
    else
        if ! run_as_target_shell <<'INSTALL_ACFS_NIGHTLY'
# Install nightly update wrapper script
if [[ -n "${ACFS_BOOTSTRAP_DIR:-}" ]] && [[ -f "${ACFS_BOOTSTRAP_DIR}/scripts/lib/nightly_update.sh" ]]; then
  cp "${ACFS_BOOTSTRAP_DIR}/scripts/lib/nightly_update.sh" ~/.acfs/scripts/nightly-update.sh
elif [[ -f "scripts/lib/nightly_update.sh" ]]; then
  cp "scripts/lib/nightly_update.sh" ~/.acfs/scripts/nightly-update.sh
else
  ACFS_RAW="${ACFS_RAW:-https://raw.githubusercontent.com/Dicklesworthstone/agentic_coding_flywheel_setup/${ACFS_REF:-main}}"
  CURL_ARGS=(-fsSL)
  if curl --help all 2>/dev/null | grep -q -- '--proto'; then
    CURL_ARGS=(--proto '=https' --proto-redir '=https' -fsSL)
  fi
  curl "${CURL_ARGS[@]}" "${ACFS_RAW}/scripts/lib/nightly_update.sh" -o ~/.acfs/scripts/nightly-update.sh
fi
chmod +x ~/.acfs/scripts/nightly-update.sh
INSTALL_ACFS_NIGHTLY
        then
            log_warn "acfs.nightly: install command failed: if [[ -n \"\${ACFS_BOOTSTRAP_DIR:-}\" ]] && [[ -f \"\${ACFS_BOOTSTRAP_DIR}/scripts/lib/nightly_update.sh\" ]]; then"
            if type -t record_skipped_tool >/dev/null 2>&1; then
              record_skipped_tool "acfs.nightly" "install command failed: if [[ -n \"\${ACFS_BOOTSTRAP_DIR:-}\" ]] && [[ -f \"\${ACFS_BOOTSTRAP_DIR}/scripts/lib/nightly_update.sh\" ]]; then"
            elif type -t state_tool_skip >/dev/null 2>&1; then
              state_tool_skip "acfs.nightly"
            fi
            return 0
        fi
    fi
    if [[ "${DRY_RUN:-false}" = "true" ]]; then
        log_info "dry-run: install: if [[ -n \"\${ACFS_BOOTSTRAP_DIR:-}\" ]] && [[ -f \"\${ACFS_BOOTSTRAP_DIR}/scripts/templates/acfs-nightly-update.timer\" ]]; then (target_user)"
    else
        if ! run_as_target_shell <<'INSTALL_ACFS_NIGHTLY'
# Install systemd timer unit
if [[ -n "${ACFS_BOOTSTRAP_DIR:-}" ]] && [[ -f "${ACFS_BOOTSTRAP_DIR}/scripts/templates/acfs-nightly-update.timer" ]]; then
  cp "${ACFS_BOOTSTRAP_DIR}/scripts/templates/acfs-nightly-update.timer" ~/.config/systemd/user/acfs-nightly-update.timer
elif [[ -f "scripts/templates/acfs-nightly-update.timer" ]]; then
  cp "scripts/templates/acfs-nightly-update.timer" ~/.config/systemd/user/acfs-nightly-update.timer
else
  ACFS_RAW="${ACFS_RAW:-https://raw.githubusercontent.com/Dicklesworthstone/agentic_coding_flywheel_setup/${ACFS_REF:-main}}"
  CURL_ARGS=(-fsSL)
  if curl --help all 2>/dev/null | grep -q -- '--proto'; then
    CURL_ARGS=(--proto '=https' --proto-redir '=https' -fsSL)
  fi
  curl "${CURL_ARGS[@]}" "${ACFS_RAW}/scripts/templates/acfs-nightly-update.timer" -o ~/.config/systemd/user/acfs-nightly-update.timer
fi
INSTALL_ACFS_NIGHTLY
        then
            log_warn "acfs.nightly: install command failed: if [[ -n \"\${ACFS_BOOTSTRAP_DIR:-}\" ]] && [[ -f \"\${ACFS_BOOTSTRAP_DIR}/scripts/templates/acfs-nightly-update.timer\" ]]; then"
            if type -t record_skipped_tool >/dev/null 2>&1; then
              record_skipped_tool "acfs.nightly" "install command failed: if [[ -n \"\${ACFS_BOOTSTRAP_DIR:-}\" ]] && [[ -f \"\${ACFS_BOOTSTRAP_DIR}/scripts/templates/acfs-nightly-update.timer\" ]]; then"
            elif type -t state_tool_skip >/dev/null 2>&1; then
              state_tool_skip "acfs.nightly"
            fi
            return 0
        fi
    fi
    if [[ "${DRY_RUN:-false}" = "true" ]]; then
        log_info "dry-run: install: if [[ -n \"\${ACFS_BOOTSTRAP_DIR:-}\" ]] && [[ -f \"\${ACFS_BOOTSTRAP_DIR}/scripts/templates/acfs-nightly-update.service\" ]]; then (target_user)"
    else
        if ! run_as_target_shell <<'INSTALL_ACFS_NIGHTLY'
# Install systemd service unit
if [[ -n "${ACFS_BOOTSTRAP_DIR:-}" ]] && [[ -f "${ACFS_BOOTSTRAP_DIR}/scripts/templates/acfs-nightly-update.service" ]]; then
  cp "${ACFS_BOOTSTRAP_DIR}/scripts/templates/acfs-nightly-update.service" ~/.config/systemd/user/acfs-nightly-update.service
elif [[ -f "scripts/templates/acfs-nightly-update.service" ]]; then
  cp "scripts/templates/acfs-nightly-update.service" ~/.config/systemd/user/acfs-nightly-update.service
else
  ACFS_RAW="${ACFS_RAW:-https://raw.githubusercontent.com/Dicklesworthstone/agentic_coding_flywheel_setup/${ACFS_REF:-main}}"
  CURL_ARGS=(-fsSL)
  if curl --help all 2>/dev/null | grep -q -- '--proto'; then
    CURL_ARGS=(--proto '=https' --proto-redir '=https' -fsSL)
  fi
  curl "${CURL_ARGS[@]}" "${ACFS_RAW}/scripts/templates/acfs-nightly-update.service" -o ~/.config/systemd/user/acfs-nightly-update.service
fi
INSTALL_ACFS_NIGHTLY
        then
            log_warn "acfs.nightly: install command failed: if [[ -n \"\${ACFS_BOOTSTRAP_DIR:-}\" ]] && [[ -f \"\${ACFS_BOOTSTRAP_DIR}/scripts/templates/acfs-nightly-update.service\" ]]; then"
            if type -t record_skipped_tool >/dev/null 2>&1; then
              record_skipped_tool "acfs.nightly" "install command failed: if [[ -n \"\${ACFS_BOOTSTRAP_DIR:-}\" ]] && [[ -f \"\${ACFS_BOOTSTRAP_DIR}/scripts/templates/acfs-nightly-update.service\" ]]; then"
            elif type -t state_tool_skip >/dev/null 2>&1; then
              state_tool_skip "acfs.nightly"
            fi
            return 0
        fi
    fi
    if [[ "${DRY_RUN:-false}" = "true" ]]; then
        log_info "dry-run: install: systemctl --user daemon-reload (target_user)"
    else
        if ! run_as_target_shell <<'INSTALL_ACFS_NIGHTLY'
# Reload systemd and enable the timer
systemctl --user daemon-reload
systemctl --user enable --now acfs-nightly-update.timer
INSTALL_ACFS_NIGHTLY
        then
            log_warn "acfs.nightly: install command failed: systemctl --user daemon-reload"
            if type -t record_skipped_tool >/dev/null 2>&1; then
              record_skipped_tool "acfs.nightly" "install command failed: systemctl --user daemon-reload"
            elif type -t state_tool_skip >/dev/null 2>&1; then
              state_tool_skip "acfs.nightly"
            fi
            return 0
        fi
    fi

    # Verify
    if [[ "${DRY_RUN:-false}" = "true" ]]; then
        log_info "dry-run: verify: systemctl --user is-enabled acfs-nightly-update.timer (target_user)"
    else
        if ! run_as_target_shell <<'INSTALL_ACFS_NIGHTLY'
systemctl --user is-enabled acfs-nightly-update.timer
INSTALL_ACFS_NIGHTLY
        then
            log_warn "acfs.nightly: verify failed: systemctl --user is-enabled acfs-nightly-update.timer"
            if type -t record_skipped_tool >/dev/null 2>&1; then
              record_skipped_tool "acfs.nightly" "verify failed: systemctl --user is-enabled acfs-nightly-update.timer"
            elif type -t state_tool_skip >/dev/null 2>&1; then
              state_tool_skip "acfs.nightly"
            fi
            return 0
        fi
    fi

    log_success "acfs.nightly installed"
}

# ACFS doctor command for health checks
install_acfs_doctor() {
    local module_id="acfs.doctor"
    acfs_require_contract "module:${module_id}" || return 1
    log_step "Installing acfs.doctor"

    if [[ "${DRY_RUN:-false}" = "true" ]]; then
        log_info "dry-run: install: trap 'rm -f \"\$doctor_tmp\"' EXIT (target_user)"
    else
        if ! run_as_target_shell <<'INSTALL_ACFS_DOCTOR'
doctor_tmp="$(mktemp "${TMPDIR:-/tmp}/acfs-doctor.XXXXXX")"
trap 'rm -f "$doctor_tmp"' EXIT
# Install acfs CLI (doctor.sh entrypoint)
if [[ -n "${ACFS_BOOTSTRAP_DIR:-}" ]] && [[ -f "${ACFS_BOOTSTRAP_DIR}/scripts/lib/doctor.sh" ]]; then
  cp "${ACFS_BOOTSTRAP_DIR}/scripts/lib/doctor.sh" "$doctor_tmp"
elif [[ -f "scripts/lib/doctor.sh" ]]; then
  cp "scripts/lib/doctor.sh" "$doctor_tmp"
else
  ACFS_RAW="${ACFS_RAW:-https://raw.githubusercontent.com/Dicklesworthstone/agentic_coding_flywheel_setup/${ACFS_REF:-main}}"
  CURL_ARGS=(-fsSL)
  if curl --help all 2>/dev/null | grep -q -- '--proto'; then
    CURL_ARGS=(--proto '=https' --proto-redir '=https' -fsSL)
  fi
  curl "${CURL_ARGS[@]}" "${ACFS_RAW}/scripts/lib/doctor.sh" -o "$doctor_tmp"
fi
acfs_install_executable_into_primary_bin "$doctor_tmp" "acfs"
INSTALL_ACFS_DOCTOR
        then
            log_error "acfs.doctor: install command failed: trap 'rm -f \"\$doctor_tmp\"' EXIT"
            return 1
        fi
    fi

    # Verify
    if [[ "${DRY_RUN:-false}" = "true" ]]; then
        log_info "dry-run: verify: acfs doctor --help || command -v acfs (target_user)"
    else
        if ! run_as_target_shell <<'INSTALL_ACFS_DOCTOR'
acfs doctor --help || command -v acfs
INSTALL_ACFS_DOCTOR
        then
            log_error "acfs.doctor: verify failed: acfs doctor --help || command -v acfs"
            return 1
        fi
    fi

    log_success "acfs.doctor installed"
}

# Install all acfs modules
install_acfs() {
    log_section "Installing acfs modules"
    install_acfs_workspace
    install_acfs_onboard
    install_acfs_update
    install_acfs_nightly
    install_acfs_doctor
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" = "${0}" ]]; then
    install_acfs
fi
