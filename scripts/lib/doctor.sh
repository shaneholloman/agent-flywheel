#!/usr/bin/env bash
# shellcheck disable=SC1091
# ============================================================
# ACFS Doctor - System Health Check
# Validates that ACFS installation is complete and working
#
# Uses gum for enhanced terminal UI when available
# ============================================================

ACFS_VERSION="${ACFS_VERSION:-0.1.0}"

# Ensure the doctor is self-contained and doesn't depend on shell rc files
# for PATH setup (e.g., when run from a fresh SSH session or non-zsh shell).
ensure_path() {
    local dir
    local to_add=()

    for dir in \
        "$HOME/.local/bin" \
        "$HOME/.bun/bin" \
        "$HOME/.cargo/bin" \
        "$HOME/go/bin" \
        "$HOME/.atuin/bin"; do
        [[ -d "$dir" ]] || continue
        case ":$PATH:" in
            *":$dir:"*) ;;
            *) to_add+=("$dir") ;;
        esac
    done

    if [[ ${#to_add[@]} -gt 0 ]]; then
        local prefix
        prefix=$(IFS=:; echo "${to_add[*]}")
        export PATH="${prefix}:$PATH"
    fi
}
ensure_path

# Check for gum and source gum_ui if available
HAS_GUM=false
if command -v gum &>/dev/null; then
    HAS_GUM=true
fi

# Source gum_ui library if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Prefer the installed VERSION file when available.
if [[ -f "$HOME/.acfs/VERSION" ]]; then
    ACFS_VERSION="$(cat "$HOME/.acfs/VERSION" 2>/dev/null || echo "$ACFS_VERSION")"
elif [[ -f "$SCRIPT_DIR/../VERSION" ]]; then
    ACFS_VERSION="$(cat "$SCRIPT_DIR/../VERSION" 2>/dev/null || echo "$ACFS_VERSION")"
elif [[ -f "$SCRIPT_DIR/../../VERSION" ]]; then
    ACFS_VERSION="$(cat "$SCRIPT_DIR/../../VERSION" 2>/dev/null || echo "$ACFS_VERSION")"
fi

# Prefer the installed state file for mode (vibe/safe) when available.
if [[ -z "${ACFS_MODE:-}" ]] && [[ -f "$HOME/.acfs/state.json" ]]; then
    if command -v jq &>/dev/null; then
        ACFS_MODE="$(jq -r '.mode // empty' "$HOME/.acfs/state.json" 2>/dev/null || true)"
    fi
    if [[ -z "${ACFS_MODE:-}" ]]; then
        ACFS_MODE="$(sed -n 's/.*"mode"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$HOME/.acfs/state.json" | head -n 1)"
    fi
    [[ -n "${ACFS_MODE:-}" ]] && export ACFS_MODE
fi

if [[ -f "$SCRIPT_DIR/gum_ui.sh" ]]; then
    source "$SCRIPT_DIR/gum_ui.sh"
elif [[ -f "$HOME/.acfs/scripts/lib/gum_ui.sh" ]]; then
    source "$HOME/.acfs/scripts/lib/gum_ui.sh"
fi

# Colors (fallback if gum_ui not loaded)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Color scheme (Catppuccin Mocha)
ACFS_PRIMARY="${ACFS_PRIMARY:-#89b4fa}"
ACFS_SUCCESS="${ACFS_SUCCESS:-#a6e3a1}"
ACFS_WARNING="${ACFS_WARNING:-#f9e2af}"
ACFS_ERROR="${ACFS_ERROR:-#f38ba8}"
ACFS_MUTED="${ACFS_MUTED:-#6c7086}"
ACFS_ACCENT="${ACFS_ACCENT:-#cba6f7}"
ACFS_TEAL="${ACFS_TEAL:-#94e2d5}"

# Counters
PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

# Output modes
JSON_MODE=false
JSON_CHECKS=()

# Deep mode - run functional tests beyond binary existence
# Related: agentic_coding_flywheel_setup-01s
DEEP_MODE=false

# Print `acfs` CLI help (only used when this script is installed as the `acfs` entrypoint).
print_acfs_help() {
    echo "ACFS - Agentic Coding Flywheel Setup"
    echo ""
    echo "Usage: acfs <command> [options]"
    echo ""
    echo "Commands:"
    echo "  doctor [options]    Check system health and tool status"
    echo "    --json            Output results as JSON"
    echo "    --deep            Run functional tests (auth, connections)"
    echo "  update [options]    Update ACFS tools to latest versions"
    echo "  services-setup      Configure AI agents and cloud services"
    echo "  version             Show ACFS version"
    echo "  help                Show this help message"
}

# Print a section header only in human output mode.
section() {
    if [[ "$JSON_MODE" != "true" ]]; then
        if [[ "$HAS_GUM" == "true" ]]; then
            echo ""
            gum style \
                --foreground "$ACFS_PRIMARY" \
                --bold \
                --border-foreground "$ACFS_MUTED" \
                --border normal \
                --padding "0 2" \
                "󰋊 $1"
        else
            echo ""
            echo -e "${CYAN}━━━ $1 ━━━${NC}"
        fi
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
        pass) ((PASS_COUNT += 1)) ;;
        warn) ((WARN_COUNT += 1)) ;;
        fail) ((FAIL_COUNT += 1)) ;;
    esac

    if [[ "$JSON_MODE" == "true" ]]; then
        local fix_json="null"
        if [[ -n "$fix" ]]; then
            fix_json="\"$(json_escape "$fix")\""
        fi

        JSON_CHECKS+=("{\"id\":\"$(json_escape "$id")\",\"label\":\"$(json_escape "$label")\",\"status\":\"$(json_escape "$status")\",\"details\":\"$(json_escape "$details")\",\"fix\":$fix_json}")
        return 0
    fi

    if [[ "$HAS_GUM" == "true" ]]; then
        case "$status" in
            pass)
                echo "  $(gum style --foreground "$ACFS_SUCCESS" --bold "✓ PASS") $(gum style --foreground "$ACFS_TEAL" "$label")"
                ;;
            warn)
                echo "  $(gum style --foreground "$ACFS_WARNING" --bold "⚠ WARN") $(gum style "$label")"
                if [[ -n "$fix" ]]; then
                    echo "        $(gum style --foreground "$ACFS_MUTED" "Fix:") $(gum style --foreground "$ACFS_ACCENT" --italic "$fix")"
                fi
                ;;
            fail)
                echo "  $(gum style --foreground "$ACFS_ERROR" --bold "✖ FAIL") $(gum style "$label")"
                if [[ -n "$fix" ]]; then
                    echo "        $(gum style --foreground "$ACFS_MUTED" "Fix:") $(gum style --foreground "$ACFS_ACCENT" --italic "$fix")"
                fi
                ;;
        esac
    else
        case "$status" in
            pass)
                echo -e "  ${GREEN}✓ PASS${NC} $label"
                ;;
            warn)
                echo -e "  ${YELLOW}⚠ WARN${NC} $label"
                if [[ -n "$fix" ]]; then
                    echo -e "        Fix: $fix"
                fi
                ;;
            fail)
                echo -e "  ${RED}✖ FAIL${NC} $label"
                if [[ -n "$fix" ]]; then
                    echo -e "        Fix: $fix"
                fi
                ;;
        esac
    fi
}

