#!/usr/bin/env bash
# shellcheck disable=SC1091
# ============================================================
# ACFS Export Config - Export current configuration
# Exports tool versions, settings, and module list for backup/migration
# ============================================================

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACFS_HOME="${ACFS_HOME:-$HOME/.acfs}"

# Source logging if available
if [[ -f "$SCRIPT_DIR/logging.sh" ]]; then
    source "$SCRIPT_DIR/logging.sh"
else
    log_error() { echo "[ERROR] $*" >&2; }
    log_warn() { echo "[WARN] $*" >&2; }
fi

# ============================================================
# Configuration
# ============================================================
OUTPUT_FORMAT="yaml"  # yaml, json, or minimal
STATE_FILE="$ACFS_HOME/state.json"
VERSION_FILE="$ACFS_HOME/VERSION"

# ============================================================
# Parse Arguments
# ============================================================
show_help() {
    cat << 'EOF'
ACFS Export Config - Export current configuration

USAGE:
  acfs export-config [OPTIONS]

OPTIONS:
  --json          Output in JSON format (default: YAML)
  --minimal       Output only module list (one per line)
  --output FILE   Write to file instead of stdout
  -h, --help      Show this help message

EXAMPLES:
  acfs export-config                    # Print YAML to stdout
  acfs export-config > backup.yaml      # Save to file
  acfs export-config --json             # JSON output
  acfs export-config --minimal          # Just module list

SENSITIVE DATA:
  This command NEVER exports:
  - SSH keys, API tokens, passwords
  - Full paths containing usernames (sanitized to ~/)
  - Environment-specific secrets

EOF
}

OUTPUT_FILE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --json)
            OUTPUT_FORMAT="json"
            shift
            ;;
        --minimal)
            OUTPUT_FORMAT="minimal"
            shift
            ;;
        --output)
            if [[ -z "${2:-}" || "$2" == -* ]]; then
                log_error "--output requires a file path"
                exit 1
            fi
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# ============================================================
# Utility Functions
# ============================================================

# Get ACFS version
get_acfs_version() {
    if [[ -f "$VERSION_FILE" ]]; then
        cat "$VERSION_FILE"
    else
        echo "unknown"
    fi
}

# Get tool version (returns empty string if not found)
get_tool_version() {
    local tool="$1"
    local version=""

    case "$tool" in
        rust|cargo)
            version=$(cargo --version 2>/dev/null | awk '{print $2}' || true)
            ;;
        bun)
            version=$(bun --version 2>/dev/null || true)
            ;;
        uv)
            version=$(uv --version 2>/dev/null | awk '{print $2}' || true)
            ;;
        go)
            version=$(go version 2>/dev/null | awk '{print $3}' | sed 's/go//' || true)
            ;;
        zsh)
            version=$(zsh --version 2>/dev/null | awk '{print $2}' || true)
            ;;
        tmux)
            version=$(tmux -V 2>/dev/null | awk '{print $2}' || true)
            ;;
        nvim|neovim)
            version=$(nvim --version 2>/dev/null | head -1 | awk '{print $2}' | sed 's/v//' || true)
            ;;
        claude|claude-code)
            version=$(claude --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
            ;;
        codex)
            version=$(codex --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
            ;;
        gemini)
            version=$(gemini --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
            ;;
        zoxide)
            version=$(zoxide --version 2>/dev/null | awk '{print $2}' || true)
            ;;
        atuin)
            version=$(atuin --version 2>/dev/null | awk '{print $2}' || true)
            ;;
        fzf)
            version=$(fzf --version 2>/dev/null | awk '{print $1}' || true)
            ;;
        ripgrep|rg)
            version=$(rg --version 2>/dev/null | head -1 | awk '{print $2}' || true)
            ;;
        gh)
            version=$(gh --version 2>/dev/null | head -1 | awk '{print $3}' || true)
            ;;
        docker)
            version=$(docker --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
            ;;
        postgresql|psql)
            version=$(psql --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+' | head -1 || true)
            ;;
        ntm)
            # ntm uses "ntm version" not --version
            version=$(ntm version 2>/dev/null | awk '{print $3}' || true)
            ;;
        cass)
            version=$(cass --version 2>/dev/null | awk '{print $2}' || true)
            ;;
        cm)
            version=$(cm --version 2>/dev/null | head -1 | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
            ;;
        bv)
            version=$(bv --version 2>/dev/null | awk '{print $2}' || true)
            ;;
        br)
            version=$(br --version 2>/dev/null | awk '{print $2}' || true)
            ;;
        dcg)
            # dcg doesn't have --version, check if binary exists
            if command -v dcg &>/dev/null; then
                version="installed"
            fi
            ;;
        slb)
            # slb uses "slb version" not --version, first line only
            version=$(slb version 2>/dev/null | head -1 | awk '{print $2}' || true)
            ;;
        caam)
            # caam uses "caam version" not --version
            version=$(caam version 2>/dev/null | awk '{print $2}' || true)
            ;;
        ubs)
            # ubs doesn't have typical version output, check if binary exists
            if command -v ubs &>/dev/null; then
                version="installed"
            fi
            ;;
        rch)
            version=$(rch --version 2>/dev/null | awk '{print $2}' || true)
            ;;
        ms)
            version=$(ms --version 2>/dev/null | awk '{print $2}' || true)
            ;;
        ru)
            version=$(ru --version 2>/dev/null | awk '{print $3}' || true)
            ;;
        *)
            # Generic version check
            version=$($tool --version 2>/dev/null | head -1 | grep -Eo '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || true)
            ;;
    esac

    echo "${version:-}"
}

