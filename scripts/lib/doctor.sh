#!/usr/bin/env bash
# shellcheck disable=SC1091
# ============================================================
# ACFS Doctor - System Health Check
# Validates that ACFS installation is complete and working
# ============================================================

ACFS_VERSION="${ACFS_VERSION:-0.1.0}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Counters
PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

# JSON output mode
JSON_MODE=false
JSON_CHECKS=()

# Print a section header only in human output mode.
section() {
    if [[ "$JSON_MODE" != "true" ]]; then
        echo "$1"
    fi
}

# Print a blank line only in human output mode.
blank_line() {
    if [[ "$JSON_MODE" != "true" ]]; then
        echo ""
    fi
}

# Escape a string for safe inclusion in JSON (without surrounding quotes).
json_escape() {
    local s="${1:-}"
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\n'/\\n}
    s=${s//$'\r'/\\r}
    s=${s//$'\t'/\\t}
    printf '%s' "$s"
}

# Check result helper
check() {
    local id="$1"
    local label="$2"
    local status="$3"
    local details="${4:-}"
    local fix="${5:-}"

    case "$status" in
        pass) ((PASS_COUNT++)) ;;
        warn) ((WARN_COUNT++)) ;;
        fail) ((FAIL_COUNT++)) ;;
    esac

    if [[ "$JSON_MODE" == "true" ]]; then
        local fix_json="null"
        if [[ -n "$fix" ]]; then
            fix_json="\"$(json_escape "$fix")\""
        fi

        JSON_CHECKS+=("{\"id\":\"$(json_escape "$id")\",\"label\":\"$(json_escape "$label")\",\"status\":\"$(json_escape "$status")\",\"details\":\"$(json_escape "$details")\",\"fix\":$fix_json}")
        return 0
    fi

    case "$status" in
        pass)
            echo -e "  ${GREEN}PASS${NC} $label"
            ;;
        warn)
            echo -e "  ${YELLOW}WARN${NC} $label"
            if [[ -n "$fix" ]]; then
                echo -e "        Fix: $fix"
            fi
            ;;
        fail)
            echo -e "  ${RED}FAIL${NC} $label"
            if [[ -n "$fix" ]]; then
                echo -e "        Fix: $fix"
            fi
            ;;
    esac
}

# Check if command exists
check_command() {
    local id="$1"
    local label="$2"
    local cmd="$3"
    local fix="${4:-}"

    if command -v "$cmd" &>/dev/null; then
        local version
        version=$("$cmd" --version 2>/dev/null | head -n1 || echo "available")
        check "$id" "$label ($version)" "pass" "installed"
    else
        check "$id" "$label" "fail" "not found" "$fix"
    fi
}

# Check a command, but treat missing as WARN (optional dependency).
check_optional_command() {
    local id="$1"
    local label="$2"
    local cmd="$3"
    local fix="${4:-}"

    if command -v "$cmd" &>/dev/null; then
        local version
        version=$("$cmd" --version 2>/dev/null | head -n1 || echo "available")
        check "$id" "$label ($version)" "pass" "installed"
    else
        check "$id" "$label" "warn" "not found" "$fix"
    fi
}

# Check identity
check_identity() {
    section "Identity"

    # Check user
    local user
    user=$(whoami)
    if [[ "$user" == "ubuntu" ]]; then
        check "identity.user_is_ubuntu" "Logged in as ubuntu" "pass" "whoami=$user"
    else
        check "identity.user_is_ubuntu" "Logged in as ubuntu (currently: $user)" "warn" "whoami=$user" "ssh ubuntu@YOUR_SERVER"
    fi

    # Check passwordless sudo
    if sudo -n true 2>/dev/null; then
        check "identity.passwordless_sudo" "Passwordless sudo" "pass"
    else
        check "identity.passwordless_sudo" "Passwordless sudo" "fail" "requires password" "Re-run ACFS installer with --mode vibe"
    fi

    blank_line
}

# Check workspace
check_workspace() {
    section "Workspace"

    if [[ -d "/data/projects" ]] && [[ -w "/data/projects" ]]; then
        check "workspace.data_projects" "/data/projects exists and writable" "pass"
    else
        check "workspace.data_projects" "/data/projects" "fail" "missing or not writable" "sudo mkdir -p /data/projects && sudo chown ubuntu:ubuntu /data/projects"
    fi

    blank_line
}