# Try to retrieve a reasonably informative version line for a command without
# assuming it supports `--version`.
get_version_line() {
    local cmd="$1"

    local version=""
    version=$("$cmd" --version 2>/dev/null | head -n1) || true
    if [[ -z "$version" ]]; then
        version=$("$cmd" -V 2>/dev/null | head -n1) || true
    fi
    if [[ -z "$version" ]]; then
        version=$("$cmd" version 2>/dev/null | head -n1) || true
    fi

    if [[ -z "$version" ]]; then
        version="available"
    fi

    printf '%s' "$version"
}

# Check if command exists
check_command() {
    local id="$1"
    local label="$2"
    local cmd="$3"
    local fix="${4:-}"

    if command -v "$cmd" &>/dev/null; then
        local version
        version=$(get_version_line "$cmd")
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
        version=$(get_version_line "$cmd")
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

    # Check sudo configuration (passwordless only required in vibe mode)
    if [[ "${ACFS_MODE:-vibe}" == "vibe" ]]; then
        if sudo -n true 2>/dev/null; then
            check "identity.passwordless_sudo" "Passwordless sudo (vibe mode)" "pass"
        else
            check "identity.passwordless_sudo" "Passwordless sudo (vibe mode)" "fail" "requires password" "Re-run ACFS installer with --mode vibe"
        fi
    else
        if command -v sudo &>/dev/null && id -nG 2>/dev/null | grep -qw sudo; then
            check "identity.sudo" "Sudo available (safe mode)" "pass"
        else
            check "identity.sudo" "Sudo available (safe mode)" "fail" "sudo unavailable" "Ensure ubuntu is in the sudo group and sudo is installed"
        fi
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
        check "shell.ohmyzsh" "Oh My Zsh" "fail" "not installed" "Re-run the ACFS installer (shell setup phase)"
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

    check_command "shell.atuin" "Atuin" "atuin" "Re-run the ACFS installer (language runtimes phase)"
    check_command "shell.fzf" "fzf" "fzf" "sudo apt install fzf"
    check_command "shell.zoxide" "zoxide" "zoxide"
    check_command "shell.direnv" "direnv" "direnv" "sudo apt install direnv"

    blank_line
}

