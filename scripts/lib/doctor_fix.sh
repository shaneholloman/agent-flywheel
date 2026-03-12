#!/usr/bin/env bash
# ============================================================
# ACFS Doctor --fix Implementation
# Safe, deterministic fixers with logging and undo capability
#
# Implements bd-31ps.6.2 based on spec in doctor_fix_spec.md
# ============================================================

# Prevent multiple sourcing
[[ -n "${_ACFS_DOCTOR_FIX_LOADED:-}" ]] && return 0
_ACFS_DOCTOR_FIX_LOADED=1

# Source autofix library for change tracking
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
if [[ -f "$SCRIPT_DIR/autofix.sh" ]]; then
    # shellcheck source=autofix.sh
    source "$SCRIPT_DIR/autofix.sh"
elif [[ -f "$HOME/.acfs/scripts/lib/autofix.sh" ]]; then
    # shellcheck source=autofix.sh
    source "$HOME/.acfs/scripts/lib/autofix.sh"
fi

# ============================================================
# Configuration
# ============================================================

DOCTOR_FIX_LOG="${HOME}/.local/share/acfs/doctor.log"
DOCTOR_FIX_DRY_RUN=false
DOCTOR_FIX_YES=false
DOCTOR_FIX_PROMPT=false

# Counters for fix summary
declare -g FIX_APPLIED=0
declare -g FIX_SKIPPED=0
declare -g FIX_FAILED=0
declare -g FIX_MANUAL=0

# Arrays to track fixes for summary
declare -ga FIXES_APPLIED=()
declare -ga FIXES_DRY_RUN=()
declare -ga FIXES_MANUAL=()
declare -ga FIXES_PROMPTED=()

# ============================================================
# Logging Helpers
# ============================================================

doctor_fix_log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Ensure log directory exists
    mkdir -p "$(dirname "$DOCTOR_FIX_LOG")"

    # Log to file
    echo "[$timestamp] [$level] $message" >> "$DOCTOR_FIX_LOG"

    # Output to user
    case "$level" in
        INFO)  echo "  [fix] $message" ;;
        WARN)  echo "  [fix] WARNING: $message" >&2 ;;
        ERROR) echo "  [fix] ERROR: $message" >&2 ;;
        DRY)   echo "  [dry-run] Would: $message" ;;
    esac
}

# ============================================================
# Guard Helpers
# ============================================================

# Check if a file contains a specific line
file_contains_line() {
    local file="$1"
    local pattern="$2"

    [[ -f "$file" ]] && grep -qF "$pattern" "$file" 2>/dev/null
}

# Check if directory is in PATH
dir_in_path() {
    local dir="$1"
    case ":$PATH:" in
        *":$dir:"*) return 0 ;;
        *) return 1 ;;
    esac
}

# ============================================================
# Fixer: PATH Ordering (fix.path.ordering)
# ============================================================

# Fix PATH ordering in shell config
# Ensures ~/.local/bin and other ACFS dirs are at front of PATH
fix_path_ordering() {
    local check_id="$1"
    local target_file="${HOME}/.zshrc"

    # Required directories in order
    local -a path_dirs=(
        '$HOME/.local/bin'
        '$HOME/.bun/bin'
        '$HOME/.cargo/bin'
        '$HOME/go/bin'
        '$HOME/.atuin/bin'
    )

    # Build the export line
    local path_string
    path_string=$(IFS=:; echo "${path_dirs[*]}")
    local export_line="export PATH=\"${path_string}:\$PATH\""
    local marker="# ACFS PATH ordering (added by doctor --fix)"

    # Guard: Check if already present
    if file_contains_line "$target_file" "$marker"; then
        doctor_fix_log INFO "PATH ordering already configured in $target_file"
        return 0
    fi

    # Dry-run mode
    if [[ "$DOCTOR_FIX_DRY_RUN" == "true" ]]; then
        FIXES_DRY_RUN+=("fix.path.ordering|Prepend PATH directories to $target_file|$target_file|$export_line")
        doctor_fix_log DRY "Prepend PATH directories to $target_file"
        return 0
    fi

    # Create backup
    local backup_json=""
    if [[ -f "$target_file" ]]; then
        backup_json=$(create_backup "$target_file" "path-ordering")
    fi

    # Apply fix
    {
        echo ""
        echo "$marker"
        echo "$export_line"
    } >> "$target_file"

    # Record change
    record_change "path" "Added PATH ordering to $target_file" \
        "sed -i '/$marker/,+1d' '$target_file'" \
        false "info" "[\"$target_file\"]" "${backup_json:-[]}" "[]" >/dev/null

    doctor_fix_log INFO "Added PATH ordering to $target_file"
    FIXES_APPLIED+=("fix.path.ordering|Added PATH ordering to $target_file")
    FIX_APPLIED=$((FIX_APPLIED + 1))

    return 0
}

