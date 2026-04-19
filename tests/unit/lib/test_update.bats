#!/usr/bin/env bats

load '../test_helper'

setup() {
    common_setup
    
    unset TARGET_USER TARGET_HOME ACFS_BIN_DIR ACFS_STATE_FILE ACFS_HOME

    # update.sh logic relies on being sourced or executed
    # We source it.
    # It has a guard at the end `if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then main "$@"; fi`
    # When sourced by bats, this guard prevents main.
    
    # Mock environment for update.sh
    export HOME=$(create_temp_dir)
    export TARGET_HOME="$HOME"
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

@test "get_version: prefers target runtime binaries when HOME differs" {
    local current_home
    local target_home
    current_home="$(create_temp_dir)"
    target_home="$(create_temp_dir)"

    export HOME="$current_home"
    export TARGET_USER="ubuntu"
    export TARGET_HOME="$target_home"
    unset ACFS_BIN_DIR
    unset ACFS_STATE_FILE
    unset ACFS_HOME

    mkdir -p "$current_home/.bun/bin" "$current_home/.cargo/bin" "$current_home/.local/bin"
    mkdir -p "$target_home/.bun/bin" "$target_home/.cargo/bin" "$target_home/.local/bin"

    cat > "$current_home/.bun/bin/bun" <<'EOF'
#!/usr/bin/env bash
echo "0.9.0"
EOF
    chmod +x "$current_home/.bun/bin/bun"

    cat > "$target_home/.bun/bin/bun" <<'EOF'
#!/usr/bin/env bash
echo "1.3.12"
EOF
    chmod +x "$target_home/.bun/bin/bun"

    cat > "$current_home/.cargo/bin/rustc" <<'EOF'
#!/usr/bin/env bash
echo "rustc 1.70.0 (old)"
EOF
    chmod +x "$current_home/.cargo/bin/rustc"

    cat > "$target_home/.cargo/bin/rustc" <<'EOF'
#!/usr/bin/env bash
echo "rustc 1.88.0 (target)"
EOF
    chmod +x "$target_home/.cargo/bin/rustc"

    cat > "$current_home/.local/bin/uv" <<'EOF'
#!/usr/bin/env bash
echo "uv 0.10.0"
EOF
    chmod +x "$current_home/.local/bin/uv"

    cat > "$target_home/.local/bin/uv" <<'EOF'
#!/usr/bin/env bash
echo "uv 0.11.6"
EOF
    chmod +x "$target_home/.local/bin/uv"

    run get_version "bun"
    assert_success
    assert_output "1.3.12"

    run get_version "rust"
    assert_success
    assert_output "1.88.0"

    run get_version "uv"
    assert_success
    assert_output "0.11.6"
}

@test "get_version: handles unknown" {
    run get_version "nonexistent"
    assert_output "unknown"
}

@test "update_target_home: ignores slash TARGET_HOME and uses passwd resolution" {
    local resolved_home
    resolved_home="$(create_temp_dir)"

    export TARGET_HOME="/"
    export HOME="/"

    update_getent_passwd_entry() {
        if [[ "${1:-}" == "tester" ]]; then
            printf 'tester:x:1000:1000::%s:/bin/bash\n' "$resolved_home"
            return 0
        fi
        return 2
    }

    run update_target_home "tester"
    assert_success
    assert_output "$resolved_home"
}

@test "update_target_home: ignores stale TARGET_HOME and uses passwd resolution" {
    local resolved_home
    local stale_home
    resolved_home="$(create_temp_dir)"
    stale_home="$BATS_TEST_TMPDIR/stale-target-home"

    export TARGET_HOME="$stale_home"
    export HOME="$stale_home"

    update_getent_passwd_entry() {
        if [[ "${1:-}" == "tester" ]]; then
            printf 'tester:x:1000:1000::%s:/bin/bash\n' "$resolved_home"
            return 0
        fi
        return 2
    }

    run update_target_home "tester"
    assert_success
    assert_output "$resolved_home"
}

@test "update_target_home: rejects invalid fallback usernames" {
    export TARGET_HOME="/"
    export HOME="/"

    getent() {
        return 2
    }

    run update_target_home "../bad-user"
    assert_failure
}

@test "update_target_home: fails closed when valid user home is unresolved" {
    export TARGET_HOME="/"
    export HOME="/"

    update_getent_passwd_entry() {
        return 2
    }

    run update_target_home "missinguser"
    assert_failure
}

@test "update.sh: sources under set -u without HOME" {
    local update="$PROJECT_ROOT/scripts/lib/update.sh"

    run env -i PATH="/usr/bin:/bin" bash -c 'set -euo pipefail; source "$1"; printf "home=%s\nlog=%s\n" "${HOME:-}" "$UPDATE_LOG_DIR"' _ "$update"
    assert_success
    refute_output --partial "unbound variable"
    assert_output --partial ".acfs/logs/updates"

    run grep -F 'if [[ -n "${HOME:-}" ]]; then' "$update"
    assert_success
}

@test "update_preferred_user_bin_dir: falls back to target home when HOME differs" {
    local current_home
    local target_home
    current_home="$(create_temp_dir)"
    target_home="$(create_temp_dir)"

    export HOME="$current_home"
    export TARGET_USER="ubuntu"
    export TARGET_HOME="$target_home"
    unset ACFS_BIN_DIR
    unset ACFS_STATE_FILE
    unset ACFS_HOME

    run update_preferred_user_bin_dir
    assert_success
    assert_output "$target_home/.local/bin"
}

@test "update_preferred_user_bin_dir: ignores relative ACFS_BIN_DIR and falls back to target home" {
    local current_home
    local target_home
    local cwd
    current_home="$(create_temp_dir)"
    target_home="$(create_temp_dir)"
    cwd="$(create_temp_dir)"

    mkdir -p "$cwd/relative/bin"

    export HOME="$current_home"
    export TARGET_USER="ubuntu"
    export TARGET_HOME="$target_home"
    export ACFS_BIN_DIR="relative/bin"
    unset ACFS_STATE_FILE
    unset ACFS_HOME

    pushd "$cwd" >/dev/null
    run update_preferred_user_bin_dir
    popd >/dev/null

    assert_success
    assert_output "$target_home/.local/bin"
}

@test "update_preferred_user_bin_dir: parses bin_dir from state without jq" {
    local current_home
    local target_home
    local state_file
    local fake_path
    local original_path="${PATH-}"
    current_home="$(create_temp_dir)"
    target_home="$(create_temp_dir)"
    state_file="$BATS_TEST_TMPDIR/update-state.json"
    fake_path="$(create_temp_dir)"

    cat > "$state_file" <<EOF
{"bin_dir":"$target_home/custom-bin"}
EOF

    ln -s /usr/bin/sed "$fake_path/sed"
    ln -s /usr/bin/head "$fake_path/head"

    export HOME="$current_home"
    export PATH="$fake_path"
    export TARGET_USER="ubuntu"
    export TARGET_HOME="$target_home"
    export ACFS_STATE_FILE="$state_file"
    unset ACFS_BIN_DIR
    unset ACFS_HOME

    run update_preferred_user_bin_dir
    PATH="${original_path:-/usr/bin:/bin}"
    assert_success
    assert_output "$target_home/custom-bin"
}

@test "update_preferred_user_bin_dir: does not fall back to current HOME for different unresolved target" {
    local current_home
    current_home="$(create_temp_dir)"

    export HOME="$current_home"
    export TARGET_USER="missinguser"
    export TARGET_HOME="/"
    unset ACFS_BIN_DIR
    unset ACFS_STATE_FILE
    unset ACFS_HOME

    getent() {
        return 2
    }

    run update_preferred_user_bin_dir
    assert_failure
}

@test "update_default_user_bin_dir: does not fall back to current HOME for different unresolved target" {
    local current_home
    current_home="$(create_temp_dir)"

    export HOME="$current_home"
    export TARGET_USER="missinguser"
    export TARGET_HOME="/"

    getent() {
        return 2
    }

    run update_default_user_bin_dir
    assert_failure
}

@test "update_binary_path: ignores current-shell-only PATH entries" {
    init_stub_dir

    local current_home
    local target_home
    local tool_name="acfs-test-update-tool"
    current_home="$(create_temp_dir)"
    target_home="$(create_temp_dir)"

    export HOME="$current_home"
    export TARGET_USER="ubuntu"
    export TARGET_HOME="$target_home"
    unset ACFS_BIN_DIR
    unset ACFS_STATE_FILE
    unset ACFS_HOME
    mkdir -p "$target_home/.local/bin"

    cat > "$STUB_DIR/$tool_name" <<'EOF'
#!/usr/bin/env bash
echo "current-shell-only"
EOF
    chmod +x "$STUB_DIR/$tool_name"
    export PATH="$STUB_DIR:/usr/bin:/bin"

    run update_binary_path "$tool_name"
    assert_failure

    cat > "$target_home/.local/bin/$tool_name" <<'EOF'
#!/usr/bin/env bash
echo "target-home"
EOF
    chmod +x "$target_home/.local/bin/$tool_name"

    run update_binary_path "$tool_name"
    assert_success
    assert_output "$target_home/.local/bin/$tool_name"
}

@test "update_binary_path: ignores relative ACFS_BIN_DIR shim when target bin exists" {
    local current_home
    local target_home
    local cwd
    current_home="$(create_temp_dir)"
    target_home="$(create_temp_dir)"
    cwd="$(create_temp_dir)"

    mkdir -p "$cwd/relative/bin" "$target_home/.local/bin"

    export HOME="$current_home"
    export TARGET_USER="ubuntu"
    export TARGET_HOME="$target_home"
    export ACFS_BIN_DIR="relative/bin"
    unset ACFS_STATE_FILE
    unset ACFS_HOME
    export PATH="/usr/bin:/bin"

    cat > "$cwd/relative/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "wrong-relative-gh"
EOF
    chmod +x "$cwd/relative/bin/gh"

    cat > "$target_home/.local/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "target-gh"
EOF
    chmod +x "$target_home/.local/bin/gh"

    pushd "$cwd" >/dev/null
    run update_binary_path "gh"
    popd >/dev/null

    assert_success
    assert_output "$target_home/.local/bin/gh"
}

@test "update_binary_path: finds target gcloud in google-cloud-sdk bin" {
    init_stub_dir

    local current_home
    local target_home
    current_home="$(create_temp_dir)"
    target_home="$(create_temp_dir)"

    export HOME="$current_home"
    export TARGET_USER="ubuntu"
    export TARGET_HOME="$target_home"
    unset ACFS_BIN_DIR
    unset ACFS_STATE_FILE
    unset ACFS_HOME
    mkdir -p "$target_home/google-cloud-sdk/bin"

    cat > "$STUB_DIR/gcloud" <<'EOF'
#!/usr/bin/env bash
echo "current-shell-gcloud"
EOF
    chmod +x "$STUB_DIR/gcloud"
    export PATH="$STUB_DIR:/usr/bin:/bin"

    cat > "$target_home/google-cloud-sdk/bin/gcloud" <<'EOF'
#!/usr/bin/env bash
echo "target-gcloud"
EOF
    chmod +x "$target_home/google-cloud-sdk/bin/gcloud"

    run update_binary_path "gcloud"
    assert_success
    assert_output "$target_home/google-cloud-sdk/bin/gcloud"
}

@test "update_binary_path: does not fall back to current HOME for different unresolved target" {
    local current_home
    current_home="$(create_temp_dir)"

    export HOME="$current_home"
    export TARGET_USER="missinguser"
    export TARGET_HOME="/"
    unset ACFS_BIN_DIR
    unset ACFS_STATE_FILE
    unset ACFS_HOME
    mkdir -p "$current_home/.local/bin"

    getent() {
        return 2
    }

    cat > "$current_home/.local/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "wrong-home-gh"
EOF
    chmod +x "$current_home/.local/bin/gh"

    run update_binary_path "gh"
    assert_failure
}

@test "update_tool_binary_path: prefers target atuin over current HOME" {
    local current_home
    local target_home
    current_home="$(create_temp_dir)"
    target_home="$(create_temp_dir)"

    export HOME="$current_home"
    export TARGET_USER="ubuntu"
    export TARGET_HOME="$target_home"
    unset ACFS_BIN_DIR
    unset ACFS_STATE_FILE
    unset ACFS_HOME
    mkdir -p "$current_home/.atuin/bin" "$target_home/.atuin/bin"

    cat > "$current_home/.atuin/bin/atuin" <<'EOF'
#!/usr/bin/env bash
echo "current-home"
EOF
    chmod +x "$current_home/.atuin/bin/atuin"

    cat > "$target_home/.atuin/bin/atuin" <<'EOF'
#!/usr/bin/env bash
echo "target-home"
EOF
    chmod +x "$target_home/.atuin/bin/atuin"

    run update_tool_binary_path "atuin"
    assert_success
    assert_output "$target_home/.atuin/bin/atuin"
}

@test "update_tool_binary_path: does not fall back to current HOME atuin for different unresolved target" {
    local current_home
    current_home="$(create_temp_dir)"

    export HOME="$current_home"
    export TARGET_USER="missinguser"
    export TARGET_HOME="/"
    unset ACFS_BIN_DIR
    unset ACFS_STATE_FILE
    unset ACFS_HOME
    mkdir -p "$current_home/.atuin/bin"

    getent() {
        return 2
    }

    cat > "$current_home/.atuin/bin/atuin" <<'EOF'
#!/usr/bin/env bash
echo "wrong-home-atuin"
EOF
    chmod +x "$current_home/.atuin/bin/atuin"

    run update_tool_binary_path "atuin"
    assert_failure
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

@test "update.sh: runtime resolver gates avoid inherited PATH leaks" {
    local update="$PROJECT_ROOT/scripts/lib/update.sh"

    run grep -F 'cargo_bin="$(update_binary_path cargo 2>/dev/null || true)"' "$update"
    assert_success

    run grep -F 'bun_bin="$(update_binary_path bun 2>/dev/null || true)"' "$update"
    assert_success

    run grep -F 'rustup_bin="$(update_binary_path rustup 2>/dev/null || true)"' "$update"
    assert_success

    run grep -F 'uv_bin="$(update_binary_path uv 2>/dev/null || true)"' "$update"
    assert_success

    run grep -F 'if ! update_binary_exists "$binary_name"; then' "$update"
    assert_success

    run grep -F 'update_run_in_target_context "" "$cargo_bin" install --git https://github.com/Dicklesworthstone/meta_skill --force' "$update"
    assert_success

    run grep -F 'run_cmd "DCG Hook" "$dcg_bin" install --force' "$update"
    assert_success

    run grep -F '"$target_home/.atuin/bin/atuin"' "$update"
    assert_success

    run rg -n '\$HOME/\.bun/bin/bun' "$update"
    assert_failure

    run grep -F 'command -v "$binary_name"' "$update"
    assert_failure
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
    assert_output --partial "$HOME/.acfs/scripts/lib/security.sh"
    refute_output --partial "$ACFS_HOME/scripts/lib/security.sh"
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

@test "update_repair_atuin_install: uses target atuin as shim source when HOME differs" {
    local current_home
    local target_home
    current_home="$(create_temp_dir)"
    target_home="$(create_temp_dir)"

    export HOME="$current_home"
    export TARGET_USER="ubuntu"
    export TARGET_HOME="$target_home"
    export ACFS_BIN_DIR="$target_home/custom-bin"
    mkdir -p "$current_home/.atuin/bin" "$target_home/.atuin/bin"

    cat > "$current_home/.atuin/bin/atuin" <<'EOF'
#!/usr/bin/env bash
echo "current-home"
EOF
    chmod +x "$current_home/.atuin/bin/atuin"

    cat > "$target_home/.atuin/bin/atuin" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
  echo "atuin 18.14.1"
else
  echo "target-home"
fi
EOF
    chmod +x "$target_home/.atuin/bin/atuin"

    run update_repair_atuin_install
    assert_success

    [[ -L "$ACFS_BIN_DIR/atuin" ]]
    [[ -L "$target_home/.local/bin/atuin" ]]

    run readlink "$ACFS_BIN_DIR/atuin"
    assert_output "$target_home/.atuin/bin/atuin"

    run readlink "$target_home/.local/bin/atuin"
    assert_output "$target_home/.atuin/bin/atuin"
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

@test "update_repair_atuin_install: does not repair from current HOME for different unresolved target" {
    local current_home
    current_home="$(create_temp_dir)"

    export HOME="$current_home"
    export TARGET_USER="missinguser"
    export TARGET_HOME="/"
    export ACFS_BIN_DIR="$current_home/custom-bin"
    mkdir -p "$current_home/.atuin/bin" "$ACFS_BIN_DIR"

    getent() {
        return 2
    }

    cat > "$current_home/.atuin/bin/atuin" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
  echo "atuin 18.14.1"
else
  echo "wrong-home-atuin"
fi
EOF
    chmod +x "$current_home/.atuin/bin/atuin"

    run update_repair_atuin_install
    assert_failure
    [[ ! -e "$ACFS_BIN_DIR/atuin" ]]
}

@test "update_repair_zoxide_install: normalizes custom shim to target local bin" {
    export ACFS_BIN_DIR="$HOME/custom-bin"
    mkdir -p "$HOME/.local/bin" "$ACFS_BIN_DIR"

    cat > "$HOME/.local/bin/zoxide" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
  echo "zoxide 0.9.9"
else
  echo "zoxide 0.9.9"
fi
EOF
    chmod +x "$HOME/.local/bin/zoxide"

    cat > "$ACFS_BIN_DIR/zoxide" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
  echo "zoxide 0.9.8"
else
  echo "stale-custom-copy"
fi
EOF
    chmod +x "$ACFS_BIN_DIR/zoxide"

    run update_repair_zoxide_install
    assert_success

    [[ -L "$ACFS_BIN_DIR/zoxide" ]]

    run readlink "$ACFS_BIN_DIR/zoxide"
    assert_output "$HOME/.local/bin/zoxide"
}

@test "install_atuin: does not skip target install because of a global atuin or partial target dir" {
    source_lib "cli_tools"
    init_stub_dir

    export PATH="$STUB_DIR:$PATH"
    export TARGET_USER="tester"
    export TARGET_HOME="$HOME/target-home"
    export ACFS_BIN_DIR="$TARGET_HOME/.local/bin"
    mkdir -p "$TARGET_HOME/.local/bin" "$TARGET_HOME/.atuin"

    cat > "$STUB_DIR/atuin" <<'EOF'
#!/usr/bin/env bash
echo "global atuin"
EOF
    chmod +x "$STUB_DIR/atuin"

    CLI_RUN_AS_USER_CALLS=0

    _cli_target_home() {
        printf '%s\n' "$TARGET_HOME"
    }

    _cli_require_security() {
        return 0
    }

    _cli_normalize_atuin_shims() {
        :
    }

    _cli_run_as_user() {
        CLI_RUN_AS_USER_CALLS=$((CLI_RUN_AS_USER_CALLS + 1))
        mkdir -p "$TARGET_HOME/.atuin/bin"
        cat > "$TARGET_HOME/.atuin/bin/atuin" <<'EOF'
#!/usr/bin/env bash
echo "atuin 18.14.1"
EOF
        chmod +x "$TARGET_HOME/.atuin/bin/atuin"
        return 0
    }

    declare -gA KNOWN_INSTALLERS=(["atuin"]="https://example.com")
    get_checksum() {
        echo "deadbeef"
    }

    install_atuin

    [[ "$CLI_RUN_AS_USER_CALLS" -eq 1 ]]
    [[ -x "$TARGET_HOME/.atuin/bin/atuin" ]]
}

@test "_cli_target_has_command: ignores current-shell-only PATH entries" {
    source_lib "cli_tools"
    init_stub_dir

    export PATH="$STUB_DIR:$PATH"
    export TARGET_USER="tester"
    export TARGET_HOME="$HOME/target-home"
    export ACFS_BIN_DIR="$TARGET_HOME/.local/bin"
    mkdir -p "$TARGET_HOME/.local/bin"

    cat > "$STUB_DIR/current-shell-only-tool" <<'EOF'
#!/usr/bin/env bash
echo "current shell only"
EOF
    chmod +x "$STUB_DIR/current-shell-only-tool"

    _cli_target_home() {
        printf '%s\n' "$TARGET_HOME"
    }

    run _cli_target_has_command "current-shell-only-tool"
    assert_failure
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

@test "sync_acfs_zprofile_paths: upgrades legacy ACFS zsh login PATH line" {
    cat > "$HOME/.zprofile" <<'EOF'
# ~/.zprofile: executed by zsh for login shells

# User binary paths
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.bun/bin:$PATH"
EOF

    run sync_acfs_zprofile_paths
    assert_success

    run cat "$HOME/.zprofile"
    assert_output --partial 'export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.bun/bin:$HOME/.atuin/bin:$PATH"'
    refute_output --partial 'export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.bun/bin:$PATH"'
}

@test "sync_acfs_profile_paths: respects TARGET_HOME when HOME differs" {
    local current_home
    local target_home
    current_home="$(create_temp_dir)"
    target_home="$(create_temp_dir)"

    export HOME="$current_home"
    export TARGET_USER="ubuntu"
    export TARGET_HOME="$target_home"

    cat > "$current_home/.profile" <<'EOF'
# current profile
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.bun/bin:$PATH"
EOF

    cat > "$target_home/.profile" <<'EOF'
# target profile
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.bun/bin:$PATH"
EOF

    run sync_acfs_profile_paths
    assert_success

    run cat "$target_home/.profile"
    assert_output --partial 'export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.bun/bin:$HOME/.atuin/bin:$PATH"'

    run cat "$current_home/.profile"
    refute_output --partial '.atuin/bin'
}

@test "sync_acfs_profile_paths: does not touch current HOME for unresolved explicit target" {
    local current_home
    current_home="$(create_temp_dir)"

    export HOME="$current_home"
    export TARGET_USER="missinguser"
    export TARGET_HOME="/"

    cat > "$current_home/.profile" <<'EOF'
# current profile
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.bun/bin:$PATH"
EOF

    getent() {
        return 2
    }

    run sync_acfs_profile_paths
    assert_success

    run cat "$current_home/.profile"
    refute_output --partial '.atuin/bin'
}

@test "sync_acfs_zprofile_paths: respects TARGET_HOME when HOME differs" {
    local current_home
    local target_home
    current_home="$(create_temp_dir)"
    target_home="$(create_temp_dir)"

    export HOME="$current_home"
    export TARGET_USER="ubuntu"
    export TARGET_HOME="$target_home"

    cat > "$current_home/.zprofile" <<'EOF'
# current zprofile
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.bun/bin:$PATH"
EOF

    cat > "$target_home/.zprofile" <<'EOF'
# target zprofile
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.bun/bin:$PATH"
EOF

    run sync_acfs_zprofile_paths
    assert_success

    run cat "$target_home/.zprofile"
    assert_output --partial 'export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.bun/bin:$HOME/.atuin/bin:$PATH"'

    run cat "$current_home/.zprofile"
    refute_output --partial '.atuin/bin'
}

@test "sync_acfs_zsh_loader: respects TARGET_HOME when HOME differs" {
    local current_home
    local target_home
    current_home="$(create_temp_dir)"
    target_home="$(create_temp_dir)"

    export HOME="$current_home"
    export TARGET_USER="ubuntu"
    export TARGET_HOME="$target_home"

    cat > "$current_home/.zshrc" <<'EOF'
# current zshrc
source "$HOME/.acfs/zsh/acfs.zshrc"
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
EOF

    cat > "$target_home/.zshrc" <<'EOF'
# target zshrc
source "$HOME/.acfs/zsh/acfs.zshrc"
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
EOF

    run sync_acfs_zsh_loader
    assert_success

    run cat "$target_home/.zshrc"
    refute_output --partial '[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"'

    run cat "$current_home/.zshrc"
    assert_output --partial '[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"'
}

@test "cleanup_legacy_git_safety_guard: respects TARGET_HOME when HOME differs" {
    local current_home
    local target_home
    current_home="$(create_temp_dir)"
    target_home="$(create_temp_dir)"

    export HOME="$current_home"
    export TARGET_USER="ubuntu"
    export TARGET_HOME="$target_home"

    mkdir -p "$current_home/.claude/hooks" "$target_home/.claude/hooks"
    printf 'current\n' > "$current_home/.claude/hooks/git_safety_guard.sh"
    printf 'target\n' > "$target_home/.claude/hooks/git_safety_guard.sh"

    run cleanup_legacy_git_safety_guard
    assert_success

    [[ -f "$current_home/.claude/hooks/git_safety_guard.sh" ]]
    [[ ! -e "$target_home/.claude/hooks/git_safety_guard.sh" ]]
}

@test "cleanup_legacy_bv_alias: respects TARGET_HOME when HOME differs" {
    local current_home
    local target_home
    current_home="$(create_temp_dir)"
    target_home="$(create_temp_dir)"

    export HOME="$current_home"
    export TARGET_USER="ubuntu"
    export TARGET_HOME="$target_home"

    cat > "$current_home/.zshrc.local" <<'EOF'
alias bv="current"
EOF

    cat > "$target_home/.zshrc.local" <<'EOF'
alias bv="target"
EOF

    run cleanup_legacy_bv_alias
    assert_success

    run cat "$current_home/.zshrc.local"
    assert_output --partial 'alias bv="current"'

    run cat "$target_home/.zshrc.local"
    refute_output --partial 'alias bv='
}

@test "cleanup_legacy_br_alias: respects TARGET_HOME when HOME differs" {
    local current_home
    local target_home
    current_home="$(create_temp_dir)"
    target_home="$(create_temp_dir)"

    export HOME="$current_home"
    export TARGET_USER="ubuntu"
    export TARGET_HOME="$target_home"

    mkdir -p "$current_home/.acfs/zsh" "$target_home/.acfs/zsh"
    cat > "$current_home/.acfs/zsh/acfs.zshrc" <<'EOF'
alias br='bun run dev'
EOF

    cat > "$target_home/.acfs/zsh/acfs.zshrc" <<'EOF'
alias br='bun run dev'
EOF

    run cleanup_legacy_br_alias
    assert_success

    run cat "$current_home/.acfs/zsh/acfs.zshrc"
    assert_output --partial "alias br='bun run dev'"

    run grep -n "^alias br='bun run dev'$" "$target_home/.acfs/zsh/acfs.zshrc"
    assert_failure

    run cat "$target_home/.acfs/zsh/acfs.zshrc"
    assert_output --partial "# alias br='bun run dev'"
}

@test "generated install_shell: uses minimal loader and Atuin-aware login paths" {
    local generated="$PROJECT_ROOT/scripts/generated/install_shell.sh"

    run grep -F 'echo '\''source "$HOME/.acfs/zsh/acfs.zshrc"'\'' >> ~/.zshrc' "$generated"
    assert_success

    run grep -F 'echo '\''[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"'\'' >> ~/.zshrc' "$generated"
    assert_failure

    run grep -F 'export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.bun/bin:$HOME/.atuin/bin:$PATH"' "$generated"
    assert_success
}

@test "generated install_cloud: preserves wrangler bun shim fallback" {
    local generated="$PROJECT_ROOT/scripts/generated/install_cloud.sh"

    run grep -F 'command -v node >/dev/null 2>&1' "$generated"
    assert_success

    run grep -F 'exec "$HOME/.bun/bin/bun" x wrangler@latest "$@"' "$generated"
    assert_success

    run grep -F 'acfs_install_executable_into_primary_bin "$wrapper_tmp" "wrangler"' "$generated"
    assert_success
}

@test "generated installers: reject invalid TARGET_HOME and ACFS_BIN_DIR" {
    local generated="$PROJECT_ROOT/scripts/generated/install_all.sh"
    local doctor_checks="$PROJECT_ROOT/scripts/generated/doctor_checks.sh"

    run grep -F '_acfs_validate_target_user "${TARGET_USER}" "TARGET_USER" || exit 1' "$generated"
    assert_success

    run grep -F '[[ "${TARGET_HOME}" == "/" ]]' "$generated"
    assert_success

    run grep -F "Invalid TARGET_HOME for '\${TARGET_USER}': \${TARGET_HOME:-<empty>} (must be an absolute path and cannot be '/')" "$generated"
    assert_success

    run grep -F '[[ "${HOME}" != "/" ]]' "$generated"
    assert_success

    run grep -F 'TARGET_HOME="${HOME%/}"' "$generated"
    assert_success

    run grep -F "ACFS_BIN_DIR must be an absolute path and cannot be '/' (got: \${ACFS_BIN_DIR:-<empty>})" "$generated"
    assert_success

    run grep -F "Invalid TARGET_HOME for '\$target_user': \${target_home:-<empty>} (must be an absolute path and cannot be '/')" "$doctor_checks"
    assert_success

    run grep -F '[[ "${HOME}" != "/" ]]' "$doctor_checks"
    assert_success

    run grep -F 'target_home="${HOME%/}"' "$doctor_checks"
    assert_success

    run grep -F '_acfs_validate_target_user "$target_user" "TARGET_USER" || return 1' "$doctor_checks"
    assert_success

    run grep -F "ACFS_BIN_DIR must be an absolute path and cannot be '/' (got: \${target_bin:-<empty>})" "$doctor_checks"
    assert_success
}

@test "scripts/lib/zsh.sh: mirrors Atuin-aware login PATH setup" {
    local zsh_lib="$PROJECT_ROOT/scripts/lib/zsh.sh"

    run grep -F 'local user_zprofile="$HOME/.zprofile"' "$zsh_lib"
    assert_success

    run grep -F 'export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.bun/bin:$HOME/.atuin/bin:$PATH"' "$zsh_lib"
    assert_success

    run grep -F '# ACFS loader — user overrides go in ~/.zshrc.local (sourced by acfs.zshrc)' "$zsh_lib"
    assert_success
}

@test "scripts/lib/zsh.sh: resolves shell user via trusted helpers" {
    local zsh_lib="$PROJECT_ROOT/scripts/lib/zsh.sh"

    run grep -F 'current_user="$(zsh_resolve_current_user 2>/dev/null || true)"' "$zsh_lib"
    assert_success

    run grep -F 'passwd_entry="$(zsh_getent_passwd_entry "$current_user" 2>/dev/null || true)"' "$zsh_lib"
    assert_success

    run grep -F 'if zsh_is_externally_managed_user "$current_user"; then' "$zsh_lib"
    assert_success

    run grep -F '$SUDO "$chsh_path" -s "$zsh_path" "$current_user"' "$zsh_lib"
    assert_success

    run grep -F 'getent passwd "$(whoami)"' "$zsh_lib"
    assert_failure
}

@test "scripts/preflight.sh: resolves identity and passwd data via trusted helpers" {
    local preflight="$PROJECT_ROOT/scripts/preflight.sh"

    run grep -F 'id_bin="$(preflight_system_binary_path id 2>/dev/null || true)"' "$preflight"
    assert_success

    run grep -F 'whoami_bin="$(preflight_system_binary_path whoami 2>/dev/null || true)"' "$preflight"
    assert_success

    run grep -F 'done < <(preflight_getent_passwd_entry 2>/dev/null || true)' "$preflight"
    assert_success

    run grep -F 'passwd_entry="$(preflight_getent_passwd_entry "$user" 2>/dev/null || true)"' "$preflight"
    assert_success

    run grep -F 'current_user="$(id -un 2>/dev/null || whoami 2>/dev/null || true)"' "$preflight"
    assert_failure

    run grep -F 'getent passwd "$user"' "$preflight"
    assert_failure
}

@test "scripts/lib/smoke_test.sh: validates bin dirs via trusted passwd helpers" {
    local smoke_lib="$PROJECT_ROOT/scripts/lib/smoke_test.sh"

    run grep -F 'if [[ -z "$user" ]]; then' "$smoke_lib"
    assert_success

    run grep -F 'done < <(_smoke_getent_passwd_entry 2>/dev/null || true)' "$smoke_lib"
    assert_success

    run grep -F 'done < <(getent passwd 2>/dev/null || true)' "$smoke_lib"
    assert_failure
}

@test "scripts/lib/github_api.sh: validates bin dirs via trusted passwd helpers" {
    local github_api="$PROJECT_ROOT/scripts/lib/github_api.sh"

    run grep -F '_github_api_system_binary_path() {' "$github_api"
    assert_success

    run grep -F '_github_api_getent_passwd_entry() {' "$github_api"
    assert_success

    run grep -F 'done < <(_github_api_getent_passwd_entry 2>/dev/null || true)' "$github_api"
    assert_success

    run grep -F 'done < <(getent passwd 2>/dev/null || true)' "$github_api"
    assert_failure
}

@test "services-setup and wrappers parse passwd homes via helpers" {
    local services_setup="$PROJECT_ROOT/scripts/services-setup.sh"
    local update_wrapper="$PROJECT_ROOT/scripts/acfs-update"
    local global_wrapper="$PROJECT_ROOT/scripts/acfs-global"

    run grep -F 'services_setup_passwd_home_from_entry() {' "$services_setup"
    assert_success

    run grep -F 'home="$(services_setup_passwd_home_from_entry "$passwd_entry" 2>/dev/null || true)"' "$services_setup"
    assert_success

    run grep -F 'done < <(services_setup_getent_passwd_entry 2>/dev/null || true)' "$services_setup"
    assert_success

    run grep -F 'cut -d: -f6' "$services_setup"
    assert_failure

    run grep -F 'awk -F: -v u=' "$services_setup"
    assert_failure

    run grep -F 'done < <(getent_passwd_entry 2>/dev/null || true)' "$update_wrapper"
    assert_success

    run grep -F 'done < <(getent_passwd_entry 2>/dev/null || true)' "$global_wrapper"
    assert_success

    run grep -F 'cut -d: -f6' "$update_wrapper"
    assert_failure

    run grep -F 'cut -d: -f6' "$global_wrapper"
    assert_failure
}

@test "auxiliary libs parse passwd homes via helpers" {
    local support="$PROJECT_ROOT/scripts/lib/support.sh"
    local status_lib="$PROJECT_ROOT/scripts/lib/status.sh"
    local info="$PROJECT_ROOT/scripts/lib/info.sh"
    local dashboard="$PROJECT_ROOT/scripts/lib/dashboard.sh"
    local export_config="$PROJECT_ROOT/scripts/lib/export-config.sh"
    local cheatsheet="$PROJECT_ROOT/scripts/lib/cheatsheet.sh"
    local continue_lib="$PROJECT_ROOT/scripts/lib/continue.sh"
    local changelog_lib="$PROJECT_ROOT/scripts/lib/changelog.sh"
    local notifications_lib="$PROJECT_ROOT/scripts/lib/notifications.sh"
    local notify_lib="$PROJECT_ROOT/scripts/lib/notify.sh"
    local webhook_lib="$PROJECT_ROOT/scripts/lib/webhook.sh"
    local agents_lib="$PROJECT_ROOT/scripts/lib/agents.sh"
    local cli_tools_lib="$PROJECT_ROOT/scripts/lib/cli_tools.sh"
    local languages_lib="$PROJECT_ROOT/scripts/lib/languages.sh"
    local cloud_db_lib="$PROJECT_ROOT/scripts/lib/cloud_db.sh"
    local stack_lib="$PROJECT_ROOT/scripts/lib/stack.sh"
    local doctor_lib="$PROJECT_ROOT/scripts/lib/doctor.sh"
    local doctor_fix_lib="$PROJECT_ROOT/scripts/lib/doctor_fix.sh"
    local user_lib="$PROJECT_ROOT/scripts/lib/user.sh"

    run grep -F 'support_passwd_home_from_entry() {' "$support"
    assert_success

    run grep -F 'done < <(support_getent_passwd_entry 2>/dev/null || true)' "$support"
    assert_success

    run grep -F '_status_passwd_home_from_entry() {' "$status_lib"
    assert_success

    run grep -F 'done < <(_status_getent_passwd_entry 2>/dev/null || true)' "$status_lib"
    assert_success

    run grep -F 'info_passwd_home_from_entry() {' "$info"
    assert_success

    run grep -F 'done < <(info_getent_passwd_entry 2>/dev/null || true)' "$info"
    assert_success

    run grep -F 'dashboard_passwd_home_from_entry() {' "$dashboard"
    assert_success

    run grep -F 'done < <(dashboard_getent_passwd_entry 2>/dev/null || true)' "$dashboard"
    assert_success

    run grep -F 'export_passwd_home_from_entry() {' "$export_config"
    assert_success

    run grep -F 'done < <(export_getent_passwd_entry 2>/dev/null || true)' "$export_config"
    assert_success

    run grep -F 'cheatsheet_passwd_home_from_entry() {' "$cheatsheet"
    assert_success

    run grep -F 'done < <(cheatsheet_getent_passwd_entry 2>/dev/null || true)' "$cheatsheet"
    assert_success

    run grep -F 'continue_passwd_home_from_entry() {' "$continue_lib"
    assert_success

    run grep -F 'continue_passwd_home_from_entry "$passwd_entry" 2>/dev/null || true' "$continue_lib"
    assert_success

    run grep -F 'changelog_passwd_home_from_entry() {' "$changelog_lib"
    assert_success

    run grep -F 'changelog_passwd_home_from_entry "$passwd_entry" 2>/dev/null || true' "$changelog_lib"
    assert_success

    run grep -F 'notifications_passwd_home_from_entry() {' "$notifications_lib"
    assert_success

    run grep -F 'notifications_passwd_home_from_entry "$passwd_entry" 2>/dev/null || true' "$notifications_lib"
    assert_success

    run grep -F '_acfs_notify_passwd_home_from_entry() {' "$notify_lib"
    assert_success

    run grep -F '_acfs_notify_passwd_home_from_entry "$passwd_entry" 2>/dev/null || true' "$notify_lib"
    assert_success

    run grep -F 'webhook_passwd_home_from_entry() {' "$webhook_lib"
    assert_success

    run grep -F 'webhook_passwd_home_from_entry "$passwd_entry" 2>/dev/null || true' "$webhook_lib"
    assert_success

    run grep -F '_agent_passwd_home_from_entry() {' "$agents_lib"
    assert_success

    run grep -F 'done < <(_agent_getent_passwd_entry 2>/dev/null || true)' "$agents_lib"
    assert_success

    run grep -F '_cli_passwd_home_from_entry() {' "$cli_tools_lib"
    assert_success

    run grep -F 'done < <(_cli_getent_passwd_entry 2>/dev/null || true)' "$cli_tools_lib"
    assert_success

    run grep -F '_lang_passwd_home_from_entry() {' "$languages_lib"
    assert_success

    run grep -F '_lang_passwd_home_from_entry "$passwd_entry" 2>/dev/null || true' "$languages_lib"
    assert_success

    run grep -F '_cloud_passwd_home_from_entry() {' "$cloud_db_lib"
    assert_success

    run grep -F '_cloud_passwd_home_from_entry "$passwd_entry" 2>/dev/null || true' "$cloud_db_lib"
    assert_success

    run grep -F '_stack_passwd_home_from_entry() {' "$stack_lib"
    assert_success

    run grep -F '_stack_passwd_home_from_entry "$passwd_entry" 2>/dev/null || true' "$stack_lib"
    assert_success

    run grep -F '_acfs_doctor_passwd_home_from_entry() {' "$doctor_lib"
    assert_success

    run grep -F '_acfs_doctor_passwd_home_from_entry "$passwd_entry" 2>/dev/null || true' "$doctor_lib"
    assert_success

    run grep -F 'doctor_fix_passwd_home_from_entry() {' "$doctor_fix_lib"
    assert_success

    run grep -F 'doctor_fix_passwd_home_from_entry "$passwd_entry" 2>/dev/null || true' "$doctor_fix_lib"
    assert_success

    run grep -F 'user_passwd_home_from_entry() {' "$user_lib"
    assert_success

    run grep -F 'user_passwd_home_from_entry "$passwd_entry" 2>/dev/null || true' "$user_lib"
    assert_success

    run rg -n 'cut -d: -f6' "$support" "$status_lib" "$info" "$dashboard" "$export_config" "$cheatsheet" "$continue_lib" "$changelog_lib" "$notifications_lib" "$notify_lib" "$webhook_lib" "$agents_lib" "$cli_tools_lib" "$languages_lib" "$cloud_db_lib" "$stack_lib" "$doctor_lib" "$doctor_fix_lib" "$user_lib"
    assert_failure

    run rg -n 'awk -F: -v u=|awk -F: -v user=' "$doctor_lib" "$doctor_fix_lib" "$user_lib"
    assert_failure
}

@test "services-setup: probes custom and ACFS bin dirs for target-user commands" {
    local services_setup="$PROJECT_ROOT/scripts/services-setup.sh"
    local preflight="$PROJECT_ROOT/scripts/preflight.sh"

    run grep -F "services_setup_validate_target_user() {" "$services_setup"
    assert_success

    run grep -F 'services_setup_validate_target_user "$TARGET_USER" || return 1' "$services_setup"
    assert_success

    run grep -F 'local target_path_prefix="$primary_bin_dir:$TARGET_HOME/.local/bin:$TARGET_HOME/.acfs/bin:$TARGET_HOME/.cargo/bin:$TARGET_HOME/.bun/bin:$TARGET_HOME/.atuin/bin:$TARGET_HOME/go/bin"' "$services_setup"
    assert_success

    run grep -F 'run_as_user env ACFS_TARGET_PATH_PREFIX="$target_path_prefix" bash -c' "$services_setup"
    assert_success

    run grep -F '"$TARGET_HOME/.acfs/bin/$name"' "$services_setup"
    assert_success

    run grep -F "printf '/home/%s\n' \"\$current_user\"" "$services_setup"
    assert_failure

    run grep -F "printf '/home/%s' \"\$user\"" "$services_setup"
    assert_failure

    run grep -F "printf '/home/%s\n' \"\$current_user\"" "$preflight"
    assert_failure

    run grep -F "printf '/home/%s\n' \"\$target_user\"" "$preflight"
    assert_failure
}

@test "services-setup: run_as_user ignores function-poisoned whoami on same-user fast path" {
    local services_setup="$PROJECT_ROOT/scripts/services-setup.sh"
    local current_user
    local current_home

    current_user="$(command id -un 2>/dev/null || command whoami 2>/dev/null || true)"
    if [[ "$current_user" == "root" ]]; then
        current_home="/root"
    else
        current_home="$(command getent passwd "$current_user" | cut -d: -f6)"
    fi
    current_home="${current_home%/}"
    mkdir -p "$current_home/.local/bin"

    eval "$(sed -n '/^services_setup_sanitize_abs_nonroot_path()/,/^}$/p' "$services_setup")"
    eval "$(sed -n '/^services_setup_valid_target_user()/,/^}$/p' "$services_setup")"
    eval "$(sed -n '/^services_setup_validate_target_user()/,/^}$/p' "$services_setup")"
    eval "$(sed -n '/^services_setup_system_binary_path()/,/^}$/p' "$services_setup")"
    eval "$(sed -n '/^services_setup_getent_passwd_entry()/,/^}$/p' "$services_setup")"
    eval "$(sed -n '/^services_setup_validate_bin_dir_for_home()/,/^}$/p' "$services_setup")"
    eval "$(sed -n '/^services_setup_resolve_current_user()/,/^}$/p' "$services_setup")"
    eval "$(sed -n '/^run_as_user()/,/^}$/p' "$services_setup")"

    export TARGET_USER="$current_user"
    export TARGET_HOME="$current_home"
    export HOME="$current_home"
    export ACFS_BIN_DIR="$current_home/.local/bin"

    whoami() {
        printf 'poisoned-user\n'
    }

    sudo() {
        echo 'sudo should not run' >&2
        return 1
    }

    run run_as_user bash -c 'printf "%s\n" "$HOME"'
    assert_success
    assert_output "$current_home"
}

@test "services-setup: init_target_context repairs stale TARGET_HOME from trusted passwd data" {
    local services_setup="$PROJECT_ROOT/scripts/services-setup.sh"
    local test_current_user
    local test_trusted_home
    local test_stale_home
    local stale_bun
    local trusted_bun
    local env_home_output

    test_current_user="$(command id -un 2>/dev/null || command whoami 2>/dev/null || true)"
    test_trusted_home="$(create_temp_dir)"
    test_stale_home="$(create_temp_dir)"
    stale_bun="$test_stale_home/.local/bin/bun"
    trusted_bun="$test_trusted_home/.local/bin/bun"
    mkdir -p "$test_trusted_home/.local/bin" "$test_stale_home/.local/bin"
    touch "$stale_bun" "$trusted_bun"
    chmod +x "$stale_bun" "$trusted_bun"

    eval "$(sed -n '/^services_setup_sanitize_abs_nonroot_path()/,/^}$/p' "$services_setup")"
    eval "$(sed -n '/^services_setup_valid_target_user()/,/^}$/p' "$services_setup")"
    eval "$(sed -n '/^services_setup_validate_target_user()/,/^}$/p' "$services_setup")"
    eval "$(sed -n '/^services_setup_passwd_home_from_entry()/,/^}$/p' "$services_setup")"
    eval "$(sed -n '/^resolve_home_dir()/,/^}$/p' "$services_setup")"
    eval "$(sed -n '/^services_setup_validate_bin_dir_for_home()/,/^}$/p' "$services_setup")"
    eval "$(sed -n '/^find_user_bin()/,/^}$/p' "$services_setup")"
    eval "$(sed -n '/^init_target_context()/,/^}$/p' "$services_setup")"
    eval "$(sed -n '/^run_as_user()/,/^}$/p' "$services_setup")"

    log_error() {
        printf '%s\n' "$*" >&2
    }

    services_setup_resolve_current_user() {
        printf '%s\n' "$test_current_user"
    }

    services_setup_getent_passwd_entry() {
        if [[ -z "${1:-}" ]]; then
            printf '%s:x:1000:1000::%s:/bin/bash\n' "$test_current_user" "$test_trusted_home"
            printf 'stale-user:x:1001:1001::%s:/bin/bash\n' "$test_stale_home"
            return 0
        fi
        if [[ "${1:-}" == "$test_current_user" ]]; then
            printf '%s:x:1000:1000::%s:/bin/bash\n' "$test_current_user" "$test_trusted_home"
            return 0
        fi
        return 1
    }

    export TARGET_USER="$test_current_user"
    export TARGET_HOME="$test_stale_home"
    export HOME="$test_stale_home"
    export ACFS_BIN_DIR="$test_stale_home/.local/bin"
    export BUN_BIN="$stale_bun"

    init_target_context

    [[ "$TARGET_HOME" == "$test_trusted_home" ]] || {
        printf 'TARGET_HOME was not repaired: %s\n' "$TARGET_HOME" >&2
        return 1
    }
    [[ "$ACFS_BIN_DIR" != "$test_stale_home/.local/bin" ]] || {
        printf 'ACFS_BIN_DIR still points at stale home\n' >&2
        return 1
    }
    [[ "$BUN_BIN" == "$trusted_bun" ]] || {
        printf 'BUN_BIN was not repaired: %s\n' "$BUN_BIN" >&2
        return 1
    }

    env_home_output="$(run_as_user bash -c 'printf "%s\n" "$HOME"')"
    [[ "$env_home_output" == "$test_trusted_home" ]] || {
        printf 'run_as_user HOME was not repaired: %s\n' "$env_home_output" >&2
        return 1
    }
}

@test "diagnostic helpers: prepend primary ACFS bin dir and ~/.acfs/bin" {
    local doctor="$PROJECT_ROOT/scripts/lib/doctor.sh"
    local info="$PROJECT_ROOT/scripts/lib/info.sh"
    local status_lib="$PROJECT_ROOT/scripts/lib/status.sh"
    local export_config="$PROJECT_ROOT/scripts/lib/export-config.sh"
    local smoke="$PROJECT_ROOT/scripts/lib/smoke_test.sh"
    local update="$PROJECT_ROOT/scripts/lib/update.sh"

    run grep -F 'local system_path_prefix="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin"' "$doctor"
    assert_success
    run grep -F 'local current_path="${PATH:-$system_path_prefix}"' "$doctor"
    assert_success
    run grep -F 'local seen_path=":$current_path:"' "$doctor"
    assert_success
    run grep -F 'seen_path="${seen_path}${dir}:"' "$doctor"
    assert_success
    run grep -F 'local primary_bin_dir="${ACFS_BIN_DIR:-$primary_home/.local/bin}"' "$doctor"
    assert_success
    run grep -F 'target_path="$target_path_prefix${PATH:+:$PATH}"' "$doctor"
    assert_success
    run grep -F 'local -a target_path_entries=()' "$doctor"
    assert_success
    run grep -F '"$_acfs_doctor_current_home/google-cloud-sdk/bin"' "$doctor"
    assert_success
    run grep -F "Invalid TARGET_USER '\${target_user:-<empty>}' (expected: lowercase user name like 'ubuntu')" "$doctor"
    assert_success
    run grep -F 'target_home="/home/$target_user"' "$doctor"
    assert_failure
    run grep -F 'sudo -n env TARGET_USER="$target_user" PATH="$system_path_prefix" bash -o pipefail -c "$cmd"' "$doctor"
    assert_success
    run grep -F 'export PATH="$prefix${current_path:+:$current_path}"' "$doctor"
    assert_success

    run grep -F 'update_sanitize_abs_nonroot_path() {' "$update"
    assert_success
    run grep -F 'local system_path_prefix="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin"' "$update"
    assert_success
    run grep -F 'local current_path="${PATH:-$system_path_prefix}"' "$update"
    assert_success
    run grep -F 'local seen_path=":$current_path:"' "$update"
    assert_success
    run grep -F 'sanitized_primary_bin="$(update_validate_bin_dir_for_home "${ACFS_BIN_DIR:-}" "${HOME:-}" 2>/dev/null || true)"' "$update"
    assert_success
    run grep -F '$HOME/google-cloud-sdk/bin' "$update"
    assert_success
    run grep -F '$target_home/google-cloud-sdk/bin/$tool' "$update"
    assert_success
    run grep -F 'path_prefix=$(IFS=:; echo "${path_entries[*]}")' "$update"
    assert_success
    run grep -F 'local current_state_file=""' "$update"
    assert_success
    run grep -F 'local acfs_home_state_file=""' "$update"
    assert_success
    run grep -F 'local target_state_file=""' "$update"
    assert_success
    run grep -F 'local explicit_bin_dir=""' "$update"
    assert_success
    run grep -F 'local explicit_state_file=""' "$update"
    assert_success
    run grep -F 'local sanitized_acfs_home=""' "$update"
    assert_success
    run grep -F '$current_state_file' "$update"
    assert_success
    run grep -F 'explicit_bin_dir="$(update_validate_bin_dir_for_home "${ACFS_BIN_DIR:-}" "$target_home" 2>/dev/null || true)"' "$update"
    assert_success
    run grep -F 'explicit_state_file="$(update_sanitize_abs_nonroot_path "${ACFS_STATE_FILE:-}" 2>/dev/null || true)"' "$update"
    assert_success
    run grep -F 'sanitized_acfs_home="$(update_sanitize_abs_nonroot_path "${ACFS_HOME:-}" 2>/dev/null || true)"' "$update"
    assert_success
    run grep -F 'user_bin="$(update_default_user_bin_dir 2>/dev/null || true)"' "$update"
    assert_success
    run grep -F 'local -a candidates=()' "$update"
    assert_success
    run grep -F 'configured_bin="$(update_validate_bin_dir_for_home "${ACFS_BIN_DIR:-}" "$target_home" 2>/dev/null || true)"' "$update"
    assert_success
    run grep -F '[[ -n "$target_home" ]] && preferred_src="$target_home/.atuin/bin/atuin"' "$update"
    assert_success
    run grep -F "printf '/home/%s\n'" "$update"
    assert_failure
    run grep -F '$HOME/.atuin/bin/atuin' "$update"
    assert_failure
    run grep -F "printf '%s\n' \"\$HOME/.local/bin\"" "$update"
    assert_failure
    run grep -F '"${ACFS_HOME:-}/state.json"' "$update"
    assert_failure
    run grep -F 'target_state_file="$target_home/.acfs/state.json"' "$update"
    assert_success
    run grep -F 'export PATH="$prefix${current_path:+:$current_path}"' "$update"
    assert_success
    run grep -F 'export PATH="${prefix}:$PATH"' "$update"
    assert_failure

    run grep -F 'primary_bin_dir="$(info_preferred_bin_dir "$base_home" 2>/dev/null || true)"' "$info"
    assert_success
    run grep -F '[[ -n "$primary_bin_dir" ]] || primary_bin_dir="$base_home/.local/bin"' "$info"
    assert_success
    run grep -F '"$base_home/.acfs/bin"' "$info"
    assert_success

    run grep -F 'primary_bin_dir="$(_status_preferred_bin_dir "$base_home" 2>/dev/null || true)"' "$status_lib"
    assert_success
    run grep -F '[[ -n "$primary_bin_dir" ]] || primary_bin_dir="$base_home/.local/bin"' "$status_lib"
    assert_success
    run grep -F '"$base_home/.acfs/bin"' "$status_lib"
    assert_success

    run grep -F 'local primary_bin_dir="${ACFS_BIN_DIR:-$target_home/.local/bin}"' "$export_config"
    assert_success
    run grep -F '"$target_home/.acfs/bin"' "$export_config"
    assert_success

    run grep -F '_smoke_prepend_user_paths "$_SMOKE_TARGET_HOME"' "$smoke"
    assert_success
    run grep -F 'primary_bin_dir="$(_smoke_preferred_bin_dir "$base_home" 2>/dev/null || true)"' "$smoke"
    assert_success
    run grep -F '[[ -n "$primary_bin_dir" ]] || primary_bin_dir="$base_home/.local/bin"' "$smoke"
    assert_success

    run grep -F '"$HOME/.acfs/bin"' "$update"
    assert_success
}

@test "wrappers and nightly update sanitize invalid path env" {
    local nightly="$PROJECT_ROOT/scripts/lib/nightly_update.sh"
    local global_wrapper="$PROJECT_ROOT/scripts/acfs-global"
    local update_wrapper="$PROJECT_ROOT/scripts/acfs-update"

    run grep -F 'sanitize_abs_nonroot_path()' "$nightly"
    assert_success
    run grep -F 'HOME="$(resolve_current_home)" || {' "$nightly"
    assert_success
    run grep -F 'ACFS_STATE_FILE="$(sanitize_abs_nonroot_path "${ACFS_STATE_FILE:-}" 2>/dev/null || true)"' "$nightly"
    assert_success
    run grep -F 'ACFS_SYSTEM_STATE_FILE="$(sanitize_abs_nonroot_path "${ACFS_SYSTEM_STATE_FILE:-/var/lib/acfs/state.json}" 2>/dev/null || true)"' "$nightly"
    assert_success
    run grep -F 'ACFS_BIN_DIR="$(sanitize_abs_nonroot_path "${ACFS_BIN_DIR:-}" 2>/dev/null || true)"' "$nightly"
    assert_success

    run grep -F 'sanitize_abs_nonroot_path()' "$global_wrapper"
    assert_success
    run grep -F 'resolve_current_home()' "$global_wrapper"
    assert_success
    run grep -F 'ACFS_STATE_FILE="$(sanitize_abs_nonroot_path "${ACFS_STATE_FILE:-}" 2>/dev/null || true)"' "$global_wrapper"
    assert_success
    run grep -F 'ACFS_SYSTEM_STATE_FILE="$(sanitize_abs_nonroot_path "${ACFS_SYSTEM_STATE_FILE:-}" 2>/dev/null || true)"' "$global_wrapper"
    assert_success
    run grep -F 'ACFS_BIN_DIR="$(sanitize_abs_nonroot_path "${ACFS_BIN_DIR:-}" 2>/dev/null || true)"' "$global_wrapper"
    assert_success
    run grep -F 'state_bin_dir="$(read_validated_bin_dir_from_state_file "$ACFS_STATE_FILE" "$runtime_target_home" 2>/dev/null || true)"' "$global_wrapper"
    assert_success
    run grep -F 'ACFS_BIN_DIR="${state_bin_dir:-}"' "$global_wrapper"
    assert_success
    run grep -F 'current_home="$(resolve_current_home 2>/dev/null || true)"' "$global_wrapper"
    assert_success
    run grep -F '[[ -n "$sanitized_state_file" ]] && env_args+=("ACFS_STATE_FILE=$sanitized_state_file")' "$global_wrapper"
    assert_success
    run grep -F '[[ -n "$sanitized_system_state_file" ]] && env_args+=("ACFS_SYSTEM_STATE_FILE=$sanitized_system_state_file")' "$global_wrapper"
    assert_success
    run grep -F '[[ -n "$sanitized_target_home" ]] && env_args+=("HOME=$sanitized_target_home" "TARGET_HOME=$sanitized_target_home")' "$global_wrapper"
    assert_success

    run grep -F 'sanitize_abs_nonroot_path()' "$update_wrapper"
    assert_success
    run grep -F 'resolve_current_home()' "$update_wrapper"
    assert_success
    run grep -F 'ACFS_STATE_FILE="$(sanitize_abs_nonroot_path "${ACFS_STATE_FILE:-}" 2>/dev/null || true)"' "$update_wrapper"
    assert_success
    run grep -F 'ACFS_SYSTEM_STATE_FILE="$(sanitize_abs_nonroot_path "${ACFS_SYSTEM_STATE_FILE:-}" 2>/dev/null || true)"' "$update_wrapper"
    assert_success
    run grep -F 'ACFS_BIN_DIR="$(sanitize_abs_nonroot_path "${ACFS_BIN_DIR:-}" 2>/dev/null || true)"' "$update_wrapper"
    assert_success
    run grep -F 'state_bin_dir="$(read_validated_bin_dir_from_state_file "$ACFS_STATE_FILE" "$runtime_target_home" 2>/dev/null || true)"' "$update_wrapper"
    assert_success
    run grep -F 'ACFS_BIN_DIR="${state_bin_dir:-}"' "$update_wrapper"
    assert_success
    run grep -F 'current_home="$(resolve_current_home 2>/dev/null || true)"' "$update_wrapper"
    assert_success
    run grep -F '[[ -n "$sanitized_state_file" ]] && env_args+=("ACFS_STATE_FILE=$sanitized_state_file")' "$update_wrapper"
    assert_success
    run grep -F '[[ -n "$sanitized_system_state_file" ]] && env_args+=("ACFS_SYSTEM_STATE_FILE=$sanitized_system_state_file")' "$update_wrapper"
    assert_success
    run grep -F '[[ -n "$sanitized_target_home" ]] && env_args+=("HOME=$sanitized_target_home" "TARGET_HOME=$sanitized_target_home")' "$update_wrapper"
    assert_success
}

setup_nightly_update_identity_stubs() {
    init_stub_dir

    cat > "$STUB_DIR/id" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    cat > "$STUB_DIR/getent" <<'EOF'
#!/usr/bin/env bash
exit 2
EOF
    chmod +x "$STUB_DIR/id" "$STUB_DIR/getent"
    printf '%s\n' "$STUB_DIR:/usr/bin:/bin"
}

@test "nightly update honors explicit system state and repairs target runtime home" {
    local nightly="$PROJECT_ROOT/scripts/lib/nightly_update.sh"
    local nightly_path
    local root_home
    local target_home
    local system_state

    root_home="$(create_temp_dir)"
    target_home="$(create_temp_dir)"
    system_state="$root_home/system-state.json"

    mkdir -p \
        "$root_home/.acfs/scripts/lib" \
        "$target_home/.acfs/scripts/lib" \
        "$target_home/.acfs/logs/updates" \
        "$target_home/.local/bin"

    cat > "$root_home/.acfs/scripts/lib/notify.sh" <<'EOF'
acfs_notify_update_success() { :; }
acfs_notify_update_failure() { :; }
EOF
    cat > "$target_home/.acfs/scripts/lib/notify.sh" <<'EOF'
acfs_notify_update_success() { :; }
acfs_notify_update_failure() { :; }
EOF
    cat > "$system_state" <<EOF
{
  "target_home": "$target_home",
  "bin_dir": "$target_home/.local/bin"
}
EOF
    cat > "$target_home/.local/bin/acfs-update" <<'EOF'
#!/usr/bin/env bash
printf 'CHILD_HOME=%s TARGET_HOME=%s ACFS_HOME=%s\n' "$HOME" "${TARGET_HOME:-}" "${ACFS_HOME:-}"
EOF
    chmod +x "$target_home/.local/bin/acfs-update"

    nightly_path="$(setup_nightly_update_identity_stubs)"
    run env -i PATH="$nightly_path" HOME="$root_home" ACFS_SYSTEM_STATE_FILE="$system_state" bash "$nightly"

    assert_success
    assert_output --partial "Running: $target_home/.local/bin/acfs-update --yes --quiet --no-self-update"
    assert_output --partial "CHILD_HOME=$target_home TARGET_HOME=$target_home ACFS_HOME=$target_home/.acfs"
    [[ -f "$target_home/.acfs/logs/updates/nightly-2025-01-01.log" ]]
}

@test "nightly update prefers live target-home updater over stale persisted bin dir" {
    local nightly="$PROJECT_ROOT/scripts/lib/nightly_update.sh"
    local nightly_path
    local root_home
    local target_home
    local stale_home
    local system_state

    root_home="$(create_temp_dir)"
    target_home="$(create_temp_dir)"
    stale_home="$(create_temp_dir)"
    system_state="$root_home/system-state.json"

    mkdir -p         "$root_home/.acfs/scripts/lib"         "$target_home/.acfs/bin"         "$target_home/.acfs/scripts/lib"         "$target_home/.acfs/logs/updates"         "$stale_home/.local/bin"

    cat > "$root_home/.acfs/scripts/lib/notify.sh" <<'EOF'
acfs_notify_update_success() { :; }
acfs_notify_update_failure() { :; }
EOF
    cat > "$target_home/.acfs/scripts/lib/notify.sh" <<'EOF'
acfs_notify_update_success() { :; }
acfs_notify_update_failure() { :; }
EOF
    cat > "$system_state" <<EOF
{
  "target_home": "$target_home",
  "bin_dir": "$stale_home/.local/bin"
}
EOF
    cat > "$target_home/.acfs/bin/acfs-update" <<'EOF'
#!/usr/bin/env bash
printf 'LIVE_HOME=%s TARGET_HOME=%s ACFS_HOME=%s\n' "$HOME" "${TARGET_HOME:-}" "${ACFS_HOME:-}"
EOF
    cat > "$stale_home/.local/bin/acfs-update" <<'EOF'
#!/usr/bin/env bash
printf 'STALE_HOME=%s TARGET_HOME=%s ACFS_HOME=%s\n' "$HOME" "${TARGET_HOME:-}" "${ACFS_HOME:-}"
EOF
    chmod +x "$target_home/.acfs/bin/acfs-update" "$stale_home/.local/bin/acfs-update"

    nightly_path="$(setup_nightly_update_identity_stubs)"
    run env -i PATH="$nightly_path" HOME="$root_home" ACFS_SYSTEM_STATE_FILE="$system_state" bash "$nightly"

    assert_success
    assert_output --partial "Running: $target_home/.acfs/bin/acfs-update --yes --quiet --no-self-update"
    refute_output --partial "STALE_HOME="
    assert_output --partial "LIVE_HOME=$target_home TARGET_HOME=$target_home ACFS_HOME=$target_home/.acfs"
    [[ -f "$target_home/.acfs/logs/updates/nightly-2025-01-01.log" ]]
}

@test "nightly update falls back to target home binaries when system state omits bin dir" {
    local nightly="$PROJECT_ROOT/scripts/lib/nightly_update.sh"
    local nightly_path
    local root_home
    local target_home
    local system_state

    root_home="$(create_temp_dir)"
    target_home="$(create_temp_dir)"
    system_state="$root_home/system-state.json"

    mkdir -p \
        "$root_home/.acfs/scripts/lib" \
        "$target_home/.acfs/bin" \
        "$target_home/.acfs/scripts/lib" \
        "$target_home/.acfs/logs/updates"

    cat > "$root_home/.acfs/scripts/lib/notify.sh" <<'EOF'
acfs_notify_update_success() { :; }
acfs_notify_update_failure() { :; }
EOF
    cat > "$target_home/.acfs/scripts/lib/notify.sh" <<'EOF'
acfs_notify_update_success() { :; }
acfs_notify_update_failure() { :; }
EOF
    cat > "$system_state" <<EOF
{
  "target_home": "$target_home"
}
EOF
    cat > "$target_home/.acfs/bin/acfs-update" <<'EOF'
#!/usr/bin/env bash
printf 'CHILD_HOME=%s TARGET_HOME=%s ACFS_HOME=%s\n' "$HOME" "${TARGET_HOME:-}" "${ACFS_HOME:-}"
EOF
    chmod +x "$target_home/.acfs/bin/acfs-update"

    nightly_path="$(setup_nightly_update_identity_stubs)"
    run env -i PATH="$nightly_path" HOME="$root_home" ACFS_SYSTEM_STATE_FILE="$system_state" bash "$nightly"

    assert_success
    assert_output --partial "Running: $target_home/.acfs/bin/acfs-update --yes --quiet --no-self-update"
    assert_output --partial "CHILD_HOME=$target_home TARGET_HOME=$target_home ACFS_HOME=$target_home/.acfs"
    [[ -f "$target_home/.acfs/logs/updates/nightly-2025-01-01.log" ]]
}

@test "nightly update honors explicit TARGET_HOME over stale system state" {
    local nightly="$PROJECT_ROOT/scripts/lib/nightly_update.sh"
    local nightly_path
    local root_home
    local target_home
    local stale_home
    local system_state

    root_home="$(create_temp_dir)"
    target_home="$(create_temp_dir)"
    stale_home="$(create_temp_dir)"
    system_state="$root_home/system-state.json"

    mkdir -p         "$root_home/.acfs/scripts/lib"         "$target_home/.acfs/scripts/lib"         "$target_home/.acfs/logs/updates"         "$target_home/.local/bin"         "$stale_home/.acfs/scripts/lib"         "$stale_home/.acfs/logs/updates"         "$stale_home/.local/bin"

    cat > "$root_home/.acfs/scripts/lib/notify.sh" <<'EOF'
acfs_notify_update_success() { :; }
acfs_notify_update_failure() { :; }
EOF
    cat > "$target_home/.acfs/scripts/lib/notify.sh" <<'EOF'
acfs_notify_update_success() { :; }
acfs_notify_update_failure() { :; }
EOF
    cat > "$stale_home/.acfs/scripts/lib/notify.sh" <<'EOF'
acfs_notify_update_success() { :; }
acfs_notify_update_failure() { :; }
EOF
    cat > "$system_state" <<EOF
{
  "target_home": "$stale_home",
  "bin_dir": "$stale_home/.local/bin"
}
EOF
    cat > "$target_home/.local/bin/acfs-update" <<'EOF'
#!/usr/bin/env bash
printf 'LIVE_NIGHTLY HOME=%s TARGET_HOME=%s ACFS_HOME=%s\n' "$HOME" "${TARGET_HOME:-}" "${ACFS_HOME:-}"
EOF
    cat > "$stale_home/.local/bin/acfs-update" <<'EOF'
#!/usr/bin/env bash
printf 'STALE_NIGHTLY HOME=%s TARGET_HOME=%s ACFS_HOME=%s\n' "$HOME" "${TARGET_HOME:-}" "${ACFS_HOME:-}"
EOF
    chmod +x "$target_home/.local/bin/acfs-update" "$stale_home/.local/bin/acfs-update"

    nightly_path="$(setup_nightly_update_identity_stubs)"
    run env -i PATH="$nightly_path" HOME="$root_home" TARGET_HOME="$target_home" ACFS_SYSTEM_STATE_FILE="$system_state" bash "$nightly"

    assert_success
    assert_output --partial "Running: $target_home/.local/bin/acfs-update --yes --quiet --no-self-update"
    refute_output --partial "STALE_NIGHTLY"
    assert_output --partial "LIVE_NIGHTLY HOME=$target_home TARGET_HOME=$target_home ACFS_HOME=$target_home/.acfs"
    [[ -f "$target_home/.acfs/logs/updates/nightly-2025-01-01.log" ]]
}

@test "acfs-update wrapper honors explicit TARGET_HOME over stale system state" {
    local update_wrapper="$PROJECT_ROOT/scripts/acfs-update"
    local wrapper_dir
    local root_home
    local target_home
    local stale_home
    local system_state
    local current_user

    wrapper_dir="$(create_temp_dir)"
    root_home="$(create_temp_dir)"
    target_home="$(create_temp_dir)"
    stale_home="$(create_temp_dir)"
    system_state="$BATS_TEST_TMPDIR/update-wrapper-system-state.json"
    current_user="$(id -un 2>/dev/null || whoami 2>/dev/null || true)"

    mkdir -p "$target_home/.acfs/scripts/lib" "$stale_home/.acfs/scripts/lib"
    cp "$update_wrapper" "$wrapper_dir/acfs-update"
    chmod +x "$wrapper_dir/acfs-update"

    cat > "$target_home/.acfs/scripts/lib/update.sh" <<'EOF'
#!/usr/bin/env bash
printf 'LIVE_SCRIPT HOME=%s TARGET_HOME=%s ACFS_HOME=%s\n' "$HOME" "${TARGET_HOME:-}" "${ACFS_HOME:-}"
EOF
    cat > "$stale_home/.acfs/scripts/lib/update.sh" <<'EOF'
#!/usr/bin/env bash
printf 'STALE_SCRIPT HOME=%s TARGET_HOME=%s ACFS_HOME=%s\n' "$HOME" "${TARGET_HOME:-}" "${ACFS_HOME:-}"
EOF
    chmod +x "$target_home/.acfs/scripts/lib/update.sh" "$stale_home/.acfs/scripts/lib/update.sh"

    cat > "$system_state" <<EOF
{
  "target_user": "$current_user",
  "target_home": "$stale_home"
}
EOF

    run env HOME="$root_home" TARGET_HOME="$target_home" ACFS_SYSTEM_STATE_FILE="$system_state" bash "$wrapper_dir/acfs-update"

    assert_success
    refute_output --partial "STALE_SCRIPT"
    assert_output --partial "LIVE_SCRIPT HOME=$target_home TARGET_HOME=$target_home ACFS_HOME=$target_home/.acfs"
}

@test "acfs global wrapper honors explicit TARGET_HOME over stale system state" {
    local global_wrapper="$PROJECT_ROOT/scripts/acfs-global"
    local wrapper_dir
    local root_home
    local target_home
    local stale_home
    local system_state
    local current_user

    wrapper_dir="$(create_temp_dir)"
    root_home="$(create_temp_dir)"
    target_home="$(create_temp_dir)"
    stale_home="$(create_temp_dir)"
    system_state="$BATS_TEST_TMPDIR/global-wrapper-system-state.json"
    current_user="$(id -un 2>/dev/null || whoami 2>/dev/null || true)"

    mkdir -p "$target_home/.local/bin" "$target_home/.acfs" "$stale_home/.local/bin" "$stale_home/.acfs"
    cp "$global_wrapper" "$wrapper_dir/acfs"
    chmod +x "$wrapper_dir/acfs"

    cat > "$target_home/.local/bin/acfs" <<'EOF'
#!/usr/bin/env bash
printf 'LIVE_ACFS HOME=%s TARGET_HOME=%s ACFS_HOME=%s\n' "$HOME" "${TARGET_HOME:-}" "${ACFS_HOME:-}"
EOF
    cat > "$stale_home/.local/bin/acfs" <<'EOF'
#!/usr/bin/env bash
printf 'STALE_ACFS HOME=%s TARGET_HOME=%s ACFS_HOME=%s\n' "$HOME" "${TARGET_HOME:-}" "${ACFS_HOME:-}"
EOF
    chmod +x "$target_home/.local/bin/acfs" "$stale_home/.local/bin/acfs"

    cat > "$system_state" <<EOF
{
  "target_user": "$current_user",
  "target_home": "$stale_home"
}
EOF

    run env HOME="$root_home" TARGET_HOME="$target_home" ACFS_SYSTEM_STATE_FILE="$system_state" bash "$wrapper_dir/acfs"

    assert_success
    refute_output --partial "STALE_ACFS"
    assert_output --partial "LIVE_ACFS HOME=$target_home TARGET_HOME=$target_home ACFS_HOME=$target_home/.acfs"
}

@test "ACFS home resolvers honor explicit TARGET_HOME over stale system state" {
    local current_home
    local target_home
    local stale_home
    local system_state
    local label
    local script
    local func
    local expected

    current_home="$(create_temp_dir)"
    target_home="$(create_temp_dir)"
    stale_home="$(create_temp_dir)"
    system_state="$BATS_TEST_TMPDIR/resolver-system-state.json"

    mkdir -p "$current_home" "$target_home/.acfs" "$stale_home/.acfs"
    printf 'live\n' > "$target_home/.acfs/VERSION"
    printf 'stale\n' > "$stale_home/.acfs/VERSION"
    printf '{}\n' > "$target_home/.acfs/state.json"
    printf '{}\n' > "$stale_home/.acfs/state.json"
    printf '# live\n' > "$target_home/.acfs/CHANGELOG.md"
    printf '# stale\n' > "$stale_home/.acfs/CHANGELOG.md"

    cat > "$system_state" <<EOF
{
  "target_home": "$stale_home"
}
EOF

    while IFS='|' read -r label script func expected; do
        run env -i PATH="/usr/bin:/bin" HOME="$current_home" TARGET_HOME="$target_home" ACFS_SYSTEM_STATE_FILE="$system_state" bash -c 'source "$1" >/dev/null 2>&1; func="$2"; "$func"' _ "$script" "$func"
        assert_success
        assert_output "$expected"
    done <<EOF
status|$PROJECT_ROOT/scripts/lib/status.sh|_status_resolve_acfs_home|$target_home/.acfs
dashboard|$PROJECT_ROOT/scripts/lib/dashboard.sh|dashboard_resolve_acfs_home|$target_home/.acfs
export-config|$PROJECT_ROOT/scripts/lib/export-config.sh|resolve_acfs_home|$target_home/.acfs
support|$PROJECT_ROOT/scripts/lib/support.sh|support_resolve_acfs_home|$target_home/.acfs
cheatsheet|$PROJECT_ROOT/scripts/lib/cheatsheet.sh|cheatsheet_resolve_acfs_home|$target_home/.acfs
continue|$PROJECT_ROOT/scripts/lib/continue.sh|get_install_state_file|$target_home/.acfs/state.json
changelog|$PROJECT_ROOT/scripts/lib/changelog.sh|resolve_changelog_acfs_home|$target_home/.acfs
EOF
}

@test "target home resolvers honor explicit TARGET_HOME over stale system state" {
    local current_home
    local target_home
    local stale_home
    local system_state
    local label
    local script
    local func

    current_home="$(create_temp_dir)"
    target_home="$(create_temp_dir)"
    stale_home="$(create_temp_dir)"
    system_state="$BATS_TEST_TMPDIR/target-home-resolver-system-state.json"

    mkdir -p "$current_home" "$target_home/.acfs" "$stale_home/.acfs"
    printf '{}\n' > "$target_home/.acfs/state.json"
    printf '{}\n' > "$stale_home/.acfs/state.json"

    cat > "$system_state" <<EOF
{
  "target_home": "$stale_home"
}
EOF

    while IFS='|' read -r label script func; do
        run env -i PATH="/usr/bin:/bin" HOME="$current_home" TARGET_HOME="$target_home" ACFS_SYSTEM_STATE_FILE="$system_state" bash -c 'source "$1" >/dev/null 2>&1; func="$2"; "$func" "$3"' _ "$script" "$func" "$target_home/.acfs/state.json"
        assert_success
        assert_output "$target_home"
    done <<EOF
status|$PROJECT_ROOT/scripts/lib/status.sh|_status_resolve_target_home
export-config|$PROJECT_ROOT/scripts/lib/export-config.sh|resolve_target_home
support|$PROJECT_ROOT/scripts/lib/support.sh|support_resolve_target_home
info|$PROJECT_ROOT/scripts/lib/info.sh|info_resolve_target_home
EOF
}

@test "context builders and info paths honor explicit TARGET_HOME over stale system state" {
    local current_home
    local target_home
    local stale_home
    local system_state

    current_home="$(create_temp_dir)"
    target_home="$(create_temp_dir)"
    stale_home="$(create_temp_dir)"
    system_state="$BATS_TEST_TMPDIR/context-builder-system-state.json"

    mkdir -p "$current_home" "$target_home/.acfs" "$stale_home/.acfs"
    printf 'live\n' > "$target_home/.acfs/VERSION"
    printf 'stale\n' > "$stale_home/.acfs/VERSION"
    printf '{}\n' > "$target_home/.acfs/state.json"
    printf '{}\n' > "$stale_home/.acfs/state.json"

    cat > "$system_state" <<EOF
{
  "target_home": "$stale_home"
}
EOF

    run env -i PATH="/usr/bin:/bin" HOME="$current_home" TARGET_HOME="$target_home" ACFS_SYSTEM_STATE_FILE="$system_state" bash -c 'source "$1" >/dev/null 2>&1; printf "data_home=%s\nstate_file=%s\ntarget_home=%s\n" "$(info_get_data_home 2>/dev/null || true)" "$(info_get_install_state_file 2>/dev/null || true)" "$(info_resolve_target_home "$(info_get_install_state_file 2>/dev/null || true)" 2>/dev/null || true)"' _ "$PROJECT_ROOT/scripts/lib/info.sh"
    assert_success
    assert_output --partial "data_home=$target_home/.acfs"
    assert_output --partial "state_file=$target_home/.acfs/state.json"
    assert_output --partial "target_home=$target_home"

    run env -i PATH="/usr/bin:/bin" HOME="$current_home" TARGET_HOME="$target_home" ACFS_SYSTEM_STATE_FILE="$system_state" bash -c 'source "$1" >/dev/null 2>&1; dashboard_prepare_context >/dev/null 2>&1; printf "%s\n" "${_DASHBOARD_RESOLVED_TARGET_HOME:-}"' _ "$PROJECT_ROOT/scripts/lib/dashboard.sh"
    assert_success
    assert_output "$target_home"

    run env -i PATH="/usr/bin:/bin" HOME="$current_home" TARGET_HOME="$target_home" ACFS_SYSTEM_STATE_FILE="$system_state" bash -c 'source "$1" >/dev/null 2>&1; support_initialize_context >/dev/null 2>&1; printf "%s\n" "${SUPPORT_TARGET_HOME:-}"' _ "$PROJECT_ROOT/scripts/lib/support.sh"
    assert_success
    assert_output "$target_home"

    run env -i PATH="/usr/bin:/bin" HOME="$current_home" TARGET_HOME="$target_home" ACFS_SYSTEM_STATE_FILE="$system_state" bash -c 'source "$1" >/dev/null 2>&1; cheatsheet_prepare_context >/dev/null 2>&1; printf "%s\n" "${_CHEATSHEET_RESOLVED_TARGET_HOME:-}"' _ "$PROJECT_ROOT/scripts/lib/cheatsheet.sh"
    assert_success
    assert_output "$target_home"
}

@test "home-to-user helpers ignore PATH-poisoned id/whoami/getent shims" {
    local current_user
    local current_home
    local fake_home
    local fake_bin
    local label
    local script
    local func
    local current_home_var

    current_user="$(id -un 2>/dev/null || whoami 2>/dev/null || true)"
    if [[ "$current_user" == "root" ]]; then
        current_home="/root"
    else
        current_home="$(getent passwd "$current_user" | cut -d: -f6)"
    fi
    current_home="${current_home%/}"

    fake_home="$(create_temp_dir)"
    fake_bin="$BATS_TEST_TMPDIR/path-poison-bin"
    mkdir -p "$fake_home/.local/bin" "$fake_bin"

    cat > "$fake_bin/id" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "-un" ]]; then
    printf 'poisoned-user\n'
    exit 0
fi
exit 2
EOF
    cat > "$fake_bin/whoami" <<'EOF'
#!/usr/bin/env bash
printf 'poisoned-user\n'
EOF
    cat > "$fake_bin/getent" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "passwd" ]]; then
    printf 'poisoned-user:x:1000:1000::%s:/bin/bash\n' "$fake_home"
    exit 0
fi
exit 2
EOF
    chmod +x "$fake_bin/id" "$fake_bin/whoami" "$fake_bin/getent"

    while IFS='|' read -r label script func current_home_var; do
        run env -i PATH="$fake_bin:/usr/bin:/bin" HOME="$fake_home" bash -s -- "$script" "$label" "$func" "$current_home" "$current_home_var" <<'EOF_HELPER'
script="$1"
label="$2"
func="$3"
current_home="$4"
current_home_var="$5"
case "$label" in
    status)
        eval "$(sed -n "/^_status_sanitize_abs_nonroot_path()/,/^}$/p" "$script")"
        eval "$(sed -n "/^_status_system_binary_path()/,/^}$/p" "$script")"
        eval "$(sed -n "/^_status_resolve_current_user()/,/^}$/p" "$script")"
        eval "$(sed -n "/^_status_read_user_for_home()/,/^}$/p" "$script")"
        ;;
    support)
        eval "$(sed -n "/^support_sanitize_abs_nonroot_path()/,/^}$/p" "$script")"
        eval "$(sed -n "/^support_system_binary_path()/,/^}$/p" "$script")"
        eval "$(sed -n "/^support_resolve_current_user()/,/^}$/p" "$script")"
        eval "$(sed -n "/^support_read_user_for_home()/,/^}$/p" "$script")"
        ;;
    info)
        eval "$(sed -n "/^info_sanitize_abs_nonroot_path()/,/^}$/p" "$script")"
        eval "$(sed -n "/^info_system_binary_path()/,/^}$/p" "$script")"
        eval "$(sed -n "/^info_resolve_current_user()/,/^}$/p" "$script")"
        eval "$(sed -n "/^info_read_user_for_home()/,/^}$/p" "$script")"
        ;;
    export-config)
        eval "$(sed -n "/^export_sanitize_abs_nonroot_path()/,/^}$/p" "$script")"
        eval "$(sed -n "/^export_system_binary_path()/,/^}$/p" "$script")"
        eval "$(sed -n "/^export_resolve_current_user()/,/^}$/p" "$script")"
        eval "$(sed -n "/^read_user_for_home()/,/^}$/p" "$script")"
        ;;
    dashboard)
        eval "$(sed -n "/^dashboard_sanitize_abs_nonroot_path()/,/^}$/p" "$script")"
        eval "$(sed -n "/^dashboard_system_binary_path()/,/^}$/p" "$script")"
        eval "$(sed -n "/^dashboard_resolve_current_user()/,/^}$/p" "$script")"
        eval "$(sed -n "/^dashboard_read_user_for_home()/,/^}$/p" "$script")"
        ;;
    cheatsheet)
        eval "$(sed -n "/^cheatsheet_sanitize_abs_nonroot_path()/,/^}$/p" "$script")"
        eval "$(sed -n "/^cheatsheet_system_binary_path()/,/^}$/p" "$script")"
        eval "$(sed -n "/^cheatsheet_resolve_current_user()/,/^}$/p" "$script")"
        eval "$(sed -n "/^cheatsheet_read_user_for_home()/,/^}$/p" "$script")"
        ;;