# Check core tools
check_core_tools() {
    section "Core tools"

    check_command "tool.bun" "Bun" "bun" "Re-run the ACFS installer (language runtimes phase)"
    check_command "tool.uv" "uv" "uv" "Re-run the ACFS installer (language runtimes phase)"
    check_command "tool.cargo" "Cargo (Rust)" "cargo" "Re-run the ACFS installer (language runtimes phase)"
    check_command "tool.go" "Go" "go" "sudo apt install golang-go"
    check_command "tool.tmux" "tmux" "tmux" "sudo apt install tmux"
    check_command "tool.rg" "ripgrep" "rg" "sudo apt install ripgrep"
    check_command "tool.gh" "GitHub CLI (gh)" "gh" "sudo apt-get install -y gh"
    check_command "tool.git_lfs" "Git LFS" "git-lfs" "sudo apt-get install -y git-lfs"
    check_command "tool.rsync" "rsync" "rsync" "sudo apt-get install -y rsync"
    check_command "tool.strace" "strace" "strace" "sudo apt-get install -y strace"
    check_command "tool.lsof" "lsof" "lsof" "sudo apt-get install -y lsof"
    check_command "tool.dig" "dig (dnsutils)" "dig" "sudo apt-get install -y dnsutils"
    check_command "tool.nc" "nc (netcat-openbsd)" "nc" "sudo apt-get install -y netcat-openbsd"
    check_command "tool.sg" "ast-grep" "sg" "cargo install ast-grep --locked"

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

# ============================================================
# Deep Checks - Functional Tests (bead 01s)
# ============================================================
# These tests go beyond "is the binary installed" to verify
# actual functionality: authentication, connectivity, etc.
#
# Only runs when --deep flag is provided.
# ============================================================

# Run all deep/functional checks
# Usage: run_deep_checks
run_deep_checks() {
    section "Deep Checks (Functional Tests)"

    if [[ "$JSON_MODE" != "true" ]]; then
        if [[ "$HAS_GUM" == "true" ]]; then
            gum style --foreground "$ACFS_MUTED" "  Running functional tests... this may take a moment"
        else
            echo -e "  ${CYAN}Running functional tests... this may take a moment${NC}"
        fi
        echo ""
    fi

    # Agent authentication checks
    deep_check_agent_auth

    # Database connectivity checks
    deep_check_database

    # Cloud CLI checks
    deep_check_cloud

    blank_line
}

# Deep check: Agent authentication
# Enhanced per bead 325: Check config files, API keys, and low-cost API checks
deep_check_agent_auth() {
    check_claude_auth
    check_codex_auth
    check_gemini_auth
}

# check_claude_auth - Thorough Claude Code authentication check
# Returns via check(): pass (auth OK), warn (partial/skipped), fail (auth broken)
# Related: bead 325
check_claude_auth() {
    # Skip if not installed
    if ! command -v claude &>/dev/null; then
        check "deep.agent.claude_auth" "Claude Code" "warn" "not installed" "bun install -g @anthropic-ai/claude-code"
        return
    fi

    # Check if binary works
    if ! claude --version &>/dev/null 2>&1; then
        check "deep.agent.claude_auth" "Claude Code auth" "fail" "binary error" "Reinstall: bun install -g @anthropic-ai/claude-code"
        return
    fi

    # Check for config file (indicates previous auth)
    local config_file="$HOME/.claude/config.json"
    if [[ ! -f "$config_file" ]]; then
        check "deep.agent.claude_auth" "Claude Code auth" "warn" "no config file" "Run: claude to authenticate"
        return
    fi

    # Try low-cost API check: --print-system-info doesn't make API calls but verifies setup
    if timeout 5 claude --print-system-info &>/dev/null 2>&1; then
        check "deep.agent.claude_auth" "Claude Code auth" "pass" "authenticated"
    else
        # Config exists but system info fails - partial setup
        check "deep.agent.claude_auth" "Claude Code auth" "warn" "config exists, verify failed" "Run: claude to re-authenticate"
    fi
}

# check_codex_auth - Thorough Codex CLI authentication check
# Returns via check(): pass (auth OK), warn (partial/skipped), fail (auth broken)
# Related: bead 325
check_codex_auth() {
    # Skip if not installed
    if ! command -v codex &>/dev/null; then
        check "deep.agent.codex_auth" "Codex CLI" "warn" "not installed" "bun install -g @openai/codex@latest"
        return
    fi

    # Check if binary works
    if ! codex --version &>/dev/null 2>&1; then
        check "deep.agent.codex_auth" "Codex CLI auth" "fail" "binary error" "Reinstall: bun install -g @openai/codex@latest"
        return
    fi

    # Check for OPENAI_API_KEY in environment
    if [[ -n "${OPENAI_API_KEY:-}" ]]; then
        check "deep.agent.codex_auth" "Codex CLI auth" "pass" "OPENAI_API_KEY set"
        return
    fi

    # Check for API key in common config locations
    local found_key=false

    # Check ~/.zshrc.local (ACFS convention)
    if [[ -f "$HOME/.zshrc.local" ]] && grep -q "OPENAI_API_KEY" "$HOME/.zshrc.local" 2>/dev/null; then
        found_key=true
    fi

    # Check ~/.config/openai (common location)
    if [[ -f "$HOME/.config/openai/api_key" ]] || [[ -f "$HOME/.openai/api_key" ]]; then
        found_key=true
    fi

    # Check direnv .envrc in common project dirs
    if [[ -f "/data/projects/.envrc" ]] && grep -q "OPENAI_API_KEY" "/data/projects/.envrc" 2>/dev/null; then
        found_key=true
    fi

    if [[ "$found_key" == "true" ]]; then
        check "deep.agent.codex_auth" "Codex CLI auth" "pass" "API key found in config"
    else
        check "deep.agent.codex_auth" "Codex CLI auth" "warn" "no OPENAI_API_KEY found" "Set OPENAI_API_KEY in ~/.zshrc.local"
    fi
}

# check_gemini_auth - Thorough Gemini CLI authentication check
# Returns via check(): pass (auth OK), warn (partial/skipped), fail (auth broken)
# Related: bead 325
check_gemini_auth() {
    # Skip if not installed
    if ! command -v gemini &>/dev/null; then
        check "deep.agent.gemini_auth" "Gemini CLI" "warn" "not installed" "bun install -g @google/gemini-cli@latest"
        return
    fi

    # Check if binary works
    if ! gemini --version &>/dev/null 2>&1; then
        check "deep.agent.gemini_auth" "Gemini CLI auth" "fail" "binary error" "Reinstall: bun install -g @google/gemini-cli@latest"
        return
    fi

    # Check for GOOGLE_API_KEY or GEMINI_API_KEY in environment
    if [[ -n "${GOOGLE_API_KEY:-}" ]] || [[ -n "${GEMINI_API_KEY:-}" ]]; then
        local key_name="GOOGLE_API_KEY"
        [[ -n "${GEMINI_API_KEY:-}" ]] && key_name="GEMINI_API_KEY"
        check "deep.agent.gemini_auth" "Gemini CLI auth" "pass" "$key_name set"
        return
    fi

    # Check for API key in common config locations
    local found_key=false

    # Check ~/.zshrc.local (ACFS convention)
    if [[ -f "$HOME/.zshrc.local" ]]; then
        if grep -qE "(GOOGLE_API_KEY|GEMINI_API_KEY)" "$HOME/.zshrc.local" 2>/dev/null; then
            found_key=true
        fi
    fi

    # Check Google Cloud application default credentials
    if [[ -f "$HOME/.config/gcloud/application_default_credentials.json" ]]; then
        found_key=true
    fi

    # Check for Gemini-specific config
    if [[ -d "$HOME/.config/gemini" ]] || [[ -f "$HOME/.gemini/config" ]]; then
        found_key=true
    fi

    if [[ "$found_key" == "true" ]]; then
        check "deep.agent.gemini_auth" "Gemini CLI auth" "pass" "credentials found"
    else
        check "deep.agent.gemini_auth" "Gemini CLI auth" "warn" "no API key found" "Set GOOGLE_API_KEY in ~/.zshrc.local"
    fi
}

# Deep check: Database connectivity
# Enhanced per bead azw: PostgreSQL connection and role checks
deep_check_database() {
    check_postgres_connection
    check_postgres_role
}

# check_postgres_connection - Test PostgreSQL connectivity
# Related: bead azw
check_postgres_connection() {
    # Skip if not installed
    if ! command -v psql &>/dev/null; then
        check "deep.db.postgres_connect" "PostgreSQL connection" "warn" "psql not installed" "sudo apt install postgresql-client"
        return
    fi

    # Try to connect to local postgres (5 second timeout, no password prompt)
    # Use -w to avoid password prompts (would hang)
    if timeout 5 psql -w -h localhost -U postgres -c 'SELECT 1' &>/dev/null 2>&1; then
        check "deep.db.postgres_connect" "PostgreSQL connection" "pass" "localhost:5432"
    elif timeout 5 psql -w -h /var/run/postgresql -U postgres -c 'SELECT 1' &>/dev/null 2>&1; then
        check "deep.db.postgres_connect" "PostgreSQL connection" "pass" "unix socket"
    else
        # Try connecting as current user
        if timeout 5 psql -w -c 'SELECT 1' &>/dev/null 2>&1; then
            check "deep.db.postgres_connect" "PostgreSQL connection" "pass" "current user"
        else
            check "deep.db.postgres_connect" "PostgreSQL connection" "warn" "connection failed" "sudo systemctl status postgresql"
        fi
    fi
}

# check_postgres_role - Verify ubuntu role exists in PostgreSQL
# Related: bead azw
check_postgres_role() {
    # Skip if not installed
    if ! command -v psql &>/dev/null; then
        return  # Already reported in connection check
    fi

    # Try to check if ubuntu role exists
    local role_check
    role_check=$(timeout 5 psql -w -h localhost -U postgres -tAc \
        "SELECT 1 FROM pg_roles WHERE rolname='ubuntu'" 2>/dev/null) || \
    role_check=$(timeout 5 psql -w -h /var/run/postgresql -U postgres -tAc \
        "SELECT 1 FROM pg_roles WHERE rolname='ubuntu'" 2>/dev/null) || \
    role_check=""

    if [[ "$role_check" == "1" ]]; then
        check "deep.db.postgres_role" "PostgreSQL ubuntu role" "pass" "role exists"
    elif [[ -z "$role_check" ]]; then
        # Connection failed or role doesn't exist - info status
        check "deep.db.postgres_role" "PostgreSQL ubuntu role" "warn" "could not verify" "sudo -u postgres createuser -s ubuntu"
    else
        check "deep.db.postgres_role" "PostgreSQL ubuntu role" "warn" "role missing" "sudo -u postgres createuser -s ubuntu"
    fi
}

# Deep check: Cloud CLI authentication
# Enhanced per bead azw: Thorough cloud CLI auth checks with proper status handling
# All checks use 10 second timeout to prevent hanging on network issues
deep_check_cloud() {
    check_vault_configured
    check_gh_auth
    check_wrangler_auth
    check_supabase_auth
    check_vercel_auth
}

# check_vault_configured - Check if Vault is configured and reachable
# Related: bead azw
check_vault_configured() {
    # Skip if not installed
    if ! command -v vault &>/dev/null; then
        check "deep.cloud.vault_status" "Vault" "warn" "not installed" "Install from https://www.vaultproject.io/"
        return
    fi

    # Check if VAULT_ADDR is set (required for vault to work)
    if [[ -z "${VAULT_ADDR:-}" ]]; then
        # Check common config locations
        if [[ -f "$HOME/.zshrc.local" ]] && grep -q "VAULT_ADDR" "$HOME/.zshrc.local" 2>/dev/null; then
            check "deep.cloud.vault_config" "Vault config" "pass" "VAULT_ADDR in ~/.zshrc.local"
        else
            check "deep.cloud.vault_config" "Vault config" "warn" "VAULT_ADDR not set" "export VAULT_ADDR=https://your-vault-server:8200"
        fi
        return
    fi

    # VAULT_ADDR is set, try to connect
    if timeout 10 vault status &>/dev/null 2>&1; then
        check "deep.cloud.vault_status" "Vault status" "pass" "connected to $VAULT_ADDR"
    else
        check "deep.cloud.vault_status" "Vault status" "warn" "not reachable" "Check VAULT_ADDR and network"
    fi
}

# check_gh_auth - GitHub CLI authentication check
# Related: bead azw
check_gh_auth() {
    if ! command -v gh &>/dev/null; then
        check "deep.cloud.gh_auth" "GitHub CLI" "warn" "not installed" "sudo apt install gh"
        return
    fi

    if timeout 10 gh auth status &>/dev/null 2>&1; then
        # Get the authenticated user for more detail
        local gh_user
        gh_user=$(timeout 5 gh api user --jq '.login' 2>/dev/null) || gh_user="authenticated"
        check "deep.cloud.gh_auth" "GitHub CLI auth" "pass" "$gh_user"
    else
        check "deep.cloud.gh_auth" "GitHub CLI auth" "warn" "not authenticated" "gh auth login"
    fi
}

# check_wrangler_auth - Cloudflare Wrangler authentication check
# Related: bead azw
check_wrangler_auth() {
    if ! command -v wrangler &>/dev/null; then
        check "deep.cloud.wrangler_auth" "Wrangler (Cloudflare)" "warn" "not installed" "bun install -g wrangler"
        return
    fi

    if timeout 10 wrangler whoami &>/dev/null 2>&1; then
        check "deep.cloud.wrangler_auth" "Wrangler (Cloudflare) auth" "pass" "authenticated"
    else
        # Check for CLOUDFLARE_API_TOKEN as alternative
        if [[ -n "${CLOUDFLARE_API_TOKEN:-}" ]]; then
            check "deep.cloud.wrangler_auth" "Wrangler (Cloudflare) auth" "pass" "CLOUDFLARE_API_TOKEN set"
        else
            check "deep.cloud.wrangler_auth" "Wrangler (Cloudflare) auth" "warn" "not authenticated" "wrangler login"
        fi
    fi
}

# check_supabase_auth - Supabase CLI authentication check
# Related: bead azw
check_supabase_auth() {
    if ! command -v supabase &>/dev/null; then
        check "deep.cloud.supabase" "Supabase CLI" "warn" "not installed" "bun install -g supabase"
        return
    fi

    # Check if binary works
    if ! timeout 5 supabase --version &>/dev/null 2>&1; then
        check "deep.cloud.supabase" "Supabase CLI" "fail" "binary error" "Reinstall: bun install -g supabase"
        return
    fi

    # Check for access token in config directory
    local supabase_config="$HOME/.supabase"
    local access_token_file="$supabase_config/access-token"

    if [[ -f "$access_token_file" ]]; then
        # Check if token is not empty
        if [[ -s "$access_token_file" ]]; then
            check "deep.cloud.supabase" "Supabase CLI auth" "pass" "access token exists"
        else
            check "deep.cloud.supabase" "Supabase CLI auth" "warn" "empty access token" "supabase login"
        fi
    elif [[ -n "${SUPABASE_ACCESS_TOKEN:-}" ]]; then
        check "deep.cloud.supabase" "Supabase CLI auth" "pass" "SUPABASE_ACCESS_TOKEN set"
    else
        check "deep.cloud.supabase" "Supabase CLI auth" "warn" "not authenticated" "supabase login"
    fi
}

# check_vercel_auth - Vercel CLI authentication check
# Related: bead azw
check_vercel_auth() {
    if ! command -v vercel &>/dev/null; then
        check "deep.cloud.vercel_auth" "Vercel CLI" "warn" "not installed" "bun install -g vercel"
        return
    fi

    if timeout 10 vercel whoami &>/dev/null 2>&1; then
        # Get the authenticated user/team for more detail
        local vercel_user
        vercel_user=$(timeout 5 vercel whoami 2>/dev/null) || vercel_user="authenticated"
        check "deep.cloud.vercel_auth" "Vercel auth" "pass" "$vercel_user"
    else
        # Check for VERCEL_TOKEN as alternative
        if [[ -n "${VERCEL_TOKEN:-}" ]]; then
            check "deep.cloud.vercel_auth" "Vercel auth" "pass" "VERCEL_TOKEN set"
        else
            check "deep.cloud.vercel_auth" "Vercel auth" "warn" "not authenticated" "vercel login"
        fi
    fi
}

# Print summary
print_summary() {
    echo ""

    if [[ "$HAS_GUM" == "true" ]]; then
        # Beautiful gum-styled summary
        local status_line=""
        status_line="$(gum style --foreground "$ACFS_SUCCESS" --bold "$PASS_COUNT passed") "
        status_line+="$(gum style --foreground "$ACFS_WARNING" "$WARN_COUNT warnings") "
        status_line+="$(gum style --foreground "$ACFS_ERROR" "$FAIL_COUNT failed")"

        if [[ $FAIL_COUNT -eq 0 ]]; then
            gum style \
                --border double \
                --border-foreground "$ACFS_SUCCESS" \
                --padding "1 3" \
                --margin "1 0" \
                --align center \
                "$(gum style --foreground "$ACFS_SUCCESS" --bold '✓ ACFS Health Check Passed')

$status_line

$(gum style --foreground "$ACFS_MUTED" "Next: run 'onboard' to learn how to use your new setup")"
        else
            gum style \
                --border double \
                --border-foreground "$ACFS_ERROR" \
                --padding "1 3" \
                --margin "1 0" \
                --align center \
                "$(gum style --foreground "$ACFS_ERROR" --bold '✖ Some Checks Failed')

$status_line

$(gum style --foreground "$ACFS_MUTED" "Run the suggested fix commands, then 'acfs doctor' again")"
        fi
    else
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
    local invoked_as
    invoked_as="$(basename "${0:-acfs}")"

    # If installed as `acfs`, support subcommands (doctor/update/services-setup/version).
    local subcmd="${1:-}"
    case "$subcmd" in
        doctor|check)
            shift
            ;;
        update)
            shift
            local update_script=""
            if [[ -f "$HOME/.acfs/scripts/lib/update.sh" ]]; then
                update_script="$HOME/.acfs/scripts/lib/update.sh"
            elif [[ -f "$SCRIPT_DIR/update.sh" ]]; then
                update_script="$SCRIPT_DIR/update.sh"
            elif [[ -f "$SCRIPT_DIR/../scripts/lib/update.sh" ]]; then
                update_script="$SCRIPT_DIR/../scripts/lib/update.sh"
            fi

            if [[ -n "$update_script" ]]; then
                exec bash "$update_script" "$@"
            fi

            echo "Error: update.sh not found" >&2
            return 1
            ;;
        services-setup|services|setup)
            shift
            local services_script=""
            if [[ -f "$HOME/.acfs/scripts/services-setup.sh" ]]; then
                services_script="$HOME/.acfs/scripts/services-setup.sh"
            elif [[ -f "$SCRIPT_DIR/../services-setup.sh" ]]; then
                services_script="$SCRIPT_DIR/../services-setup.sh"
            elif [[ -f "$SCRIPT_DIR/../scripts/services-setup.sh" ]]; then
                services_script="$SCRIPT_DIR/../scripts/services-setup.sh"
            fi

            if [[ -n "$services_script" ]]; then
                exec bash "$services_script" "$@"
            fi

            echo "Error: services-setup.sh not found" >&2
            return 1
            ;;
        version|-v|--version)
            local version_file=""
            if [[ -f "$HOME/.acfs/VERSION" ]]; then
                version_file="$HOME/.acfs/VERSION"
            elif [[ -f "$SCRIPT_DIR/../VERSION" ]]; then
                version_file="$SCRIPT_DIR/../VERSION"
            elif [[ -f "$SCRIPT_DIR/../../VERSION" ]]; then
                version_file="$SCRIPT_DIR/../../VERSION"
            fi

            if [[ -n "$version_file" ]]; then
                cat "$version_file"
            else
                echo "${ACFS_VERSION:-unknown}"
            fi
            return 0
            ;;
        help|-h)
            print_acfs_help
            return 0
            ;;
        "")
            if [[ "$invoked_as" == "acfs" ]]; then
                print_acfs_help
                return 0
            fi
            ;;
    esac

    # Parse args
    while [[ $# -gt 0 ]]; do
        case $1 in
            --json)
                JSON_MODE=true
                shift
                ;;
            --deep)
                DEEP_MODE=true
                shift
                ;;
            --help|-h)
                echo "Usage: acfs doctor [--json] [--deep]"
                echo ""
                echo "Options:"
                echo "  --json    Output results as JSON"
                echo "  --deep    Run functional tests (auth, connections)"
                echo ""
                echo "By default, doctor runs quick existence checks only."
                echo "Use --deep for thorough validation including:"
                echo "  - Agent authentication (claude, codex, gemini)"
                echo "  - Database connectivity (PostgreSQL)"
                echo "  - Cloud CLI authentication (vault, wrangler, etc.)"
                echo ""
                echo "Examples:"
                echo "  acfs doctor              # Quick health check"
                echo "  acfs doctor --deep       # Full functional tests"
                echo "  acfs doctor --json       # JSON output for tooling"
                echo "  acfs doctor --deep --json # Both"
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

        if [[ "$HAS_GUM" == "true" ]]; then
            echo ""
            gum style \
                --border rounded \
                --border-foreground "$ACFS_PRIMARY" \
                --padding "1 2" \
                --margin "0 0 1 0" \
                "$(gum style --foreground "$ACFS_ACCENT" --bold '🩺 ACFS Doctor') $(gum style --foreground "$ACFS_MUTED" "v$ACFS_VERSION")

$(gum style --foreground "$ACFS_MUTED" "User:") $(gum style --foreground "$ACFS_TEAL" "$(whoami)")  $(gum style --foreground "$ACFS_MUTED" "Mode:") $(gum style --foreground "$ACFS_TEAL" "${ACFS_MODE:-vibe}")
$(gum style --foreground "$ACFS_MUTED" "OS:") $(gum style --foreground "$ACFS_TEAL" "$os_pretty")"
        else
            echo ""
            echo "ACFS Doctor v$ACFS_VERSION"
            echo "User: $(whoami)"
            echo "Mode: ${ACFS_MODE:-vibe}"
            echo "OS: $os_pretty"
            echo ""
        fi
    fi

    check_identity
    check_workspace
    check_shell
    check_core_tools
    check_agents
    check_cloud
    check_stack

    # Run deep checks if --deep flag was provided
    if [[ "$DEEP_MODE" == "true" ]]; then
        run_deep_checks
    fi

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