# ============================================================
# Fixer: Config Copy (fix.config.copy)
# ============================================================

# Copy missing ACFS config files
fix_config_copy() {
    local check_id="$1"
    local src="$2"
    local dest="$3"

    # Guard: Source must exist
    if [[ ! -f "$src" ]]; then
        doctor_fix_log WARN "Source config not found: $src"
        return 1
    fi

    # Guard: Dest must not exist
    if [[ -f "$dest" ]]; then
        doctor_fix_log INFO "Config already exists: $dest"
        return 0
    fi

    # Dry-run mode
    if [[ "$DOCTOR_FIX_DRY_RUN" == "true" ]]; then
        FIXES_DRY_RUN+=("fix.config.copy|Copy $(basename "$src") to $dest|$dest|cp -p $src $dest")
        doctor_fix_log DRY "Copy $(basename "$src") to $dest"
        return 0
    fi

    # Ensure parent directory exists
    mkdir -p "$(dirname "$dest")"

    # Copy file
    cp -p "$src" "$dest"

    # Record change
    record_change "config" "Copied config: $(basename "$src")" \
        "rm -f '$dest'" \
        false "info" "[\"$dest\"]" "[]" "[]" >/dev/null

    doctor_fix_log INFO "Copied $(basename "$src") to $dest"
    FIXES_APPLIED+=("fix.config.copy|Copied $(basename "$src") to $dest")
    FIX_APPLIED=$((FIX_APPLIED + 1))

    return 0
}

# ============================================================
# Fixer: DCG Hook (fix.dcg.hook)
# ============================================================

# Install DCG pre-tool-use hook
fix_dcg_hook() {
    local check_id="$1"

    # Guard: dcg command must exist
    if ! command -v dcg &>/dev/null; then
        doctor_fix_log WARN "DCG not installed, cannot fix hook"
        return 1
    fi

    # Guard: Check if already installed
    if dcg doctor --format json 2>/dev/null | jq -e '.hook_installed == true' &>/dev/null; then
        doctor_fix_log INFO "DCG hook already installed"
        return 0
    fi

    # Dry-run mode
    if [[ "$DOCTOR_FIX_DRY_RUN" == "true" ]]; then
        FIXES_DRY_RUN+=("fix.dcg.hook|Install DCG pre-tool-use hook|~/.config/claude-code|dcg install")
        doctor_fix_log DRY "Install DCG pre-tool-use hook"
        return 0
    fi

    # Install hook
    if dcg install 2>/dev/null; then
        record_change "hook" "Installed DCG pre-tool-use hook" \
            "dcg uninstall" \
            false "info" "[]" "[]" "[]" >/dev/null

        doctor_fix_log INFO "Installed DCG pre-tool-use hook"
        FIXES_APPLIED+=("fix.dcg.hook|Installed DCG pre-tool-use hook")
        FIX_APPLIED=$((FIX_APPLIED + 1))
        return 0
    else
        doctor_fix_log ERROR "Failed to install DCG hook"
        FIX_FAILED=$((FIX_FAILED + 1))
        return 1
    fi
}

# ============================================================
# Fixer: Symlink Create (fix.symlink.create)
# ============================================================

