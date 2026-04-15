#!/usr/bin/env bash
# shellcheck disable=SC1091
# ============================================================
# ACFS Installer - Post-Install Smoke Test
# Fast verification that runs at the end of install.sh
# ============================================================

# Ensure we have logging functions available
if [[ -z "${ACFS_BLUE:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # shellcheck source=logging.sh
    source "$SCRIPT_DIR/logging.sh"
fi

_smoke_sanitize_abs_nonroot_path() {
    local path_value="${1:-}"

    [[ -n "$path_value" ]] || return 1
    path_value="${path_value%/}"
    [[ -n "$path_value" ]] || return 1
    [[ "$path_value" == /* ]] || return 1
    [[ "$path_value" != "/" ]] || return 1
    printf '%s\n' "$path_value"
}

_smoke_resolve_current_home() {
    local current_user=""
    local home_candidate=""
    local passwd_entry=""

    home_candidate="$(_smoke_sanitize_abs_nonroot_path "${HOME:-}" 2>/dev/null || true)"
    if [[ -n "$home_candidate" ]]; then
        printf '%s\n' "$home_candidate"
        return 0
    fi

    current_user="$(id -un 2>/dev/null || whoami 2>/dev/null || true)"
    if [[ "$current_user" == "root" ]]; then
        printf '/root\n'
        return 0
    fi

    if [[ -n "$current_user" ]]; then
        passwd_entry="$(getent passwd "$current_user" 2>/dev/null || true)"
        if [[ -n "$passwd_entry" ]]; then
            home_candidate="$(printf '%s\n' "$passwd_entry" | cut -d: -f6)"
            home_candidate="$(_smoke_sanitize_abs_nonroot_path "$home_candidate" 2>/dev/null || true)"
            if [[ -n "$home_candidate" ]]; then
                printf '%s\n' "$home_candidate"
                return 0
            fi
        fi

        if [[ "$current_user" =~ ^[a-z_][a-z0-9._-]*$ ]]; then
            printf '/home/%s\n' "$current_user"
            return 0
        fi
    fi

    return 1
}

_SMOKE_CURRENT_HOME="$(_smoke_resolve_current_home 2>/dev/null || true)"
if [[ -n "$_SMOKE_CURRENT_HOME" ]]; then
    HOME="$_SMOKE_CURRENT_HOME"
    export HOME
fi

# ============================================================
# Configuration
# ============================================================

# Test result counters (reset in run_smoke_test)
CRITICAL_PASS=0
CRITICAL_FAIL=0
NONCRITICAL_PASS=0
WARNING_COUNT=0

# Target user (from install.sh or default)
TARGET_USER="${TARGET_USER:-ubuntu}"
TARGET_HOME="$(_smoke_sanitize_abs_nonroot_path "${TARGET_HOME:-}" 2>/dev/null || true)"
if [[ -z "${TARGET_HOME:-}" ]]; then
    _smoke_target_passwd_entry="$(getent passwd "$TARGET_USER" 2>/dev/null || true)"
    if [[ -n "$_smoke_target_passwd_entry" ]]; then
        TARGET_HOME="$(_smoke_sanitize_abs_nonroot_path "$(printf '%s\n' "$_smoke_target_passwd_entry" | cut -d: -f6)" 2>/dev/null || true)"
    elif [[ "${TARGET_USER}" == "root" ]]; then
        TARGET_HOME="/root"
    elif [[ "${TARGET_USER}" == "$(id -un 2>/dev/null || true)" ]] && [[ -n "${_SMOKE_CURRENT_HOME:-}" ]]; then
        TARGET_HOME="$_SMOKE_CURRENT_HOME"
    elif [[ "${TARGET_USER}" =~ ^[a-z_][a-z0-9._-]*$ ]]; then
        TARGET_HOME="/home/$TARGET_USER"
    fi
    unset _smoke_target_passwd_entry
fi
if [[ "${TARGET_HOME:-}" != /* ]]; then
    if [[ "${TARGET_USER}" == "root" ]]; then
        TARGET_HOME="/root"
    elif [[ "${TARGET_USER}" == "$(id -un 2>/dev/null || true)" ]] && [[ -n "${_SMOKE_CURRENT_HOME:-}" ]]; then
        TARGET_HOME="$_SMOKE_CURRENT_HOME"
    elif [[ "${TARGET_USER}" =~ ^[a-z_][a-z0-9._-]*$ ]]; then
        TARGET_HOME="/home/$TARGET_USER"
    else
        TARGET_HOME=""
    fi
fi

_smoke_prepend_user_paths() {
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
        "$base_home/.atuin/bin" \
        "$base_home/go/bin"; do
        [[ -d "$dir" ]] || continue
        case ":$PATH:" in
            *":$dir:"*) ;;
            *) export PATH="$dir:$PATH" ;;
        esac
    done
}

_smoke_prepend_user_paths "$TARGET_HOME"
if [[ -n "${_SMOKE_CURRENT_HOME:-}" ]] && [[ "$_SMOKE_CURRENT_HOME" != "$TARGET_HOME" ]]; then
    _smoke_prepend_user_paths "$_SMOKE_CURRENT_HOME"
fi

_smoke_get_local_passwd_entry() {
    local user="${1:-}"
    [[ -n "$user" ]] || return 1
    [[ -r /etc/passwd ]] || return 1
    awk -F: -v user="$user" '$1 == user { print $0; exit }' /etc/passwd 2>/dev/null
}

_smoke_is_externally_managed_user() {
    local user="${1:-}"
    local passwd_entry=""
    local local_entry=""

    [[ -n "$user" ]] || return 1
    passwd_entry="$(getent passwd "$user" 2>/dev/null || true)"
    [[ -n "$passwd_entry" ]] || return 1

    local_entry="$(_smoke_get_local_passwd_entry "$user" || true)"
    [[ -z "$local_entry" ]]
}

_smoke_external_shell_handoff_configured() {
    local target_home="${1:-}"
    [[ -n "$target_home" ]] || return 1
    grep -q 'ACFS externally-managed shell handoff' "$target_home/.bashrc" 2>/dev/null
}

# ============================================================
# Output Helpers
# ============================================================

# Use ${var-default} (not ${var:-default}) to preserve empty strings for NO_COLOR.
# Related: bd-39ye
_smoke_pass() {
    local label="$1"
    echo -e "  ${ACFS_GREEN-\033[0;32m}✅${ACFS_NC-\033[0m} $label"
    ((CRITICAL_PASS += 1))
}

_smoke_fail() {
    local label="$1"
    local fix="${2:-}"
    echo -e "  ${ACFS_RED-\033[0;31m}❌${ACFS_NC-\033[0m} $label"
    if [[ -n "$fix" ]]; then
        echo -e "     ${ACFS_GRAY-\033[0;90m}Fix: $fix${ACFS_NC-\033[0m}"
    fi
    ((CRITICAL_FAIL += 1))
}

_smoke_warn() {
    local label="$1"
    local note="${2:-}"
    echo -e "  ${ACFS_YELLOW-\033[0;33m}⚠️${ACFS_NC-\033[0m} $label"
    if [[ -n "$note" ]]; then
        echo -e "     ${ACFS_GRAY-\033[0;90m}$note${ACFS_NC-\033[0m}"
    fi
    ((WARNING_COUNT += 1))
}

# Non-critical pass (doesn't affect critical count)
_smoke_info() {
    local label="$1"
    echo -e "  ${ACFS_GREEN-\033[0;32m}✅${ACFS_NC-\033[0m} $label"
    ((NONCRITICAL_PASS += 1))
}

_smoke_header() {
    echo ""
    echo -e "${ACFS_BLUE-\033[0;34m}[Smoke Test]${ACFS_NC-\033[0m}"
    echo ""
}

# ============================================================
# Critical Checks (must pass)
# ============================================================

# Check 1: User is ubuntu
_check_user() {
    local current_user
    current_user=$(whoami)
    if [[ "$current_user" == "$TARGET_USER" ]]; then
        _smoke_pass "User: $TARGET_USER"
        return 0
    else
        _smoke_fail "User: expected $TARGET_USER, got $current_user" "ssh $TARGET_USER@YOUR_SERVER"
        return 1
    fi
}

# Check 2: Shell is zsh
_check_shell() {
    local shell
    shell=$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f7)
    # Check if configured shell is zsh (the actual login shell, not just that zsh exists)
    if [[ "$shell" == *"zsh"* ]]; then
        _smoke_pass "Shell: zsh"
        return 0
    elif _smoke_is_externally_managed_user "$TARGET_USER"; then
        if _smoke_external_shell_handoff_configured "$TARGET_HOME"; then
            _smoke_pass "Shell: externally managed login hands off to zsh"
        else
            _smoke_warn "Shell: externally managed account reports ${shell:-unknown}" \
                "Local chsh is not valid here; configure the identity provider shell or add the ACFS bash-to-zsh handoff."
        fi
        return 0
    else
        _smoke_fail "Shell: expected zsh, got $shell" "chsh -s \$(which zsh)"
        return 1
    fi
}

# Check 3: Passwordless sudo works
_check_sudo() {
    if sudo -n true 2>/dev/null; then
        _smoke_pass "Sudo: passwordless"
        return 0
    else
        _smoke_fail "Sudo: requires password" "Re-run installer with --mode vibe"
        return 1
    fi
}

# Check 4: /data/projects exists
_check_workspace() {
    if [[ -d "/data/projects" ]]; then
        _smoke_pass "Workspace: /data/projects exists"
        return 0
    else
        _smoke_fail "Workspace: /data/projects missing" "sudo mkdir -p /data/projects && sudo chown $TARGET_USER:$TARGET_USER /data/projects"
        return 1
    fi
}

# Check 5: Language runtimes available
_check_languages() {
    local missing=()

    # Check bun
    if [[ -x "$TARGET_HOME/.bun/bin/bun" ]] || command -v bun &>/dev/null; then
        :
    else
        missing+=("bun")
    fi

    # Check uv
    if [[ -x "$TARGET_HOME/.local/bin/uv" ]] || command -v uv &>/dev/null; then
        :
    else
        missing+=("uv")
    fi

    # Check cargo
    if [[ -x "$TARGET_HOME/.cargo/bin/cargo" ]] || command -v cargo &>/dev/null; then
        :
    else
        missing+=("cargo")
    fi

    # Check go
    if command -v go &>/dev/null || [[ -x "/usr/local/go/bin/go" ]]; then
        :
    else
        missing+=("go")
    fi

    if [[ ${#missing[@]} -eq 0 ]]; then
        _smoke_pass "Languages: bun, uv, cargo, go"
        return 0
    else
        _smoke_fail "Languages: missing ${missing[*]}" "Re-run installer"
        return 1
    fi
}

# Check 6: Agent CLIs exist
_check_agents() {
    local found=()
    local missing=()

    # Check for each agent CLI
    if command -v claude &>/dev/null; then
        found+=("claude")
    else
        missing+=("claude")
    fi

    if command -v codex &>/dev/null || [[ -x "$TARGET_HOME/.bun/bin/codex" ]]; then
        found+=("codex")
    else
        missing+=("codex")
    fi

    if command -v gemini &>/dev/null || [[ -x "$TARGET_HOME/.bun/bin/gemini" ]]; then
        found+=("gemini")
    else
        missing+=("gemini")
    fi

    if [[ ${#missing[@]} -eq 0 ]]; then
        _smoke_pass "Agents: ${found[*]}"
        return 0
    elif [[ ${#found[@]} -gt 0 ]]; then
        # At least one agent found
        _smoke_pass "Agents: ${found[*]}"
        _smoke_warn "Missing agents: ${missing[*]}" "May need manual installation"
        return 0
    else
        _smoke_fail "Agents: none found" "bun install -g --trust @openai/codex@latest @google/gemini-cli@latest"
        return 1
    fi
}

# Check 7: NTM command works
_check_ntm() {
    if command -v ntm &>/dev/null || [[ -x "$TARGET_HOME/.local/bin/ntm" ]] || [[ -x "$TARGET_HOME/.acfs/bin/ntm" ]]; then
        _smoke_pass "NTM: installed"
        return 0
    else
        _smoke_fail "NTM: not found" "Re-run: curl -fsSL https://agent-flywheel.com/install | bash -s -- --yes --only-phase 8"
        return 1
    fi
}

# Check 8: Onboard command exists
_check_onboard() {
    if command -v onboard &>/dev/null || [[ -x "$TARGET_HOME/.local/bin/onboard" ]] || [[ -x "$TARGET_HOME/.acfs/bin/onboard" ]]; then
        _smoke_pass "Onboard: installed"
        return 0
    else
        _smoke_fail "Onboard: not found" "Check ~/.acfs/bin/onboard"
        return 1
    fi
}

# ============================================================
# Non-Critical Checks (warn only)
# ============================================================

# Check: Agent Mail can respond
_check_agent_mail() {
    if curl -fsS --max-time 5 http://127.0.0.1:8765/health/liveness &>/dev/null; then
        _smoke_info "Agent Mail: running"
    else
        _smoke_warn "Agent Mail: not running" "re-run ACFS update/install to rewrite agent-mail.service, then run 'systemctl --user enable --now agent-mail.service'"
    fi
}

# Check: Stack tools respond to --help
_check_stack_tools() {
    local stack_tools=("slb" "ubs" "bv" "cass" "cm" "caam")
    local found=()
    local missing=()

    for tool in "${stack_tools[@]}"; do
        if command -v "$tool" &>/dev/null || [[ -x "$TARGET_HOME/.local/bin/$tool" ]] || [[ -x "$TARGET_HOME/.acfs/bin/$tool" ]]; then
            found+=("$tool")
        else
            missing+=("$tool")
        fi
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        _smoke_info "Stack tools: all installed"
    else
        _smoke_warn "Stack tools missing: ${missing[*]}" "Some tools may need manual install"
    fi
}

# Check: PostgreSQL running
_check_postgres() {
    if systemctl is-active --quiet postgresql 2>/dev/null; then
        _smoke_info "PostgreSQL: running"
    elif command -v psql &>/dev/null; then
        _smoke_warn "PostgreSQL: installed but not running" "sudo systemctl start postgresql"
    else
        _smoke_warn "PostgreSQL: not installed" "optional - install with apt"
    fi
}

# ============================================================
# Main Smoke Test Function
# ============================================================

run_smoke_test() {
    # Reset counters (important if run multiple times in same shell)
    CRITICAL_PASS=0
    CRITICAL_FAIL=0
    NONCRITICAL_PASS=0
    WARNING_COUNT=0

    local start_time
    start_time=$(date +%s)

    _smoke_header

    echo "Critical Checks:"

    # Run all critical checks
    _check_user
    _check_shell
    _check_sudo
    _check_workspace
    _check_languages
    _check_agents
    _check_ntm
    _check_onboard

    echo ""
    echo "Non-Critical Checks:"

    # Run non-critical checks
    _check_agent_mail
    _check_stack_tools
    _check_postgres

    # Calculate duration
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Print summary
    echo ""
    local total_critical=$((CRITICAL_PASS + CRITICAL_FAIL))

    if [[ $CRITICAL_FAIL -eq 0 ]]; then
        echo -e "${ACFS_GREEN-\033[0;32m}Smoke test: $CRITICAL_PASS/$total_critical critical passed${ACFS_NC-\033[0m}"
    else
        echo -e "${ACFS_RED-\033[0;31m}Smoke test: $CRITICAL_PASS/$total_critical critical passed, $CRITICAL_FAIL failed${ACFS_NC-\033[0m}"
    fi

    if [[ $WARNING_COUNT -gt 0 ]]; then
        echo -e "${ACFS_YELLOW-\033[0;33m}$WARNING_COUNT warning(s)${ACFS_NC-\033[0m}"
    fi

    echo -e "${ACFS_GRAY-\033[0;90m}Completed in ${duration}s${ACFS_NC-\033[0m}"
    echo ""

    # Return exit code based on critical failures
    if [[ $CRITICAL_FAIL -gt 0 ]]; then
        echo -e "${ACFS_YELLOW-\033[0;33m}Some critical checks failed. Run 'acfs doctor' for detailed diagnostics.${ACFS_NC-\033[0m}"
        return 1
    fi

    echo -e "${ACFS_GREEN-\033[0;32m}Installation successful! Run 'onboard' to start the tutorial.${ACFS_NC-\033[0m}"
    return 0
}

# ============================================================
# Module can be sourced or run directly
# ============================================================

# If run directly (not sourced), execute main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_smoke_test "$@"
fi