esac
export "$current_home_var=$current_home"
"$func" "$current_home"
EOF_HELPER
        assert_success
        assert_output "$current_user"
    done <<EOF
status|$PROJECT_ROOT/scripts/lib/status.sh|_status_read_user_for_home|_STATUS_CURRENT_HOME
support|$PROJECT_ROOT/scripts/lib/support.sh|support_read_user_for_home|_SUPPORT_CURRENT_HOME
info|$PROJECT_ROOT/scripts/lib/info.sh|info_read_user_for_home|_INFO_CURRENT_HOME
export-config|$PROJECT_ROOT/scripts/lib/export-config.sh|read_user_for_home|_EXPORT_CURRENT_HOME
dashboard|$PROJECT_ROOT/scripts/lib/dashboard.sh|dashboard_read_user_for_home|_DASHBOARD_CURRENT_HOME
cheatsheet|$PROJECT_ROOT/scripts/lib/cheatsheet.sh|cheatsheet_read_user_for_home|_CHEATSHEET_CURRENT_HOME
EOF
}

@test "bin-dir validators ignore PATH-poisoned getent passwd streams" {
    local current_user
    local current_home
    local fake_home
    local fake_bin
    local fake_bin_dir
    local label
    local script
    local func

    current_user="$(id -un 2>/dev/null || whoami 2>/dev/null || true)"
    if [[ "$current_user" == "root" ]]; then
        current_home="/root"
    else
        current_home="$(getent passwd "$current_user" | cut -d: -f6)"
    fi
    current_home="${current_home%/}"

    fake_home="$(create_temp_dir)"
    fake_bin_dir="$current_home/.local/bin"
    fake_bin="$BATS_TEST_TMPDIR/validate-path-poison-bin"
    mkdir -p "$fake_bin"

    cat > "$fake_bin/getent" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "passwd" ]]; then
    printf 'poisoned-user:x:1000:1000::%s:/bin/bash\n' "$fake_home"
    exit 0