# Create missing tool symlinks
fix_symlink_create() {
    local check_id="$1"
    local binary="$2"
    local symlink="$3"

    # Guard: Binary must exist and be executable
    if [[ ! -x "$binary" ]]; then
        doctor_fix_log WARN "Binary not found or not executable: $binary"
        return 1
    fi

    # Guard: Symlink must not exist
    if [[ -e "$symlink" ]]; then
        doctor_fix_log INFO "Symlink already exists: $symlink"
        return 0
    fi

    # Dry-run mode
    if [[ "$DOCTOR_FIX_DRY_RUN" == "true" ]]; then
        FIXES_DRY_RUN+=("fix.symlink.create|Create symlink $(basename "$symlink")|$symlink|ln -s $binary $symlink")
        doctor_fix_log DRY "Create symlink: $(basename "$symlink") -> $binary"
        return 0
    fi

    # Ensure symlink directory exists
    mkdir -p "$(dirname "$symlink")"

    # Create symlink
    ln -s "$binary" "$symlink"

    # Record change
    record_change "symlink" "Created symlink: $(basename "$symlink")" \
        "rm -f '$symlink'" \
        false "info" "[\"$symlink\"]" "[]" "[]" >/dev/null

    doctor_fix_log INFO "Created symlink: $(basename "$symlink") -> $binary"
    FIXES_APPLIED+=("fix.symlink.create|Created symlink $(basename "$symlink")")
    FIX_APPLIED=$((FIX_APPLIED + 1))

    return 0
}

# ============================================================
# Fixer: Plugin Clone (fix.plugin.clone)
# ============================================================

# Clone missing zsh plugins
fix_plugin_clone() {
    local check_id="$1"
    local plugin_name="$2"
    local repo_url="$3"

    local plugins_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
    local target_dir="$plugins_dir/$plugin_name"

    # Guard: Must not already exist
    if [[ -d "$target_dir" ]]; then
        doctor_fix_log INFO "Plugin already installed: $plugin_name"
        return 0
    fi

    # Guard: Oh-my-zsh must be installed
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        doctor_fix_log WARN "Oh-my-zsh not installed, cannot install plugins"
        FIXES_MANUAL+=("fix.plugin.clone|Install Oh-my-zsh first|curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | bash")
        FIX_MANUAL=$((FIX_MANUAL + 1))
        return 1
    fi

    # Dry-run mode
    if [[ "$DOCTOR_FIX_DRY_RUN" == "true" ]]; then
        FIXES_DRY_RUN+=("fix.plugin.clone|Clone zsh plugin: $plugin_name|$target_dir|git clone --depth 1 $repo_url $target_dir")
        doctor_fix_log DRY "Clone zsh plugin: $plugin_name"
        return 0
    fi

    # Ensure plugins directory exists
    mkdir -p "$plugins_dir"

    # Clone plugin
    if git clone --depth 1 "$repo_url" "$target_dir" 2>/dev/null; then
        record_change "plugin" "Cloned zsh plugin: $plugin_name" \
            "rm -rf '$target_dir'" \
            false "info" "[\"$target_dir\"]" "[]" "[]" >/dev/null

        doctor_fix_log INFO "Cloned zsh plugin: $plugin_name"
        FIXES_APPLIED+=("fix.plugin.clone|Cloned zsh plugin: $plugin_name")
        FIX_APPLIED=$((FIX_APPLIED + 1))
        return 0
    else
        doctor_fix_log ERROR "Failed to clone plugin: $plugin_name"
        FIX_FAILED=$((FIX_FAILED + 1))
        return 1
    fi
}

# ============================================================
# Fixer: ACFS Sourcing (fix.acfs.sourcing)
# ============================================================

