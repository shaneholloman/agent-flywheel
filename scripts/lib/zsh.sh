#!/usr/bin/env bash
# ============================================================
# ACFS Installer - Zsh Setup Library
# Installs and configures zsh with oh-my-zsh and powerlevel10k
#
# Requires:
#   - logging.sh to be sourced first for log_* functions
#   - $SUDO to be set (empty string for root, "sudo" otherwise)
# ============================================================

# Fallback logging if logging.sh not sourced
if ! declare -f log_fatal &>/dev/null; then
    log_fatal() { echo "FATAL: $1" >&2; exit 1; }
    log_detail() { echo "  $1" >&2; }
    log_warn() { echo "WARN: $1" >&2; }
    log_success() { echo "OK: $1" >&2; }
    log_error() { echo "ERROR: $1" >&2; }
    log_step() { echo "[$1] $2" >&2; }
fi

# Ensure SUDO is set (empty string for root, "sudo" otherwise)
if [[ $EUID -eq 0 ]]; then
    SUDO=""
else
    : "${SUDO:=sudo}"
fi

ZSH_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Oh My Zsh installation URL
OMZ_INSTALL_URL="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"

# Powerlevel10k repository
P10K_REPO="https://github.com/romkatv/powerlevel10k.git"

# Plugin repositories
ZSH_AUTOSUGGESTIONS_REPO="https://github.com/zsh-users/zsh-autosuggestions"
ZSH_SYNTAX_HIGHLIGHTING_REPO="https://github.com/zsh-users/zsh-syntax-highlighting.git"

zsh_get_local_passwd_entry() {
    local user="${1:-}"
    [[ -n "$user" ]] || return 1
    [[ -r /etc/passwd ]] || return 1
    awk -F: -v user="$user" '$1 == user { print $0; exit }' /etc/passwd 2>/dev/null
}

zsh_is_externally_managed_user() {
    local user="${1:-}"
    local passwd_entry=""
    local local_entry=""

    [[ -n "$user" ]] || return 1
    passwd_entry="$(getent passwd "$user" 2>/dev/null || true)"
    [[ -n "$passwd_entry" ]] || return 1

    local_entry="$(zsh_get_local_passwd_entry "$user" || true)"
    [[ -z "$local_entry" ]]
}

configure_external_shell_handoff() {
    local bashrc="$HOME/.bashrc"

    if grep -q 'ACFS externally-managed shell handoff' "$bashrc" 2>/dev/null; then
        return 0
    fi

    if [[ -f "$bashrc" ]] && [[ -s "$bashrc" ]]; then
        local last_char=""
        last_char=$(tail -c 1 "$bashrc" | od -An -t u1 | tr -d ' ' 2>/dev/null || true)
        if [[ "$last_char" != "10" ]]; then
            printf '\n' >> "$bashrc"
        fi
    fi

    cat >> "$bashrc" << 'EOF'
# ACFS externally-managed shell handoff
if [[ $- == *i* ]] && [[ -t 0 ]] && command -v zsh >/dev/null 2>&1 && [[ -z "${ACFS_ZSH_HANDOFF_ACTIVE:-}" ]]; then
  export ACFS_ZSH_HANDOFF_ACTIVE=1
  exec "$(command -v zsh)" -l
fi
EOF
}

# Load security helpers + checksums.yaml (fail closed if unavailable).
ZSH_SECURITY_READY=false
_zsh_require_security() {
    if [[ "${ZSH_SECURITY_READY}" == "true" ]]; then
        return 0
    fi

    if [[ ! -f "$ZSH_LIB_DIR/security.sh" ]]; then
        log_error "Security library not found ($ZSH_LIB_DIR/security.sh); refusing to run upstream installer scripts"
        return 1
    fi

    # shellcheck source=security.sh
    # shellcheck disable=SC1091  # runtime relative source
    source "$ZSH_LIB_DIR/security.sh"
    if ! load_checksums; then
        log_error "checksums.yaml not available; refusing to run upstream installer scripts"
        return 1
    fi

    ZSH_SECURITY_READY=true
    return 0
}