fi
exit 2
EOF
    chmod +x "$fake_bin/getent"

    while IFS='|' read -r label script func; do
        run env -i PATH="$fake_bin:/usr/bin:/bin" HOME="$current_home" bash -s -- "$script" "$label" "$func" "$fake_bin_dir" "$current_home" <<'EOF_VALIDATOR'
script="$1"
label="$2"
func="$3"
fake_bin_dir="$4"
current_home="$5"
case "$label" in
    status)
        eval "$(sed -n "/^_status_sanitize_abs_nonroot_path()/,/^}$/p" "$script")"
        eval "$(sed -n "/^_status_system_binary_path()/,/^}$/p" "$script")"
        eval "$(sed -n "/^_status_validate_bin_dir_for_home()/,/^}$/p" "$script")"
        ;;
    info)
        eval "$(sed -n "/^info_sanitize_abs_nonroot_path()/,/^}$/p" "$script")"
        eval "$(sed -n "/^info_system_binary_path()/,/^}$/p" "$script")"
        eval "$(sed -n "/^info_validate_bin_dir_for_home()/,/^}$/p" "$script")"
        ;;
    export-config)
        eval "$(sed -n "/^export_sanitize_abs_nonroot_path()/,/^}$/p" "$script")"
        eval "$(sed -n "/^export_system_binary_path()/,/^}$/p" "$script")"
        eval "$(sed -n "/^export_validate_bin_dir_for_home()/,/^}$/p" "$script")"
        ;;
    cheatsheet)
        eval "$(sed -n "/^cheatsheet_sanitize_abs_nonroot_path()/,/^}$/p" "$script")"
        eval "$(sed -n "/^cheatsheet_system_binary_path()/,/^}$/p" "$script")"
        eval "$(sed -n "/^cheatsheet_validate_bin_dir_for_home()/,/^}$/p" "$script")"
        ;;