# Add ACFS config sourcing to .zshrc
fix_acfs_sourcing() {
    local check_id="$1"
    local zshrc="$HOME/.zshrc"
    local source_line='[[ -f ~/.acfs/zsh/acfs.zshrc ]] && source ~/.acfs/zsh/acfs.zshrc'
    local marker="# ACFS configuration (added by doctor --fix)"

    # Guard: Check if already sourced
    if file_contains_line "$zshrc" "acfs.zshrc"; then
        doctor_fix_log INFO "ACFS already sourced in .zshrc"
        return 0
    fi

    # Guard: Check if acfs.zshrc exists
    if [[ ! -f "$HOME/.acfs/zsh/acfs.zshrc" ]]; then
        doctor_fix_log WARN "ACFS config not found at ~/.acfs/zsh/acfs.zshrc"
        return 1
    fi

    # Dry-run mode
    if [[ "$DOCTOR_FIX_DRY_RUN" == "true" ]]; then
        FIXES_DRY_RUN+=("fix.acfs.sourcing|Add ACFS sourcing to .zshrc|$zshrc|$source_line")
        doctor_fix_log DRY "Add ACFS sourcing to .zshrc"
        return 0
    fi

    # Create backup
    local backup_json=""
    if [[ -f "$zshrc" ]]; then
        backup_json=$(create_backup "$zshrc" "acfs-sourcing")
    fi

    # Append sourcing line
    {
        echo ""
        echo "$marker"
        echo "$source_line"
    } >> "$zshrc"

    # Record change
    record_change "config" "Added ACFS sourcing to .zshrc" \
        "sed -i '/$marker/,+1d' '$zshrc'" \
        false "info" "[\"$zshrc\"]" "${backup_json:-[]}" "[]" >/dev/null

    doctor_fix_log INFO "Added ACFS sourcing to .zshrc"
    FIXES_APPLIED+=("fix.acfs.sourcing|Added ACFS sourcing to .zshrc")
    FIX_APPLIED=$((FIX_APPLIED + 1))

    return 0
}

# ============================================================
# Fix Dispatcher
# ============================================================

# Dispatch a fix based on check ID
# Returns 0 if fix was applied or not needed, 1 if fix failed
dispatch_fix() {
    local check_id="$1"
    local check_status="$2"
    local fix_hint="${3:-}"  # Optional hint from check (e.g., file path)

    # Only fix failed or warned checks
    case "$check_status" in
        pass) return 0 ;;
        skip) return 0 ;;
    esac

    case "$check_id" in
        # PATH fixes
        path.*)
            fix_path_ordering "$check_id"
            ;;

        # Config file copies
        config.acfs_zshrc)
            fix_config_copy "$check_id" \
                "$SCRIPT_DIR/../../acfs/zsh/acfs.zshrc" \
                "$HOME/.acfs/zsh/acfs.zshrc"
            ;;
        config.tmux)
            fix_config_copy "$check_id" \
                "$SCRIPT_DIR/../../acfs/tmux/tmux.conf" \
                "$HOME/.acfs/tmux/tmux.conf"
            ;;

        # DCG hook
        hook.dcg.*)
            fix_dcg_hook "$check_id"
            ;;

        # Stack tools (fixes #160 - meta_skill and other stack tools)
        stack.meta_skill*)
            fix_stack_install "$check_id" "ms" \
                "curl -fsSL https://raw.githubusercontent.com/Dicklesworthstone/meta_skill/main/scripts/install.sh | bash -s -- --easy-mode"
            ;;
        stack.mcp_agent_mail*)
            fix_stack_install "$check_id" "am" \
                "curl -fsSL https://raw.githubusercontent.com/Dicklesworthstone/mcp_agent_mail/main/scripts/install.sh | bash -s -- --dir ~/mcp_agent_mail --yes"
            ;;

        # Symlinks
        symlink.br)
            fix_symlink_create "$check_id" "$HOME/.cargo/bin/br" "$HOME/.local/bin/br"
            ;;
        symlink.bv)
            fix_symlink_create "$check_id" "$HOME/.cargo/bin/bv" "$HOME/.local/bin/bv"
            ;;

        # Zsh plugins
        shell.plugins.zsh_autosuggestions)
            fix_plugin_clone "$check_id" "zsh-autosuggestions" \
                "https://github.com/zsh-users/zsh-autosuggestions"
            ;;
        shell.plugins.zsh_syntax_highlighting)
            fix_plugin_clone "$check_id" "zsh-syntax-highlighting" \
                "https://github.com/zsh-users/zsh-syntax-highlighting"
            ;;

        # ACFS sourcing
        shell.acfs_sourced)
            fix_acfs_sourcing "$check_id"
            ;;

        # SSH server (fixes #161/#162)
        network.ssh_server)
            fix_ssh_server "$check_id"
            ;;

        # SSH keepalive
        network.ssh_keepalive|network.ssh_keepalive.*)
            fix_ssh_keepalive "$check_id"
            ;;

        # Agent CLI tools (fixes #213)
        agent.claude)
            fix_stack_install "$check_id" "claude" \
                "curl -fsSL https://agent-flywheel.com/install | bash -s -- --yes --force-reinstall --only agents.claude"
            ;;
        agent.codex)
            fix_stack_install "$check_id" "codex" \
                "bun install -g --trust @openai/codex@latest"
            ;;
        agent.gemini)
            fix_stack_install "$check_id" "gemini" \
                "bun install -g --trust @google/gemini-cli@latest"
            ;;

        # Agent aliases/functions (fixes #163)
        agent.alias.*)
            fix_acfs_sourcing "$check_id"
            ;;

        # Manual fixes (log suggestion only)
        shell.ohmyzsh|shell.p10k|*.apt_install|*.sudo_required)
            if [[ -n "$fix_hint" ]]; then
                FIXES_MANUAL+=("$check_id|Requires manual action|$fix_hint")
            fi
            FIX_MANUAL=$((FIX_MANUAL + 1))
            return 0
            ;;

        *)
            # Unknown check - skip silently
            FIX_SKIPPED=$((FIX_SKIPPED + 1))
            return 0
            ;;
    esac
}

