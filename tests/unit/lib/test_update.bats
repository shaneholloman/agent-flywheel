#!/usr/bin/env bats

load '../test_helper'

setup() {
    common_setup
    
    # update.sh logic relies on being sourced or executed
    # We source it.
    # It has a guard at the end `if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then main "$@"; fi`
    # When sourced by bats, this guard prevents main.
    
    # Mock environment for update.sh
    export HOME=$(create_temp_dir)
    export UPDATE_LOG_DIR="$HOME/.acfs/logs/updates"
    
    source_lib "update"
    
    # Mock date
    stub_command "date" "2025-01-01"
}

teardown() {
    common_teardown
}

@test "get_version: detects bun" {
    mkdir -p "$HOME/.bun/bin"
    # Create stub script at location
    cat > "$HOME/.bun/bin/bun" <<EOF
#!/bin/bash
echo "1.0.0"
EOF
    chmod +x "$HOME/.bun/bin/bun"
    
    run get_version "bun"
    assert_output "1.0.0"
}

@test "get_version: detects rust" {
    mkdir -p "$HOME/.cargo/bin"
    cat > "$HOME/.cargo/bin/rustc" <<EOF
#!/bin/bash
echo "rustc 1.75.0 (hash)"
EOF
    chmod +x "$HOME/.cargo/bin/rustc"
    
    run get_version "rust"
    assert_output "1.75.0"
}

@test "get_version: handles unknown" {
    run get_version "nonexistent"
    assert_output "unknown"
}

@test "capture_version: tracks changes" {
    mkdir -p "$HOME/.bun/bin"
    
    # Before
    cat > "$HOME/.bun/bin/bun" <<EOF
#!/bin/bash
echo "1.0.0"
EOF
    chmod +x "$HOME/.bun/bin/bun"
    
    capture_version_before "bun"
    assert_equal "${VERSION_BEFORE[bun]}" "1.0.0"
    
    # After (update)
    cat > "$HOME/.bun/bin/bun" <<EOF
#!/bin/bash
echo "1.0.1"
EOF
    chmod +x "$HOME/.bun/bin/bun"
    
    capture_version_after "bun"
    assert_equal "${VERSION_AFTER[bun]}" "1.0.1"
}

@test "update_cargo_tools: runs cargo install --force" {
    mkdir -p "$HOME/.cargo/bin"
    
    # Mock cargo
    local log_file="$HOME/cargo.log"
    cat > "$HOME/.cargo/bin/cargo" <<EOF
#!/bin/bash
echo "\$@" >> "$log_file"
EOF
    chmod +x "$HOME/.cargo/bin/cargo"
    
    # Mock existing tools so update_cargo_tools attempts update
    # sg needs to exist in PATH or .cargo/bin
    touch "$HOME/.cargo/bin/sg"
    chmod +x "$HOME/.cargo/bin/sg"
    
    # Mock get_version for sg
    # We need sg in PATH for get_version
    export PATH="$HOME/.cargo/bin:$PATH"
    cat > "$HOME/.cargo/bin/sg" <<EOF
#!/bin/bash
echo "0.1.0"
EOF
    chmod +x "$HOME/.cargo/bin/sg"
    
    # Run update
    UPDATE_RUNTIME=true
    run update_cargo_tools
    assert_success
    
    # Verify cargo install called
    run cat "$log_file"
    assert_output --partial "install ast-grep --locked --force"
}

@test "apt_lock_is_held: uses plain fuser when accessible" {
    init_stub_dir
    local lockfile="$HOME/dpkg.lock"
    local fuser_log="$HOME/fuser.log"
    : > "$lockfile"

    cat > "$STUB_DIR/fuser" <<EOF
#!/usr/bin/env bash
echo "\$*" >> "$fuser_log"
exit 0
EOF
    chmod +x "$STUB_DIR/fuser"

    run apt_lock_is_held "$lockfile"
    assert_success

    run cat "$fuser_log"
    assert_output --partial "$lockfile"
}