esac
"$func" "$fake_bin_dir" "$current_home"
EOF_VALIDATOR
        assert_success
        assert_output "$fake_bin_dir"
    done <<EOF
status|$PROJECT_ROOT/scripts/lib/status.sh|_status_validate_bin_dir_for_home
info|$PROJECT_ROOT/scripts/lib/info.sh|info_validate_bin_dir_for_home
export-config|$PROJECT_ROOT/scripts/lib/export-config.sh|export_validate_bin_dir_for_home
cheatsheet|$PROJECT_ROOT/scripts/lib/cheatsheet.sh|cheatsheet_validate_bin_dir_for_home
EOF
}


@test "continue state-file scan ignores PATH-poisoned getent output" {
    local safe_home
    local poisoned_home
    local safe_bin
    local poison_bin

    safe_home="$(create_temp_dir)"
    poisoned_home="$(create_temp_dir)"
    safe_bin="$BATS_TEST_TMPDIR/continue-safe-bin"
    poison_bin="$BATS_TEST_TMPDIR/continue-poison-bin"

    mkdir -p "$safe_home/.acfs" "$poisoned_home/.acfs" "$safe_bin" "$poison_bin"
    printf '{}\n' > "$safe_home/.acfs/state.json"
    printf '{}\n' > "$poisoned_home/.acfs/state.json"

    cat > "$safe_bin/getent" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "passwd" ]]; then
    printf 'safe-user:x:1000:1000::%s:/bin/bash\n' "$safe_home"
    exit 0
fi
exit 2
EOF
    cat > "$poison_bin/getent" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "passwd" ]]; then
    printf 'poisoned-user:x:1000:1000::%s:/bin/bash\n' "$poisoned_home"
    exit 0
fi
exit 2
EOF
    chmod +x "$safe_bin/getent" "$poison_bin/getent"

    run env -i PATH="$poison_bin:/usr/bin:/bin" SAFE_BIN="$safe_bin" bash -s -- "$PROJECT_ROOT/scripts/lib/continue.sh" <<'EOF_CONTINUE_SCAN'
script="$1"
eval "$(sed -n "/^find_scanned_install_state_file()/,/^}$/p" "$script")"
continue_system_binary_path() {
    local name="${1:-}"
    [[ "$name" == "getent" ]] || return 1
    printf '%s\n' "$SAFE_BIN/getent"
}
find_scanned_install_state_file
EOF_CONTINUE_SCAN
    assert_success
    assert_output "$safe_home/.acfs/state.json"
}

@test "support environment summary ignores PATH-poisoned whoami fallback" {
    local current_user
    local current_home
    local fake_bin
    local bundle_dir
    local acfs_home
    local jq_real

    jq_real="$(command -v jq 2>/dev/null || true)"
    [[ -n "$jq_real" ]] || skip "jq required"

    current_user="$(id -un 2>/dev/null || whoami 2>/dev/null || true)"
    if [[ "$current_user" == "root" ]]; then
        current_home="/root"
    else
        current_home="$(getent passwd "$current_user" | cut -d: -f6)"
    fi
    current_home="${current_home%/}"

    fake_bin="$BATS_TEST_TMPDIR/support-path-poison-bin"
    bundle_dir="$(create_temp_dir)"
    acfs_home="$(create_temp_dir)/.acfs"
    mkdir -p "$fake_bin" "$bundle_dir" "$acfs_home"

    cat > "$fake_bin/whoami" <<'EOF'
#!/usr/bin/env bash
printf 'poisoned-user\n'
EOF
    cat > "$fake_bin/jq" <<EOF
#!/usr/bin/env bash
exec "$jq_real" "\$@"
EOF
    chmod +x "$fake_bin/whoami" "$fake_bin/jq"
    printf '0.0.0-test\n' > "$acfs_home/VERSION"

    run env -i PATH="$fake_bin:/usr/bin:/bin" HOME="$current_home" SHELL="/bin/bash" bash -s -- "$PROJECT_ROOT/scripts/lib/support.sh" "$bundle_dir" "$acfs_home" <<'EOF_SUPPORT_ENV'
script="$1"
bundle_dir="$2"
acfs_home="$3"
record_bundle_file() { :; }
log_warn() { :; }
eval "$(sed -n "/^support_system_binary_path()/,/^}$/p" "$script")"
eval "$(sed -n "/^support_resolve_current_user()/,/^}$/p" "$script")"
eval "$(sed -n "/^capture_env_summary()/,/^}$/p" "$script")"
_SUPPORT_CURRENT_HOME="$HOME"
_SUPPORT_ACFS_HOME="$acfs_home"
SUPPORT_TARGET_HOME="$HOME"
SUPPORT_TARGET_USER=""
capture_env_summary "$bundle_dir"
jq -r '.user' "$bundle_dir/environment.json"
EOF_SUPPORT_ENV
    assert_success
    assert_output "$current_user"
}

@test "dashboard serve banner ignores PATH-poisoned whoami fallback" {
    local current_user
    local current_home
    local fake_bin
    local acfs_home
    local port

    current_user="$(id -un 2>/dev/null || whoami 2>/dev/null || true)"
    if [[ "$current_user" == "root" ]]; then
        current_home="/root"
    else
        current_home="$(getent passwd "$current_user" | cut -d: -f6)"
    fi
    current_home="${current_home%/}"

    fake_bin="$BATS_TEST_TMPDIR/dashboard-path-poison-bin"
    acfs_home="$(create_temp_dir)/.acfs"
    port=18080
    mkdir -p "$fake_bin" "$acfs_home/dashboard"
    printf '<html></html>\n' > "$acfs_home/dashboard/index.html"

    cat > "$fake_bin/whoami" <<'EOF'
#!/usr/bin/env bash
printf 'poisoned-user\n'
EOF
    cat > "$fake_bin/python3" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$fake_bin/whoami" "$fake_bin/python3"

    run env -i PATH="$fake_bin:/usr/bin:/bin" HOME="$current_home" bash -s -- "$PROJECT_ROOT/scripts/lib/dashboard.sh" "$acfs_home" "$port" <<'EOF_DASHBOARD_SERVE'
script="$1"
acfs_home="$2"
port="$3"
validate_port() { return 0; }
dashboard_generate() { return 0; }
eval "$(sed -n "/^dashboard_system_binary_path()/,/^}$/p" "$script")"
eval "$(sed -n "/^dashboard_resolve_current_user()/,/^}$/p" "$script")"
eval "$(sed -n "/^dashboard_serve()/,/^}$/p" "$script")"
_DASHBOARD_ACFS_HOME="$acfs_home"
_DASHBOARD_RESOLVED_TARGET_USER=""
dashboard_serve --port "$port"
EOF_DASHBOARD_SERVE
    assert_success
    [[ "$output" == *"${current_user}@"* ]]
    [[ "$output" != *"poisoned-user@"* ]]
}

@test "username helpers and wrappers allow dotted usernames and validate before re-exec" {
    local update_wrapper="$PROJECT_ROOT/scripts/acfs-update"
    local global_wrapper="$PROJECT_ROOT/scripts/acfs-global"
    local preflight="$PROJECT_ROOT/scripts/preflight.sh"
    local services_setup="$PROJECT_ROOT/scripts/services-setup.sh"
    local onboard="$PROJECT_ROOT/packages/onboard/onboard.sh"

    run grep -F '[[ "$username" =~ ^[a-z_][a-z0-9._-]*$ ]]' "$update_wrapper"
    assert_success

    run grep -F '[[ "$username" =~ ^[a-z_][a-z0-9._-]*$ ]]' "$global_wrapper"
    assert_success

    run grep -F "validate_target_user_or_die \"\$user\"" "$update_wrapper"
    assert_success

    run grep -F "validate_target_user_or_die \"\$user\"" "$global_wrapper"
    assert_success

    run grep -F '[[ "$username" =~ ^[a-z_][a-z0-9._-]*$ ]]' "$preflight"
    assert_success

    run grep -F '[[ "$user" =~ ^[a-z_][a-z0-9._-]*$ ]]' "$services_setup"
    assert_success

    run grep -F 'onboard_passwd_home_from_entry() {' "$onboard"
    assert_success

    run grep -F 'home_candidate="$(onboard_lookup_passwd_home "$user" 2>/dev/null || true)"' "$onboard"
    assert_success

    run grep -F 'home_candidate="$(onboard_passwd_home_from_entry "$passwd_entry" 2>/dev/null || true)"' "$onboard"
    assert_success

    run grep -F 'done < <(onboard_getent_passwd_entry 2>/dev/null || true)' "$onboard"
    assert_success

    run grep -F 'jq_bin="$(onboard_system_binary_path jq 2>/dev/null || true)"' "$onboard"
    assert_success

    run grep -F 'sed_bin="$(onboard_system_binary_path sed 2>/dev/null || true)"' "$onboard"
    assert_success

    run grep -F 'cut -d: -f6' "$onboard"
    assert_failure

    run grep -F 'awk -F: -v u=' "$onboard"
    assert_failure

    run grep -F "printf '/home/%s\n' \"\$user\"" "$onboard"
    assert_failure
}

@test "run-as-user helper libs validate target context and preserve repaired env" {
    local cli_tools="$PROJECT_ROOT/scripts/lib/cli_tools.sh"
    local agents="$PROJECT_ROOT/scripts/lib/agents.sh"
    local languages="$PROJECT_ROOT/scripts/lib/languages.sh"
    local cloud_db="$PROJECT_ROOT/scripts/lib/cloud_db.sh"
    local stack="$PROJECT_ROOT/scripts/lib/stack.sh"

    run grep -F '_cli_validate_target_user "$target_user" || return 1' "$cli_tools"
    assert_success
    run grep -F 'wrapped_cmd="export TARGET_USER=$target_user_q TARGET_HOME=$target_home_q HOME=$target_home_q;"' "$cli_tools"
    assert_success
    run grep -F 'wrapped_cmd+=" export PATH=$target_path_prefix_q:\$PATH; set -o pipefail; $cmd"' "$cli_tools"
    assert_success

    run grep -F '_agent_validate_target_user "$target_user" || return 1' "$agents"
    assert_success
    run grep -F 'wrapped_cmd="export TARGET_USER=$target_user_q TARGET_HOME=$target_home_q HOME=$target_home_q;"' "$agents"
    assert_success
    run grep -F 'wrapped_cmd+=" export PATH=$target_path_prefix_q:\$PATH; set -o pipefail; $cmd"' "$agents"
    assert_success

    run grep -F '_lang_validate_target_user "$target_user" || return 1' "$languages"
    assert_success
    run grep -F 'wrapped_cmd="export TARGET_USER=$target_user_q TARGET_HOME=$target_home_q HOME=$target_home_q;"' "$languages"
    assert_success
    run grep -F 'wrapped_cmd+=" export PATH=$target_path_prefix_q:\$PATH; set -o pipefail; $cmd"' "$languages"
    assert_success

    run grep -F '_cloud_validate_target_user "$target_user" || return 1' "$cloud_db"
    assert_success
    run grep -F 'wrapped_cmd="export TARGET_USER=$target_user_q TARGET_HOME=$target_home_q HOME=$target_home_q;"' "$cloud_db"
    assert_success
    run grep -F 'wrapped_cmd+=" export PATH=$target_path_prefix_q:\$PATH; set -o pipefail; $cmd"' "$cloud_db"
    assert_success

    run grep -F '_stack_validate_target_user "$target_user" || return 1' "$stack"
    assert_success
}

@test "run-as-user helper libs reject invalid TARGET_USER before sudo" {
    export TARGET_USER="../bad user"
    export TARGET_HOME="/home/tester"
    export ACFS_BIN_DIR="/home/tester/.local/bin"

    source_lib "cli_tools"
    spy_command "sudo"
    run _cli_run_as_user env
    assert_failure
    assert_output --partial "Invalid TARGET_USER '../bad user'"
    [[ ! -s "$STUB_DIR/sudo.log" ]] || fail "_cli_run_as_user should not invoke sudo for invalid TARGET_USER"

    source_lib "agents"
    : > "$STUB_DIR/sudo.log"
    run _agent_run_as_user env
    assert_failure
    assert_output --partial "Invalid TARGET_USER '../bad user'"
    [[ ! -s "$STUB_DIR/sudo.log" ]] || fail "_agent_run_as_user should not invoke sudo for invalid TARGET_USER"

    source_lib "languages"
    : > "$STUB_DIR/sudo.log"
    run _lang_run_as_user env
    assert_failure
    assert_output --partial "Invalid TARGET_USER '../bad user'"
    [[ ! -s "$STUB_DIR/sudo.log" ]] || fail "_lang_run_as_user should not invoke sudo for invalid TARGET_USER"

    source_lib "cloud_db"
    : > "$STUB_DIR/sudo.log"
    run _cloud_run_as_user env
    assert_failure
    assert_output --partial "Invalid TARGET_USER '../bad user'"
    [[ ! -s "$STUB_DIR/sudo.log" ]] || fail "_cloud_run_as_user should not invoke sudo for invalid TARGET_USER"

    source_lib "stack"
    : > "$STUB_DIR/sudo.log"
    run _stack_run_as_user env
    assert_failure
    assert_output --partial "Invalid TARGET_USER '../bad user'"
    [[ ! -s "$STUB_DIR/sudo.log" ]] || fail "_stack_run_as_user should not invoke sudo for invalid TARGET_USER"
}