# ============================================================
# Fixer: Stack Install (fix.stack.install)
# ============================================================

# Install missing stack tools via their upstream installer
fix_stack_install() {
    local check_id="$1"
    local binary_name="$2"
    local install_cmd="$3"

    # Guard: Check if already installed
    if command -v "$binary_name" &>/dev/null; then
        doctor_fix_log INFO "$binary_name already installed"
        return 0
    fi

    # Dry-run mode
    if [[ "$DOCTOR_FIX_DRY_RUN" == "true" ]]; then
        FIXES_DRY_RUN+=("fix.stack.$binary_name|Install $binary_name|~/.local/bin/$binary_name|$install_cmd")
        doctor_fix_log DRY "Install $binary_name"
        return 0
    fi

    # Run installer
    if eval "$install_cmd" 2>/dev/null; then
        doctor_fix_log INFO "Installed $binary_name"
        FIXES_APPLIED+=("fix.stack.$binary_name|Installed $binary_name")
        FIX_APPLIED=$((FIX_APPLIED + 1))
        return 0
    else
        doctor_fix_log ERROR "Failed to install $binary_name"
        FIX_FAILED=$((FIX_FAILED + 1))
        return 1
    fi
}

# ============================================================
# Fixer: SSH Server (fix.ssh.server)
# ============================================================