# Install zsh package
install_zsh() {
    if command -v zsh &>/dev/null; then
        log_detail "zsh already installed: $(zsh --version)"
        return 0
    fi

    log_detail "Installing zsh..."
    $SUDO apt-get install -y zsh

    if ! command -v zsh &>/dev/null; then
        log_error "Failed to install zsh"
        return 1
    fi

    log_success "zsh installed"
}

# Install Oh My Zsh
install_ohmyzsh() {
    local omz_dir="$HOME/.oh-my-zsh"

    if [[ -d "$omz_dir" ]]; then
        log_detail "Oh My Zsh already installed"
        return 0
    fi

    log_detail "Installing Oh My Zsh..."

    if ! _zsh_require_security; then
        return 1
    fi

    local expected_sha256
    expected_sha256="$(get_checksum ohmyzsh)"
    if [[ -z "$expected_sha256" ]]; then
        log_error "No checksum recorded for ohmyzsh; refusing to run unverified installer"
        return 1
    fi

    # Install non-interactively without changing shell.
    (
        set -o pipefail
        verify_checksum "$OMZ_INSTALL_URL" "$expected_sha256" "ohmyzsh" | sh -s -- --unattended --keep-zshrc
    )

    if [[ ! -d "$omz_dir" ]]; then
        log_error "Failed to install Oh My Zsh"
        return 1
    fi

    log_success "Oh My Zsh installed"
}

# Install Powerlevel10k theme
install_powerlevel10k() {
    local custom_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    local p10k_dir="$custom_dir/themes/powerlevel10k"

    if [[ -d "$p10k_dir" ]]; then
        log_detail "Powerlevel10k already installed"
        return 0
    fi

    log_detail "Installing Powerlevel10k theme..."

    git clone --depth=1 "$P10K_REPO" "$p10k_dir"

    if [[ ! -d "$p10k_dir" ]]; then
        log_error "Failed to install Powerlevel10k"
        return 1
    fi

    log_success "Powerlevel10k installed"
}

# Install zsh plugins
install_zsh_plugins() {
    local custom_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    local plugins_dir="$custom_dir/plugins"

    mkdir -p "$plugins_dir"

    # zsh-autosuggestions
    if [[ ! -d "$plugins_dir/zsh-autosuggestions" ]]; then
        log_detail "Installing zsh-autosuggestions..."
        git clone "$ZSH_AUTOSUGGESTIONS_REPO" "$plugins_dir/zsh-autosuggestions"
    else
        log_detail "zsh-autosuggestions already installed"
    fi

    # zsh-syntax-highlighting
    if [[ ! -d "$plugins_dir/zsh-syntax-highlighting" ]]; then
        log_detail "Installing zsh-syntax-highlighting..."
        git clone "$ZSH_SYNTAX_HIGHLIGHTING_REPO" "$plugins_dir/zsh-syntax-highlighting"
    else
        log_detail "zsh-syntax-highlighting already installed"
    fi

    log_success "Zsh plugins installed"
}