@test "helper home resolvers ignore stale explicit TARGET_HOME" {
    local current_user
    local resolved_home
    local stale_home
    current_user="$(id -un 2>/dev/null || whoami 2>/dev/null || true)"
    [[ -n "$current_user" ]] || fail "Unable to resolve current user"
    resolved_home="$(getent passwd "$current_user" | cut -d: -f6)"
    [[ -n "$resolved_home" && -d "$resolved_home" ]] || fail "Unable to resolve current user home"
    stale_home="$BATS_TEST_TMPDIR/stale-target-home"

    export TARGET_USER="$current_user"
    export TARGET_HOME="$stale_home"
    export HOME="$stale_home"

    source_lib "cli_tools"
    run _cli_target_home "$current_user"
    assert_success
    assert_output "$resolved_home"

    source_lib "agents"
    run _agent_target_home "$current_user"
    assert_success
    assert_output "$resolved_home"

    source_lib "languages"
    run _lang_target_home "$current_user"
    assert_success
    assert_output "$resolved_home"

    source_lib "cloud_db"
    run _cloud_target_home "$current_user"
    assert_success
    assert_output "$resolved_home"

    source_lib "stack"
    run _stack_target_home "$current_user"
    assert_success
    assert_output "$resolved_home"
}

@test "helper home resolvers ignore function-poisoned passwd and identity shims" {
    local current_user
    local current_home
    local poisoned_home

    current_user="$(command id -un 2>/dev/null || command whoami 2>/dev/null || true)"
    [[ "$current_user" != "root" ]] || skip "requires non-root current user"
    current_home="$(command getent passwd "$current_user" | cut -d: -f6)"
    current_home="${current_home%/}"
    poisoned_home="$(create_temp_dir)"

    export TARGET_USER=""
    export TARGET_HOME=""
    export HOME="$current_home"

    getent() {
        if [[ "$1" == "passwd" && "$2" == "$current_user" ]]; then
            printf '%s:x:1000:1000::%s:/bin/bash\n' "$current_user" "$poisoned_home"
            return 0
        fi
        command getent "$@"
    }

    id() {
        if [[ "$1" == "-un" ]]; then
            printf 'poisoned-user\n'
            return 0
        fi
        command id "$@"
    }

    whoami() {
        printf 'poisoned-user\n'
    }

    source_lib "cli_tools"
    run _cli_target_home "$current_user"
    assert_success
    assert_output "$current_home"

    source_lib "agents"
    run _agent_target_home "$current_user"
    assert_success
    assert_output "$current_home"

    source_lib "languages"
    run _lang_target_home "$current_user"
    assert_success
    assert_output "$current_home"

    source_lib "cloud_db"
    run _cloud_target_home "$current_user"
    assert_success
    assert_output "$current_home"

    source_lib "stack"
    run _stack_target_home "$current_user"
    assert_success
    assert_output "$current_home"
}

@test "run-as-user helper libs ignore function-poisoned whoami on same-user fast path" {
    local current_user
    local current_home

    current_user="$(command id -un 2>/dev/null || command whoami 2>/dev/null || true)"
    [[ "$current_user" != "root" ]] || skip "requires non-root current user"
    current_home="$(command getent passwd "$current_user" | cut -d: -f6)"
    current_home="${current_home%/}"
    mkdir -p "$current_home/.local/bin"

    export TARGET_USER="$current_user"
    export TARGET_HOME="$current_home"
    export HOME="$current_home"
    export ACFS_BIN_DIR="$current_home/.local/bin"

    whoami() {
        printf 'poisoned-user\n'
    }

    source_lib "cli_tools"
    spy_command "sudo"
    run _cli_run_as_user 'printf "%s\n" "$HOME"'
    assert_success
    assert_output "$current_home"
    [[ ! -s "$STUB_DIR/sudo.log" ]] || fail "_cli_run_as_user should not invoke sudo for same-user fast path"

    source_lib "agents"
    : > "$STUB_DIR/sudo.log"
    run _agent_run_as_user 'printf "%s\n" "$HOME"'
    assert_success
    assert_output "$current_home"
    [[ ! -s "$STUB_DIR/sudo.log" ]] || fail "_agent_run_as_user should not invoke sudo for same-user fast path"

    source_lib "languages"
    : > "$STUB_DIR/sudo.log"
    run _lang_run_as_user 'printf "%s\n" "$HOME"'
    assert_success
    assert_output "$current_home"
    [[ ! -s "$STUB_DIR/sudo.log" ]] || fail "_lang_run_as_user should not invoke sudo for same-user fast path"

    source_lib "cloud_db"
    : > "$STUB_DIR/sudo.log"
    run _cloud_run_as_user 'printf "%s\n" "$HOME"'
    assert_success
    assert_output "$current_home"
    [[ ! -s "$STUB_DIR/sudo.log" ]] || fail "_cloud_run_as_user should not invoke sudo for same-user fast path"

    source_lib "stack"
    : > "$STUB_DIR/sudo.log"
    run _stack_run_as_user 'printf "%s\n" "$HOME"'
    assert_success
    assert_output "$current_home"
    [[ ! -s "$STUB_DIR/sudo.log" ]] || fail "_stack_run_as_user should not invoke sudo for same-user fast path"
}

@test "helper bin-dir selectors ignore function-poisoned getent passwd streams" {
    local current_user
    local current_home
    local fake_home
    local fake_bin_dir

    current_user="$(command id -un 2>/dev/null || command whoami 2>/dev/null || true)"
    current_home="$(command getent passwd "$current_user" | cut -d: -f6)"
    current_home="${current_home%/}"
    fake_home="$(create_temp_dir)"
    fake_bin_dir="$fake_home/.local/bin"
    mkdir -p "$fake_bin_dir" "$current_home/.local/bin"

    export TARGET_USER="$current_user"
    export TARGET_HOME="$current_home"
    export HOME="$current_home"
    export ACFS_BIN_DIR="$fake_bin_dir"

    getent() {
        if [[ "$1" == "passwd" ]]; then
            printf 'poisoned-user:x:1000:1000::%s:/bin/bash\n' "$fake_home"
            return 0
        fi
        command getent "$@"
    }

    source_lib "cli_tools"
    run _cli_validate_bin_dir_for_home "$fake_bin_dir" ""
    assert_success
    assert_output "$fake_bin_dir"

    source_lib "agents"
    run _agent_validate_bin_dir_for_home "$fake_bin_dir" ""
    assert_success
    assert_output "$fake_bin_dir"

    source_lib "stack"
    run _stack_target_bin_dir "$current_user"
    assert_success
    assert_output "$fake_bin_dir"
}

@test "services-setup: resolve_home_dir prefers current HOME over guessed standard path" {
    local services_setup="$PROJECT_ROOT/scripts/services-setup.sh"
    local resolved_home
    resolved_home="$(create_temp_dir)"

    eval "$(sed -n '/^services_setup_sanitize_abs_nonroot_path()/,/^}$/p' "$services_setup")"
    eval "$(sed -n '/^services_setup_system_binary_path()/,/^}$/p' "$services_setup")"
    eval "$(sed -n '/^services_setup_resolve_current_user()/,/^}$/p' "$services_setup")"
    eval "$(sed -n '/^services_setup_getent_passwd_entry()/,/^}$/p' "$services_setup")"
    eval "$(sed -n '/^resolve_home_dir()/,/^}$/p' "$services_setup")"

    export HOME="$resolved_home"

    services_setup_resolve_current_user() {
        printf 'tester\n'
    }

    services_setup_getent_passwd_entry() {
        return 1
    }

    run resolve_home_dir "tester"
    assert_success
    assert_output "$resolved_home"
}

@test "services-setup: resolve_current_home fails closed when HOME is invalid and passwd lookup fails" {
    local services_setup="$PROJECT_ROOT/scripts/services-setup.sh"

    eval "$(sed -n '/^services_setup_sanitize_abs_nonroot_path()/,/^}$/p' "$services_setup")"
    eval "$(sed -n '/^services_setup_system_binary_path()/,/^}$/p' "$services_setup")"
    eval "$(sed -n '/^services_setup_resolve_current_user()/,/^}$/p' "$services_setup")"
    eval "$(sed -n '/^services_setup_getent_passwd_entry()/,/^}$/p' "$services_setup")"
    eval "$(sed -n '/^services_setup_passwd_home_from_entry()/,/^}$/p' "$services_setup")"
    eval "$(sed -n '/^services_setup_resolve_current_home()/,/^}$/p' "$services_setup")"

    export HOME="relative-home"

    services_setup_resolve_current_user() {
        printf 'tester\n'
    }

    services_setup_getent_passwd_entry() {
        return 1
    }

    run services_setup_resolve_current_home
    assert_failure
    assert_output ""
}

@test "remaining helpers: resolve_current_home prefers passwd home over mismatched absolute HOME" {
    local current_user
    local passwd_home
    local poisoned_home
    local failures=""
    local label
    local script
    local func

    current_user="$(id -un 2>/dev/null || whoami 2>/dev/null || true)"
    passwd_home="$(create_temp_dir)"
    poisoned_home="$(create_temp_dir)"
    mkdir -p "$passwd_home" "$poisoned_home"
    export ACFS_TEST_CURRENT_USER="$current_user"
    export ACFS_TEST_PASSWD_HOME="$passwd_home"

    getent() {
        if [[ "${1:-}" == "passwd" ]] && [[ "${2:-}" == "$ACFS_TEST_CURRENT_USER" ]]; then
            printf '%s:x:1000:1000::%s:/bin/bash\n' "$ACFS_TEST_CURRENT_USER" "$ACFS_TEST_PASSWD_HOME"
            return 0
        fi
        return 2
    }

    id() {
        if [[ "${1:-}" == "-un" ]]; then
            printf '%s\n' "$ACFS_TEST_CURRENT_USER"
            return 0
        fi
        command id "$@"
    }

    whoami() {
        printf '%s\n' "$ACFS_TEST_CURRENT_USER"
    }

    while IFS='|' read -r label script func; do
        [[ -n "$label" ]] || continue

        case "$label" in
            preflight)
                local preflight_bin_dir="$BATS_TEST_TMPDIR/preflight-bin"
                mkdir -p "$preflight_bin_dir"
                cat > "$preflight_bin_dir/id" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "-un" ]]; then
    echo "$current_user"
    exit 0
fi
exit 2
EOF
                cat > "$preflight_bin_dir/whoami" <<EOF
#!/usr/bin/env bash
echo "$current_user"
EOF
                cat > "$preflight_bin_dir/getent" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "passwd" ]] && [[ "\${2:-}" == "$current_user" ]]; then
    echo "$current_user:x:1000:1000::$passwd_home:/bin/bash"
    exit 0
fi
if [[ "\${1:-}" == "passwd" ]] && [[ -z "\${2:-}" ]]; then
    echo "$current_user:x:1000:1000::$passwd_home:/bin/bash"
    exit 0
fi
exit 2
EOF
                chmod +x "$preflight_bin_dir/id" "$preflight_bin_dir/whoami" "$preflight_bin_dir/getent"
                eval "$(sed -n '/^preflight_sanitize_abs_nonroot_path()/,/^}$/p' "$script")"
                eval "$(sed -n '/^preflight_system_binary_path()/,/^}$/p' "$script")"
                eval "$(sed -n '/^preflight_getent_passwd_entry()/,/^}$/p' "$script")"
                eval "$(sed -n '/^resolve_current_user()/,/^}$/p' "$script")"
                eval "$(sed -n '/^resolve_home_dir()/,/^}$/p' "$script")"
                eval "$(sed -n '/^resolve_current_home()/,/^}$/p' "$script")"
                preflight_system_binary_path() {
                    local name="${1:-}"
                    [[ -n "$name" ]] || return 1
                    echo "$preflight_bin_dir/$name"
                }
                ;;
            services-setup)
                local services_bin_dir="$BATS_TEST_TMPDIR/services-setup-bin"
                mkdir -p "$services_bin_dir"
                cat > "$services_bin_dir/id" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "-un" ]]; then
    printf '%s\n' "$current_user"
    exit 0
fi
exit 2
EOF
                cat > "$services_bin_dir/whoami" <<EOF
#!/usr/bin/env bash
printf '%s\n' "$current_user"
EOF
                cat > "$services_bin_dir/getent" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "passwd" ]] && [[ "\${2:-}" == "$current_user" ]]; then
    printf '%s:x:1000:1000::%s:/bin/bash\n' "$current_user" "$passwd_home"
    exit 0
fi
exit 2
EOF
                chmod +x "$services_bin_dir/id" "$services_bin_dir/whoami" "$services_bin_dir/getent"
                eval "$(sed -n '/^services_setup_sanitize_abs_nonroot_path()/,/^}$/p' "$script")"
                eval "$(sed -n '/^services_setup_system_binary_path()/,/^}$/p' "$script")"
                eval "$(sed -n '/^services_setup_resolve_current_user()/,/^}$/p' "$script")"
                eval "$(sed -n '/^services_setup_getent_passwd_entry()/,/^}$/p' "$script")"
                eval "$(sed -n '/^services_setup_passwd_home_from_entry()/,/^}$/p' "$script")"
                eval "$(sed -n '/^services_setup_resolve_current_home()/,/^}$/p' "$script")"
                services_setup_system_binary_path() {
                    local name="${1:-}"
                    [[ -n "$name" ]] || return 1
                    printf '%s/%s\n' "$services_bin_dir" "$name"
                }
                ;;
            notifications)
                local notifications_bin_dir="$BATS_TEST_TMPDIR/notifications-bin"
                mkdir -p "$notifications_bin_dir"
                cat > "$notifications_bin_dir/id" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "-un" ]]; then
    printf '%s\n' "$current_user"
    exit 0
fi
exit 2
EOF
                cat > "$notifications_bin_dir/whoami" <<EOF
#!/usr/bin/env bash
printf '%s\n' "$current_user"
EOF
                cat > "$notifications_bin_dir/getent" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "passwd" ]] && [[ "\${2:-}" == "$current_user" ]]; then
    printf '%s:x:1000:1000::%s:/bin/bash\n' "$current_user" "$passwd_home"
    exit 0
fi
exit 2
EOF
                chmod +x "$notifications_bin_dir/id" "$notifications_bin_dir/whoami" "$notifications_bin_dir/getent"
                eval "$(sed -n '/^notifications_sanitize_abs_nonroot_path()/,/^}$/p' "$script")"
                eval "$(sed -n '/^notifications_system_binary_path()/,/^}$/p' "$script")"
                eval "$(sed -n '/^notifications_resolve_current_user()/,/^}$/p' "$script")"
                eval "$(sed -n '/^notifications_getent_passwd_entry()/,/^}$/p' "$script")"
                eval "$(sed -n '/^notifications_passwd_home_from_entry()/,/^}$/p' "$script")"
                eval "$(sed -n '/^notifications_resolve_current_home()/,/^}$/p' "$script")"
                notifications_system_binary_path() {
                    local name="${1:-}"
                    [[ -n "$name" ]] || return 1
                    printf '%s/%s\n' "$notifications_bin_dir" "$name"
                }
                ;;
            notify)
                local notify_bin_dir="$BATS_TEST_TMPDIR/notify-bin"
                mkdir -p "$notify_bin_dir"
                cat > "$notify_bin_dir/id" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "-un" ]]; then
    printf '%s\n' "$current_user"
    exit 0
fi
exit 2
EOF
                cat > "$notify_bin_dir/whoami" <<EOF
#!/usr/bin/env bash
printf '%s\n' "$current_user"
EOF
                cat > "$notify_bin_dir/getent" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "passwd" ]] && [[ "\${2:-}" == "$current_user" ]]; then
    printf '%s:x:1000:1000::%s:/bin/bash\n' "$current_user" "$passwd_home"
    exit 0
fi
exit 2
EOF
                chmod +x "$notify_bin_dir/id" "$notify_bin_dir/whoami" "$notify_bin_dir/getent"
                eval "$(sed -n '/^_acfs_notify_sanitize_abs_nonroot_path()/,/^}$/p' "$script")"
                eval "$(sed -n '/^_acfs_notify_system_binary_path()/,/^}$/p' "$script")"
                eval "$(sed -n '/^_acfs_notify_resolve_current_user()/,/^}$/p' "$script")"
                eval "$(sed -n '/^_acfs_notify_getent_passwd_entry()/,/^}$/p' "$script")"
                eval "$(sed -n '/^_acfs_notify_passwd_home_from_entry()/,/^}$/p' "$script")"
                eval "$(sed -n '/^_acfs_notify_resolve_current_home()/,/^}$/p' "$script")"
                _acfs_notify_system_binary_path() {
                    local name="${1:-}"
                    [[ -n "$name" ]] || return 1
                    printf '%s/%s\n' "$notify_bin_dir" "$name"
                }
                ;;
            webhook)
                local webhook_bin_dir="$BATS_TEST_TMPDIR/webhook-bin"
                mkdir -p "$webhook_bin_dir"
                cat > "$webhook_bin_dir/id" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "-un" ]]; then
    printf '%s\n' "$current_user"
    exit 0
fi
exit 2
EOF
                cat > "$webhook_bin_dir/whoami" <<EOF
#!/usr/bin/env bash
printf '%s\n' "$current_user"
EOF
                cat > "$webhook_bin_dir/getent" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "passwd" ]] && [[ "\${2:-}" == "$current_user" ]]; then
    printf '%s:x:1000:1000::%s:/bin/bash\n' "$current_user" "$passwd_home"
    exit 0
fi
exit 2
EOF
                chmod +x "$webhook_bin_dir/id" "$webhook_bin_dir/whoami" "$webhook_bin_dir/getent"
                eval "$(sed -n '/^webhook_sanitize_abs_nonroot_path()/,/^}$/p' "$script")"
                eval "$(sed -n '/^webhook_system_binary_path()/,/^}$/p' "$script")"
                eval "$(sed -n '/^webhook_resolve_current_user()/,/^}$/p' "$script")"
                eval "$(sed -n '/^webhook_getent_passwd_entry()/,/^}$/p' "$script")"
                eval "$(sed -n '/^webhook_passwd_home_from_entry()/,/^}$/p' "$script")"
                eval "$(sed -n '/^webhook_resolve_current_home()/,/^}$/p' "$script")"
                webhook_system_binary_path() {
                    local name="${1:-}"
                    [[ -n "$name" ]] || return 1
                    printf '%s/%s\n' "$webhook_bin_dir" "$name"
                }
                ;;
            doctor)
                local doctor_bin_dir="$BATS_TEST_TMPDIR/doctor-bin"
                mkdir -p "$doctor_bin_dir"
                cat > "$doctor_bin_dir/id" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "-un" ]]; then
    printf '%s\n' "$current_user"
    exit 0
fi
exit 2
EOF
                cat > "$doctor_bin_dir/whoami" <<EOF
#!/usr/bin/env bash
printf '%s\n' "$current_user"
EOF
                cat > "$doctor_bin_dir/getent" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "passwd" ]] && [[ "\${2:-}" == "$current_user" ]]; then
    printf '%s:x:1000:1000::%s:/bin/bash\n' "$current_user" "$passwd_home"
    exit 0
fi
exit 2
EOF
                chmod +x "$doctor_bin_dir/id" "$doctor_bin_dir/whoami" "$doctor_bin_dir/getent"
                eval "$(sed -n '/^_acfs_doctor_sanitize_abs_nonroot_path()/,/^}$/p' "$script")"
                eval "$(sed -n '/^_acfs_doctor_system_binary_path()/,/^}$/p' "$script")"
                eval "$(sed -n '/^_acfs_doctor_resolve_current_user()/,/^}$/p' "$script")"
                eval "$(sed -n '/^_acfs_doctor_getent_passwd_entry()/,/^}$/p' "$script")"
                eval "$(sed -n '/^_acfs_doctor_passwd_home_from_entry()/,/^}$/p' "$script")"
                eval "$(sed -n '/^_acfs_doctor_resolve_current_home()/,/^}$/p' "$script")"
                _acfs_doctor_system_binary_path() {
                    local name="${1:-}"
                    [[ -n "$name" ]] || return 1
                    printf '%s/%s\n' "$doctor_bin_dir" "$name"
                }
                ;;
            doctor-fix)
                local doctor_fix_bin_dir="$BATS_TEST_TMPDIR/doctor-fix-bin"
                mkdir -p "$doctor_fix_bin_dir"
                cat > "$doctor_fix_bin_dir/id" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "-un" ]]; then
    printf '%s\n' "$current_user"
    exit 0
fi
exit 2
EOF
                cat > "$doctor_fix_bin_dir/whoami" <<EOF
#!/usr/bin/env bash
printf '%s\n' "$current_user"
EOF
                cat > "$doctor_fix_bin_dir/getent" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "passwd" ]] && [[ "\${2:-}" == "$current_user" ]]; then
    printf '%s:x:1000:1000::%s:/bin/bash\n' "$current_user" "$passwd_home"
    exit 0
fi
exit 2
EOF
                chmod +x "$doctor_fix_bin_dir/id" "$doctor_fix_bin_dir/whoami" "$doctor_fix_bin_dir/getent"
                eval "$(sed -n '/^doctor_fix_sanitize_abs_nonroot_path()/,/^}$/p' "$script")"
                eval "$(sed -n '/^doctor_fix_is_valid_username()/,/^}$/p' "$script")"
                eval "$(sed -n '/^doctor_fix_system_binary_path()/,/^}$/p' "$script")"
                eval "$(sed -n '/^doctor_fix_getent_passwd_entry()/,/^}$/p' "$script")"
                eval "$(sed -n '/^doctor_fix_current_user()/,/^}$/p' "$script")"
                eval "$(sed -n '/^doctor_fix_passwd_home_from_entry()/,/^}$/p' "$script")"
                eval "$(sed -n '/^doctor_fix_resolve_home_for_user()/,/^}$/p' "$script")"
                eval "$(sed -n '/^doctor_fix_resolve_current_home()/,/^}$/p' "$script")"
                doctor_fix_system_binary_path() {
                    local name="${1:-}"
                    [[ -n "$name" ]] || return 1
                    printf '%s/%s\n' "$doctor_fix_bin_dir" "$name"
                }
                ;;
            nightly-update)
                local nightly_bin_dir="$BATS_TEST_TMPDIR/nightly-update-bin"
                mkdir -p "$nightly_bin_dir"
                cat > "$nightly_bin_dir/id" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "-un" ]]; then
    printf '%s\n' "$current_user"
    exit 0
fi
exit 2
EOF
                cat > "$nightly_bin_dir/whoami" <<EOF
#!/usr/bin/env bash
printf '%s\n' "$current_user"
EOF
                cat > "$nightly_bin_dir/getent" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "passwd" ]] && [[ "\${2:-}" == "$current_user" ]]; then
    printf '%s:x:1000:1000::%s:/bin/bash\n' "$current_user" "$passwd_home"
    exit 0
fi
exit 2
EOF
                chmod +x "$nightly_bin_dir/id" "$nightly_bin_dir/whoami" "$nightly_bin_dir/getent"
                eval "$(sed -n '/^sanitize_abs_nonroot_path()/,/^}$/p' "$script")"
                eval "$(sed -n '/^system_binary_path()/,/^}$/p' "$script")"
                eval "$(sed -n '/^resolve_current_user()/,/^}$/p' "$script")"
                eval "$(sed -n '/^getent_passwd_entry()/,/^}$/p' "$script")"
                eval "$(sed -n '/^passwd_home_from_entry()/,/^}$/p' "$script")"
                eval "$(sed -n '/^resolve_current_home()/,/^}$/p' "$script")"
                system_binary_path() {
                    local name="${1:-}"
                    [[ -n "$name" ]] || return 1
                    printf '%s/%s\n' "$nightly_bin_dir" "$name"
                }
                ;;
            smoke)
                local smoke_bin_dir="$BATS_TEST_TMPDIR/smoke-bin"
                mkdir -p "$smoke_bin_dir"
                cat > "$smoke_bin_dir/id" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "-un" ]]; then
    printf '%s\\n' "$current_user"
    exit 0
fi
exit 2
EOF
                cat > "$smoke_bin_dir/whoami" <<EOF