# Install and enable SSH server
fix_ssh_server() {
    local check_id="$1"

    # Guard: Check if already installed
    if command -v sshd &>/dev/null || [[ -f /etc/ssh/sshd_config ]]; then
        # Check if running
        if command -v systemctl &>/dev/null && [[ -d /run/systemd/system ]]; then
            if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then
                doctor_fix_log INFO "SSH server already installed and running"
                return 0
            fi

            # Installed but not running - enable and start
            if [[ "$DOCTOR_FIX_DRY_RUN" == "true" ]]; then
                FIXES_DRY_RUN+=("fix.ssh.server|Enable and start SSH server|/etc/ssh/sshd_config|sudo systemctl enable --now ssh")
                doctor_fix_log DRY "Enable and start SSH server"
                return 0
            fi

            if sudo systemctl enable --now ssh 2>/dev/null || sudo systemctl enable --now sshd 2>/dev/null; then
                doctor_fix_log INFO "Enabled and started SSH server"
                FIXES_APPLIED+=("fix.ssh.server|Enabled and started SSH server")
                FIX_APPLIED=$((FIX_APPLIED + 1))
                return 0
            else
                doctor_fix_log ERROR "Failed to start SSH server"
                FIX_FAILED=$((FIX_FAILED + 1))
                return 1
            fi
        fi
        return 0
    fi

    # Not installed - install it
    if [[ "$DOCTOR_FIX_DRY_RUN" == "true" ]]; then
        FIXES_DRY_RUN+=("fix.ssh.server|Install openssh-server|/etc/ssh/sshd_config|sudo apt-get install -y openssh-server")
        doctor_fix_log DRY "Install openssh-server"
        return 0
    fi

    if sudo apt-get install -y openssh-server 2>/dev/null; then
        sudo systemctl enable --now ssh 2>/dev/null || sudo systemctl enable --now sshd 2>/dev/null || true
        doctor_fix_log INFO "Installed and enabled openssh-server"
        FIXES_APPLIED+=("fix.ssh.server|Installed and enabled openssh-server")
        FIX_APPLIED=$((FIX_APPLIED + 1))
        return 0
    else
        doctor_fix_log ERROR "Failed to install openssh-server"
        FIX_FAILED=$((FIX_FAILED + 1))
        return 1
    fi
}

# ============================================================
# Fixer: SSH Keepalive (fix.ssh.keepalive)
# ============================================================

# Configure SSH keepalive settings
fix_ssh_keepalive() {
    local check_id="$1"
    local sshd_config="/etc/ssh/sshd_config"

    # Guard: sshd_config must exist
    if [[ ! -f "$sshd_config" ]]; then
        doctor_fix_log WARN "sshd_config not found, install openssh-server first"
        FIXES_MANUAL+=("$check_id|Install openssh-server first|sudo apt-get install -y openssh-server")
        FIX_MANUAL=$((FIX_MANUAL + 1))
        return 1
    fi

    # Guard: Check if already configured
    if grep -qE '^[[:space:]]*ClientAliveInterval[[:space:]]+[0-9]+' "$sshd_config" 2>/dev/null; then
        doctor_fix_log INFO "SSH keepalive already configured"
        return 0
    fi

    if [[ "$DOCTOR_FIX_DRY_RUN" == "true" ]]; then
        FIXES_DRY_RUN+=("fix.ssh.keepalive|Configure SSH keepalive|$sshd_config|echo 'ClientAliveInterval 60' >> $sshd_config")
        doctor_fix_log DRY "Configure SSH keepalive in $sshd_config"
        return 0
    fi

    # Create backup
    local backup_json=""
    if [[ -f "$sshd_config" ]]; then
        backup_json=$(create_backup "$sshd_config" "ssh-keepalive")
    fi

    # Apply settings
    {
        echo ""
        echo "# ACFS: SSH keepalive settings (added by doctor --fix)"
        echo "ClientAliveInterval 60"
        echo "ClientAliveCountMax 3"
    } | sudo tee -a "$sshd_config" > /dev/null

    # Restart sshd to apply
    sudo systemctl reload ssh 2>/dev/null || sudo systemctl reload sshd 2>/dev/null || true

    doctor_fix_log INFO "Configured SSH keepalive (ClientAliveInterval 60, ClientAliveCountMax 3)"
    FIXES_APPLIED+=("fix.ssh.keepalive|Configured SSH keepalive settings")
    FIX_APPLIED=$((FIX_APPLIED + 1))

    return 0
}

# ============================================================
# Summary Output
# ============================================================