@test "apt_lock_is_held: falls back to sudo -n without prompting" {
    init_stub_dir
    local lockfile="$HOME/dpkg.lock"
    local sudo_log="$HOME/sudo.log"
    : > "$lockfile"

    cat > "$STUB_DIR/fuser" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x "$STUB_DIR/fuser"

    cat > "$STUB_DIR/sudo" <<EOF
#!/usr/bin/env bash
echo "\$*" >> "$sudo_log"
if [[ "\$1" == "-n" ]]; then
  exit 0
fi
exit 1
EOF
    chmod +x "$STUB_DIR/sudo"

    run apt_lock_is_held "$lockfile"
    assert_success

    run cat "$sudo_log"
    assert_output --partial "-n fuser $lockfile"
}

@test "update_require_security: sources repo-local scripts/lib/security.sh" {
    local repo_root
    local marker_file

    repo_root="$(create_temp_dir)"
    marker_file="$repo_root/security-sourced.marker"

    mkdir -p "$repo_root/scripts/lib"
    cat > "$repo_root/scripts/lib/security.sh" <<EOF
#!/usr/bin/env bash
load_checksums() {
    : > "$marker_file"
    return 0
}
EOF
    chmod +x "$repo_root/scripts/lib/security.sh"

    export ACFS_BIN_DIR="$repo_root/missing-bin"
    export ACFS_HOME="$repo_root/missing-home"
    export ACFS_REPO_ROOT="$repo_root"
    export CHECKSUMS_LOCAL="$repo_root/checksums.yaml"
    UPDATE_SECURITY_READY=false

    refresh_checksums() {
        return 0
    }

    run update_require_security
    assert_success
    [[ -f "$marker_file" ]]
}

@test "update_require_security: does not probe bogus repo path when ACFS_REPO_ROOT is unset" {
    export ACFS_BIN_DIR="$HOME/missing-bin"
    export ACFS_HOME="$HOME/missing-home"
    unset ACFS_REPO_ROOT
    export CHECKSUMS_LOCAL="$HOME/checksums.yaml"
    UPDATE_SECURITY_READY=false

    refresh_checksums() {
        return 0
    }

    run update_require_security
    assert_failure
    assert_output --partial "$ACFS_BIN_DIR/security.sh"
    assert_output --partial "$ACFS_HOME/scripts/lib/security.sh"
    refute_output --partial "    - /scripts/lib/security.sh"
}

@test "update_atuin: falls back to reinstall after failed self-update" {
    init_stub_dir
    export PATH="$STUB_DIR:$PATH"
    export ACFS_UPDATE_RETRY_MAX_ATTEMPTS=1
    export ACFS_UPDATE_RETRY_SLEEP_SECONDS=0
    QUIET=true
    VERBOSE=false
    DRY_RUN=false
    YES_MODE=false
    ABORT_ON_FAILURE=false
    UPDATE_LOG_FILE="$HOME/update.log"
    SUCCESS_COUNT=0
    FAIL_COUNT=0
    SKIP_COUNT=0

    cat > "$STUB_DIR/atuin" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  --help)
    echo "self-update"
    ;;
  self-update)
    echo "curl: (28) operation timed out" >&2
    exit 1
    ;;
  --version)
    echo "atuin 1.0.0"
    ;;
  *)
    echo "atuin 1.0.0"
    ;;
esac
EOF
    chmod +x "$STUB_DIR/atuin"

    update_require_security() {
        return 0
    }

    update_run_verified_installer() {
        : > "$HOME/atuin-reinstall-ran"
        return 0
    }

    update_atuin

    [[ -f "$HOME/atuin-reinstall-ran" ]]
    [[ "$SUCCESS_COUNT" -eq 1 ]]
    [[ "$FAIL_COUNT" -eq 0 ]]
}

@test "update_repair_atuin_install: normalizes custom and local shims" {
    export ACFS_BIN_DIR="$HOME/custom-bin"
    mkdir -p "$HOME/.atuin/bin"

    cat > "$HOME/.atuin/bin/atuin" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
  echo "atuin 18.14.1"
else
  echo "atuin 18.14.1"
fi
EOF
    chmod +x "$HOME/.atuin/bin/atuin"

    run update_repair_atuin_install
    assert_success

    [[ -L "$ACFS_BIN_DIR/atuin" ]]
    [[ -L "$HOME/.local/bin/atuin" ]]

    run readlink "$ACFS_BIN_DIR/atuin"
    assert_output "$HOME/.atuin/bin/atuin"

    run readlink "$HOME/.local/bin/atuin"
    assert_output "$HOME/.atuin/bin/atuin"
}