#!/usr/bin/env bash
printf '%s\\n' "$current_user"
EOF
                cat > "$smoke_bin_dir/getent" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "passwd" ]] && [[ "\${2:-}" == "$current_user" ]]; then
    printf '%s:x:1000:1000::%s:/bin/bash\\n' "$current_user" "$passwd_home"
    exit 0
fi
exit 2
EOF
                chmod +x "$smoke_bin_dir/id" "$smoke_bin_dir/whoami" "$smoke_bin_dir/getent"
                eval "$(sed -n '/^_smoke_sanitize_abs_nonroot_path()/,/^}$/p' "$script")"
                eval "$(sed -n '/^_smoke_system_binary_path()/,/^}$/p' "$script")"
                eval "$(sed -n '/^_smoke_getent_passwd_entry()/,/^}$/p' "$script")"
                eval "$(sed -n '/^_smoke_resolve_current_user()/,/^}$/p' "$script")"
                eval "$(sed -n '/^_smoke_passwd_home_from_entry()/,/^}$/p' "$script")"
                eval "$(sed -n '/^_smoke_resolve_current_home()/,/^}$/p' "$script")"
                _smoke_system_binary_path() {
                    local name="${1:-}"
                    [[ -n "$name" ]] || return 1
                    printf '%s/%s\n' "$smoke_bin_dir" "$name"
                }
                ;;
            state)
                local state_bin_dir="$BATS_TEST_TMPDIR/state-bin"
                mkdir -p "$state_bin_dir"
                cat > "$state_bin_dir/id" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "-un" ]]; then
    printf '%s\n' "$current_user"
    exit 0
fi
exit 2
EOF
                cat > "$state_bin_dir/whoami" <<EOF
#!/usr/bin/env bash
printf '%s\n' "$current_user"
EOF
                cat > "$state_bin_dir/getent" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "passwd" ]] && [[ "\${2:-}" == "$current_user" ]]; then
    printf '%s:x:1000:1000::%s:/bin/bash\n' "$current_user" "$passwd_home"
    exit 0
fi
exit 2
EOF
                chmod +x "$state_bin_dir/id" "$state_bin_dir/whoami" "$state_bin_dir/getent"
                eval "$(sed -n '/^state_sanitize_abs_nonroot_path()/,/^}$/p' "$script")"
                eval "$(sed -n '/^state_system_binary_path()/,/^}$/p' "$script")"
                eval "$(sed -n '/^state_resolve_current_user()/,/^}$/p' "$script")"
                eval "$(sed -n '/^state_getent_passwd_entry()/,/^}$/p' "$script")"
                eval "$(sed -n '/^state_passwd_home_from_entry()/,/^}$/p' "$script")"
                eval "$(sed -n '/^state_resolve_current_home()/,/^}$/p' "$script")"
                state_system_binary_path() {
                    local name="${1:-}"
                    [[ -n "$name" ]] || return 1
                    printf '%s/%s\n' "$state_bin_dir" "$name"
                }
                ;;
        esac

        HOME="$poisoned_home"
        run "$func"
        if [[ "$status" -ne 0 ]] || [[ "$output" != "$passwd_home" ]]; then
            printf -v failures '%s%s: status=%s output=%s\n' "$failures" "$label" "$status" "$output"
        fi
    done <<EOF
preflight|$PROJECT_ROOT/scripts/preflight.sh|resolve_current_home
services-setup|$PROJECT_ROOT/scripts/services-setup.sh|services_setup_resolve_current_home
notifications|$PROJECT_ROOT/scripts/lib/notifications.sh|notifications_resolve_current_home
notify|$PROJECT_ROOT/scripts/lib/notify.sh|_acfs_notify_resolve_current_home
webhook|$PROJECT_ROOT/scripts/lib/webhook.sh|webhook_resolve_current_home
doctor|$PROJECT_ROOT/scripts/lib/doctor.sh|_acfs_doctor_resolve_current_home
doctor-fix|$PROJECT_ROOT/scripts/lib/doctor_fix.sh|doctor_fix_resolve_current_home
nightly-update|$PROJECT_ROOT/scripts/lib/nightly_update.sh|resolve_current_home
smoke|$PROJECT_ROOT/scripts/lib/smoke_test.sh|_smoke_resolve_current_home
state|$PROJECT_ROOT/scripts/lib/state.sh|state_resolve_current_home
EOF

    if [[ -n "$failures" ]]; then
        printf '%s' "$failures" >&2
        return 1
    fi
}

@test "state: resolve_current_home fails closed when HOME is invalid and passwd lookup fails" {
    local state_lib="$PROJECT_ROOT/scripts/lib/state.sh"

    eval "$(sed -n '/^state_sanitize_abs_nonroot_path()/,/^}$/p' "$state_lib")"
    eval "$(sed -n '/^state_passwd_home_from_entry()/,/^}$/p' "$state_lib")"
    eval "$(sed -n '/^state_resolve_current_home()/,/^}$/p' "$state_lib")"

    export HOME="relative-home"

    getent() {
        return 2
    }

    id() {
        if [[ "${1:-}" == "-un" ]]; then
            printf 'tester\n'
            return 0
        fi
        command id "$@"
    }

    whoami() {
        printf 'tester\n'
    }

    run state_resolve_current_home
    assert_failure
    assert_output ""
}

@test "preflight: resolve_current_home fails closed when HOME is invalid and passwd lookup fails" {
    local preflight="$PROJECT_ROOT/scripts/preflight.sh"

    eval "$(sed -n '/^preflight_sanitize_abs_nonroot_path()/,/^}$/p' "$preflight")"
    eval "$(sed -n '/^preflight_is_valid_username()/,/^}$/p' "$preflight")"
    eval "$(sed -n '/^preflight_system_binary_path()/,/^}$/p' "$preflight")"
    eval "$(sed -n '/^preflight_getent_passwd_entry()/,/^}$/p' "$preflight")"
    eval "$(sed -n '/^resolve_current_user()/,/^}$/p' "$preflight")"
    eval "$(sed -n '/^resolve_home_dir()/,/^}$/p' "$preflight")"
    eval "$(sed -n '/^resolve_current_home()/,/^}$/p' "$preflight")"

    export HOME="relative-home"

    preflight_system_binary_path() {
        return 1
    }

    run resolve_current_home
    assert_failure
    assert_output ""
}

@test "preflight: resolve_install_target_home fails closed for different unresolved target" {
    local preflight="$PROJECT_ROOT/scripts/preflight.sh"

    eval "$(sed -n '/^preflight_sanitize_abs_nonroot_path()/,/^}$/p' "$preflight")"
    eval "$(sed -n '/^preflight_is_valid_username()/,/^}$/p' "$preflight")"
    eval "$(sed -n '/^preflight_system_binary_path()/,/^}$/p' "$preflight")"
    eval "$(sed -n '/^preflight_getent_passwd_entry()/,/^}$/p' "$preflight")"
    eval "$(sed -n '/^resolve_current_user()/,/^}$/p' "$preflight")"
    eval "$(sed -n '/^resolve_home_dir()/,/^}$/p' "$preflight")"
    eval "$(sed -n '/^resolve_current_home()/,/^}$/p' "$preflight")"
    eval "$(sed -n '/^resolve_install_target_home()/,/^}$/p' "$preflight")"

    export HOME="$(create_temp_dir)"
    export TARGET_USER="missinguser"
    export TARGET_HOME="/"

    resolve_current_user() {
        printf 'tester\n'
    }

    preflight_getent_passwd_entry() {
        return 1
    }

    run resolve_install_target_home
    assert_failure
    assert_output ""
}

@test "preflight: binary helper ignores stale other-user ACFS_BIN_DIR" {
    local preflight="$PROJECT_ROOT/scripts/preflight.sh"
    local current_home
    local target_home
    local tool_name="acfs-preflight-test-tool"

    eval "$(sed -n '/^preflight_sanitize_abs_nonroot_path()/,/^}$/p' "$preflight")"
    eval "$(sed -n '/^preflight_is_valid_username()/,/^}$/p' "$preflight")"
    eval "$(sed -n '/^preflight_system_binary_path()/,/^}$/p' "$preflight")"
    eval "$(sed -n '/^preflight_getent_passwd_entry()/,/^}$/p' "$preflight")"
    eval "$(sed -n '/^resolve_current_user()/,/^}$/p' "$preflight")"
    eval "$(sed -n '/^preflight_validate_bin_dir_for_home()/,/^}$/p' "$preflight")"
    eval "$(sed -n '/^resolve_home_dir()/,/^}$/p' "$preflight")"
    eval "$(sed -n '/^resolve_current_home()/,/^}$/p' "$preflight")"
    eval "$(sed -n '/^resolve_install_target_home()/,/^}$/p' "$preflight")"
    eval "$(sed -n '/^preflight_binary_path()/,/^}$/p' "$preflight")"

    current_home="$(create_temp_dir)"
    target_home="$(create_temp_dir)"
    mkdir -p "$current_home/.local/bin" "$target_home/.local/bin"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$current_home/.local/bin/$tool_name"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$target_home/.local/bin/$tool_name"
    chmod +x "$current_home/.local/bin/$tool_name" "$target_home/.local/bin/$tool_name"

    export HOME="$current_home"
    export TARGET_HOME="$target_home"
    unset TARGET_USER
    export ACFS_BIN_DIR="$current_home/.local/bin"

    run preflight_binary_path "$tool_name"
    assert_success
    assert_output "$target_home/.local/bin/$tool_name"
}

@test "run-as-user helper libs reject unresolved TARGET_HOME before sudo" {
    export TARGET_USER="missinguser"
    export TARGET_HOME=""
    export ACFS_BIN_DIR="/home/tester/.local/bin"

    getent() {
        return 2
    }

    source_lib "cli_tools"
    spy_command "sudo"
    run _cli_run_as_user env
    assert_failure
    assert_output --partial "Invalid TARGET_HOME for 'missinguser': <empty>"
    [[ ! -s "$STUB_DIR/sudo.log" ]] || fail "_cli_run_as_user should not invoke sudo for unresolved TARGET_HOME"

    source_lib "agents"
    : > "$STUB_DIR/sudo.log"
    run _agent_run_as_user env
    assert_failure
    assert_output --partial "Invalid TARGET_HOME for 'missinguser': <empty>"
    [[ ! -s "$STUB_DIR/sudo.log" ]] || fail "_agent_run_as_user should not invoke sudo for unresolved TARGET_HOME"

    source_lib "languages"
    : > "$STUB_DIR/sudo.log"
    run _lang_run_as_user env
    assert_failure
    assert_output --partial "Invalid TARGET_HOME for 'missinguser': <empty>"
    [[ ! -s "$STUB_DIR/sudo.log" ]] || fail "_lang_run_as_user should not invoke sudo for unresolved TARGET_HOME"

    source_lib "cloud_db"
    : > "$STUB_DIR/sudo.log"
    run _cloud_run_as_user env
    assert_failure
    assert_output --partial "Invalid TARGET_HOME for 'missinguser': <empty>"
    [[ ! -s "$STUB_DIR/sudo.log" ]] || fail "_cloud_run_as_user should not invoke sudo for unresolved TARGET_HOME"

    source_lib "stack"
    : > "$STUB_DIR/sudo.log"
    run _stack_run_as_user env
    assert_failure
    assert_output --partial "Invalid TARGET_HOME for 'missinguser': <empty>"
    [[ ! -s "$STUB_DIR/sudo.log" ]] || fail "_stack_run_as_user should not invoke sudo for unresolved TARGET_HOME"
}

@test "cloud_db username validation accepts dotted target usernames" {
    source_lib "cloud_db"

    run _cloud_validate_username "john.doe"
    assert_success
}

@test "github_api runtime home ignores stale TARGET_HOME and falls back to existing HOME" {
    source_lib "github_api"

    local runtime_home
    local stale_home
    runtime_home="$(create_temp_dir)"
    stale_home="$BATS_TEST_TMPDIR/stale-runtime-home"

    export TARGET_HOME="$stale_home"
    export HOME="$runtime_home"

    run _github_api_runtime_home
    assert_success
    assert_output "$runtime_home"
}

@test "update init honors explicit TARGET_HOME for early runtime paths" {
    local update="$PROJECT_ROOT/scripts/lib/update.sh"
    local current_home
    local target_home

    current_home="$(create_temp_dir)"
    target_home="$(create_temp_dir)"

    run env -i PATH="/usr/bin:/bin" HOME="$current_home" TARGET_HOME="$target_home" bash -c '
        source "$1" >/dev/null 2>&1
        printf "HOME=%s\nUPDATE_LOG_DIR=%s\nCHECKSUMS_LOCAL=%s\n" "$HOME" "$UPDATE_LOG_DIR" "$CHECKSUMS_LOCAL"
    ' _ "$update"

    assert_success
    assert_output --partial "HOME=$target_home"
    assert_output --partial "UPDATE_LOG_DIR=$target_home/.acfs/logs/updates"
    assert_output --partial "CHECKSUMS_LOCAL=$target_home/.acfs/checksums.yaml"
}

@test "agent mail MCP path detection prefers target install over current-shell am" {
    source_lib "agents"

    local target_home="$BATS_TEST_TMPDIR/target-home"
    local target_am="$target_home/mcp_agent_mail/am"
    local global_bin="$BATS_TEST_TMPDIR/global-bin"
    mkdir -p "$(dirname "$target_am")" "$global_bin"

    cat > "$target_am" <<'EOF'
#!/usr/bin/env bash
printf 'mcp-agent-mail 0.2.19\n'
EOF
    chmod +x "$target_am"

    cat > "$global_bin/am" <<'EOF'
#!/usr/bin/env bash
printf 'am 0.2.39\n'
EOF
    chmod +x "$global_bin/am"

    export PATH="$global_bin:/usr/bin:/bin"

    run _agent_detect_am_mcp_path "$target_home"
    assert_success
    assert_output "/api/"
}

@test "agent mail MCP path detection ignores current-shell-only am" {
    source_lib "agents"

    local target_home="$BATS_TEST_TMPDIR/target-home"
    local global_bin="$BATS_TEST_TMPDIR/global-bin"
    mkdir -p "$global_bin"

    cat > "$global_bin/am" <<'EOF'
#!/usr/bin/env bash
printf 'mcp-agent-mail 0.2.19\n'
EOF
    chmod +x "$global_bin/am"

    export PATH="$global_bin:/usr/bin:/bin"

    run _agent_detect_am_mcp_path "$target_home"
    assert_success
    assert_output "/mcp/"
}

@test "agent mail resolvers avoid system am fallback" {
    local agents_lib="$PROJECT_ROOT/scripts/lib/agents.sh"
    local stack_lib="$PROJECT_ROOT/scripts/lib/stack.sh"
    local doctor_lib="$PROJECT_ROOT/scripts/lib/doctor.sh"
    local doctor_fix_lib="$PROJECT_ROOT/scripts/lib/doctor_fix.sh"
    local installer="$PROJECT_ROOT/install.sh"

    run rg -n 'command -v am' "$agents_lib" "$stack_lib" "$doctor_lib" "$doctor_fix_lib" "$installer"
    assert_failure

    run rg -n '"/(usr/local/bin|usr/bin|bin|snap/bin)/am"' "$agents_lib" "$stack_lib" "$doctor_lib" "$doctor_fix_lib"
    assert_failure

    run grep -F 'resolve_target_am() {' "$installer"
    assert_success

    run grep -F 'doctor_agent_mail_cli_path() {' "$doctor_lib"
    assert_success

    run grep -F 'doctor_fix_agent_mail_cli_path() {' "$doctor_fix_lib"
    assert_success
}

@test "configure_gemini_settings repairs stale agent mail url after migration" {
    source_lib "agents"

    local target_home="$BATS_TEST_TMPDIR/target-home"
    local settings_dir="$target_home/.gemini"
    local settings_file="$settings_dir/settings.json"
    local target_am="$target_home/mcp_agent_mail/am"
    mkdir -p "$settings_dir" "$(dirname "$target_am")"

    cat > "$target_am" <<'EOF'
#!/usr/bin/env bash
printf 'am 0.2.39\n'
EOF
    chmod +x "$target_am"

    cat > "$settings_file" <<'EOF'
{
  "selectedType": "gemini-api-key",
  "tools": {
    "shell": {
      "enableInteractiveShell": true
    }
  },
  "mcpServers": {
    "mcp-agent-mail": {
      "httpUrl": "http://127.0.0.1:8765/api/"
    }
  }
}
EOF

    _agent_run_as_user() {
        bash -c "$1"
    }

    run _configure_gemini_settings "$target_home"
    assert_success

    run jq -r '.selectedType' "$settings_file"
    assert_success
    assert_output 'oauth-personal'

    run jq -r '.tools.shell.enableInteractiveShell' "$settings_file"
    assert_success
    assert_output 'false'

    run jq -r '.mcpServers."mcp-agent-mail".httpUrl' "$settings_file"
    assert_success
    assert_output 'http://127.0.0.1:8765/mcp/'
}

@test "install and update deploy all acfs doctor-dispatched runtime scripts" {
    local installer="$PROJECT_ROOT/install.sh"
    local update="$PROJECT_ROOT/scripts/lib/update.sh"

    run grep -F 'install_asset "scripts/lib/status.sh" "$ACFS_HOME/scripts/lib/status.sh"' "$installer"
    assert_success
    run grep -F 'install_asset "scripts/lib/changelog.sh" "$ACFS_HOME/scripts/lib/changelog.sh"' "$installer"
    assert_success
    run grep -F 'install_asset "scripts/lib/export-config.sh" "$ACFS_HOME/scripts/lib/export-config.sh"' "$installer"
    assert_success
    run grep -F 'install_asset "scripts/lib/support.sh" "$ACFS_HOME/scripts/lib/support.sh"' "$installer"
    assert_success

    run grep -F '"scripts/lib/status.sh:scripts/lib/status.sh"' "$update"
    assert_success
    run grep -F '"scripts/lib/changelog.sh:scripts/lib/changelog.sh"' "$update"
    assert_success
    run grep -F '"scripts/lib/export-config.sh:scripts/lib/export-config.sh"' "$update"
    assert_success
    run grep -F '"scripts/lib/support.sh:scripts/lib/support.sh"' "$update"
    assert_success
    run grep -F '"scripts/lib/doctor.sh:bin/acfs"' "$update"
    assert_success
    run grep -F '"scripts/acfs-update:bin/acfs-update"' "$update"
    assert_success
    run grep -F 'for generated_script in "$ACFS_REPO_ROOT/scripts/generated/"*.sh; do' "$update"
    assert_success
    run grep -F 'sync_acfs_global_wrapper' "$update"
    assert_success
}

@test "finalize keeps legacy runtime deployment after generated acfs phase" {
    local installer="$PROJECT_ROOT/install.sh"
    local block=""

    block="$(sed -n '/if acfs_use_generated_category "acfs"/,/^    # Copy tmux config/p' "$installer")"

    [[ "$block" == *'acfs_run_generated_category_phase "acfs" "10" || return 1'* ]]
    [[ "$block" == *'continuing legacy finalize for full runtime deployment parity'* ]]
    [[ "$block" != *$'\n        return 0'* ]]
}

@test "custom bin dir persists in state and nightly service PATH includes runtime bins" {
    local state_lib="$PROJECT_ROOT/scripts/lib/state.sh"
    local nightly="$PROJECT_ROOT/scripts/lib/nightly_update.sh"
    local service_template="$PROJECT_ROOT/scripts/templates/acfs-nightly-update.service"
    local global_wrapper="$PROJECT_ROOT/scripts/acfs-global"
    local update_wrapper="$PROJECT_ROOT/scripts/acfs-update"

    run grep -F 'bin_dir: $bin_dir,' "$state_lib"
    assert_success
    run grep -F '"bin_dir": "${ACFS_BIN_DIR:-$resolved_target_home/.local/bin}",' "$state_lib"
    assert_success

    run grep -F 'ACFS_BIN_DIR="$(read_bin_dir_from_state_file "$state_candidate" 2>/dev/null || true)"' "$nightly"
    assert_success
    run grep -F 'ACFS_BIN_DIR="$(sanitize_abs_nonroot_path "${ACFS_BIN_DIR:-}" 2>/dev/null || true)"' "$nightly"
    assert_success
    run grep -F '"$HOME/.acfs/bin/acfs-update"' "$nightly"
    assert_success
    run grep -F '%h/.acfs/bin:%h/.local/bin:%h/.cargo/bin:%h/.bun/bin:%h/.atuin/bin:%h/go/bin' "$service_template"
    assert_success

    run grep -F '[[ -n "$sanitized_bin_dir" ]] && env_args+=("ACFS_BIN_DIR=$sanitized_bin_dir")' "$global_wrapper"
    assert_success
    run grep -F '[[ -n "$sanitized_bin_dir" ]] && env_args+=("ACFS_BIN_DIR=$sanitized_bin_dir")' "$update_wrapper"
    assert_success
}

@test "install execution helpers preserve ACFS bootstrap context" {
    local installer="$PROJECT_ROOT/install.sh"
    local install_helpers="$PROJECT_ROOT/scripts/lib/install_helpers.sh"

    for context_var in \
        ACFS_BOOTSTRAP_DIR \
        ACFS_LIB_DIR \
        ACFS_GENERATED_DIR \
        ACFS_ASSETS_DIR \
        ACFS_CHECKSUMS_YAML \
        ACFS_MANIFEST_YAML \
        CHECKSUMS_FILE \
        SCRIPT_DIR \
        ACFS_RAW \
        ACFS_VERSION \
        ACFS_REF
    do
        local expected="env_args+=(\"$context_var=\$$context_var\")"

        run grep -F "$expected" "$installer"
        assert_success

        run bash -c 'grep -F "$1" "$2" | wc -l' _ "$expected" "$install_helpers"
        assert_success
        [[ "$output" -ge 2 ]] || fail "Expected $context_var in both target and root helper env allowlists"
    done

    run grep -F 'export CHECKSUMS_FILE="${ACFS_CHECKSUMS_YAML:-${CHECKSUMS_FILE:-}}"' "$installer"
    assert_success
}

@test "install.sh target-home contexts repair stale TARGET_HOME from passwd" {
    local installer="$PROJECT_ROOT/install.sh"

    run grep -F 'resolved_target_home="$(acfs_home_for_user "$TARGET_USER" 2>/dev/null || true)"' "$installer"
    assert_success

    run grep -F 'resolved_target_home="$(acfs_home_for_user "${TARGET_USER:-ubuntu}" 2>/dev/null || true)"' "$installer"
    assert_success

    run grep -F 'TARGET_HOME="${TARGET_HOME%/}"' "$installer"
    assert_success

    run grep -F 'resolved_target_home="${resolved_target_home%/}"' "$installer"
    assert_success

    run bash -c 'sed -n "/^acfs_summary_emit()/,/^}/p" "$1" | grep -F "[[ \"\$resolved_target_home\" == \"/\" ]]"' _ "$installer"
    assert_success

    run bash -c 'sed -n "/^init_target_paths()/,/^}/p" "$1" | grep -F "if [[ -z \"\${TARGET_HOME:-}\" ]]; then"' _ "$installer"
    assert_failure

    run bash -c 'sed -n "/^acfs_summary_emit()/,/^}/p" "$1" | grep -F "local resolved_target_home=\"\${TARGET_HOME:-}\""' _ "$installer"
    assert_failure
}

