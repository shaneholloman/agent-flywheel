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

@test "update_target_home: ignores slash TARGET_HOME and uses passwd resolution" {
    local resolved_home
    resolved_home="$(create_temp_dir)"

    export TARGET_HOME="/"
    export HOME="/"

    getent() {
        if [[ "$1" == "passwd" && "$2" == "tester" ]]; then
            printf 'tester:x:1000:1000::%s:/bin/bash\n' "$resolved_home"
            return 0
        fi
        command getent "$@"
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

@test "services-setup: probes custom and ACFS bin dirs for target-user commands" {
    local services_setup="$PROJECT_ROOT/scripts/services-setup.sh"

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
}

@test "diagnostic helpers: prepend primary ACFS bin dir and ~/.acfs/bin" {
    local doctor="$PROJECT_ROOT/scripts/lib/doctor.sh"
    local info="$PROJECT_ROOT/scripts/lib/info.sh"
    local status_lib="$PROJECT_ROOT/scripts/lib/status.sh"
    local export_config="$PROJECT_ROOT/scripts/lib/export-config.sh"
    local smoke="$PROJECT_ROOT/scripts/lib/smoke_test.sh"
    local update="$PROJECT_ROOT/scripts/lib/update.sh"

    run grep -F 'local primary_bin_dir="${ACFS_BIN_DIR:-$primary_home/.local/bin}"' "$doctor"
    assert_success
    run grep -F 'target_path="$target_bin:$target_home/.local/bin:$target_home/.acfs/bin:$target_home/.bun/bin:$target_home/.cargo/bin:$target_home/.atuin/bin:$target_home/go/bin:${PATH:-/usr/local/bin:/usr/bin:/bin}"' "$doctor"
    assert_success

    run grep -F 'local primary_bin_dir="${ACFS_BIN_DIR:-$base_home/.local/bin}"' "$info"
    assert_success
    run grep -F '"$base_home/.acfs/bin"' "$info"
    assert_success

    run grep -F 'local primary_bin_dir="${ACFS_BIN_DIR:-$base_home/.local/bin}"' "$status_lib"
    assert_success
    run grep -F '"$base_home/.acfs/bin"' "$status_lib"
    assert_success

    run grep -F 'local primary_bin_dir="${ACFS_BIN_DIR:-$target_home/.local/bin}"' "$export_config"
    assert_success
    run grep -F '"$target_home/.acfs/bin"' "$export_config"
    assert_success

    run grep -F '_smoke_prepend_user_paths "$TARGET_HOME"' "$smoke"
    assert_success
    run grep -F 'local primary_bin_dir="${ACFS_BIN_DIR:-$base_home/.local/bin}"' "$smoke"
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
    run grep -F 'current_home="$(resolve_current_home 2>/dev/null || true)"' "$global_wrapper"
    assert_success
    run grep -F '[[ -n "$sanitized_state_file" ]] && env_args+=("ACFS_STATE_FILE=$sanitized_state_file")' "$global_wrapper"
    assert_success
    run grep -F '[[ -n "$sanitized_system_state_file" ]] && env_args+=("ACFS_SYSTEM_STATE_FILE=$sanitized_system_state_file")' "$global_wrapper"
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
    run grep -F 'current_home="$(resolve_current_home 2>/dev/null || true)"' "$update_wrapper"
    assert_success
    run grep -F '[[ -n "$sanitized_state_file" ]] && env_args+=("ACFS_STATE_FILE=$sanitized_state_file")' "$update_wrapper"
    assert_success
    run grep -F '[[ -n "$sanitized_system_state_file" ]] && env_args+=("ACFS_SYSTEM_STATE_FILE=$sanitized_system_state_file")' "$update_wrapper"
    assert_success
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

    run grep -F '[[ "$current_user" =~ ^[a-z_][a-z0-9._-]*$ ]]' "$services_setup"
    assert_success

    run grep -F '[[ "$user" =~ ^[a-z_][a-z0-9._-]*$ ]]' "$onboard"
    assert_success
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

@test "cloud_db username validation accepts dotted target usernames" {
    source_lib "cloud_db"

    run _cloud_validate_username "john.doe"
    assert_success
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