# Install ACFS zshrc configuration
install_acfs_zshrc() {
    local acfs_zsh_dir="$HOME/.acfs/zsh"
    local acfs_zshrc="$acfs_zsh_dir/acfs.zshrc"
    local user_zshrc="$HOME/.zshrc"
    local user_profile="$HOME/.profile"
    local user_zprofile="$HOME/.zprofile"
    local legacy_profile_path_line='export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.bun/bin:$PATH"'
    local profile_path_line='export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.bun/bin:$HOME/.atuin/bin:$PATH"'

    mkdir -p "$acfs_zsh_dir"

    # Download ACFS zshrc from repository
    log_detail "Installing ACFS zshrc..."

    if ! _zsh_require_security; then
        return 1
    fi

    if ! acfs_curl "${ACFS_RAW:-https://raw.githubusercontent.com/Dicklesworthstone/agentic_coding_flywheel_setup/${ACFS_REF:-main}}/acfs/zsh/acfs.zshrc" "$acfs_zshrc" "ACFS zshrc"; then
        log_error "Failed to download ACFS zshrc"
        return 1
    fi

    # Backup existing .zshrc if it exists and isn't our loader
    if [[ -f "$user_zshrc" ]] && ! grep -q "ACFS loader" "$user_zshrc" 2>/dev/null; then
        local backup
        backup="$user_zshrc.bak.$(date +%Y%m%d%H%M%S)"
        log_detail "Backing up existing .zshrc to $backup"
        mv "$user_zshrc" "$backup"
    fi

    # Create minimal loader .zshrc
    cat > "$user_zshrc" << 'EOF'
# ACFS loader — user overrides go in ~/.zshrc.local (sourced by acfs.zshrc)
source "$HOME/.acfs/zsh/acfs.zshrc"
EOF

    if [[ ! -f "$user_profile" ]]; then
        {
            echo "# ~/.profile: executed by bash for login shells"
            echo ""
            echo "# User binary paths"
            echo "$profile_path_line"
        } > "$user_profile"
    elif grep -Fq "$legacy_profile_path_line" "$user_profile" 2>/dev/null; then
        sed -i "s|$(printf '%s' "$legacy_profile_path_line" | sed 's/[.[\\*^$()+?{|]/\\&/g')|$profile_path_line|" "$user_profile"
    elif ! grep -q '\.local/bin' "$user_profile" 2>/dev/null || \
         ! grep -q '\.atuin/bin' "$user_profile" 2>/dev/null; then
        {
            echo ""
            echo "# Added by ACFS - user binary paths"
            echo "$profile_path_line"
        } >> "$user_profile"
    fi

    if [[ ! -f "$user_zprofile" ]]; then
        {
            echo "# ~/.zprofile: executed by zsh for login shells"
            echo ""
            echo "# User binary paths"
            echo "$profile_path_line"
        } > "$user_zprofile"
    elif grep -Fq "$legacy_profile_path_line" "$user_zprofile" 2>/dev/null; then
        sed -i "s|$(printf '%s' "$legacy_profile_path_line" | sed 's/[.[\\*^$()+?{|]/\\&/g')|$profile_path_line|" "$user_zprofile"
    elif ! grep -q '\.local/bin' "$user_zprofile" 2>/dev/null || \
         ! grep -q '\.atuin/bin' "$user_zprofile" 2>/dev/null; then
        {
            echo ""
            echo "# Added by ACFS - user binary paths"
            echo "$profile_path_line"
        } >> "$user_zprofile"
    fi

    log_success "ACFS zshrc installed"
}

# Set zsh as default shell
set_zsh_default() {
    local current_shell
    current_shell=$(getent passwd "$(whoami)" | cut -d: -f7)
    local zsh_path
    zsh_path=$(command -v zsh)

    if [[ "$current_shell" == "$zsh_path" ]]; then
        log_detail "zsh is already the default shell"
        return 0
    fi

    if zsh_is_externally_managed_user "$(whoami)"; then
        log_warn "Shell is managed outside /etc/passwd; installing a bash-to-zsh handoff instead of using chsh"
        configure_external_shell_handoff
    else
        log_detail "Setting zsh as default shell..."
        $SUDO chsh -s "$zsh_path" "$(whoami)"
    fi

    log_success "Default shell set to zsh"
}

# Full shell setup sequence
setup_shell() {
    log_step "3/8" "Setting up shell..."

    install_zsh
    install_ohmyzsh
    install_powerlevel10k
    install_zsh_plugins
    install_acfs_zshrc
    set_zsh_default

    log_success "Shell setup complete"
}