@test "install.sh: target install checks avoid inherited PATH leaks" {
    local installer="$PROJECT_ROOT/install.sh"

    run grep -F 'binary_path() {' "$installer"
    assert_success

    run grep -F 'if ! binary_installed "zsh"; then' "$installer"
    assert_success

    run grep -F 'if ! binary_installed "go"; then' "$installer"
    assert_success

    run grep -F 'if binary_installed "uv"; then' "$installer"
    assert_success

    run grep -F 'if [[ -d "$TARGET_HOME/.atuin" ]] || binary_installed "atuin"; then' "$installer"
    assert_success

    run grep -F 'if binary_installed "zoxide"; then' "$installer"
    assert_success

    run grep -F 'if binary_installed "gum"; then' "$installer"
    assert_success

    run grep -F 'if binary_installed "gh"; then' "$installer"
    assert_success

    run grep -F 'if ! binary_installed "lazygit"; then' "$installer"
    assert_success

    run grep -F 'if ! binary_installed "lazydocker"; then' "$installer"
    assert_success

    run grep -F 'elif psql_bin="$(binary_path psql 2>/dev/null || true)" && [[ -n "$psql_bin" ]]; then' "$installer"
    assert_success

    run grep -F 'elif vault_bin="$(binary_path vault 2>/dev/null || true)" && [[ -n "$vault_bin" ]]; then' "$installer"
    assert_success

    run grep -F 'binary_installed "go" || missing_lang+=("go")' "$installer"
    assert_success

    run grep -F 'gh_bin="$(binary_path gh 2>/dev/null || true)"' "$installer"
    assert_success

    run grep -F 'psql_bin="$(binary_path psql 2>/dev/null || true)"' "$installer"
    assert_success

    run grep -F 'vault_bin="$(binary_path vault 2>/dev/null || true)"' "$installer"
    assert_success

    run grep -F 'export PATH="${ACFS_BIN_DIR:-$HOME/.local/bin}:$HOME/.local/bin:$HOME/.acfs/bin:$HOME/.cargo/bin:$HOME/.bun/bin:$HOME/.atuin/bin:$HOME/go/bin:/usr/local/bin:/usr/bin:/bin:/snap/bin"' "$installer"
    assert_success

    run grep -F 'run_as_target bash -c "' "$installer"
    assert_success

    run grep -F 'export PATH=\"\${ACFS_BIN_DIR:-\$HOME/.local/bin}:\$HOME/.local/bin:\$HOME/.acfs/bin:\$HOME/.cargo/bin:\$HOME/.bun/bin:\$HOME/.atuin/bin:\$HOME/go/bin:/usr/local/bin:/usr/bin:/bin:/snap/bin\"' "$installer"
    assert_success

    run grep -F "if run_as_target bash -c 'set -euo pipefail" "$installer"
    assert_success

    run grep -F 'if ! command_exists zsh; then' "$installer"
    assert_failure

    run grep -F 'if ! command_exists go; then' "$installer"
    assert_failure

    run grep -F 'if command_exists gum; then' "$installer"
    assert_failure

    run grep -F 'if command_exists gh; then' "$installer"
    assert_failure

    run grep -F 'if ! command_exists lazygit; then' "$installer"
    assert_failure

    run grep -F 'if ! command_exists lazydocker; then' "$installer"
    assert_failure

    run grep -F 'elif command_exists psql; then' "$installer"
    assert_failure

    run grep -F 'elif command_exists vault; then' "$installer"
    assert_failure

    run grep -F 'command_exists go || missing_lang+=("go")' "$installer"
    assert_failure

    run grep -F "$(gh --version 2>/dev/null | head -1 || echo 'gh')" "$installer"
    assert_failure

    run grep -F "$(psql --version 2>/dev/null | head -1 || echo 'psql')" "$installer"
    assert_failure

    run grep -F "$(vault --version 2>/dev/null | head -1 || echo 'vault')" "$installer"
    assert_failure

    run grep -F 'command -v uv &>/dev/null' "$installer"
    assert_failure

    run grep -F 'command -v atuin &>/dev/null' "$installer"
    assert_failure

    run grep -F 'command -v zoxide &>/dev/null' "$installer"
    assert_failure
}

@test "install.sh: resolves target user and shell via trusted helpers" {
    local installer="$PROJECT_ROOT/install.sh"

    run grep -F '_ACFS_DETECTED_USER="$(acfs_early_resolve_current_user 2>/dev/null || true)"' "$installer"
    assert_success

    run grep -F 'passwd_entry="$(acfs_early_getent_passwd_entry "$user" 2>/dev/null || true)"' "$installer"
    assert_success

    run grep -F 'current_user="$(acfs_early_resolve_current_user 2>/dev/null || true)"' "$installer"
    assert_success

    run grep -F 'current_shell_entry="$(acfs_early_getent_passwd_entry "$TARGET_USER" 2>/dev/null || true)"' "$installer"
    assert_success

    run grep -F '$SUDO "$chsh_path" -s "$zsh_path" "$TARGET_USER"' "$installer"
    assert_success

    run grep -F '_ACFS_DETECTED_USER="${SUDO_USER:-$(whoami)}"' "$installer"
    assert_failure

    run grep -F 'passwd_entry="$(getent passwd "$user" 2>/dev/null || true)"' "$installer"
    assert_failure

    run grep -F 'current_shell=$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f7 || true)' "$installer"
    assert_failure
}

@test "packages/manifest generator emits trusted passwd and identity helpers" {
    local generator="$PROJECT_ROOT/packages/manifest/src/generate.ts"

    run grep -F 'acfs_generated_getent_passwd_entry() {' "$generator"
    assert_success

    run grep -F 'acfs_generated_passwd_home_from_entry() {' "$generator"
    assert_success

    run grep -F '_ACFS_DETECTED_USER="\${SUDO_USER:-\$(whoami)}"' "$generator"
    assert_failure

    run grep -F 'cut -d: -f6' "$generator"
    assert_failure

    run grep -F 'current_user="$(acfs_generated_resolve_current_user 2>/dev/null || true)"' "$generator"
    assert_success
}

@test "acfs.manifest inline shell blocks use trusted passwd and identity helpers" {
    local manifest="$PROJECT_ROOT/acfs.manifest.yaml"

    run grep -F 'acfs_generated_getent_passwd_entry "${TARGET_USER:-ubuntu}"' "$manifest"
    assert_success

    run grep -F 'acfs_generated_passwd_home_from_entry "$_acfs_passwd_entry"' "$manifest"
    assert_success

    run grep -F 'current_user="$(acfs_generated_resolve_current_user 2>/dev/null || true)"' "$manifest"
    assert_success

    run grep -F '_acfs_passwd_entry="$(getent passwd "${TARGET_USER:-ubuntu}" 2>/dev/null || true)"' "$manifest"
    assert_failure

    run grep -F 'target_home="$(printf '\''%s\n'\'' "$_acfs_passwd_entry" | cut -d: -f6)"' "$manifest"
    assert_failure

    run grep -F 'passwd_entry="$(getent passwd "$(whoami)" 2>/dev/null || true)"' "$manifest"
    assert_failure

    run grep -F 'sudo chsh -s "$zsh_path" "$(whoami)"' "$manifest"
    assert_failure
}

@test "install.sh: binary_path ignores current-shell-only PATH entries" {
    local installer="$PROJECT_ROOT/install.sh"

    init_stub_dir

    # shellcheck disable=SC1090
    eval "$(sed -n '/^binary_path()/,/^}$/p' "$installer")"
    # shellcheck disable=SC1090
    eval "$(sed -n '/^binary_installed()/,/^}$/p' "$installer")"

    export TARGET_HOME="$HOME/target-home"
    export ACFS_BIN_DIR="$TARGET_HOME/.local/bin"
    mkdir -p "$ACFS_BIN_DIR"

    cat > "$STUB_DIR/current-shell-only-tool" <<'EOF'
#!/usr/bin/env bash
echo "current-shell-only-tool"
EOF
    chmod +x "$STUB_DIR/current-shell-only-tool"
    export PATH="$STUB_DIR:/usr/bin:/bin"

    run binary_path "current-shell-only-tool"
    assert_failure

    cat > "$ACFS_BIN_DIR/current-shell-only-tool" <<'EOF'
#!/usr/bin/env bash
echo "target-local-tool"
EOF
    chmod +x "$ACFS_BIN_DIR/current-shell-only-tool"

    run binary_path "current-shell-only-tool"
    assert_success
    assert_output "$ACFS_BIN_DIR/current-shell-only-tool"

    run binary_installed "current-shell-only-tool"
    assert_success
}

@test "install.sh: smoke helper ignores current-shell-only PATH entries" {
    local installer="$PROJECT_ROOT/install.sh"

    init_stub_dir

    # shellcheck disable=SC1090
    eval "$(sed -n '/^_smoke_target_path()/,/^}$/p' "$installer")"
    # shellcheck disable=SC1090
    eval "$(sed -n '/^_smoke_run_as_target()/,/^}$/p' "$installer")"

    export TARGET_USER="tester"
    export TARGET_HOME="$HOME/target-home"
    export ACFS_BIN_DIR="$TARGET_HOME/.local/bin"
    mkdir -p "$ACFS_BIN_DIR"

    cat > "$STUB_DIR/current-shell-only-tool" <<'EOF'
#!/usr/bin/env bash
echo "current-shell-only-tool"
EOF
    chmod +x "$STUB_DIR/current-shell-only-tool"
    export PATH="$STUB_DIR:/usr/bin:/bin"

    run_as_target() {
        "$@"
    }

    run _smoke_run_as_target "command -v current-shell-only-tool >/dev/null && current-shell-only-tool --help >/dev/null 2>&1"
    assert_failure

    cat > "$ACFS_BIN_DIR/current-shell-only-tool" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--help" ]]; then
  exit 0
fi
exit 0
EOF
    chmod +x "$ACFS_BIN_DIR/current-shell-only-tool"

    run _smoke_run_as_target "command -v current-shell-only-tool >/dev/null && current-shell-only-tool --help >/dev/null 2>&1"
    assert_success
}

@test "smoke_test.sh: binary helper ignores current-shell-only PATH entries" {
    local smoke="$PROJECT_ROOT/scripts/lib/smoke_test.sh"

    init_stub_dir

    # shellcheck disable=SC1090
    eval "$(sed -n '/^_smoke_preferred_bin_dir()/,/^}$/p' "$smoke")"
    # shellcheck disable=SC1090
    eval "$(sed -n '/^_smoke_binary_path()/,/^}$/p' "$smoke")"
    # shellcheck disable=SC1090
    eval "$(sed -n '/^_smoke_binary_exists()/,/^}$/p' "$smoke")"

    export TARGET_HOME="$HOME/target-home"
    export _SMOKE_TARGET_HOME="$TARGET_HOME"
    export ACFS_BIN_DIR="$TARGET_HOME/.local/bin"
    mkdir -p "$ACFS_BIN_DIR"

    cat > "$STUB_DIR/current-shell-only-tool" <<'EOF'
#!/usr/bin/env bash
echo "current-shell-only-tool"
EOF
    chmod +x "$STUB_DIR/current-shell-only-tool"
    export PATH="$STUB_DIR:/usr/bin:/bin"

    run _smoke_binary_path "current-shell-only-tool"
    assert_failure

    run _smoke_binary_exists "current-shell-only-tool"
    assert_failure

    cat > "$ACFS_BIN_DIR/current-shell-only-tool" <<'EOF'
#!/usr/bin/env bash
echo "target-local-tool"
EOF
    chmod +x "$ACFS_BIN_DIR/current-shell-only-tool"

    run _smoke_binary_path "current-shell-only-tool"
    assert_success
    assert_output "$ACFS_BIN_DIR/current-shell-only-tool"

    run _smoke_binary_exists "current-shell-only-tool"
    assert_success
}

@test "cheatsheet.sh: prepend_user_paths prefers ACFS bin and skips missing dirs" {
    local cheatsheet="$PROJECT_ROOT/scripts/lib/cheatsheet.sh"
    local test_home
    local expected_path=""

    test_home="$(create_temp_dir)"
    mkdir -p "$test_home/custom-bin" "$test_home/.acfs/bin" "$test_home/google-cloud-sdk/bin"

    # shellcheck disable=SC1090
    eval "$(sed -n '/^cheatsheet_sanitize_abs_nonroot_path()/,/^}$/p' "$cheatsheet")"
    # shellcheck disable=SC1090
    eval "$(sed -n '/^cheatsheet_prepend_user_paths()/,/^}$/p' "$cheatsheet")"

    export ACFS_BIN_DIR="$test_home/custom-bin"
    PATH="/usr/bin:/bin"
    cheatsheet_prepend_user_paths "$test_home"

    expected_path="$test_home/custom-bin:$test_home/.acfs/bin:$test_home/google-cloud-sdk/bin:/usr/bin:/bin"
    [ "$PATH" = "$expected_path" ]
}

@test "cheatsheet.sh: parse_zshrc sees tools installed only in ACFS bins" {
    local cheatsheet="$PROJECT_ROOT/scripts/lib/cheatsheet.sh"
    local test_home
    local zshrc

    test_home="$(create_temp_dir)"
    zshrc="$test_home/acfs.zshrc"
    mkdir -p "$test_home/.acfs/bin" "$test_home/google-cloud-sdk/bin"

    cat > "$test_home/.acfs/bin/am" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    cat > "$test_home/google-cloud-sdk/bin/gcloud" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$test_home/.acfs/bin/am" "$test_home/google-cloud-sdk/bin/gcloud"

    cat > "$zshrc" <<'EOF'
# --- Agents ---
command -v am &>/dev/null && alias amserve='am serve-http'
command -v gcloud &>/dev/null && alias gbq='gcloud bq'
EOF

    # shellcheck disable=SC1090
    eval "$(sed -n '/^cheatsheet_sanitize_abs_nonroot_path()/,/^}$/p' "$cheatsheet")"
    # shellcheck disable=SC1090
    eval "$(sed -n '/^cheatsheet_prepend_user_paths()/,/^}$/p' "$cheatsheet")"
    # shellcheck disable=SC1090
    eval "$(sed -n '/^normalize_category()/,/^}$/p' "$cheatsheet")"
    # shellcheck disable=SC1090
    eval "$(sed -n '/^infer_category()/,/^}$/p' "$cheatsheet")"
    # shellcheck disable=SC1090
    eval "$(sed -n '/^cheatsheet_parse_zshrc()/,/^}$/p' "$cheatsheet")"

    export ACFS_BIN_DIR=""
    export CHEATSHEET_DELIM=$'	'
    PATH="/usr/bin:/bin"
    cheatsheet_prepend_user_paths "$test_home"

    run cheatsheet_parse_zshrc "$zshrc"

    assert_success
    assert_output --partial $'Agents	amserve	am serve-http	alias'
    assert_output --partial $'gbq	gcloud bq	alias'
}

@test "info.sh: prepend_user_paths preserves primary bin priority" {
    local info_lib="$PROJECT_ROOT/scripts/lib/info.sh"
    local test_home
    local expected_path=""

    test_home="$(create_temp_dir)"
    mkdir -p "$test_home/custom-bin" "$test_home/.acfs/bin" "$test_home/google-cloud-sdk/bin"

    info_preferred_bin_dir() { printf '%s\n' "$ACFS_BIN_DIR"; }
    # shellcheck disable=SC1090
    eval "$(sed -n '/^info_prepend_user_paths()/,/^}$/p' "$info_lib")"

    export ACFS_BIN_DIR="$test_home/custom-bin"
    PATH="/usr/bin:/bin"
    info_prepend_user_paths "$test_home"

    expected_path="$test_home/custom-bin:$test_home/.acfs/bin:$test_home/google-cloud-sdk/bin:/usr/bin:/bin"
    [ "$PATH" = "$expected_path" ]
}

@test "status.sh: prepend_user_paths preserves primary bin priority" {
    local status_lib="$PROJECT_ROOT/scripts/lib/status.sh"
    local test_home
    local expected_path=""

    test_home="$(create_temp_dir)"
    mkdir -p "$test_home/custom-bin" "$test_home/.acfs/bin" "$test_home/google-cloud-sdk/bin"

    _status_preferred_bin_dir() { printf '%s\n' "$ACFS_BIN_DIR"; }
    # shellcheck disable=SC1090
    eval "$(sed -n '/^_status_prepend_user_paths()/,/^}$/p' "$status_lib")"

    export ACFS_BIN_DIR="$test_home/custom-bin"
    PATH="/usr/bin:/bin"
    _status_prepend_user_paths "$test_home"

    expected_path="$test_home/custom-bin:$test_home/.acfs/bin:$test_home/google-cloud-sdk/bin:/usr/bin:/bin"
    [ "$PATH" = "$expected_path" ]
}

@test "export-config.sh: augment_path_for_target_user preserves primary bin priority" {
    local export_config="$PROJECT_ROOT/scripts/lib/export-config.sh"
    local test_home
    local expected_path=""

    test_home="$(create_temp_dir)"
    mkdir -p "$test_home/custom-bin" "$test_home/.acfs/bin" "$test_home/google-cloud-sdk/bin"

    # shellcheck disable=SC1090
    eval "$(sed -n '/^augment_path_for_target_user()/,/^}$/p' "$export_config")"

    export TARGET_HOME="$test_home"
    export ACFS_BIN_DIR="$test_home/custom-bin"
    PATH="/usr/bin:/bin"
    augment_path_for_target_user

    expected_path="$test_home/custom-bin:$test_home/.acfs/bin:$test_home/google-cloud-sdk/bin:/usr/bin:/bin"
    [ "$PATH" = "$expected_path" ]
}

@test "smoke_test.sh: prepend_user_paths preserves primary bin priority" {
    local smoke_lib="$PROJECT_ROOT/scripts/lib/smoke_test.sh"
    local test_home
    local expected_path=""

    test_home="$(create_temp_dir)"
    mkdir -p "$test_home/custom-bin" "$test_home/.acfs/bin" "$test_home/google-cloud-sdk/bin"

    _smoke_preferred_bin_dir() { printf '%s\n' "$ACFS_BIN_DIR"; }
    # shellcheck disable=SC1090
    eval "$(sed -n '/^_smoke_prepend_user_paths()/,/^}$/p' "$smoke_lib")"

    export ACFS_BIN_DIR="$test_home/custom-bin"
    PATH="/usr/bin:/bin"
    _smoke_prepend_user_paths "$test_home"

    expected_path="$test_home/custom-bin:$test_home/.acfs/bin:$test_home/google-cloud-sdk/bin:/usr/bin:/bin"
    [ "$PATH" = "$expected_path" ]
}

@test "info.sh: binary helper ignores current-shell-only PATH entries" {
    local info_lib="$PROJECT_ROOT/scripts/lib/info.sh"

    init_stub_dir

    # shellcheck disable=SC1090
    eval "$(sed -n '/^info_binary_path()/,/^}$/p' "$info_lib")"
    # shellcheck disable=SC1090
    eval "$(sed -n '/^info_binary_exists()/,/^}$/p' "$info_lib")"

    export TARGET_HOME="$HOME/target-home"
    export ACFS_BIN_DIR="$TARGET_HOME/.local/bin"
    mkdir -p "$ACFS_BIN_DIR"

    cat > "$STUB_DIR/current-shell-only-tool" <<'EOF'
#!/usr/bin/env bash
echo "current-shell-only-tool"
EOF
    chmod +x "$STUB_DIR/current-shell-only-tool"
    export PATH="$STUB_DIR:/usr/bin:/bin"

    run info_binary_path "current-shell-only-tool"
    assert_failure

    run info_binary_exists "current-shell-only-tool"
    assert_failure

    cat > "$ACFS_BIN_DIR/current-shell-only-tool" <<'EOF'
#!/usr/bin/env bash
echo "target-local-tool"
EOF
    chmod +x "$ACFS_BIN_DIR/current-shell-only-tool"

    run info_binary_path "current-shell-only-tool"
    assert_success
    assert_output "$ACFS_BIN_DIR/current-shell-only-tool"

    run info_binary_exists "current-shell-only-tool"
    assert_success
}

@test "update.sh: ensure_path dedupes primary bin and restores system PATH when empty" {
    local update="$PROJECT_ROOT/scripts/lib/update.sh"
    local test_home="$BATS_TEST_TMPDIR/update-home"
    local expected_path=""
    mkdir -p "$test_home/.local/bin" "$test_home/.acfs/bin" "$test_home/google-cloud-sdk/bin"

    run env -u TARGET_HOME -u ACFS_BIN_DIR HOME="$test_home" PATH="/usr/bin:/bin" bash -c 'source "$1"; ACFS_BIN_DIR=""; PATH=""; ensure_path; printf "%s\n" "$PATH"' _ "$update"
    assert_success

    expected_path="$test_home/.local/bin:$test_home/.acfs/bin:$test_home/google-cloud-sdk/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin"
    [ "$output" = "$expected_path" ]
}

@test "update.sh: ensure_path ignores relative ACFS_BIN_DIR when PATH is empty" {
    local update="$PROJECT_ROOT/scripts/lib/update.sh"
    local test_home="$BATS_TEST_TMPDIR/update-home-relative"
    local cwd="$BATS_TEST_TMPDIR/update-relative-cwd"
    local expected_path=""
    mkdir -p "$test_home/.local/bin" "$test_home/.acfs/bin" "$test_home/google-cloud-sdk/bin" "$cwd/relative/bin"

    run env -u TARGET_HOME -u ACFS_BIN_DIR HOME="$test_home" PATH="/usr/bin:/bin" bash -c 'cd "$3"; source "$1"; ACFS_BIN_DIR="relative/bin"; PATH=""; ensure_path; printf "%s\n" "$PATH"' _ "$update" unused "$cwd"
    assert_success

    expected_path="$test_home/.local/bin:$test_home/.acfs/bin:$test_home/google-cloud-sdk/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin"
    [ "$output" = "$expected_path" ]
}