# Get mode from state.json
get_mode() {
    if [[ -f "$STATE_FILE" ]]; then
        if command -v jq &>/dev/null; then
            jq -r '.mode // "unknown"' "$STATE_FILE" 2>/dev/null || echo "unknown"
        else
            # Use sed instead of grep -oP for portability (works on macOS/BSD)
            sed -n 's/.*"mode"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$STATE_FILE" 2>/dev/null | head -1 || echo "unknown"
        fi
    else
        echo "unknown"
    fi
}

# Get installed modules from state.json
get_modules() {
    if [[ -f "$STATE_FILE" ]]; then
        if command -v jq &>/dev/null; then
            jq -r '.installed_modules // [] | .[]' "$STATE_FILE" 2>/dev/null || true
        fi
    fi
}

# ============================================================
# Output Generation
# ============================================================

generate_minimal() {
    # Just output module list, one per line
    get_modules
}

generate_yaml() {
    local hostname
    hostname=$(hostname 2>/dev/null || echo "unknown")
    local timestamp
    timestamp=$(date -Iseconds 2>/dev/null || date)
    local acfs_version
    acfs_version=$(get_acfs_version)
    local mode
    mode=$(get_mode)

    cat << EOF
# ACFS Configuration Export
# Generated: $timestamp
# Hostname: $hostname
# ACFS Version: $acfs_version

settings:
  mode: $mode
  shell: ${SHELL##*/}

modules:
EOF

    # List modules
    while IFS= read -r module; do
        [[ -n "$module" ]] && echo "  - $module"
    done < <(get_modules)

    echo ""
    echo "tools:"

    # Core tools
    local tools=(
        "rust" "bun" "uv" "go" "zsh" "tmux" "nvim"
        "zoxide" "atuin" "fzf" "ripgrep" "gh" "docker" "postgresql"
    )

    for tool in "${tools[@]}"; do
        local version
        version=$(get_tool_version "$tool")
        if [[ -n "$version" ]]; then
            echo "  $tool:"
            echo "    version: \"$version\""
            echo "    installed: true"
        fi
    done

    echo ""
    echo "agents:"

    # AI agents
    local agents=("claude" "codex" "gemini")
    for agent in "${agents[@]}"; do
        local version
        version=$(get_tool_version "$agent")
        if [[ -n "$version" ]]; then
            echo "  $agent:"
            echo "    version: \"$version\""
            echo "    installed: true"
        fi
    done

    echo ""
    echo "flywheel_stack:"

    # Flywheel tools
    local stack_tools=("ntm" "cass" "cm" "bv" "br" "dcg" "slb" "caam" "ubs" "rch" "ms" "ru")
    for tool in "${stack_tools[@]}"; do
        local version
        version=$(get_tool_version "$tool")
        if [[ -n "$version" ]]; then
            echo "  $tool:"
            echo "    version: \"$version\""
            echo "    installed: true"
        fi
    done
}

generate_json() {
    local hostname
    hostname=$(hostname 2>/dev/null || echo "unknown")
    local timestamp
    timestamp=$(date -Iseconds 2>/dev/null || date)
    local acfs_version
    acfs_version=$(get_acfs_version)
    local mode
    mode=$(get_mode)

    # Build JSON manually to avoid jq dependency for output
    cat << EOF
{
  "metadata": {
    "generated_at": "$timestamp",
    "hostname": "$hostname",
    "acfs_version": "$acfs_version"
  },
  "settings": {
    "mode": "$mode",
    "shell": "${SHELL##*/}"
  },
  "modules": [
EOF

    # Collect modules into array
    local modules=()
    while IFS= read -r module; do
        [[ -n "$module" ]] && modules+=("$module")
    done < <(get_modules)

    # Output modules as JSON array
    local first=true
    for module in "${modules[@]}"; do
        if [[ "$first" == "true" ]]; then
            echo "    \"$module\""
            first=false
        else
            echo "    ,\"$module\""
        fi
    done

    cat << 'EOF'
  ],
  "tools": {
EOF

    # Core tools
    local tools=("rust" "bun" "uv" "go" "zsh" "tmux" "nvim" "zoxide" "atuin" "fzf" "ripgrep" "gh" "docker" "postgresql")
    first=true
    for tool in "${tools[@]}"; do
        local version
        version=$(get_tool_version "$tool")
        if [[ -n "$version" ]]; then
            if [[ "$first" == "true" ]]; then
                first=false
            else
                echo ","
            fi
            printf '    "%s": { "version": "%s", "installed": true }' "$tool" "$version"
        fi
    done

    cat << 'EOF'

  },
  "agents": {
EOF

    # AI agents
    local agents=("claude" "codex" "gemini")
    first=true
    for agent in "${agents[@]}"; do
        local version
        version=$(get_tool_version "$agent")
        if [[ -n "$version" ]]; then
            if [[ "$first" == "true" ]]; then
                first=false
            else
                echo ","
            fi
            printf '    "%s": { "version": "%s", "installed": true }' "$agent" "$version"
        fi
    done

    cat << 'EOF'

  },
  "flywheel_stack": {
EOF

    # Flywheel tools
    local stack_tools=("ntm" "cass" "cm" "bv" "br" "dcg" "slb" "caam" "ubs" "rch" "ms" "ru")
    first=true
    for tool in "${stack_tools[@]}"; do
        local version
        version=$(get_tool_version "$tool")
        if [[ -n "$version" ]]; then
            if [[ "$first" == "true" ]]; then
                first=false
            else
                echo ","
            fi
            printf '    "%s": { "version": "%s", "installed": true }' "$tool" "$version"
        fi
    done

    cat << 'EOF'

  }
}
EOF
}

# ============================================================
# Main
# ============================================================

main() {
    local output

    case "$OUTPUT_FORMAT" in
        minimal)
            output=$(generate_minimal)
            ;;
        json)
            output=$(generate_json)
            ;;
        yaml|*)
            output=$(generate_yaml)
            ;;
    esac

    if [[ -n "$OUTPUT_FILE" ]]; then
        echo "$output" > "$OUTPUT_FILE"
        echo "Configuration exported to: $OUTPUT_FILE" >&2
    else
        echo "$output"
    fi
}

main "$@"