# Print fix summary
print_fix_summary() {
    echo ""
    echo "========================================================================"
    echo "  Doctor --fix Summary"
    echo "========================================================================"

    if [[ "$DOCTOR_FIX_DRY_RUN" == "true" ]]; then
        echo "  Mode: DRY-RUN (no changes made)"
        echo ""

        if [[ ${#FIXES_DRY_RUN[@]} -gt 0 ]]; then
            echo "  Would apply the following fixes:"
            for fix in "${FIXES_DRY_RUN[@]}"; do
                IFS='|' read -r id desc file cmd <<< "$fix"
                echo ""
                echo "    [$id]"
                echo "      Action: $desc"
                echo "      File: $file"
                echo "      Command: $cmd"
            done
        else
            echo "  No fixes needed."
        fi
    else
        echo "  Applied: $FIX_APPLIED"
        echo "  Skipped: $FIX_SKIPPED"
        echo "  Failed:  $FIX_FAILED"
        echo "  Manual:  $FIX_MANUAL"

        if [[ ${#FIXES_APPLIED[@]} -gt 0 ]]; then
            echo ""
            echo "  Applied fixes:"
            for fix in "${FIXES_APPLIED[@]}"; do
                IFS='|' read -r id desc <<< "$fix"
                echo "    [$id] $desc"
            done
        fi
    fi

    if [[ ${#FIXES_MANUAL[@]} -gt 0 ]]; then
        echo ""
        echo "  Manual fixes needed:"
        for fix in "${FIXES_MANUAL[@]}"; do
            IFS='|' read -r id desc cmd <<< "$fix"
            echo "    [$id] $desc"
            echo "      Run: $cmd"
        done
    fi

    echo ""
    echo "========================================================================"

    # Show undo hint if changes were made
    if [[ "$DOCTOR_FIX_DRY_RUN" != "true" ]] && [[ $FIX_APPLIED -gt 0 ]]; then
        echo ""
        echo "  To undo changes: acfs undo --list"
        echo ""
    fi
}

# ============================================================
# Main Entry Point
# ============================================================

# Run doctor --fix
# Usage: run_doctor_fix [--dry-run] [--yes] [--only <categories>]
run_doctor_fix() {
    local only_categories=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run) DOCTOR_FIX_DRY_RUN=true; shift ;;
            --yes) DOCTOR_FIX_YES=true; shift ;;
            --prompt) DOCTOR_FIX_PROMPT=true; shift ;;
            --only)
                if [[ -z "${2:-}" || "$2" == -* ]]; then
                    echo "Error: --only requires a category value" >&2
                    return 1
                fi
                only_categories="$2"
                shift 2
                ;;
            *) shift ;;
        esac
    done

    # Initialize autofix session (unless dry-run)
    if [[ "$DOCTOR_FIX_DRY_RUN" != "true" ]]; then
        start_autofix_session || {
            echo "ERROR: Failed to start autofix session" >&2
            return 1
        }
    fi

    # Reset counters
    FIX_APPLIED=0
    FIX_SKIPPED=0
    FIX_FAILED=0
    FIX_MANUAL=0
    FIXES_APPLIED=()
    FIXES_DRY_RUN=()
    FIXES_MANUAL=()
    FIXES_PROMPTED=()

    echo ""
    if [[ "$DOCTOR_FIX_DRY_RUN" == "true" ]]; then
        echo "DRY-RUN: acfs doctor --fix"
        echo "Scanning for fixable issues..."
    else
        echo "Running: acfs doctor --fix"
        echo "Applying safe fixes..."
    fi
    echo ""

    # The actual fixes are dispatched by the caller (doctor.sh)
    # based on check results. This function sets up the environment.

    return 0
}

# Finalize doctor --fix
finalize_doctor_fix() {
    # Print summary
    print_fix_summary

    # End autofix session (unless dry-run)
    if [[ "$DOCTOR_FIX_DRY_RUN" != "true" ]]; then
        end_autofix_session

        # Print undo summary if changes were made
        if [[ $FIX_APPLIED -gt 0 ]]; then
            print_undo_summary
        fi
    fi

    # Return failure if any fixes failed
    if [[ $FIX_FAILED -gt 0 ]]; then
        return 1
    fi

    return 0
}