# Check shell
check_shell() {
    section "Shell"

    check_command "shell.zsh" "zsh" "zsh" "sudo apt install zsh"

    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        check "shell.ohmyzsh" "Oh My Zsh" "pass"
    else
        check "shell.ohmyzsh" "Oh My Zsh" "fail" "not installed" "sh -c \"\$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
    fi

    local p10k_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
    if [[ -d "$p10k_dir" ]]; then
        check "shell.p10k" "Powerlevel10k" "pass"
    else
        check "shell.p10k" "Powerlevel10k" "warn" "not installed"
    fi

    # Check plugins
    local plugins_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
    if [[ -d "$plugins_dir/zsh-autosuggestions" ]]; then
        check "shell.plugins.zsh_autosuggestions" "zsh-autosuggestions" "pass"
    else
        check "shell.plugins.zsh_autosuggestions" "zsh-autosuggestions" "warn"
    fi

    if [[ -d "$plugins_dir/zsh-syntax-highlighting" ]]; then
        check "shell.plugins.zsh_syntax_highlighting" "zsh-syntax-highlighting" "pass"
    else
        check "shell.plugins.zsh_syntax_highlighting" "zsh-syntax-highlighting" "warn"
    fi

    # Check modern CLI tools
    if command -v lsd &>/dev/null; then
        check "shell.lsd_or_eza" "lsd" "pass"
    elif command -v eza &>/dev/null; then
        check "shell.lsd_or_eza" "eza (fallback)" "pass"
    else
        check "shell.lsd_or_eza" "lsd/eza" "warn" "neither installed" "sudo apt install lsd"
    fi

    check_command "shell.atuin" "Atuin" "atuin" "curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh"
    check_command "shell.fzf" "fzf" "fzf" "sudo apt install fzf"
    check_command "shell.zoxide" "zoxide" "zoxide"
    check_command "shell.direnv" "direnv" "direnv" "sudo apt install direnv"

    blank_line
}

# Check core tools
check_core_tools() {
    section "Core tools"

    check_command "tool.bun" "Bun" "bun" "curl -fsSL https://bun.sh/install | bash"
    check_command "tool.uv" "uv" "uv" "curl -LsSf https://astral.sh/uv/install.sh | sh"
    check_command "tool.cargo" "Cargo (Rust)" "cargo" "curl https://sh.rustup.rs -sSf | sh"
    check_command "tool.go" "Go" "go" "sudo apt install golang-go"
    check_command "tool.tmux" "tmux" "tmux" "sudo apt install tmux"
    check_command "tool.rg" "ripgrep" "rg" "sudo apt install ripgrep"
    check_command "tool.sg" "ast-grep" "sg" "cargo install ast-grep"

    blank_line
}

# Check coding agents
check_agents() {
    section "Agents"

    check_command "agent.claude" "Claude Code" "claude"
    check_command "agent.codex" "Codex CLI" "codex" "bun install -g @openai/codex@latest"
    check_command "agent.gemini" "Gemini CLI" "gemini" "bun install -g @google/gemini-cli@latest"

    # Check aliases are defined in the zshrc
    if grep -q "^alias cc=" ~/.acfs/zsh/acfs.zshrc 2>/dev/null; then
        check "agent.alias.cc" "cc alias" "pass"
    else
        check "agent.alias.cc" "cc alias" "warn" "not in zshrc"
    fi

    if grep -q "^alias cod=" ~/.acfs/zsh/acfs.zshrc 2>/dev/null; then
        check "agent.alias.cod" "cod alias" "pass"
    else
        check "agent.alias.cod" "cod alias" "warn" "not in zshrc"
    fi

    if grep -q "^alias gmi=" ~/.acfs/zsh/acfs.zshrc 2>/dev/null; then
        check "agent.alias.gmi" "gmi alias" "pass"
    else
        check "agent.alias.gmi" "gmi alias" "warn" "not in zshrc"
    fi

    blank_line
}