@test "acfs.zshrc: loads atuin env before atuin init" {
    local zshrc="$PROJECT_ROOT/acfs/zsh/acfs.zshrc"
    local env_line=""
    local init_line=""

    env_line="$(grep -nF 'source "$HOME/.atuin/bin/env"' "$zshrc" | cut -d: -f1)"
    init_line="$(grep -nF 'eval "$("$_ACFS_ATUIN_BIN" init zsh)"' "$zshrc" | cut -d: -f1)"

    [[ -n "$env_line" ]]
    [[ -n "$init_line" ]]
    (( env_line < init_line ))
}

@test "acfs.zshrc: resolves atuin binary once for init and bindings" {
    local zshrc="$PROJECT_ROOT/acfs/zsh/acfs.zshrc"

    run grep -F '_ACFS_ATUIN_BIN=""' "$zshrc"
    assert_success

    run grep -F 'eval "$("$_ACFS_ATUIN_BIN" init zsh)"' "$zshrc"
    assert_success

    run grep -F 'if [[ -n "$_ACFS_ATUIN_BIN" ]]; then' "$zshrc"
    assert_success
}

@test "sync_acfs_zsh_loader: removes duplicate local override sourcing" {
    cat > "$HOME/.zshrc" <<'EOF'
# ACFS loader
source "$HOME/.acfs/zsh/acfs.zshrc"

# User overrides live here forever
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
EOF

    run sync_acfs_zsh_loader
    assert_success

    run cat "$HOME/.zshrc"
    refute_output --partial '[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"'
    assert_output --partial 'source "$HOME/.acfs/zsh/acfs.zshrc"'
}

@test "sync_acfs_zsh_loader: leaves non-ACFS zshrc untouched" {
    cat > "$HOME/.zshrc" <<'EOF'
# custom zshrc
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
EOF

    run sync_acfs_zsh_loader
    assert_success

    run cat "$HOME/.zshrc"
    assert_output --partial '[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"'
    refute_output --partial 'source "$HOME/.acfs/zsh/acfs.zshrc"'
}

@test "sync_acfs_profile_paths: upgrades legacy ACFS login PATH line" {
    cat > "$HOME/.profile" <<'EOF'
# ~/.profile: executed by bash for login shells

# User binary paths
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.bun/bin:$PATH"
EOF

    run sync_acfs_profile_paths
    assert_success

    run cat "$HOME/.profile"
    assert_output --partial 'export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.bun/bin:$HOME/.atuin/bin:$PATH"'
    refute_output --partial 'export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.bun/bin:$PATH"'
}

@test "update_zoxide: retries transient reinstall failures before succeeding" {
    init_stub_dir
    export PATH="$STUB_DIR:$PATH"
    export ACFS_UPDATE_RETRY_MAX_ATTEMPTS=2
    export ACFS_UPDATE_RETRY_SLEEP_SECONDS=0
    QUIET=true
    VERBOSE=false
    DRY_RUN=false
    YES_MODE=false
    ABORT_ON_FAILURE=false
    UPDATE_LOG_FILE="$HOME/update.log"
    SUCCESS_COUNT=0
    FAIL_COUNT=0
    SKIP_COUNT=0

    cat > "$STUB_DIR/zoxide" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
  echo "zoxide 0.9.9"
else
  echo "zoxide 0.9.9"
fi
EOF
    chmod +x "$STUB_DIR/zoxide"

    update_require_security() {
        return 0
    }

    update_run_verified_installer() {
        local attempts_file="$HOME/zoxide-attempts"
        local attempts=0
        if [[ -f "$attempts_file" ]]; then
            attempts="$(cat "$attempts_file")"
        fi
        attempts=$((attempts + 1))
        printf '%s\n' "$attempts" > "$attempts_file"
        if [[ "$attempts" -lt 2 ]]; then
            echo "download failed: rate limit exceeded" >&2
            return 1
        fi
        return 0
    }

    update_zoxide

    [[ "$(cat "$HOME/zoxide-attempts")" == "2" ]]
    [[ "$SUCCESS_COUNT" -eq 1 ]]
    [[ "$FAIL_COUNT" -eq 0 ]]
}