@test "doctor.sh: defaults ACFS_SYSTEM_STATE_FILE to system state path" {
    local doctor_lib="$PROJECT_ROOT/scripts/lib/doctor.sh"
    local test_home

    test_home="$(create_temp_dir)"
    mkdir -p "$test_home"

    unset TARGET_USER TARGET_HOME ACFS_HOME ACFS_STATE_FILE ACFS_SYSTEM_STATE_FILE ACFS_BIN_DIR
    export HOME="$test_home"

    # shellcheck disable=SC1090
    eval "$(sed -n '/^_acfs_doctor_sanitize_abs_nonroot_path()/,/^}$/p' "$doctor_lib")"
    # shellcheck disable=SC1090
    eval "$(sed -n '/^_acfs_doctor_system_binary_path()/,/^}$/p' "$doctor_lib")"
    # shellcheck disable=SC1090
    eval "$(sed -n '/^_acfs_doctor_resolve_current_user()/,/^}$/p' "$doctor_lib")"
    # shellcheck disable=SC1090
    eval "$(sed -n '/^_acfs_doctor_getent_passwd_entry()/,/^}$/p' "$doctor_lib")"
    # shellcheck disable=SC1090
    eval "$(sed -n '/^_acfs_doctor_passwd_home_from_entry()/,/^}$/p' "$doctor_lib")"
    # shellcheck disable=SC1090
    eval "$(sed -n '/^_acfs_doctor_resolve_current_home()/,/^}$/p' "$doctor_lib")"
    # shellcheck disable=SC1090
    eval "$(sed -n '/^_acfs_doctor_current_home="\$(_acfs_doctor_resolve_current_home/,/^export TARGET_HOME ACFS_HOME ACFS_STATE_FILE ACFS_SYSTEM_STATE_FILE ACFS_BIN_DIR$/p' "$doctor_lib")"

    [[ "$ACFS_SYSTEM_STATE_FILE" == "/var/lib/acfs/state.json" ]]
}

@test "doctor.sh: passwd target home repairs stale inherited TARGET_HOME" {
    local doctor_lib="$PROJECT_ROOT/scripts/lib/doctor.sh"
    local test_current_user
    local test_trusted_home
    local test_stale_home

    test_current_user="$(command id -un 2>/dev/null || command whoami 2>/dev/null || true)"
    test_trusted_home="$(create_temp_dir)"
    test_stale_home="$(create_temp_dir)"

    # shellcheck disable=SC1090
    eval "$(sed -n '/^_acfs_doctor_sanitize_abs_nonroot_path()/,/^}$/p' "$doctor_lib")"
    # shellcheck disable=SC1090
    eval "$(sed -n '/^_acfs_doctor_passwd_home_from_entry()/,/^}$/p' "$doctor_lib")"

    _acfs_doctor_getent_passwd_entry() {
        if [[ "${1:-}" == "$test_current_user" ]]; then
            printf '%s:x:1000:1000::%s:/bin/bash\n' "$test_current_user" "$test_trusted_home"
            return 0
        fi
        return 1
    }

    _acfs_doctor_resolve_current_user() {
        printf '%s\n' "$test_current_user"
    }

    TARGET_USER="$test_current_user"
    TARGET_HOME="$test_stale_home"
    _ACFS_DOCTOR_ENV_TARGET_HOME="$test_stale_home"
    _acfs_doctor_current_home="$test_stale_home"

    # shellcheck disable=SC1090
    eval "$(sed -n '/^_acfs_doctor_resolved_target_home=""/,/^unset _acfs_doctor_resolved_target_home$/p' "$doctor_lib")"

    [[ "$TARGET_HOME" == "$test_trusted_home" ]] || {
        printf 'doctor TARGET_HOME was not repaired: %s\n' "$TARGET_HOME" >&2
        return 1
    }
}

@test "doctor manifest checks and fresh-vps heuristic repair stale TARGET_HOME" {
    local doctor_lib="$PROJECT_ROOT/scripts/lib/doctor.sh"
    local os_detect_lib="$PROJECT_ROOT/scripts/lib/os_detect.sh"

    run grep -F 'local resolved_target_home=""' "$doctor_lib"
    assert_success
    run grep -F 'resolved_target_home="$(_acfs_doctor_passwd_home_from_entry "$passwd_entry" 2>/dev/null || true)"' "$doctor_lib"
    assert_success
    run grep -F 'target_home="${resolved_target_home%/}"' "$doctor_lib"
    assert_success
    run grep -F 'target_home="${target_home%/}"' "$doctor_lib"
    assert_success
    run grep -F 'if [[ -z "$target_home" ]]; then' "$doctor_lib"
    assert_failure

    run grep -F 'resolved_target_home="$(os_detect_passwd_home_from_entry "$passwd_entry" 2>/dev/null || true)"' "$os_detect_lib"
    assert_success
    run grep -F 'target_home="${resolved_target_home%/}"' "$os_detect_lib"
    assert_success
    run grep -F 'target_home="${TARGET_HOME:-}"' "$os_detect_lib"
    assert_success
}

@test "read-only context helpers repair stale TARGET_HOME for current target user" {
    local current_user
    local current_home
    local stale_home
    local label
    local script
    local prepare_cmd
    local target_var
    local failures=""

    current_user="$(command id -un 2>/dev/null || command whoami 2>/dev/null || true)"
    current_home="$(command getent passwd "$current_user" 2>/dev/null | cut -d: -f6)"
    [[ -n "$current_user" && -n "$current_home" ]] || skip "Could not resolve current user home"
    stale_home="$(create_temp_dir)"

    while IFS='|' read -r label script prepare_cmd target_var; do
        [[ -n "$label" ]] || continue
        run env \
            TARGET_USER="$current_user" \
            TARGET_HOME="$stale_home" \
            HOME="$stale_home" \
            PATH="/usr/bin:/bin" \
            bash -c '
                set -euo pipefail
                source "$1"
                eval "$2"
                printf "%s\n" "${!3}"
            ' _ "$script" "$prepare_cmd" "$target_var"

        if [[ "$status" -ne 0 || "$output" != "$current_home" ]]; then
            printf -v failures '%s%s: status=%s output=%s\n' "$failures" "$label" "$status" "$output"
        fi
    done <<EOF
status|$PROJECT_ROOT/scripts/lib/status.sh|_status_prepare_context|TARGET_HOME
info|$PROJECT_ROOT/scripts/lib/info.sh|info_prepare_context|TARGET_HOME
export-config|$PROJECT_ROOT/scripts/lib/export-config.sh|prepare_target_context|TARGET_HOME
smoke|$PROJECT_ROOT/scripts/lib/smoke_test.sh|:|_SMOKE_TARGET_HOME
EOF

    if [[ -n "$failures" ]]; then
        printf '%s' "$failures" >&2
        return 1
    fi
}

@test "sourced current-home helpers prefer passwd home over stale HOME" {
    local current_user
    local current_home
    local stale_home
    local label
    local script
    local target_var
    local failures=""

    current_user="$(command id -un 2>/dev/null || command whoami 2>/dev/null || true)"
    current_home="$(command getent passwd "$current_user" 2>/dev/null | cut -d: -f6)"
    [[ -n "$current_user" && -n "$current_home" ]] || skip "Could not resolve current user home"
    stale_home="$(create_temp_dir)"

    while IFS='|' read -r label script target_var; do
        [[ -n "$label" ]] || continue
        run env \
            TARGET_USER="$current_user" \
            TARGET_HOME="$stale_home" \
            HOME="$stale_home" \
            PATH="/usr/bin:/bin" \
            bash -c '
                set -euo pipefail
                source "$1" >/dev/null
                printf "%s\n" "${!2}"
            ' _ "$script" "$target_var"

        if [[ "$status" -ne 0 || "$output" != "$current_home" ]]; then
            printf -v failures '%s%s: status=%s output=%s\n' "$failures" "$label" "$status" "$output"
        fi
    done <<EOF
support|$PROJECT_ROOT/scripts/lib/support.sh|_SUPPORT_CURRENT_HOME
status|$PROJECT_ROOT/scripts/lib/status.sh|_STATUS_CURRENT_HOME
dashboard|$PROJECT_ROOT/scripts/lib/dashboard.sh|_DASHBOARD_CURRENT_HOME
info|$PROJECT_ROOT/scripts/lib/info.sh|_INFO_CURRENT_HOME
continue|$PROJECT_ROOT/scripts/lib/continue.sh|_CONTINUE_CURRENT_HOME
cheatsheet|$PROJECT_ROOT/scripts/lib/cheatsheet.sh|_CHEATSHEET_CURRENT_HOME
changelog|$PROJECT_ROOT/scripts/lib/changelog.sh|_CHANGELOG_CURRENT_HOME
export-config|$PROJECT_ROOT/scripts/lib/export-config.sh|_EXPORT_CURRENT_HOME
smoke|$PROJECT_ROOT/scripts/lib/smoke_test.sh|_SMOKE_CURRENT_HOME
EOF

    if [[ -n "$failures" ]]; then
        printf '%s' "$failures" >&2
        return 1
    fi
}

@test "doctor.sh: ensure_path restores system PATH when empty" {
    local doctor_lib="$PROJECT_ROOT/scripts/lib/doctor.sh"
    local test_home="$BATS_TEST_TMPDIR/doctor-home"
    local expected_path=""
    mkdir -p "$test_home/.local/bin" "$test_home/.acfs/bin" "$test_home/google-cloud-sdk/bin"

    # shellcheck disable=SC1090
    eval "$(sed -n '/^_acfs_doctor_sanitize_abs_nonroot_path()/,/^}$/p' "$doctor_lib")"
    # shellcheck disable=SC1090
    eval "$(sed -n '/^_acfs_doctor_system_binary_path()/,/^}$/p' "$doctor_lib")"
    # shellcheck disable=SC1090
    eval "$(sed -n '/^_acfs_doctor_getent_passwd_entry()/,/^}$/p' "$doctor_lib")"
    # shellcheck disable=SC1090
    eval "$(sed -n '/^_acfs_doctor_passwd_home_from_entry()/,/^}$/p' "$doctor_lib")"
    # shellcheck disable=SC1090
    eval "$(sed -n '/^_acfs_doctor_validate_bin_dir_for_home()/,/^}$/p' "$doctor_lib")"
    # shellcheck disable=SC1090
    eval "$(sed -n '/^ensure_path()/,/^}$/p' "$doctor_lib")"

    export TARGET_HOME="$test_home"
    export ACFS_BIN_DIR=""
    _acfs_doctor_current_home="$test_home"
    # shellcheck disable=SC2123
    PATH=""
    ensure_path

    expected_path="$test_home/.local/bin:$test_home/.acfs/bin:$test_home/google-cloud-sdk/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin"
    [ "$PATH" = "$expected_path" ]
}

@test "doctor.sh: runtime path includes hardened system PATH once when PATH is empty" {
    local doctor_lib="$PROJECT_ROOT/scripts/lib/doctor.sh"
    local test_home="$BATS_TEST_TMPDIR/doctor-runtime-home"
    local original_path="${PATH-}"
    mkdir -p "$test_home/.local/bin" "$test_home/.acfs/bin" "$test_home/google-cloud-sdk/bin"

    # shellcheck disable=SC1090
    eval "$(sed -n '/^_acfs_doctor_sanitize_abs_nonroot_path()/,/^}$/p' "$doctor_lib")"
    # shellcheck disable=SC1090
    eval "$(sed -n '/^doctor_runtime_home()/,/^}$/p' "$doctor_lib")"
    # shellcheck disable=SC1090
    eval "$(sed -n '/^doctor_runtime_path()/,/^}$/p' "$doctor_lib")"

    export TARGET_HOME="$test_home"
    export ACFS_HOME=""
    export ACFS_BIN_DIR=""
    _acfs_doctor_current_home="$test_home"
    # shellcheck disable=SC2123
    PATH=""

    run doctor_runtime_path
    PATH="${original_path:-/usr/bin:/bin}"
    assert_success
    [ "$output" = "$test_home/.local/bin:$test_home/.acfs/bin:$test_home/.bun/bin:$test_home/.cargo/bin:$test_home/.atuin/bin:$test_home/go/bin:$test_home/google-cloud-sdk/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin" ]
}

@test "update.sh: target path includes google cloud sdk bin and hardened system PATH" {
    local update="$PROJECT_ROOT/scripts/lib/update.sh"
    local target_home="$BATS_TEST_TMPDIR/update-target-home"
    mkdir -p "$target_home"

    run env HOME="$target_home" PATH="/usr/bin:/bin" /bin/bash -c 'source "$1"; ACFS_BIN_DIR=""; PATH=""; update_target_path "$2"' _ "$update" "$target_home"
    assert_success
    [ "$output" = "$target_home/.local/bin:$target_home/.acfs/bin:$target_home/.bun/bin:$target_home/.cargo/bin:$target_home/.atuin/bin:$target_home/go/bin:$target_home/google-cloud-sdk/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin" ]
}

@test "update.sh: run_in_target_context rejects unresolved target_home before sudo" {
    local sudo_log="$BATS_TEST_TMPDIR/update-sudo.log"
    : > "$sudo_log"

    export TARGET_USER="missinguser"
    export TARGET_HOME="/"

    getent() {
        return 2
    }

    sudo() {
        echo "sudo-called=$*" >> "$sudo_log"
        return 0
    }

    run update_run_in_target_context "" printf unreachable
    assert_failure
    assert_output --partial "Unable to resolve TARGET_HOME for 'missinguser'; export TARGET_HOME explicitly"

    run cat "$sudo_log"
    assert_success
    assert_output ""
}

@test "doctor.sh: binary helper ignores current-shell-only PATH entries" {
    local doctor_lib="$PROJECT_ROOT/scripts/lib/doctor.sh"

    init_stub_dir

    # shellcheck disable=SC1090
    eval "$(sed -n '/^doctor_binary_path()/,/^}$/p' "$doctor_lib")"
    # shellcheck disable=SC1090
    eval "$(sed -n '/^doctor_binary_exists()/,/^}$/p' "$doctor_lib")"

    doctor_runtime_home() {
        printf '%s\n' "$TARGET_HOME"
    }

    export TARGET_HOME="$HOME/target-home"
    export ACFS_BIN_DIR="$TARGET_HOME/.local/bin"
    mkdir -p "$ACFS_BIN_DIR"

    cat > "$STUB_DIR/current-shell-only-tool" <<'EOF'
#!/usr/bin/env bash
echo "current-shell-only-tool"
EOF
    chmod +x "$STUB_DIR/current-shell-only-tool"
    export PATH="$STUB_DIR:/usr/bin:/bin"

    run doctor_binary_path "current-shell-only-tool"
    assert_failure

    run doctor_binary_exists "current-shell-only-tool"
    assert_failure

    cat > "$ACFS_BIN_DIR/current-shell-only-tool" <<'EOF'
#!/usr/bin/env bash
echo "target-local-tool"
EOF
    chmod +x "$ACFS_BIN_DIR/current-shell-only-tool"

    run doctor_binary_path "current-shell-only-tool"
    assert_success
    assert_output "$ACFS_BIN_DIR/current-shell-only-tool"

    run doctor_binary_exists "current-shell-only-tool"
    assert_success
}

@test "doctor.sh: check_command ignores current-shell-only PATH entries" {
    local doctor_lib="$PROJECT_ROOT/scripts/lib/doctor.sh"

    init_stub_dir

    # shellcheck disable=SC1090
    eval "$(sed -n '/^doctor_binary_path()/,/^}$/p' "$doctor_lib")"
    # shellcheck disable=SC1090
    eval "$(sed -n '/^doctor_binary_exists()/,/^}$/p' "$doctor_lib")"
    # shellcheck disable=SC1090
    eval "$(sed -n '/^get_version_line()/,/^}$/p' "$doctor_lib")"
    # shellcheck disable=SC1090
    eval "$(sed -n '/^check_command()/,/^}$/p' "$doctor_lib")"

    doctor_runtime_home() {
        printf '%s\n' "$TARGET_HOME"
    }

    check() {
        printf '%s|%s|%s|%s|%s\n' "$1" "$2" "$3" "${4:-}" "${5:-}"
    }

    export TARGET_HOME="$HOME/target-home"
    export ACFS_BIN_DIR="$TARGET_HOME/.local/bin"
    mkdir -p "$ACFS_BIN_DIR"

    cat > "$STUB_DIR/current-shell-only-tool" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
  echo "current-shell-only-tool 9.9.9"
  exit 0
fi
echo "current-shell-only-tool"
EOF
    chmod +x "$STUB_DIR/current-shell-only-tool"
    export PATH="$STUB_DIR:/usr/bin:/bin"

    run check_command "test.id" "Tool Label" "current-shell-only-tool" "fix me"
    assert_success
    assert_output 'test.id|Tool Label|fail|not found|fix me'

    cat > "$ACFS_BIN_DIR/current-shell-only-tool" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
  echo "target-local-tool 1.2.3"
  exit 0
fi
echo "target-local-tool"
EOF
    chmod +x "$ACFS_BIN_DIR/current-shell-only-tool"

    run check_command "test.id" "Tool Label" "current-shell-only-tool" "fix me"
    assert_success
    assert_output 'test.id|Tool Label (target-local-tool 1.2.3)|pass|installed|'
}

@test "doctor.sh: agent mail CLI helper ignores current-shell am and direct install without shim" {
    local doctor_lib="$PROJECT_ROOT/scripts/lib/doctor.sh"

    init_stub_dir

    # shellcheck disable=SC1090
    eval "$(sed -n '/^doctor_binary_path()/,/^}$/p' "$doctor_lib")"
    # shellcheck disable=SC1090
    eval "$(sed -n '/^doctor_agent_mail_cli_path()/,/^}$/p' "$doctor_lib")"

    doctor_runtime_home() {
        printf '%s\n' "$TARGET_HOME"
    }

    export TARGET_HOME="$HOME/target-home"
    export ACFS_BIN_DIR="$TARGET_HOME/.local/bin"
    mkdir -p "$TARGET_HOME/mcp_agent_mail" "$ACFS_BIN_DIR"

    cat > "$STUB_DIR/am" <<'EOF'
#!/usr/bin/env bash
echo "current-shell am"
EOF
    chmod +x "$STUB_DIR/am"
    export PATH="$STUB_DIR:/usr/bin:/bin"

    cat > "$TARGET_HOME/mcp_agent_mail/am" <<'EOF'
#!/usr/bin/env bash
echo "direct install"
EOF
    chmod +x "$TARGET_HOME/mcp_agent_mail/am"

    run doctor_agent_mail_cli_path
    assert_failure

    cat > "$ACFS_BIN_DIR/am" <<'EOF'
#!/usr/bin/env bash
echo "target shim"
EOF
    chmod +x "$ACFS_BIN_DIR/am"

    run doctor_agent_mail_cli_path
    assert_success
    assert_output "$ACFS_BIN_DIR/am"
}

@test "doctor.sh: agent mail doctor check uses target CLI instead of current-shell am" {
    local doctor_lib="$PROJECT_ROOT/scripts/lib/doctor.sh"

    init_stub_dir

    # shellcheck disable=SC1090
    eval "$(sed -n '/^doctor_binary_path()/,/^}$/p' "$doctor_lib")"
    # shellcheck disable=SC1090
    eval "$(sed -n '/^doctor_agent_mail_cli_path()/,/^}$/p' "$doctor_lib")"
    # shellcheck disable=SC1090
    eval "$(sed -n '/^agent_mail_doctor_check_json()/,/^}$/p' "$doctor_lib")"

    doctor_runtime_home() {
        printf '%s\n' "$TARGET_HOME"
    }

    run_with_timeout() {
        local _timeout="$1"
        local _description="$2"
        shift 2
        "$@"
    }

    export DEEP_CHECK_TIMEOUT=5
    export TARGET_HOME="$HOME/target-home"
    export ACFS_BIN_DIR="$TARGET_HOME/.local/bin"
    mkdir -p "$ACFS_BIN_DIR"

    cat > "$STUB_DIR/am" <<'EOF'
#!/usr/bin/env bash
: > "$HOME/global-am-used"
echo '{"healthy":false,"source":"global"}'
EOF
    chmod +x "$STUB_DIR/am"
    export PATH="$STUB_DIR:/usr/bin:/bin"

    cat > "$ACFS_BIN_DIR/am" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "doctor" && "${2:-}" == "check" && "${3:-}" == "--json" ]]; then
  echo '{"healthy":true,"source":"target"}'
  exit 0
fi
exit 1
EOF
    chmod +x "$ACFS_BIN_DIR/am"

    run agent_mail_doctor_check_json
    assert_success
    assert_output '{"healthy":true,"source":"target"}'
    [[ ! -f "$HOME/global-am-used" ]]
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


@test "update_preferred_user_bin_dir: ignores stale other-user ACFS_BIN_DIR" {
    local current_home
    local target_home
    local stale_home
    current_home="$(create_temp_dir)"
    target_home="$(create_temp_dir)"
    stale_home="$(create_temp_dir)"

    mkdir -p "$stale_home/.local/bin"

    export HOME="$current_home"
    export TARGET_USER="ubuntu"
    export TARGET_HOME="$target_home"
    export ACFS_BIN_DIR="$stale_home/.local/bin"
    unset ACFS_STATE_FILE
    unset ACFS_HOME

    getent() {
        if [[ "$1" == "passwd" && "${2:-}" == "ubuntu" ]]; then
            printf 'ubuntu:x:1000:1000::%s:/bin/bash\n' "$target_home"
            return 0
        fi
        if [[ "$1" == "passwd" && -z "${2:-}" ]]; then
            printf 'ubuntu:x:1000:1000::%s:/bin/bash\n' "$target_home"
            printf 'other:x:1001:1001::%s:/bin/bash\n' "$stale_home"
            return 0
        fi
        command getent "$@"
    }

    run update_preferred_user_bin_dir
    assert_success
    assert_output "$target_home/.local/bin"
}

@test "update_binary_path: ignores stale other-user ACFS_BIN_DIR when target binary exists" {
    local current_home
    local target_home
    local stale_home
    current_home="$(create_temp_dir)"
    target_home="$(create_temp_dir)"
    stale_home="$(create_temp_dir)"

    mkdir -p "$target_home/.local/bin" "$stale_home/.local/bin"

    export HOME="$current_home"
    export TARGET_USER="ubuntu"
    export TARGET_HOME="$target_home"
    export ACFS_BIN_DIR="$stale_home/.local/bin"
    unset ACFS_STATE_FILE
    unset ACFS_HOME

    cat > "$stale_home/.local/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "stale-home-gh"
EOF
    chmod +x "$stale_home/.local/bin/gh"

    cat > "$target_home/.local/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "target-home-gh"
EOF
    chmod +x "$target_home/.local/bin/gh"

    getent() {
        if [[ "$1" == "passwd" && "${2:-}" == "ubuntu" ]]; then
            printf 'ubuntu:x:1000:1000::%s:/bin/bash\n' "$target_home"
            return 0
        fi
        if [[ "$1" == "passwd" && -z "${2:-}" ]]; then
            printf 'ubuntu:x:1000:1000::%s:/bin/bash\n' "$target_home"
            printf 'other:x:1001:1001::%s:/bin/bash\n' "$stale_home"
            return 0
        fi
        command getent "$@"
    }

    run update_binary_path "gh"
    assert_success
    assert_output "$target_home/.local/bin/gh"
}

@test "update.sh: target path ignores stale other-user ACFS_BIN_DIR" {
    local target_home
    local stale_home
    target_home="$(create_temp_dir)"
    stale_home="$(create_temp_dir)"

    mkdir -p "$target_home/.local/bin" "$target_home/.acfs/bin" "$target_home/google-cloud-sdk/bin" "$stale_home/.local/bin"

    export TARGET_USER="ubuntu"
    export TARGET_HOME="$target_home"
    export ACFS_BIN_DIR="$stale_home/.local/bin"
    PATH="/usr/bin:/bin"

    getent() {
        if [[ "$1" == "passwd" && -z "${2:-}" ]]; then
            printf 'ubuntu:x:1000:1000::%s:/bin/bash\n' "$target_home"
            printf 'other:x:1001:1001::%s:/bin/bash\n' "$stale_home"
            return 0
        fi
        command getent "$@"
    }

    run update_target_path "$target_home"
    assert_success
    [[ "$output" == "$target_home/.local/bin:"* ]]
    refute_output --partial "$stale_home/.local/bin"
}

@test "update_require_security: ignores stale other-user ACFS_BIN_DIR" {
    local current_home
    local target_home
    local stale_home
    local target_marker
    local stale_marker
    current_home="$(create_temp_dir)"
    target_home="$(create_temp_dir)"
    stale_home="$(create_temp_dir)"
    target_marker="$BATS_TEST_TMPDIR/target-security.marker"
    stale_marker="$BATS_TEST_TMPDIR/stale-security.marker"

    mkdir -p "$target_home/.local/bin" "$stale_home/.local/bin"

    cat > "$target_home/.local/bin/security.sh" <<EOF
#!/usr/bin/env bash
load_checksums() {
    : > "$target_marker"
    return 0
}
EOF
    chmod +x "$target_home/.local/bin/security.sh"

    cat > "$stale_home/.local/bin/security.sh" <<EOF
#!/usr/bin/env bash
load_checksums() {
    : > "$stale_marker"
    return 0
}
EOF
    chmod +x "$stale_home/.local/bin/security.sh"

    export HOME="$current_home"
    export TARGET_USER="ubuntu"
    export TARGET_HOME="$target_home"
    export ACFS_BIN_DIR="$stale_home/.local/bin"
    export ACFS_HOME="$current_home/missing-acfs"
    unset ACFS_REPO_ROOT
    export CHECKSUMS_LOCAL="$current_home/checksums.yaml"
    UPDATE_SECURITY_READY=false

    refresh_checksums() {
        return 0
    }

    getent() {
        if [[ "$1" == "passwd" && "${2:-}" == "ubuntu" ]]; then
            printf 'ubuntu:x:1000:1000::%s:/bin/bash\n' "$target_home"
            return 0
        fi
        if [[ "$1" == "passwd" && -z "${2:-}" ]]; then
            printf 'ubuntu:x:1000:1000::%s:/bin/bash\n' "$target_home"
            printf 'other:x:1001:1001::%s:/bin/bash\n' "$stale_home"
            return 0
        fi
        command getent "$@"
    }

    run update_require_security
    assert_success
    [[ -f "$target_marker" ]]
    [[ ! -e "$stale_marker" ]]
}


@test "update_runtime_primary_bin_dir: fails closed for different unresolved target" {
    local current_home
    current_home="$(create_temp_dir)"

    mkdir -p "$current_home/.local/bin"

    export HOME="$current_home"
    export TARGET_USER="missinguser"
    export TARGET_HOME="/"
    export ACFS_BIN_DIR="$current_home/.local/bin"

    getent() {
        return 2
    }

    run update_runtime_primary_bin_dir
    assert_failure
}

@test "update_runtime_acfs_home: fails closed for different unresolved target" {
    local current_home
    current_home="$(create_temp_dir)"

    mkdir -p "$current_home/.acfs"

    export HOME="$current_home"
    export TARGET_USER="missinguser"
    export TARGET_HOME="/"
    export ACFS_HOME="$current_home/.acfs"

    getent() {
        return 2
    }

    run update_runtime_acfs_home
    assert_failure
}

@test "update_require_security: does not fall back to current HOME when different target is unresolved" {
    local current_home
    local bin_marker
    local acfs_marker
    current_home="$(create_temp_dir)"
    bin_marker="$BATS_TEST_TMPDIR/current-bin-security.marker"
    acfs_marker="$BATS_TEST_TMPDIR/current-acfs-security.marker"

    mkdir -p "$current_home/.local/bin" "$current_home/.acfs/scripts/lib"

    cat > "$current_home/.local/bin/security.sh" <<EOF
#!/usr/bin/env bash
load_checksums() {
    : > "$bin_marker"
    return 0
}
EOF
    chmod +x "$current_home/.local/bin/security.sh"

    cat > "$current_home/.acfs/scripts/lib/security.sh" <<EOF
#!/usr/bin/env bash
load_checksums() {
    : > "$acfs_marker"
    return 0
}
EOF
    chmod +x "$current_home/.acfs/scripts/lib/security.sh"

    export HOME="$current_home"
    export TARGET_USER="missinguser"
    export TARGET_HOME="/"
    export ACFS_BIN_DIR="$current_home/.local/bin"
    export ACFS_HOME="$current_home/.acfs"
    unset ACFS_REPO_ROOT
    export CHECKSUMS_LOCAL="$current_home/checksums.yaml"
    UPDATE_SECURITY_READY=false

    refresh_checksums() {
        return 0
    }

    getent() {
        return 2
    }

    run update_require_security
    assert_failure
    [[ ! -e "$bin_marker" ]]
    [[ ! -e "$acfs_marker" ]]
}

@test "refresh_checksums: does not fall back to current HOME when different target is unresolved" {
    local current_home
    local curl_marker
    current_home="$(create_temp_dir)"
    curl_marker="$BATS_TEST_TMPDIR/refresh-curl.marker"

    mkdir -p "$current_home/.acfs"

    export HOME="$current_home"
    export TARGET_USER="missinguser"
    export TARGET_HOME="/"
    export ACFS_HOME="$current_home/.acfs"
    export CHECKSUMS_LOCAL="$current_home/fallback-checksums.yaml"

    curl() {
        : > "$curl_marker"
        return 0
    }

    getent() {
        return 2
    }

    run refresh_checksums true
    assert_failure
    [[ ! -e "$curl_marker" ]]
    [[ ! -e "$current_home/.acfs/checksums.yaml" ]]
    [[ ! -e "$CHECKSUMS_LOCAL" ]]
}