# Check cloud tools
check_cloud() {
    section "Cloud/DB"

    check_optional_command "cloud.vault" "Vault" "vault"
    check_optional_command "cloud.postgres" "PostgreSQL" "psql"
    check_optional_command "cloud.wrangler" "Wrangler" "wrangler" "bun install -g wrangler"
    check_optional_command "cloud.supabase" "Supabase CLI" "supabase" "bun install -g supabase"
    check_optional_command "cloud.vercel" "Vercel CLI" "vercel" "bun install -g vercel"

    blank_line
}

# Check Dicklesworthstone stack
check_stack() {
    section "Dicklesworthstone stack"

    check_command "stack.ntm" "NTM" "ntm"
    check_command "stack.slb" "SLB" "slb"
    check_command "stack.ubs" "UBS" "ubs"
    check_command "stack.bv" "Beads Viewer" "bv"
    check_command "stack.cass" "CASS" "cass"
    check_command "stack.cm" "CASS Memory" "cm"
    check_command "stack.caam" "CAAM" "caam"

    # Check MCP Agent Mail
    if command -v am &>/dev/null || [[ -d "$HOME/mcp_agent_mail" ]]; then
        check "stack.mcp_agent_mail" "MCP Agent Mail" "pass"
    else
        check "stack.mcp_agent_mail" "MCP Agent Mail" "warn"
    fi

    blank_line
}

# Print summary
print_summary() {
    echo "============================================================"
    echo -e "Checks: ${GREEN}$PASS_COUNT passed${NC}, ${YELLOW}$WARN_COUNT warnings${NC}, ${RED}$FAIL_COUNT failed${NC}"
    echo ""

    if [[ $FAIL_COUNT -eq 0 ]]; then
        echo -e "${GREEN}All critical checks passed!${NC}"
        echo ""
        echo "Next: run 'onboard' to learn how to use your new setup"
    else
        echo -e "${RED}Some checks failed. Run the suggested fix commands.${NC}"
        echo ""
        echo "After fixing, run 'acfs doctor' again to verify."
    fi
}

# Print JSON output
print_json() {
    local checks_json
    checks_json=$(printf '%s,' "${JSON_CHECKS[@]}" | sed 's/,$//')

    local os_id="unknown"
    local os_version="unknown"
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        os_id="${ID:-unknown}"
        os_version="${VERSION_ID:-unknown}"
    fi

    cat << EOF
{
  "acfs_version": "$(json_escape "$ACFS_VERSION")",
  "timestamp": "$(json_escape "$(date -Iseconds)")",
  "mode": "$(json_escape "${ACFS_MODE:-vibe}")",
  "user": "$(json_escape "$(whoami)")",
  "os": {"id": "$(json_escape "$os_id")", "version": "$(json_escape "$os_version")"},
  "checks": [$checks_json],
  "summary": {"pass": $PASS_COUNT, "warn": $WARN_COUNT, "fail": $FAIL_COUNT}
}
EOF
}

# Main
main() {
    # Parse args
    while [[ $# -gt 0 ]]; do
        case $1 in
            --json)
                JSON_MODE=true
                shift
                ;;
            --help)
                echo "Usage: acfs doctor [--json]"
                echo ""
                echo "Options:"
                echo "  --json    Output results as JSON"
                exit 0
                ;;
            *)
                shift
                ;;
        esac
    done

    if [[ "$JSON_MODE" != "true" ]]; then
        local os_pretty="unknown"
        if [[ -f /etc/os-release ]]; then
            # shellcheck disable=SC1091
            . /etc/os-release
            os_pretty="${PRETTY_NAME:-${ID:-unknown} ${VERSION_ID:-unknown}}"
        fi

        echo ""
        echo "ACFS Doctor v$ACFS_VERSION"
        echo "User: $(whoami)"
        echo "Mode: ${ACFS_MODE:-vibe}"
        echo "OS: $os_pretty"
        echo ""
    fi

    check_identity
    check_workspace
    check_shell
    check_core_tools
    check_agents
    check_cloud
    check_stack

    if [[ "$JSON_MODE" == "true" ]]; then
        print_json
    else
        print_summary
    fi

    # Exit with appropriate code
    if [[ $FAIL_COUNT -gt 0 ]]; then
        exit 1
    fi
    exit 0
}

main "$@"
