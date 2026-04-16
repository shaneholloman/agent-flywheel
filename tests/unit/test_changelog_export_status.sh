#!/usr/bin/env bash
# shellcheck disable=SC1091
# ============================================================
# Targeted regression tests for changelog, export-config, and
# status output handling.
# Usage: bash tests/unit/test_changelog_export_status.sh
# ============================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHANGELOG_SH="$REPO_ROOT/scripts/lib/changelog.sh"
EXPORT_CONFIG_SH="$REPO_ROOT/scripts/lib/export-config.sh"
STATUS_SH="$REPO_ROOT/scripts/lib/status.sh"
INFO_SH="$REPO_ROOT/scripts/lib/info.sh"
SUPPORT_SH="$REPO_ROOT/scripts/lib/support.sh"
CHEATSHEET_SH="$REPO_ROOT/scripts/lib/cheatsheet.sh"
DASHBOARD_SH="$REPO_ROOT/scripts/lib/dashboard.sh"
DOCTOR_SH="$REPO_ROOT/scripts/lib/doctor.sh"
CONTINUE_SH="$REPO_ROOT/scripts/lib/continue.sh"
STATE_SH="$REPO_ROOT/scripts/lib/state.sh"
SMOKE_TEST_SH="$REPO_ROOT/scripts/lib/smoke_test.sh"
ONBOARD_SH="$REPO_ROOT/packages/onboard/onboard.sh"
SERVICES_SETUP_SH="$REPO_ROOT/scripts/services-setup.sh"
NOTIFY_SH="$REPO_ROOT/scripts/lib/notify.sh"
WEBHOOK_SH="$REPO_ROOT/scripts/lib/webhook.sh"
NOTIFICATIONS_SH="$REPO_ROOT/scripts/lib/notifications.sh"
AUTOFIX_SH="$REPO_ROOT/scripts/lib/autofix.sh"
AUTOFIX_EXISTING_SH="$REPO_ROOT/scripts/lib/autofix_existing.sh"

source "$REPO_ROOT/tests/vm/lib/test_harness.sh"

TEST_HOME=""
TEST_ACFS=""
TEST_REPO=""
TEST_INSTALL_HELPERS=""
TEST_MANIFEST_INDEX=""
TEST_ROOT_HOME=""
TEST_INSTALLED_ACFS=""
TEST_TARGET_HOME=""
TEST_FAKE_BIN=""
TEST_INSTALLED_HELPERS=""
TEST_INSTALLED_MANIFEST_INDEX=""
TEST_SYSTEM_STATE_FILE=""
TEST_DEV_REPO=""
RELATIVE_HOME=""
STALE_HOME=""

setup_mock_env() {
    TEST_HOME="$(mktemp -d)"
    TEST_ACFS="$TEST_HOME/.acfs"
    TEST_REPO="$TEST_HOME/mock-repo"
    mkdir -p "$TEST_ACFS" "$TEST_REPO"

    cat > "$TEST_ACFS/state.json" <<'JSON'
{
  "mode": "vibe \"quoted\"",
  "target_user": "tester",
  "started_at": "2026-03-09T08:00:00Z",
  "last_updated": "2026-03-10T12:34:56Z"
}
JSON

    printf '1.2.3 "beta"\n' > "$TEST_ACFS/VERSION"

    cat > "$TEST_REPO/CHANGELOG.md" <<'EOF'
# Changelog

## [1.2.3] - 2026-03-10

### Fixed
- Fixed "quoted" Windows path C:\temp
  Continued detail with	tab data

## [1.2.2] - 2026-03-01

### Added
- Legacy entry that should be filtered by the current state timestamp
EOF

    TEST_INSTALL_HELPERS="$TEST_HOME/mock_install_helpers.sh"
    TEST_MANIFEST_INDEX="$TEST_HOME/mock_manifest_index.sh"

    cat > "$TEST_INSTALL_HELPERS" <<'EOF'
#!/usr/bin/env bash
acfs_module_is_installed() {
    [[ "${TARGET_USER:-}" == "tester" ]] || return 1
    [[ "${TARGET_HOME:-}" == "/home/tester" ]] || return 1

    case "$1" in
        alpha|'module "beta" \\ path') return 0 ;;
        *) return 1 ;;
    esac
}
EOF
    chmod +x "$TEST_INSTALL_HELPERS"

    cat > "$TEST_MANIFEST_INDEX" <<'EOF'
#!/usr/bin/env bash
ACFS_MODULES_IN_ORDER=(
  "alpha"
  "module \"beta\" \\\\ path"
  "gamma"
)
ACFS_MANIFEST_INDEX_LOADED=true
EOF
    chmod +x "$TEST_MANIFEST_INDEX"
}

write_fake_command() {
    local path="$1"
    local output="$2"
    cat > "$path" <<EOF
#!/usr/bin/env bash
echo '$output'
EOF
    chmod +x "$path"
}

setup_installed_layout_env() {
    setup_mock_env

    TEST_ROOT_HOME="$TEST_HOME/root-home"
    TEST_INSTALLED_ACFS="$TEST_HOME/installed/.acfs"
    TEST_TARGET_HOME="$TEST_HOME/users/tester"
    TEST_FAKE_BIN="$TEST_HOME/fake-bin"
    TEST_INSTALLED_HELPERS="$TEST_HOME/installed_helpers.sh"
    TEST_INSTALLED_MANIFEST_INDEX="$TEST_HOME/installed_manifest_index.sh"

    mkdir -p \
        "$TEST_ROOT_HOME" \
        "$TEST_INSTALLED_ACFS/bin" \
        "$TEST_INSTALLED_ACFS/scripts/lib" \
        "$TEST_INSTALLED_ACFS/scripts/generated" \
        "$TEST_INSTALLED_ACFS/onboard/lessons" \
        "$TEST_TARGET_HOME/.oh-my-zsh" \
        "$TEST_TARGET_HOME/.local/bin" \
        "$TEST_TARGET_HOME/.bun/bin" \
        "$TEST_TARGET_HOME/.cargo/bin" \
        "$TEST_TARGET_HOME/go/bin" \
        "$TEST_TARGET_HOME/.atuin/bin" \
        "$TEST_FAKE_BIN"

    cp "$DOCTOR_SH" "$TEST_INSTALLED_ACFS/bin/acfs"
    cp "$STATUS_SH" "$TEST_INSTALLED_ACFS/scripts/lib/status.sh"
    cp "$CHANGELOG_SH" "$TEST_INSTALLED_ACFS/scripts/lib/changelog.sh"
    cp "$EXPORT_CONFIG_SH" "$TEST_INSTALLED_ACFS/scripts/lib/export-config.sh"
    cp "$INFO_SH" "$TEST_INSTALLED_ACFS/scripts/lib/info.sh"
    cp "$SUPPORT_SH" "$TEST_INSTALLED_ACFS/scripts/lib/support.sh"
    cp "$CONTINUE_SH" "$TEST_INSTALLED_ACFS/scripts/lib/continue.sh"

    cat > "$TEST_INSTALLED_ACFS/state.json" <<'JSON'
{
  "mode": "safe",
  "target_user": "tester",
  "started_at": "2026-03-09T08:00:00Z",
  "last_updated": "2026-03-10T12:34:56Z",
  "current_phase": { "id": "bootstrap" },
  "current_step": "Installing tools"
}
JSON
    printf '2.0.0\n' > "$TEST_INSTALLED_ACFS/VERSION"

    cat > "$TEST_INSTALLED_ACFS/CHANGELOG.md" <<'EOF'
# Changelog

## [2.0.0] - 2026-03-10

### Fixed
- Installed-layout root discovery now works correctly

## [1.9.0] - 2026-02-01

### Added
- Older entry that should be filtered out by last_updated
EOF
    printf '# Installed Lesson\n' > "$TEST_INSTALLED_ACFS/onboard/lessons/01_intro.md"

    cat > "$TEST_INSTALLED_HELPERS" <<EOF
#!/usr/bin/env bash
acfs_module_is_installed() {
    [[ "\${TARGET_USER:-}" == "tester" ]] || return 1
    [[ "\${TARGET_HOME:-}" == "$TEST_TARGET_HOME" ]] || return 1

    case "\$1" in
        alpha|'module "beta" \\\\ path') return 0 ;;
        *) return 1 ;;
    esac
}
EOF
    chmod +x "$TEST_INSTALLED_HELPERS"

    cat > "$TEST_INSTALLED_MANIFEST_INDEX" <<'EOF'
#!/usr/bin/env bash
ACFS_MODULES_IN_ORDER=(
  "alpha"
  "module \"beta\" \\\\ path"
  "gamma"
)
ACFS_MANIFEST_INDEX_LOADED=true
EOF
    chmod +x "$TEST_INSTALLED_MANIFEST_INDEX"

    cat > "$TEST_FAKE_BIN/getent" <<EOF
#!/usr/bin/env bash
if [[ "\$1" == "passwd" ]] && [[ "\$2" == "tester" ]]; then
    echo "tester:x:1000:1000::${TEST_TARGET_HOME}:/bin/bash"
    exit 0
fi
exit 2
EOF
    chmod +x "$TEST_FAKE_BIN/getent"

    cat > "$TEST_FAKE_BIN/pgrep" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x "$TEST_FAKE_BIN/pgrep"

    cat > "$TEST_FAKE_BIN/systemctl" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x "$TEST_FAKE_BIN/systemctl"

    write_fake_command "$TEST_TARGET_HOME/.local/bin/zsh" "zsh 5.9"
    write_fake_command "$TEST_TARGET_HOME/.local/bin/git" "git version 2.43.0"
    write_fake_command "$TEST_TARGET_HOME/.local/bin/tmux" "tmux 3.4"
    write_fake_command "$TEST_TARGET_HOME/.local/bin/rg" "ripgrep 14.1.0"
    write_fake_command "$TEST_TARGET_HOME/.local/bin/claude" "claude 1.2.3"
    write_fake_command "$TEST_TARGET_HOME/.local/bin/codex" "codex 1.2.3"
    write_fake_command "$TEST_TARGET_HOME/.local/bin/gemini" "gemini 1.2.3"
    write_fake_command "$TEST_TARGET_HOME/.local/bin/uv" "uv 0.8.0"
    write_fake_command "$TEST_TARGET_HOME/.local/bin/rustc" "rustc 1.85.0"
    write_fake_command "$TEST_TARGET_HOME/.local/bin/ntm" "ntm 1.2.3"
    write_fake_command "$TEST_TARGET_HOME/.bun/bin/bun" "1.2.3"
    write_fake_command "$TEST_TARGET_HOME/.cargo/bin/cargo" "cargo 1.85.0"
    write_fake_command "$TEST_TARGET_HOME/go/bin/go" "go version go1.24.0 linux/amd64"
}

setup_system_state_only_env() {
    setup_installed_layout_env

    TEST_SYSTEM_STATE_FILE="$TEST_HOME/system-state/state.json"
    mkdir -p "$(dirname "$TEST_SYSTEM_STATE_FILE")"
    mv "$TEST_INSTALLED_ACFS/state.json" "$TEST_INSTALLED_ACFS/state.user.bak"

    cat > "$TEST_SYSTEM_STATE_FILE" <<'JSON'
{
  "mode": "safe",
  "target_user": "tester",
  "started_at": "2026-03-09T08:00:00Z",
  "last_updated": "2026-03-10T12:34:56Z",
  "current_phase": { "id": "bootstrap" },
  "current_step": "Installing tools",
  "skipped_tools": ["ntm", "bv"]
}
JSON
}

setup_system_state_target_home_env() {
    setup_mock_env

    TEST_ROOT_HOME="$TEST_HOME/root-home"
    TEST_TARGET_HOME="$TEST_HOME/custom-home"
    TEST_INSTALLED_ACFS="$TEST_TARGET_HOME/.acfs"
    TEST_FAKE_BIN="$TEST_HOME/fake-bin"
    TEST_SYSTEM_STATE_FILE="$TEST_HOME/system-state/state.json"
    TEST_INSTALLED_HELPERS="$TEST_HOME/installed_helpers.sh"
    TEST_INSTALLED_MANIFEST_INDEX="$TEST_HOME/installed_manifest_index.sh"

    mkdir -p \
        "$TEST_ROOT_HOME" \
        "$TEST_INSTALLED_ACFS/onboard/lessons" \
        "$TEST_TARGET_HOME/.oh-my-zsh" \
        "$TEST_TARGET_HOME/.local/bin" \
        "$TEST_TARGET_HOME/.bun/bin" \
        "$TEST_TARGET_HOME/.cargo/bin" \
        "$TEST_TARGET_HOME/go/bin" \
        "$TEST_TARGET_HOME/.atuin/bin" \
        "$TEST_FAKE_BIN" \
        "$(dirname "$TEST_SYSTEM_STATE_FILE")"

    cat > "$TEST_INSTALLED_ACFS/state.json" <<'JSON'
{
  "mode": "safe",
  "target_user": "tester",
  "target_home": "/placeholder/overridden/by/system/state",
  "started_at": "2026-03-09T08:00:00Z",
  "last_updated": "2026-03-10T12:34:56Z",
  "current_phase": { "id": "bootstrap" },
  "current_step": "Installing tools"
}
JSON
    printf '2.0.0\n' > "$TEST_INSTALLED_ACFS/VERSION"

    cat > "$TEST_INSTALLED_ACFS/CHANGELOG.md" <<'EOF'
# Changelog

## [2.0.0] - 2026-03-10

### Fixed
- System-state target_home fallback now finds the real install
EOF

    printf '# Installed Lesson\n' > "$TEST_INSTALLED_ACFS/onboard/lessons/01_intro.md"

    cat > "$TEST_SYSTEM_STATE_FILE" <<EOF
{
  "mode": "safe",
  "target_user": "tester",
  "target_home": "$TEST_TARGET_HOME",
  "started_at": "2026-03-09T08:00:00Z",
  "last_updated": "2026-03-10T12:34:56Z",
  "current_phase": { "id": "bootstrap" },
  "current_step": "Installing tools"
}
EOF

    cat > "$TEST_INSTALLED_HELPERS" <<EOF
#!/usr/bin/env bash
acfs_module_is_installed() {
    [[ "\${TARGET_USER:-}" == "tester" ]] || return 1
    [[ "\${TARGET_HOME:-}" == "$TEST_TARGET_HOME" ]] || return 1

    case "\$1" in
        alpha|'module "beta" \\\\ path') return 0 ;;
        *) return 1 ;;
    esac
}
EOF
    chmod +x "$TEST_INSTALLED_HELPERS"

    cat > "$TEST_INSTALLED_MANIFEST_INDEX" <<'EOF'
#!/usr/bin/env bash
ACFS_MODULES_IN_ORDER=(
  "alpha"
  "module \"beta\" \\\\ path"
  "gamma"
)
ACFS_MANIFEST_INDEX_LOADED=true
EOF
    chmod +x "$TEST_INSTALLED_MANIFEST_INDEX"

    cat > "$TEST_FAKE_BIN/getent" <<'EOF'
#!/usr/bin/env bash
exit 2
EOF
    chmod +x "$TEST_FAKE_BIN/getent"

    cat > "$TEST_FAKE_BIN/pgrep" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x "$TEST_FAKE_BIN/pgrep"

    cat > "$TEST_FAKE_BIN/systemctl" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x "$TEST_FAKE_BIN/systemctl"

    write_fake_command "$TEST_TARGET_HOME/.local/bin/zsh" "zsh 5.9"
    write_fake_command "$TEST_TARGET_HOME/.local/bin/git" "git version 2.43.0"
    write_fake_command "$TEST_TARGET_HOME/.local/bin/tmux" "tmux 3.4"
    write_fake_command "$TEST_TARGET_HOME/.local/bin/rg" "ripgrep 14.1.0"
    write_fake_command "$TEST_TARGET_HOME/.local/bin/claude" "claude 1.2.3"
    write_fake_command "$TEST_TARGET_HOME/.local/bin/codex" "codex 1.2.3"
    write_fake_command "$TEST_TARGET_HOME/.local/bin/gemini" "gemini 1.2.3"
    write_fake_command "$TEST_TARGET_HOME/.local/bin/uv" "uv 0.8.0"
    write_fake_command "$TEST_TARGET_HOME/.local/bin/rustc" "rustc 1.85.0"
    write_fake_command "$TEST_TARGET_HOME/.local/bin/ntm" "ntm 1.2.3"
    write_fake_command "$TEST_TARGET_HOME/.bun/bin/bun" "1.2.3"
    write_fake_command "$TEST_TARGET_HOME/.cargo/bin/cargo" "cargo 1.85.0"
    write_fake_command "$TEST_TARGET_HOME/go/bin/go" "go version go1.24.0 linux/amd64"
}

setup_system_state_target_home_only_env() {
    setup_system_state_target_home_env

    cat > "$TEST_SYSTEM_STATE_FILE" <<EOF
{
  "mode": "safe",
  "target_home": "$TEST_TARGET_HOME",
  "started_at": "2026-03-09T08:00:00Z",
  "last_updated": "2026-03-10T12:34:56Z",
  "current_phase": { "id": "bootstrap" },
  "current_step": "Installing tools"
}
EOF
}

setup_relative_home_trap() {
    RELATIVE_HOME="relative-home"
    STALE_HOME="$TEST_HOME/$RELATIVE_HOME"
    mkdir -p "$STALE_HOME/.acfs"
}

cleanup_mock_env() {
    if [[ -n "$TEST_HOME" ]] && [[ -d "$TEST_HOME" ]]; then
        rm -rf "$TEST_HOME"
    fi
}

test_changelog_json_is_valid() {
    setup_mock_env

    local output
    output=$(ACFS_HOME="$TEST_ACFS" ACFS_REPO="$TEST_REPO" bash "$CHANGELOG_SH" --all --json)

    if printf '%s\n' "$output" | jq -e '.changes | length == 2' >/dev/null 2>&1; then
        harness_pass "changelog JSON stays valid with quotes, backslashes, and tabs"
    else
        harness_fail "changelog JSON stays valid with quotes, backslashes, and tabs"
    fi

    cleanup_mock_env
}

test_changelog_rejects_invalid_duration() {
    setup_mock_env

    local output=""
    local exit_code=0
    output=$(ACFS_HOME="$TEST_ACFS" ACFS_REPO="$TEST_REPO" bash "$CHANGELOG_SH" --since nonsense 2>&1) || exit_code=$?

    if [[ "$exit_code" -ne 0 ]] && [[ "$output" == *"invalid duration"* ]]; then
        harness_pass "changelog rejects malformed --since values"
    else
        harness_fail "changelog rejects malformed --since values" "exit=$exit_code output=$output"
    fi

    cleanup_mock_env
}

test_services_setup_prefers_target_home_libs_under_root_home() {
    setup_mock_env

    local root_home="$TEST_HOME/root-home"
    local target_home="$TEST_HOME/target-home"
    local output=""

    mkdir -p \
        "$root_home/.acfs/scripts/lib" \
        "$target_home/.acfs/scripts/lib" \
        "$target_home/.acfs/scripts"

    cp "$SERVICES_SETUP_SH" "$target_home/.acfs/scripts/services-setup.sh"

    cat > "$root_home/.acfs/scripts/lib/logging.sh" <<'EOF'
#!/usr/bin/env bash
log_error() { echo "ROOT_LOG_ERROR:$*"; }
log_info() { :; }
log_warn() { :; }
log_success() { :; }
EOF

    cat > "$root_home/.acfs/scripts/lib/gum_ui.sh" <<'EOF'
#!/usr/bin/env bash
HAS_GUM=false
ACFS_ACCENT=x
ACFS_PINK=x
ACFS_MUTED=x
ACFS_TEAL=x
ACFS_PRIMARY=x
ACFS_SUCCESS=x
ACFS_ERROR=x
print_compact_banner() { :; }
gum_detail() { :; }
gum_error() { echo "ROOT_GUM_ERROR:$*"; }
gum_warn() { :; }
gum_confirm() { return 1; }
gum_completion() { :; }
EOF

    cat > "$target_home/.acfs/scripts/lib/logging.sh" <<'EOF'
#!/usr/bin/env bash
log_error() { echo "TARGET_LOG_ERROR:$*"; }
log_info() { :; }
log_warn() { :; }
log_success() { :; }
EOF

    cat > "$target_home/.acfs/scripts/lib/gum_ui.sh" <<'EOF'
#!/usr/bin/env bash
HAS_GUM=false
ACFS_ACCENT=x
ACFS_PINK=x
ACFS_MUTED=x
ACFS_TEAL=x
ACFS_PRIMARY=x
ACFS_SUCCESS=x
ACFS_ERROR=x
print_compact_banner() { :; }
gum_detail() { :; }
gum_error() { echo "TARGET_GUM_ERROR:$*"; }
gum_warn() { :; }
gum_confirm() { return 1; }
gum_completion() { :; }
EOF

    output=$(HOME="$root_home" TARGET_HOME="$target_home" TARGET_USER="$(whoami)" \
        bash "$target_home/.acfs/scripts/services-setup.sh" --install-claude-guard --yes 2>&1 || true)

    if [[ "$output" == *"TARGET_GUM_ERROR:DCG not installed. Run the main installer first."* ]] \
        && [[ "$output" != *"ROOT_GUM_ERROR:"* ]]; then
        harness_pass "services-setup prefers target-home libs under root home"
    else
        harness_fail "services-setup prefers target-home libs under root home" "$output"
    fi

    cleanup_mock_env
}

test_services_setup_runs_target_user_commands_with_target_home() {
    setup_mock_env

    local root_home="$TEST_HOME/root-home"
    local target_home="$TEST_HOME/target-home"
    local output=""

    mkdir -p \
        "$root_home/.acfs/scripts/lib" \
        "$target_home/.acfs/scripts/lib" \
        "$target_home/.acfs/scripts" \
        "$target_home/.local/bin" \
        "$target_home/.claude"

    cp "$SERVICES_SETUP_SH" "$target_home/.acfs/scripts/services-setup.sh"

    cat > "$target_home/.acfs/scripts/lib/logging.sh" <<'EOF'
#!/usr/bin/env bash
log_error() { echo "TARGET_LOG_ERROR:$*"; }
log_info() { :; }
log_warn() { :; }
log_success() { :; }
EOF

    cat > "$target_home/.acfs/scripts/lib/gum_ui.sh" <<'EOF'
#!/usr/bin/env bash
HAS_GUM=false
ACFS_ACCENT=x
ACFS_PINK=x
ACFS_MUTED=x
ACFS_TEAL=x
ACFS_PRIMARY=x
ACFS_SUCCESS=x
ACFS_ERROR=x
print_compact_banner() { :; }
gum_box() { :; }
gum_detail() { :; }
gum_error() { echo "TARGET_GUM_ERROR:$*"; }
gum_warn() { :; }
gum_success() { :; }
gum_confirm() { return 1; }
gum_completion() { :; }
EOF

    cat > "$target_home/.local/bin/claude" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    cat > "$target_home/.local/bin/dcg" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
    install)
        mkdir -p "$HOME/.claude"
        printf '{"hook":"dcg"}\n' > "$HOME/.claude/settings.json"
        printf '%s\n' "$HOME" >> "${TARGET_HOME}/dcg-home.log"
        exit 0
        ;;
    doctor)
        printf '%s\n' "$HOME" >> "${TARGET_HOME}/dcg-home.log"
        exit 0
        ;;
    *)
        exit 0
        ;;
esac
EOF
    chmod +x "$target_home/.local/bin/claude" "$target_home/.local/bin/dcg"

    output=$(HOME="$root_home" TARGET_HOME="$target_home" TARGET_USER="$(whoami)" \
        PATH="$target_home/.local/bin:/usr/bin:/bin" \
        bash "$target_home/.acfs/scripts/services-setup.sh" --install-claude-guard --yes 2>&1 || true)

    if [[ -f "$target_home/.claude/settings.json" ]] \
        && [[ ! -f "$root_home/.claude/settings.json" ]] \
        && [[ -f "$target_home/dcg-home.log" ]] \
        && grep -Fxq "$target_home" "$target_home/dcg-home.log" \
        && ! grep -Fxq "$root_home" "$target_home/dcg-home.log"; then
        harness_pass "services-setup runs target-user commands with target HOME"
    else
        harness_fail "services-setup runs target-user commands with target HOME" "$output"
    fi

    cleanup_mock_env
}

test_services_setup_rejects_invalid_target_user_before_sudo() {
    setup_mock_env

    local root_home="$TEST_HOME/root-home"
    local target_home="$TEST_HOME/target-home"
    local fake_bin="$TEST_HOME/fake-bin"
    local sudo_log="$TEST_HOME/sudo.log"
    local output=""

    mkdir -p "$root_home" "$target_home" "$fake_bin"

    cat > "$fake_bin/sudo" <<EOF
#!/usr/bin/env bash
printf 'sudo-called\n' >> "$sudo_log"
exit 0
EOF
    chmod +x "$fake_bin/sudo"

    output=$(HOME="$root_home" TARGET_HOME="$target_home" PATH="$fake_bin:/usr/bin:/bin" \
        bash -c 'source "$1"; TARGET_USER="../bad user"; run_as_user env' _ "$SERVICES_SETUP_SH" 2>&1 || true)

    if [[ "$output" == *"Invalid TARGET_USER '../bad user'"* ]] \
        && [[ ! -s "$sudo_log" ]]; then
        harness_pass "services-setup rejects invalid TARGET_USER before sudo"
    else
        harness_fail "services-setup rejects invalid TARGET_USER before sudo" "$output"
    fi

    cleanup_mock_env
}

test_services_setup_globals_are_initialized_under_set_u() {
    setup_mock_env

    local output=""
    output=$(bash -c '
        set -u
        source "$1"
        printf "services=%s\n" "${#SERVICE_STATUS[@]}"
    ' _ "$SERVICES_SETUP_SH" 2>&1 || true)

    if [[ "$output" == "services=0" ]]; then
        harness_pass "services-setup initializes SERVICE_STATUS safely under set -u"
    else
        harness_fail "services-setup initializes SERVICE_STATUS safely under set -u" "$output"
    fi

    cleanup_mock_env
}

test_services_setup_setup_flows_tolerate_unset_status_keys() {
    setup_mock_env

    local target_home="$TEST_HOME/setup-status-target"
    local output=""
    mkdir -p "$target_home/.bun/bin"
    ln -sf /bin/true "$target_home/.bun/bin/vercel"
    ln -sf /bin/true "$target_home/.bun/bin/wrangler"

    output=$(bash -c '
        set -u
        source "$1"
        TARGET_USER="$(whoami)"
        TARGET_HOME="$2"
        BUN_BIN=/bin/true
        HAS_GUM=false
        gum_confirm() { return 1; }
        gum_box() { :; }
        gum_detail() { :; }
        gum_error() { :; }
        gum_warn() { :; }
        gum_success() { :; }
        read() { return 0; }
        find_user_bin() { printf "/bin/true\n"; }
        run_as_user() { return 0; }
        check_claude_status() { SERVICE_STATUS[claude]=configured; }
        check_codex_status() { SERVICE_STATUS[codex]=configured; }
        check_gemini_status() { SERVICE_STATUS[gemini]=configured; }
        check_vercel_status() { SERVICE_STATUS[vercel]=configured; }
        check_supabase_status() { SERVICE_STATUS[supabase]=configured; }
        check_wrangler_status() { SERVICE_STATUS[wrangler]=configured; }
        setup_claude </dev/null
        setup_codex </dev/null
        setup_gemini </dev/null
        setup_vercel </dev/null
        setup_supabase </dev/null
        setup_wrangler </dev/null
        printf "setup-ok\n"
    ' _ "$SERVICES_SETUP_SH" "$target_home" 2>&1 || true)

    if [[ "$output" == *"setup-ok"* ]]; then
        harness_pass "services-setup setup flows tolerate unset SERVICE_STATUS keys under set -u"
    else
        harness_fail "services-setup setup flows tolerate unset SERVICE_STATUS keys under set -u" "$output"
    fi

    cleanup_mock_env
}

test_notify_uses_target_home_for_config_and_state_when_home_is_relative() {
    setup_mock_env

    local target_home="$TEST_HOME/notify-target"
    mkdir -p "$target_home/.config/acfs"

    cat > "$target_home/.config/acfs/config.yaml" <<'EOF'
ntfy_topic: target-topic
EOF

    local output=""
    output=$(cd "$TEST_HOME" && HOME="relative-home" TARGET_HOME="$target_home" \
        bash -c '
            log_warn() { :; }
            log_detail() { :; }
            unset _ACFS_NOTIFY_SH_LOADED
            source "$1"
            printf "topic=%s\n" "$(_acfs_notify_config_read ntfy_topic)"
            printf "state=%s\n" "${_ACFS_NOTIFY_STATE_DIR:-}"
        ' _ "$NOTIFY_SH" 2>&1)

    if [[ "$output" == *"topic=target-topic"* ]] \
        && [[ "$output" == *"state=$target_home/.cache/acfs/notify"* ]]; then
        harness_pass "notify uses target_home for config and state when HOME is relative"
    else
        harness_fail "notify uses target_home for config and state when HOME is relative" "$output"
    fi

    cleanup_mock_env
}

test_webhook_reads_config_from_target_home_when_home_is_relative() {
    setup_mock_env

    local target_home="$TEST_HOME/webhook-target"
    mkdir -p "$target_home/.config/acfs"

    cat > "$target_home/.config/acfs/config.yaml" <<'EOF'
webhook_url: "https://example.com/hook"
EOF

    local output=""
    output=$(cd "$TEST_HOME" && HOME="relative-home" TARGET_HOME="$target_home" \
        bash -c '
            log_warn() { :; }
            log_detail() { :; }
            unset _ACFS_WEBHOOK_SH_LOADED ACFS_WEBHOOK_URL
            source "$1"
            webhook_read_config
            printf "%s\n" "${ACFS_WEBHOOK_URL:-}"
        ' _ "$WEBHOOK_SH" 2>&1)

    if [[ "$output" == "https://example.com/hook" ]]; then
        harness_pass "webhook reads config from target_home when HOME is relative"
    else
        harness_fail "webhook reads config from target_home when HOME is relative" "$output"
    fi

    cleanup_mock_env
}

test_notifications_cli_uses_target_home_when_home_is_relative() {
    setup_mock_env

    local target_home="$TEST_HOME/notifications-target"
    mkdir -p "$target_home/.config/acfs"

    cat > "$target_home/.config/acfs/config.yaml" <<'EOF'
ntfy_enabled: true
ntfy_topic: cli-topic
ntfy_server: https://ntfy.example
EOF

    local output=""
    output=$(cd "$TEST_HOME" && HOME="relative-home" TARGET_HOME="$target_home" \
        bash "$NOTIFICATIONS_SH" status 2>&1)

    if [[ "$output" == *"Topic:         cli-topic"* ]] \
        && [[ "$output" == *"Server:        https://ntfy.example"* ]] \
        && [[ "$output" == *"Config file:   $target_home/.config/acfs/config.yaml"* ]]; then
        harness_pass "notifications CLI uses target_home when HOME is relative"
    else
        harness_fail "notifications CLI uses target_home when HOME is relative" "$output"
    fi

    cleanup_mock_env
}

test_autofix_uses_target_home_for_state_dir_when_home_is_relative() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-target"
    mkdir -p "$target_home"

    local output=""
    output=$(cd "$TEST_HOME" && HOME="relative-home" TARGET_HOME="$target_home" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED
            source "$1"
            printf "%s\n" "$ACFS_STATE_DIR"
        ' _ "$AUTOFIX_SH" 2>&1)

    if [[ "$output" == "$target_home/.acfs/autofix" ]]; then
        harness_pass "autofix uses target_home for state dir when HOME is relative"
    else
        harness_fail "autofix uses target_home for state dir when HOME is relative" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_detects_target_home_install_when_home_is_relative() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-target"
    mkdir -p "$target_home/.acfs"

    local output=""
    output=$(cd "$TEST_HOME" && HOME="relative-home" TARGET_HOME="$target_home" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            detect_existing_acfs
        ' _ "$AUTOFIX_EXISTING_SH" 2>&1)

    if [[ "$output" == *"$target_home/.acfs"* ]] && [[ "$output" != *"relative-home/.acfs"* ]]; then
        harness_pass "autofix_existing detects target_home install when HOME is relative"
    else
        harness_fail "autofix_existing detects target_home install when HOME is relative" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_reads_target_home_version_under_root_home() {
    setup_mock_env

    local root_home="$TEST_HOME/root-home"
    local target_home="$TEST_HOME/autofix-existing-version-target"
    mkdir -p "$root_home/.acfs" "$target_home/.acfs"
    printf '0.0.1\n' > "$root_home/.acfs/version"
    printf '9.9.9\n' > "$target_home/.acfs/version"

    local output=""
    output=$(HOME="$root_home" TARGET_HOME="$target_home" PATH="/usr/bin:/bin" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            get_installed_version
        ' _ "$AUTOFIX_EXISTING_SH" 2>&1)

    if [[ "$output" == "9.9.9" ]]; then
        harness_pass "autofix_existing reads target_home version under root home"
    else
        harness_fail "autofix_existing reads target_home version under root home" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_prefers_target_home_over_poisoned_acfs_home() {
    setup_mock_env

    local root_home="$TEST_HOME/root-home"
    local target_home="$TEST_HOME/autofix-existing-poison-target"
    local poisoned_acfs_home="$TEST_HOME/poisoned/.acfs"
    mkdir -p "$root_home" "$target_home/.acfs" "$poisoned_acfs_home"
    printf '8.8.8\n' > "$poisoned_acfs_home/version"
    printf '9.9.9\n' > "$target_home/.acfs/version"

    local output=""
    output=$(HOME="$root_home" TARGET_HOME="$target_home" ACFS_HOME="$poisoned_acfs_home" PATH="/usr/bin:/bin" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            get_installed_version
        ' _ "$AUTOFIX_EXISTING_SH" 2>&1)

    if [[ "$output" == "9.9.9" ]]; then
        harness_pass "autofix_existing prefers target_home over poisoned ACFS_HOME"
    else
        harness_fail "autofix_existing prefers target_home over poisoned ACFS_HOME" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_backup_preserves_distinct_relative_paths() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-backup-target"
    mkdir -p "$target_home/.acfs" "$target_home/.config/acfs" "$target_home/.local/bin"
    printf 'config\n' > "$target_home/.config/acfs/settings.toml"
    printf '#!/usr/bin/env bash\n' > "$target_home/.local/bin/acfs"
    chmod +x "$target_home/.local/bin/acfs"

    local backup_dir=""
    backup_dir=$(HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            create_installation_backup
        ' _ "$AUTOFIX_EXISTING_SH" 2>/dev/null)

    if [[ -d "$backup_dir/.config/acfs" ]] && [[ -f "$backup_dir/.local/bin/acfs" ]]; then
        harness_pass "autofix_existing backup preserves distinct relative paths"
    else
        harness_fail "autofix_existing backup preserves distinct relative paths" "$backup_dir"
    fi

    cleanup_mock_env
}

test_autofix_existing_clean_reinstall_records_manifest_backups() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-clean-target"
    mkdir -p "$target_home/.acfs/bin" "$target_home/.config/acfs" "$target_home/.local/bin"
    printf 'installed\n' > "$target_home/.acfs/version"
    printf '#!/usr/bin/env bash\n' > "$target_home/.acfs/bin/acfs-real"
    chmod +x "$target_home/.acfs/bin/acfs-real"
    printf 'config\n' > "$target_home/.config/acfs/settings.toml"
    ln -s "$target_home/.acfs/bin/acfs-real" "$target_home/.local/bin/acfs"

    local output=""
    output=$(HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            start_autofix_session >/dev/null 2>&1 || exit 1
            clean_reinstall >/dev/null 2>&1 || exit 1
            end_autofix_session >/dev/null 2>&1 || true
            jq -c "{reversible: .reversible, backups: .backups}" "$ACFS_CHANGES_FILE"
        ' _ "$AUTOFIX_EXISTING_SH" 2>/dev/null)

    if printf '%s\n' "$output" | jq -e '
        .reversible == false
        and (.backups | type == "array")
        and (.backups | length > 0)
        and all(.backups[]; (.backup? != null) and (.original? != null))
        and all(.backups[]; ((.checksum // "") | length) > 0)
        and all(.backups[]; ((.path_type // "") | length) > 0)
        and any(.backups[]; .original == "'"$target_home"'/.local/bin/acfs" and .path_type == "symlink")
    ' >/dev/null 2>&1; then
        harness_pass "autofix_existing clean reinstall records manifest backups"
    else
        harness_fail "autofix_existing clean reinstall records manifest backups" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_clean_reinstall_aborts_when_recording_fails() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-clean-record-fail-target"
    mkdir -p "$target_home/.acfs" "$target_home/.config/acfs" "$target_home/.local/bin"
    printf 'installed\n' > "$target_home/.acfs/version"
    printf 'config\n' > "$target_home/.config/acfs/settings.toml"
    printf '#!/usr/bin/env bash\n' > "$target_home/.local/bin/acfs"
    chmod +x "$target_home/.local/bin/acfs"

    local output=""
    output=$(HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            record_change() { return 1; }
            start_autofix_session >/dev/null 2>&1 || exit 1
            if clean_reinstall >/dev/null 2>&1; then
                result="success"
            else
                result="failure"
            fi
            end_autofix_session >/dev/null 2>&1 || true
            jq -nc \
                --arg result "$result" \
                --arg version_exists "$(test -f "$TARGET_HOME/.acfs/version" && echo yes || echo no)" \
                --arg config_exists "$(test -f "$TARGET_HOME/.config/acfs/settings.toml" && echo yes || echo no)" \
                --arg binary_exists "$(test -f "$TARGET_HOME/.local/bin/acfs" && echo yes || echo no)" \
                --arg state_dir_exists "$(test -d "$TARGET_HOME/.acfs/autofix" && echo yes || echo no)" \
                --arg relocated_state_count "$(find "$TARGET_HOME" -maxdepth 1 -type d -name ".acfs-autofix-clean.*" | wc -l | tr -d " ")" \
                "{result: \$result, version_exists: \$version_exists, config_exists: \$config_exists, binary_exists: \$binary_exists, state_dir_exists: \$state_dir_exists, relocated_state_count: \$relocated_state_count}"
        ' _ "$AUTOFIX_EXISTING_SH" 2>/dev/null)

    if printf '%s\n' "$output" | jq -e '
        .result == "failure"
        and .version_exists == "yes"
        and .config_exists == "yes"
        and .binary_exists == "yes"
        and .state_dir_exists == "yes"
        and .relocated_state_count == "0"
    ' >/dev/null 2>&1; then
        harness_pass "autofix_existing clean reinstall aborts before deletion when recording fails"
    else
        harness_fail "autofix_existing clean reinstall aborts before deletion when recording fails" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_clean_reinstall_aborts_when_backup_root_creation_fails() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-clean-backup-root-fail-target"
    local fake_bin="$TEST_HOME/fake-bin"
    mkdir -p "$target_home/.acfs" "$target_home/.config/acfs" "$target_home/.local/bin" "$fake_bin"
    printf 'installed\n' > "$target_home/.acfs/version"
    printf 'config\n' > "$target_home/.config/acfs/settings.toml"
    printf '#!/usr/bin/env bash\n' > "$target_home/.local/bin/acfs"
    chmod +x "$target_home/.local/bin/acfs"

    cat > "$fake_bin/mkdir" <<EOF
#!/usr/bin/env bash
for arg in "\$@"; do
    if [[ "\$arg" == "$target_home/.acfs-backup-"* ]]; then
        exit 1
    fi
done
exec /bin/mkdir "\$@"
EOF
    chmod +x "$fake_bin/mkdir"

    local output=""
    output=$(PATH="$fake_bin:$PATH" HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            start_autofix_session >/dev/null 2>&1 || exit 1
            if clean_reinstall >/dev/null 2>&1; then
                result="success"
            else
                result="failure"
            fi
            end_autofix_session >/dev/null 2>&1 || true
            jq -nc \
                --arg result "$result" \
                --arg version_exists "$(test -f "$TARGET_HOME/.acfs/version" && echo yes || echo no)" \
                --arg config_exists "$(test -f "$TARGET_HOME/.config/acfs/settings.toml" && echo yes || echo no)" \
                --arg binary_exists "$(test -f "$TARGET_HOME/.local/bin/acfs" && echo yes || echo no)" \
                "{result: \$result, version_exists: \$version_exists, config_exists: \$config_exists, binary_exists: \$binary_exists}"
        ' _ "$AUTOFIX_EXISTING_SH" 2>/dev/null)

    if printf '%s\n' "$output" | jq -e '
        .result == "failure"
        and .version_exists == "yes"
        and .config_exists == "yes"
        and .binary_exists == "yes"
    ' >/dev/null 2>&1; then
        harness_pass "autofix_existing clean reinstall aborts when backup root creation fails"
    else
        harness_fail "autofix_existing clean reinstall aborts when backup root creation fails" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_clean_reinstall_aborts_when_state_relocation_fails() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-clean-relocate-fail-target"
    local fake_bin="$TEST_HOME/fake-bin"
    mkdir -p "$target_home/.acfs" "$target_home/.config/acfs" "$target_home/.local/bin" "$fake_bin"
    printf 'installed\n' > "$target_home/.acfs/version"
    printf 'config\n' > "$target_home/.config/acfs/settings.toml"
    printf '#!/usr/bin/env bash\n' > "$target_home/.local/bin/acfs"
    chmod +x "$target_home/.local/bin/acfs"

    cat > "$fake_bin/mv" <<EOF
#!/usr/bin/env bash
if [[ "\$1" == "$target_home/.acfs/autofix" ]]; then
    exit 1
fi
exec /bin/mv "\$@"
EOF
    chmod +x "$fake_bin/mv"

    local output=""
    output=$(PATH="$fake_bin:$PATH" HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" \
        ACFS_STATE_DIR="$target_home/.acfs/autofix" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            start_autofix_session >/dev/null 2>&1 || exit 1
            if clean_reinstall >/dev/null 2>&1; then
                result="success"
            else
                result="failure"
            fi
            change_count=$(jq -s "length" "$ACFS_CHANGES_FILE" 2>/dev/null || echo 0)
            end_autofix_session >/dev/null 2>&1 || true
            jq -nc \
                --arg result "$result" \
                --arg change_count "$change_count" \
                --arg version_exists "$(test -f "$TARGET_HOME/.acfs/version" && echo yes || echo no)" \
                --arg config_exists "$(test -f "$TARGET_HOME/.config/acfs/settings.toml" && echo yes || echo no)" \
                --arg binary_exists "$(test -f "$TARGET_HOME/.local/bin/acfs" && echo yes || echo no)" \
                "{result: \$result, change_count: \$change_count, version_exists: \$version_exists, config_exists: \$config_exists, binary_exists: \$binary_exists}"
        ' _ "$AUTOFIX_EXISTING_SH" 2>/dev/null)

    if printf '%s\n' "$output" | jq -e '
        .result == "failure"
        and .change_count == "0"
        and .version_exists == "yes"
        and .config_exists == "yes"
        and .binary_exists == "yes"
    ' >/dev/null 2>&1; then
        harness_pass "autofix_existing clean reinstall aborts when state relocation fails"
    else
        harness_fail "autofix_existing clean reinstall aborts when state relocation fails" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_clean_reinstall_restores_backup_after_artifact_removal_failure() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-clean-restore-artifact-target"
    mkdir -p "$target_home/.acfs" "$target_home/.config/acfs" "$target_home/.local/bin"
    printf 'installed\n' > "$target_home/.acfs/version"
    printf 'config\n' > "$target_home/.config/acfs/settings.toml"
    printf '#!/usr/bin/env bash\n' > "$target_home/.local/bin/acfs"
    chmod +x "$target_home/.local/bin/acfs"

    local output=""
    output=$(HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" \
        ACFS_STATE_DIR="$target_home/.acfs/autofix" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            eval "$(declare -f remove_acfs_artifacts | sed '\''1s/remove_acfs_artifacts/original_remove_acfs_artifacts/'\'')"
            remove_acfs_artifacts() {
                original_remove_acfs_artifacts "$@" || return 1
                return 1
            }
            start_autofix_session >/dev/null 2>&1 || exit 1
            if clean_reinstall >/dev/null 2>&1; then
                result="success"
            else
                result="failure"
            fi
            end_autofix_session >/dev/null 2>&1 || true
            jq -nc \
                --arg result "$result" \
                --arg version_exists "$(test -f "$TARGET_HOME/.acfs/version" && echo yes || echo no)" \
                --arg config_exists "$(test -f "$TARGET_HOME/.config/acfs/settings.toml" && echo yes || echo no)" \
                --arg binary_exists "$(test -f "$TARGET_HOME/.local/bin/acfs" && echo yes || echo no)" \
                --arg state_dir_exists "$(test -d "$TARGET_HOME/.acfs/autofix" && echo yes || echo no)" \
                --arg relocated_state_count "$(find "$TARGET_HOME" -maxdepth 1 -type d -name ".acfs-autofix-clean.*" | wc -l | tr -d " ")" \
                --slurpfile changes "$ACFS_CHANGES_FILE" \
                --slurpfile undos "$ACFS_UNDOS_FILE" \
                "{result: \$result, version_exists: \$version_exists, config_exists: \$config_exists, binary_exists: \$binary_exists, state_dir_exists: \$state_dir_exists, relocated_state_count: \$relocated_state_count, changes: \$changes, undos: \$undos}"
        ' _ "$AUTOFIX_EXISTING_SH" 2>/dev/null)

    if printf '%s\n' "$output" | jq -e '
        .result == "failure"
        and .version_exists == "yes"
        and .config_exists == "yes"
        and .binary_exists == "yes"
        and .state_dir_exists == "yes"
        and .relocated_state_count == "0"
        and (.changes | length == 0)
        and (.undos | length == 0)
    ' >/dev/null 2>&1; then
        harness_pass "autofix_existing clean reinstall restores backup after artifact removal failure"
    else
        harness_fail "autofix_existing clean reinstall restores backup after artifact removal failure" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_clean_reinstall_preserves_journal_when_artifact_recovery_fails() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-clean-preserve-artifact-journal-target"
    mkdir -p "$target_home/.acfs" "$target_home/.config/acfs" "$target_home/.local/bin"
    printf 'installed\n' > "$target_home/.acfs/version"
    printf 'config\n' > "$target_home/.config/acfs/settings.toml"
    printf '#!/usr/bin/env bash\n' > "$target_home/.local/bin/acfs"
    chmod +x "$target_home/.local/bin/acfs"

    local output=""
    output=$(HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" \
        ACFS_STATE_DIR="$target_home/.acfs/autofix" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            eval "$(declare -f remove_acfs_artifacts | sed '\''1s/remove_acfs_artifacts/original_remove_acfs_artifacts/'\'')"
            remove_acfs_artifacts() {
                original_remove_acfs_artifacts "$@" || return 1
                return 1
            }
            autofix_existing_restore_installation_backup() { return 1; }
            start_autofix_session >/dev/null 2>&1 || exit 1
            if clean_reinstall >/dev/null 2>&1; then
                result="success"
            else
                result="failure"
            fi
            end_autofix_session >/dev/null 2>&1 || true
            jq -nc \
                --arg result "$result" \
                --arg state_dir_exists "$(test -d "$TARGET_HOME/.acfs/autofix" && echo yes || echo no)" \
                --arg relocated_state_count "$(find "$TARGET_HOME" -maxdepth 1 -type d -name ".acfs-autofix-clean.*" | wc -l | tr -d " ")" \
                --slurpfile changes "$ACFS_CHANGES_FILE" \
                --slurpfile undos "$ACFS_UNDOS_FILE" \
                "{result: \$result, state_dir_exists: \$state_dir_exists, relocated_state_count: \$relocated_state_count, changes: \$changes, undos: \$undos}"
        ' _ "$AUTOFIX_EXISTING_SH" 2>/dev/null)

    if printf '%s\n' "$output" | jq -e '
        .result == "failure"
        and .state_dir_exists == "yes"
        and .relocated_state_count == "0"
        and (.changes | length > 0)
        and any(.changes[]; .description == "Clean reinstall - removed existing ACFS installation")
    ' >/dev/null 2>&1; then
        harness_pass "autofix_existing clean reinstall preserves journal when artifact recovery fails"
    else
        harness_fail "autofix_existing clean reinstall preserves journal when artifact recovery fails" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_clean_reinstall_recovery_preserves_preexisting_journal() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-clean-preserve-journal-target"
    mkdir -p "$target_home/.acfs" "$target_home/.config/acfs" "$target_home/.local/bin"
    printf 'installed\n' > "$target_home/.acfs/version"
    printf 'config\n' > "$target_home/.config/acfs/settings.toml"
    printf '#!/usr/bin/env bash\n' > "$target_home/.local/bin/acfs"
    chmod +x "$target_home/.local/bin/acfs"

    local output=""
    output=$(HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" \
        ACFS_STATE_DIR="$target_home/.acfs/autofix" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            eval "$(declare -f remove_acfs_artifacts | sed '\''1s/remove_acfs_artifacts/original_remove_acfs_artifacts/'\'')"
            remove_acfs_artifacts() {
                original_remove_acfs_artifacts "$@" || return 1
                return 1
            }

            start_autofix_session >/dev/null 2>&1 || exit 1
            preexisting_change_id="$(record_change \
                "acfs" \
                "Preexisting change" \
                ":" \
                false \
                "info" \
                "[]" \
                "[]" \
                "[]")" || exit 1
            undo_change "$preexisting_change_id" true true >/dev/null 2>&1 || exit 1
            end_autofix_session >/dev/null 2>&1 || true

            start_autofix_session >/dev/null 2>&1 || exit 1
            if clean_reinstall >/dev/null 2>&1; then
                result="success"
            else
                result="failure"
            fi
            end_autofix_session >/dev/null 2>&1 || true

            jq -nc \
                --arg result "$result" \
                --slurpfile changes "$ACFS_CHANGES_FILE" \
                --slurpfile undos "$ACFS_UNDOS_FILE" \
                "{result: \$result, changes: \$changes, undos: \$undos}"
        ' _ "$AUTOFIX_EXISTING_SH" 2>/dev/null)

    if printf '%s\n' "$output" | jq -e '
        (.changes[0].id) as $id
        | .result == "failure"
        and (.changes | length == 1)
        and (.changes[0].description == "Preexisting change")
        and (.undos | length == 2)
        and (([.undos[].status] | sort) == ["applied", "pending"])
        and (([.undos[].undone] | unique) == [$id])
        and ((reduce .undos[] as $undo ({}; .[$undo.undone] = ($undo.status // "applied")) | .[$id]) == "applied")
    ' >/dev/null 2>&1; then
        harness_pass "autofix_existing clean reinstall recovery preserves preexisting journal"
    else
        harness_fail "autofix_existing clean reinstall recovery preserves preexisting journal" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_drop_changes_since_restores_original_journals_on_late_replace_failure() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-drop-journal-target"
    mkdir -p "$target_home/.acfs/autofix"

    local output=""
    output=$(HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" ACFS_STATE_DIR="$target_home/.acfs/autofix" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"

            start_autofix_session >/dev/null 2>&1 || exit 1
            record_change "acfs" "Keep change" ":" false "info" "[]" "[]" "[]" > "$ACFS_STATE_DIR/keep.id" || exit 1
            record_change "acfs" "Drop change" ":" false "info" "[]" "[]" "[]" > "$ACFS_STATE_DIR/drop.id" || exit 1
            keep_id="$(cat "$ACFS_STATE_DIR/keep.id")"
            drop_id="$(cat "$ACFS_STATE_DIR/drop.id")"
            undo_change "$drop_id" true true >/dev/null 2>&1 || exit 1

            before_changes="$(jq -sc . "$ACFS_CHANGES_FILE")"
            before_undos="$(jq -sc . "$ACFS_UNDOS_FILE")"
            before_order="$(printf "%s\n" "${ACFS_CHANGE_ORDER[@]}" | awk "NF" | jq -R . | jq -sc .)"

            real_mv="$(command -v mv)"
            mv() {
                local dest="${@: -1}"
                if [[ "$dest" == "$ACFS_UNDOS_FILE" ]]; then
                    return 1
                fi
                "$real_mv" "$@"
            }

            if autofix_existing_drop_changes_since 1 >/dev/null 2>&1; then
                result="success"
            else
                result="failure"
            fi

            after_changes="$(jq -sc . "$ACFS_CHANGES_FILE")"
            after_undos="$(jq -sc . "$ACFS_UNDOS_FILE")"
            after_order="$(printf "%s\n" "${ACFS_CHANGE_ORDER[@]}" | awk "NF" | jq -R . | jq -sc .)"
            end_autofix_session >/dev/null 2>&1 || true

            jq -nc \
                --arg result "$result" \
                --argjson before_changes "$before_changes" \
                --argjson after_changes "$after_changes" \
                --argjson before_undos "$before_undos" \
                --argjson after_undos "$after_undos" \
                --argjson before_order "$before_order" \
                --argjson after_order "$after_order" \
                "{result: \$result, before_changes: \$before_changes, after_changes: \$after_changes, before_undos: \$before_undos, after_undos: \$after_undos, before_order: \$before_order, after_order: \$after_order}"
        ' _ "$AUTOFIX_EXISTING_SH" 2>/dev/null)

    if printf '%s\n' "$output" | jq -e '
        .result == "failure"
        and (.before_changes == .after_changes)
        and (.before_undos == .after_undos)
        and (.before_order == .after_order)
    ' >/dev/null 2>&1; then
        harness_pass "autofix_existing drop_changes_since restores original journals on late replace failure"
    else
        harness_fail "autofix_existing drop_changes_since restores original journals on late replace failure" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_backup_uses_unique_dir_when_timestamp_collides() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-backup-collision-target"
    local fake_bin="$TEST_HOME/fake-bin"
    local fixed_stamp="20260415_000000"
    local stale_backup_dir="$target_home/.acfs-backup-$fixed_stamp"
    mkdir -p "$target_home/.acfs" "$target_home/.config/acfs" "$target_home/.local/bin" "$fake_bin" "$stale_backup_dir"
    printf 'installed\n' > "$target_home/.acfs/version"
    printf 'config\n' > "$target_home/.config/acfs/settings.toml"
    printf '#!/usr/bin/env bash\n' > "$target_home/.local/bin/acfs"
    chmod +x "$target_home/.local/bin/acfs"
    printf 'stale\n' > "$stale_backup_dir/stale-marker"

    cat > "$fake_bin/date" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "+%Y%m%d_%H%M%S" ]]; then
    printf '20260415_000000\n'
    exit 0
fi
if [[ "${1:-}" == "-Iseconds" ]]; then
    printf '2026-04-15T00:00:00+00:00\n'
    exit 0
fi
exec /bin/date "$@"
EOF
    chmod +x "$fake_bin/date"

    local output=""
    output=$(PATH="$fake_bin:$PATH" HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            backup_dir=$(create_installation_backup) || exit 1
            jq -nc \
                --arg backup_dir "$backup_dir" \
                --arg stale_exists "$(test -f "$2/stale-marker" && echo yes || echo no)" \
                --arg stale_reused "$(if [[ "$backup_dir" == "$2" ]]; then echo yes; else echo no; fi)" \
                --arg manifest_exists "$(test -f "$backup_dir/manifest.json" && echo yes || echo no)" \
                "{backup_dir: \$backup_dir, stale_exists: \$stale_exists, stale_reused: \$stale_reused, manifest_exists: \$manifest_exists}"
        ' _ "$AUTOFIX_EXISTING_SH" "$stale_backup_dir" 2>/dev/null)

    if printf '%s\n' "$output" | jq -e '
        .stale_exists == "yes"
        and .stale_reused == "no"
        and .manifest_exists == "yes"
        and (.backup_dir | startswith("'"$target_home"'/.acfs-backup-20260415_000000"))
    ' >/dev/null 2>&1; then
        harness_pass "autofix_existing backup uses unique dir when timestamp collides"
    else
        harness_fail "autofix_existing backup uses unique dir when timestamp collides" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_backup_avoids_broken_symlink_collision() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-backup-broken-symlink-target"
    local fake_bin="$TEST_HOME/fake-bin"
    local fixed_stamp="20260415_000001"
    local stale_backup_dir="$target_home/.acfs-backup-$fixed_stamp"
    mkdir -p "$target_home/.acfs" "$target_home/.config/acfs" "$target_home/.local/bin" "$fake_bin"
    printf 'installed\n' > "$target_home/.acfs/version"
    printf 'config\n' > "$target_home/.config/acfs/settings.toml"
    printf '#!/usr/bin/env bash\n' > "$target_home/.local/bin/acfs"
    chmod +x "$target_home/.local/bin/acfs"
    ln -s "$target_home/missing-backup-dir" "$stale_backup_dir"

    cat > "$fake_bin/date" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "+%Y%m%d_%H%M%S" ]]; then
    printf '20260415_000001\n'
    exit 0
fi
if [[ "${1:-}" == "-Iseconds" ]]; then
    printf '2026-04-15T00:00:01+00:00\n'
    exit 0
fi
exec /bin/date "$@"
EOF
    chmod +x "$fake_bin/date"

    local output=""
    output=$(PATH="$fake_bin:$PATH" HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            backup_dir=$(create_installation_backup) || exit 1
            jq -nc \
                --arg backup_dir "$backup_dir" \
                --arg stale_is_symlink "$(test -L "$2" && echo yes || echo no)" \
                --arg stale_reused "$(if [[ "$backup_dir" == "$2" ]]; then echo yes; else echo no; fi)" \
                --arg manifest_exists "$(test -f "$backup_dir/manifest.json" && echo yes || echo no)" \
                "{backup_dir: \$backup_dir, stale_is_symlink: \$stale_is_symlink, stale_reused: \$stale_reused, manifest_exists: \$manifest_exists}"
        ' _ "$AUTOFIX_EXISTING_SH" "$stale_backup_dir" 2>/dev/null)

    if printf '%s\n' "$output" | jq -e '
        .stale_is_symlink == "yes"
        and .stale_reused == "no"
        and .manifest_exists == "yes"
        and (.backup_dir | startswith("'"$target_home"'/.acfs-backup-20260415_000001"))
    ' >/dev/null 2>&1; then
        harness_pass "autofix_existing backup avoids broken symlink collision"
    else
        harness_fail "autofix_existing backup avoids broken symlink collision" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_backup_fsyncs_manifest_and_parent_dir() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-backup-fsync-target"
    local fsync_log="$TEST_HOME/fsync.log"
    mkdir -p "$target_home/.acfs" "$target_home/.config/acfs" "$target_home/.local/bin"
    printf 'installed\n' > "$target_home/.acfs/version"
    printf 'config\n' > "$target_home/.config/acfs/settings.toml"
    printf '#!/usr/bin/env bash\n' > "$target_home/.local/bin/acfs"
    chmod +x "$target_home/.local/bin/acfs"

    local output=""
    output=$(HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            FSYNC_LOG_PATH="$2"
            fsync_file() { printf "file:%s\n" "$1" >> "$FSYNC_LOG_PATH"; return 0; }
            fsync_directory() { printf "dir:%s\n" "$1" >> "$FSYNC_LOG_PATH"; return 0; }
            backup_dir=$(create_installation_backup) || exit 1
            manifest="$backup_dir/manifest.json"
            artifact_backup=$(jq -r --arg original "$TARGET_HOME/.config/acfs" \
                ".backed_up_items[] | select(.original == \$original) | .backup" \
                "$manifest")
            jq -nc \
                --arg parent_synced "$(grep -Fx "dir:$(dirname "$backup_dir")" "$FSYNC_LOG_PATH" >/dev/null 2>&1 && echo yes || echo no)" \
                --arg artifact_synced "$(grep -Fx "dir:$artifact_backup" "$FSYNC_LOG_PATH" >/dev/null 2>&1 && echo yes || echo no)" \
                --arg manifest_synced "$(grep -Fx "file:$manifest" "$FSYNC_LOG_PATH" >/dev/null 2>&1 && echo yes || echo no)" \
                "{parent_synced: \$parent_synced, artifact_synced: \$artifact_synced, manifest_synced: \$manifest_synced}"
        ' _ "$AUTOFIX_EXISTING_SH" "$fsync_log" 2>/dev/null)

    if printf '%s\n' "$output" | jq -e '
        .parent_synced == "yes"
        and .artifact_synced == "yes"
        and .manifest_synced == "yes"
    ' >/dev/null 2>&1; then
        harness_pass "autofix_existing backup fsyncs manifest and parent dir"
    else
        harness_fail "autofix_existing backup fsyncs manifest and parent dir" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_restore_from_backup_fsyncs_restored_path() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-restore-sync-target"
    mkdir -p "$target_home"
    printf 'old\n' > "$target_home/config.toml"
    printf 'restored\n' > "$target_home/config.toml.backup"

    local output=""
    output=$(HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            fsync_log="$TARGET_HOME/fsync.log"
            autofix_sync_backup_path() {
                printf "%s\n" "$1" >> "$fsync_log"
                return 0
            }
            backup_json=$(jq -cn \
                --arg original "$TARGET_HOME/config.toml" \
                --arg backup "$TARGET_HOME/config.toml.backup" \
                "{original: \$original, backup: \$backup}")
            if autofix_existing_restore_from_backup "$backup_json" "$TARGET_HOME/config.toml" >/dev/null 2>&1; then
                result="success"
            else
                result="failure"
            fi
            jq -nc \
                --arg result "$result" \
                --arg contents "$(cat "$TARGET_HOME/config.toml" 2>/dev/null || true)" \
                --arg fsync_log "$(cat "$fsync_log" 2>/dev/null || true)" \
                "{result: \$result, contents: \$contents, fsync_log: \$fsync_log}"
        ' _ "$AUTOFIX_EXISTING_SH" 2>/dev/null)

    if printf '%s\n' "$output" | jq -e '
        .result == "success"
        and .contents == "restored"
        and (.fsync_log | contains("/config.toml"))
    ' >/dev/null 2>&1; then
        harness_pass "autofix_existing restore from backup fsyncs restored path"
    else
        harness_fail "autofix_existing restore from backup fsyncs restored path" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_backup_cleans_partial_dir_after_copy_failure() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-backup-copy-fail-target"
    local fsync_log="$TEST_HOME/fsync.log"
    mkdir -p "$target_home/.acfs" "$target_home/.config/acfs" "$target_home/.local/bin"
    printf 'installed\n' > "$target_home/.acfs/version"
    printf 'config\n' > "$target_home/.config/acfs/settings.toml"
    printf '#!/usr/bin/env bash\n' > "$target_home/.local/bin/acfs"
    chmod +x "$target_home/.local/bin/acfs"

    local output=""
    output=$(HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            FSYNC_LOG_PATH="$2"
            cp() {
                local last="${@: -1}"
                if [[ "$last" == "$TARGET_HOME/.acfs-backup-"* ]]; then
                    mkdir -p "$last"
                    return 1
                fi
                command cp "$@"
            }
            fsync_directory() { printf "dir:%s\n" "$1" >> "$FSYNC_LOG_PATH"; return 0; }
            if create_installation_backup >/dev/null 2>&1; then
                result="success"
            else
                result="failure"
            fi
            jq -nc \
                --arg result "$result" \
                --arg leftover_count "$(find "$TARGET_HOME" -maxdepth 1 -type d -name ".acfs-backup-*" | wc -l | tr -d " ")" \
                --arg parent_synced "$(grep -Fx "dir:$TARGET_HOME" "$FSYNC_LOG_PATH" >/dev/null 2>&1 && echo yes || echo no)" \
                "{result: \$result, leftover_count: \$leftover_count, parent_synced: \$parent_synced}"
        ' _ "$AUTOFIX_EXISTING_SH" "$fsync_log" 2>/dev/null)

    if printf '%s\n' "$output" | jq -e '
        .result == "failure"
        and .leftover_count == "0"
        and .parent_synced == "yes"
    ' >/dev/null 2>&1; then
        harness_pass "autofix_existing backup cleans partial dir after copy failure"
    else
        harness_fail "autofix_existing backup cleans partial dir after copy failure" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_artifacts_include_global_wrapper() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-artifacts-target"
    mkdir -p "$target_home"

    local output=""
    output=$(HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            autofix_existing_artifacts | jq -R . | jq -s .
        ' _ "$AUTOFIX_EXISTING_SH" 2>/dev/null)

    if printf '%s\n' "$output" | jq -e '
        index("/usr/local/bin/acfs") != null
        and index("'"$target_home"'/.acfs") != null
        and index("'"$target_home"'/.local/bin/acfs") != null
    ' >/dev/null 2>&1; then
        harness_pass "autofix_existing artifacts include global wrapper"
    else
        harness_fail "autofix_existing artifacts include global wrapper" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_backup_preserves_symlink_artifacts() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-symlink-backup-target"
    mkdir -p "$target_home/.acfs/bin" "$target_home/.config/acfs" "$target_home/.local/bin"
    printf 'installed\n' > "$target_home/.acfs/version"
    printf '#!/usr/bin/env bash\n' > "$target_home/.acfs/bin/acfs-real"
    chmod +x "$target_home/.acfs/bin/acfs-real"
    printf 'config\n' > "$target_home/.config/acfs/settings.toml"
    ln -s "$target_home/.acfs/bin/acfs-real" "$target_home/.local/bin/acfs"

    local output=""
    output=$(HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            backup_dir=$(create_installation_backup) || exit 1
            original="$TARGET_HOME/.local/bin/acfs"
            backup_path=$(jq -r --arg original "$original" \
                ".backed_up_items[] | select(.original == \$original) | .backup" \
                "$backup_dir/manifest.json")
            path_type=$(jq -r --arg original "$original" \
                ".backed_up_items[] | select(.original == \$original) | .path_type" \
                "$backup_dir/manifest.json")
            jq -nc \
                --arg path_type "$path_type" \
                --arg is_symlink "$(test -L "$backup_path" && echo yes || echo no)" \
                "{path_type: \$path_type, is_symlink: \$is_symlink}"
        ' _ "$AUTOFIX_EXISTING_SH" 2>/dev/null)

    if printf '%s\n' "$output" | jq -e '
        .path_type == "symlink"
        and .is_symlink == "yes"
    ' >/dev/null 2>&1; then
        harness_pass "autofix_existing backup preserves symlink artifacts"
    else
        harness_fail "autofix_existing backup preserves symlink artifacts" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_handles_broken_symlink_artifacts() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-broken-symlink-target"
    mkdir -p "$target_home/.acfs" "$target_home/.config/acfs" "$target_home/.local/bin"
    printf 'installed\n' > "$target_home/.acfs/version"
    printf 'config\n' > "$target_home/.config/acfs/settings.toml"
    ln -s "$target_home/.acfs/bin/missing-acfs" "$target_home/.local/bin/acfs"

    local output=""
    output=$(HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            markers=$(detect_existing_acfs | tr " " "\n" | jq -R . | jq -s .)
            if remove_acfs_artifacts >/dev/null 2>&1; then
                remove_result="success"
            else
                remove_result="failure"
            fi
            jq -nc \
                --argjson markers "$markers" \
                --arg remove_result "$remove_result" \
                --arg symlink_exists "$(test -L "$TARGET_HOME/.local/bin/acfs" && echo yes || echo no)" \
                "{markers: \$markers, remove_result: \$remove_result, symlink_exists: \$symlink_exists}"
        ' _ "$AUTOFIX_EXISTING_SH" 2>/dev/null)

    if printf '%s\n' "$output" | jq -e '
        (.markers | index("'"$target_home"'/.local/bin/acfs")) != null
        and .remove_result == "success"
        and .symlink_exists == "no"
    ' >/dev/null 2>&1; then
        harness_pass "autofix_existing handles broken symlink artifacts"
    else
        harness_fail "autofix_existing handles broken symlink artifacts" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_clean_shell_configs_records_changes() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-shell-target"
    mkdir -p "$target_home"
    cat > "$target_home/.zshrc" <<'EOF'
# shell config
# ACFS PATH
source ~/.acfs/zsh/acfs.zshrc
keep_me=1
EOF

    local output=""
    output=$(HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            start_autofix_session >/dev/null 2>&1 || exit 1
            clean_shell_configs >/dev/null 2>&1 || exit 1
            end_autofix_session >/dev/null 2>&1 || true
            jq -nc \
                --arg file_contents "$(cat "$TARGET_HOME/.zshrc")" \
                --slurpfile changes "$ACFS_CHANGES_FILE" \
                "{file_contents: \$file_contents, changes: \$changes}"
        ' _ "$AUTOFIX_EXISTING_SH" 2>/dev/null)

    if printf '%s\n' "$output" | jq -e '
        (.file_contents | contains("keep_me=1"))
        and (.file_contents | contains(".acfs") | not)
        and (.changes | length == 1)
        and (.changes[0].description | contains("Cleaned ACFS entries from"))
        and (.changes[0].reversible == true)
        and (.changes[0].backups | length == 1)
        and (.changes[0].backups[0].backup != null)
    ' >/dev/null 2>&1; then
        harness_pass "autofix_existing clean shell configs records changes"
    else
        harness_fail "autofix_existing clean shell configs records changes" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_clean_shell_configs_preserves_symlinked_config() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-shell-symlink-target"
    local dotfiles_home="$TEST_HOME/dotfiles"
    local real_config="$dotfiles_home/zshrc"
    mkdir -p "$target_home" "$dotfiles_home"
    cat > "$real_config" <<'EOF'
# shell config
# ACFS PATH
source ~/.acfs/zsh/acfs.zshrc
keep_me=1
EOF
    ln -s "$real_config" "$target_home/.zshrc"

    local output=""
    output=$(HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            start_autofix_session >/dev/null 2>&1 || exit 1
            clean_shell_configs >/dev/null 2>&1 || exit 1
            end_autofix_session >/dev/null 2>&1 || true
            jq -nc \
                --arg symlink_exists "$(test -L "$TARGET_HOME/.zshrc" && echo yes || echo no)" \
                --arg symlink_target "$(readlink "$TARGET_HOME/.zshrc" 2>/dev/null || true)" \
                --arg file_contents "$(cat "$2")" \
                --slurpfile changes "$ACFS_CHANGES_FILE" \
                "{symlink_exists: \$symlink_exists, symlink_target: \$symlink_target, file_contents: \$file_contents, changes: \$changes}"
        ' _ "$AUTOFIX_EXISTING_SH" "$real_config" 2>/dev/null)

    if printf '%s\n' "$output" | jq -e '
        .symlink_exists == "yes"
        and .symlink_target == "'"$real_config"'"
        and (.file_contents | contains("keep_me=1"))
        and (.file_contents | contains(".acfs") | not)
        and (.changes | length == 1)
        and any(.changes[0].files_affected[]; . == "'"$target_home"'/.zshrc")
        and any(.changes[0].files_affected[]; . == "'"$real_config"'")
        and (.changes[0].backups | length == 1)
        and (.changes[0].backups[0].original == "'"$real_config"'")
    ' >/dev/null 2>&1; then
        harness_pass "autofix_existing clean shell configs preserve symlinked config"
    else
        harness_fail "autofix_existing clean shell configs preserve symlinked config" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_clean_shell_configs_preserves_owner_before_move() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-shell-owner-target"
    local fake_bin="$TEST_HOME/fake-bin"
    local chown_log="$TEST_HOME/chown.log"
    mkdir -p "$target_home" "$fake_bin"
    cat > "$target_home/.zshrc" <<'EOF'
# shell config
# ACFS PATH
source ~/.acfs/zsh/acfs.zshrc
keep_me=1
EOF

    cat > "$fake_bin/stat" <<EOF
#!/usr/bin/env bash
fmt="\$2"
path="\$3"
if [[ "\$fmt" == "%u:%g" ]]; then
    if [[ "\$path" == "$target_home/.zshrc" ]]; then
        printf '2001:3002\\n'
        exit 0
    fi
    if [[ "\$path" == "$target_home"/.acfs-clean.* ]]; then
        printf '1000:1000\\n'
        exit 0
    fi
fi
exec /usr/bin/stat "\$@"
EOF
    chmod +x "$fake_bin/stat"

    cat > "$fake_bin/chown" <<EOF
#!/usr/bin/env bash
printf '%s\\n' "\$*" > "$chown_log"
exit 0
EOF
    chmod +x "$fake_bin/chown"

    local output=""
    output=$(PATH="$fake_bin:$PATH" HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            start_autofix_session >/dev/null 2>&1 || exit 1
            clean_shell_configs >/dev/null 2>&1 || exit 1
            end_autofix_session >/dev/null 2>&1 || true
            jq -nc \
                --arg chown_args "$(cat "$2")" \
                --arg file_contents "$(cat "$TARGET_HOME/.zshrc")" \
                "{chown_args: \$chown_args, file_contents: \$file_contents}"
        ' _ "$AUTOFIX_EXISTING_SH" "$chown_log" 2>/dev/null)

    if printf '%s\n' "$output" | jq -e '
        (.chown_args | startswith("2001:3002 "))
        and (.chown_args | contains(".acfs-clean."))
        and (.file_contents | contains("keep_me=1"))
        and (.file_contents | contains(".acfs") | not)
    ' >/dev/null 2>&1; then
        harness_pass "autofix_existing clean shell configs preserves owner before move"
    else
        harness_fail "autofix_existing clean shell configs preserves owner before move" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_clean_shell_configs_restores_file_when_recording_fails() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-shell-record-fail-target"
    mkdir -p "$target_home"
    cat > "$target_home/.zshrc" <<'EOF'
# shell config
# ACFS PATH
source ~/.acfs/zsh/acfs.zshrc
keep_me=1
EOF

    local output=""
    output=$(HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            start_autofix_session >/dev/null 2>&1 || exit 1
            record_change() { return 1; }
            if clean_shell_configs >/dev/null 2>&1; then
                result="success"
            else
                result="failure"
            fi
            end_autofix_session >/dev/null 2>&1 || true
            jq -nc \
                --arg result "$result" \
                --arg file_contents "$(cat "$TARGET_HOME/.zshrc")" \
                --slurpfile changes "$ACFS_CHANGES_FILE" \
                "{result: \$result, file_contents: \$file_contents, changes: \$changes}"
        ' _ "$AUTOFIX_EXISTING_SH" 2>/dev/null)

    if printf '%s\n' "$output" | jq -e '
        .result == "failure"
        and (.file_contents == "# shell config\n# ACFS PATH\nsource ~/.acfs/zsh/acfs.zshrc\nkeep_me=1")
        and (.changes | length == 0)
    ' >/dev/null 2>&1; then
        harness_pass "autofix_existing clean shell configs restores file when recording fails"
    else
        harness_fail "autofix_existing clean shell configs restores file when recording fails" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_update_path_entries_restores_file_when_recording_fails() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-path-record-fail-target"
    mkdir -p "$target_home"
    cat > "$target_home/.zshrc" <<'EOF'
# shell config
export PATH="$HOME/bin:$PATH"
EOF

    local output=""
    output=$(HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            record_change() { return 1; }
            if update_path_entries >/dev/null 2>&1; then
                result="success"
            else
                result="failure"
            fi
            jq -nc \
                --arg result "$result" \
                --arg file_contents "$(cat "$TARGET_HOME/.zshrc")" \
                "{result: \$result, file_contents: \$file_contents}"
        ' _ "$AUTOFIX_EXISTING_SH" 2>/dev/null)

    if printf '%s\n' "$output" | jq -e '
        .result == "failure"
        and (.file_contents == "# shell config\nexport PATH=\"$HOME/bin:$PATH\"")
        and (.file_contents | contains("# ACFS PATH") | not)
    ' >/dev/null 2>&1; then
        harness_pass "autofix_existing update_path_entries restores file when recording fails"
    else
        harness_fail "autofix_existing update_path_entries restores file when recording fails" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_update_path_entries_restores_symlink_target_when_recording_fails() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-path-symlink-record-fail-target"
    local dotfiles_home="$TEST_HOME/dotfiles"
    local real_config="$dotfiles_home/zshrc"
    mkdir -p "$target_home" "$dotfiles_home"
    cat > "$real_config" <<'EOF'
# shell config
export PATH="$HOME/bin:$PATH"
EOF
    ln -s "$real_config" "$target_home/.zshrc"

    local output=""
    output=$(HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            record_change() { return 1; }
            if update_path_entries >/dev/null 2>&1; then
                result="success"
            else
                result="failure"
            fi
            jq -nc \
                --arg result "$result" \
                --arg symlink_exists "$(test -L "$TARGET_HOME/.zshrc" && echo yes || echo no)" \
                --arg symlink_target "$(readlink "$TARGET_HOME/.zshrc" 2>/dev/null || true)" \
                --arg file_contents "$(cat "$2")" \
                "{result: \$result, symlink_exists: \$symlink_exists, symlink_target: \$symlink_target, file_contents: \$file_contents}"
        ' _ "$AUTOFIX_EXISTING_SH" "$real_config" 2>/dev/null)

    if printf '%s\n' "$output" | jq -e '
        .result == "failure"
        and .symlink_exists == "yes"
        and .symlink_target == "'"$real_config"'"
        and (.file_contents == "# shell config\nexport PATH=\"$HOME/bin:$PATH\"")
        and (.file_contents | contains("# ACFS PATH") | not)
    ' >/dev/null 2>&1; then
        harness_pass "autofix_existing update path entries restore symlink target on journaling failure"
    else
        harness_fail "autofix_existing update path entries restore symlink target on journaling failure" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_legacy_config_migration_undo_handles_quoted_paths() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-quote-target-'legacy"
    mkdir -p "$target_home/.acfs"
    printf 'legacy-config\n' > "$target_home/.acfs_config"

    local output=""
    output=$(HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            start_autofix_session >/dev/null 2>&1 || exit 1
            run_migrations "0.9.0" "1.0.0" >/dev/null 2>&1 || exit 1
            end_autofix_session >/dev/null 2>&1 || true
            if acfs_undo_command --all >/dev/null 2>&1; then
                result="success"
            else
                result="failure"
            fi
            jq -nc \
                --arg result "$result" \
                --arg legacy_exists "$(test -f "$TARGET_HOME/.acfs_config" && echo yes || echo no)" \
                --arg settings_exists "$(test -f "$TARGET_HOME/.acfs/config/settings.toml" && echo yes || echo no)" \
                --arg legacy_contents "$(cat "$TARGET_HOME/.acfs_config" 2>/dev/null || true)" \
                "{result: \$result, legacy_exists: \$legacy_exists, settings_exists: \$settings_exists, legacy_contents: \$legacy_contents}"
        ' _ "$AUTOFIX_EXISTING_SH" 2>/dev/null)

    if printf '%s\n' "$output" | jq -e '
        .result == "success"
        and .legacy_exists == "yes"
        and .settings_exists == "no"
        and .legacy_contents == "legacy-config"
    ' >/dev/null 2>&1; then
        harness_pass "autofix_existing legacy config migration undo handles quoted paths"
    else
        harness_fail "autofix_existing legacy config migration undo handles quoted paths" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_legacy_config_migration_undo_cleans_created_dirs() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-undo-clean-target"
    local state_dir="$TEST_HOME/autofix-state"
    mkdir -p "$target_home"
    printf 'legacy-config\n' > "$target_home/.acfs_config"

    local output=""
    output=$(HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" ACFS_STATE_DIR="$state_dir" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            start_autofix_session >/dev/null 2>&1 || exit 1
            run_migrations "0.9.0" "1.0.0" >/dev/null 2>&1 || exit 1
            end_autofix_session >/dev/null 2>&1 || true
            if acfs_undo_command --all >/dev/null 2>&1; then
                result="success"
            else
                result="failure"
            fi
            jq -nc \
                --arg result "$result" \
                --arg legacy_exists "$(test -f "$TARGET_HOME/.acfs_config" && echo yes || echo no)" \
                --arg settings_exists "$(test -f "$TARGET_HOME/.acfs/config/settings.toml" && echo yes || echo no)" \
                --arg acfs_home_exists "$(test -d "$TARGET_HOME/.acfs" && echo yes || echo no)" \
                --arg config_dir_exists "$(test -d "$TARGET_HOME/.acfs/config" && echo yes || echo no)" \
                --arg local_dir_exists "$(test -d "$TARGET_HOME/.local" && echo yes || echo no)" \
                --arg local_bin_exists "$(test -d "$TARGET_HOME/.local/bin" && echo yes || echo no)" \
                --arg legacy_contents "$(cat "$TARGET_HOME/.acfs_config" 2>/dev/null || true)" \
                "{result: \$result, legacy_exists: \$legacy_exists, settings_exists: \$settings_exists, acfs_home_exists: \$acfs_home_exists, config_dir_exists: \$config_dir_exists, local_dir_exists: \$local_dir_exists, local_bin_exists: \$local_bin_exists, legacy_contents: \$legacy_contents}"
        ' _ "$AUTOFIX_EXISTING_SH" 2>/dev/null)

    if printf '%s\n' "$output" | jq -e '
        .result == "success"
        and .legacy_exists == "yes"
        and .settings_exists == "no"
        and .acfs_home_exists == "no"
        and .config_dir_exists == "no"
        and .local_dir_exists == "no"
        and .local_bin_exists == "no"
        and .legacy_contents == "legacy-config"
    ' >/dev/null 2>&1; then
        harness_pass "autofix_existing legacy config migration undo cleans created dirs"
    else
        harness_fail "autofix_existing legacy config migration undo cleans created dirs" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_legacy_json_migration_undo_handles_quoted_paths() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-quote-target-'json"
    mkdir -p "$target_home/.acfs"
    printf '{\"legacy\":true}\n' > "$target_home/.acfs/config.json"

    local output=""
    output=$(HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            start_autofix_session >/dev/null 2>&1 || exit 1
            run_migrations "0.9.0" "1.0.0" >/dev/null 2>&1 || exit 1
            end_autofix_session >/dev/null 2>&1 || true
            if acfs_undo_command --all >/dev/null 2>&1; then
                result="success"
            else
                result="failure"
            fi
            jq -nc \
                --arg result "$result" \
                --arg json_exists "$(test -f "$TARGET_HOME/.acfs/config.json" && echo yes || echo no)" \
                --arg migrated_exists "$(test -f "$TARGET_HOME/.acfs/config.json.migrated" && echo yes || echo no)" \
                --arg json_contents "$(cat "$TARGET_HOME/.acfs/config.json" 2>/dev/null || true)" \
                "{result: \$result, json_exists: \$json_exists, migrated_exists: \$migrated_exists, json_contents: \$json_contents}"
        ' _ "$AUTOFIX_EXISTING_SH" 2>/dev/null)

    if printf '%s\n' "$output" | jq -e '
        .result == "success"
        and .json_exists == "yes"
        and .migrated_exists == "no"
        and .json_contents == "{\"legacy\":true}"
    ' >/dev/null 2>&1; then
        harness_pass "autofix_existing legacy json migration undo handles quoted paths"
    else
        harness_fail "autofix_existing legacy json migration undo handles quoted paths" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_legacy_config_migration_record_failure_cleans_created_dirs() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-migration-clean-target"
    local state_dir="$TEST_HOME/autofix-state"
    mkdir -p "$target_home"
    printf 'legacy-config\n' > "$target_home/.acfs_config"

    local output=""
    output=$(HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" ACFS_STATE_DIR="$state_dir" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            start_autofix_session >/dev/null 2>&1 || exit 1
            record_change() { return 1; }
            if run_migrations "0.9.0" "1.0.0" >/dev/null 2>&1; then
                result="success"
            else
                result="failure"
            fi
            end_autofix_session >/dev/null 2>&1 || true
            jq -nc \
                --arg result "$result" \
                --arg legacy_exists "$(test -f "$TARGET_HOME/.acfs_config" && echo yes || echo no)" \
                --arg acfs_home_exists "$(test -d "$TARGET_HOME/.acfs" && echo yes || echo no)" \
                --arg config_dir_exists "$(test -d "$TARGET_HOME/.acfs/config" && echo yes || echo no)" \
                "{result: \$result, legacy_exists: \$legacy_exists, acfs_home_exists: \$acfs_home_exists, config_dir_exists: \$config_dir_exists}"
        ' _ "$AUTOFIX_EXISTING_SH" 2>/dev/null)

    if printf '%s\n' "$output" | jq -e '
        .result == "failure"
        and .legacy_exists == "yes"
        and .acfs_home_exists == "no"
        and .config_dir_exists == "no"
    ' >/dev/null 2>&1; then
        harness_pass "autofix_existing legacy config migration failure cleans created dirs"
    else
        harness_fail "autofix_existing legacy config migration failure cleans created dirs" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_run_migrations_rolls_back_earlier_steps_on_late_failure() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-migration-rollback-target"
    local state_dir="$TEST_HOME/autofix-state"
    mkdir -p "$target_home/.acfs"
    printf 'legacy-config\n' > "$target_home/.acfs_config"
    printf '{"legacy":true}\n' > "$target_home/.acfs/config.json"

    local output=""
    output=$(HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" ACFS_STATE_DIR="$state_dir" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            eval "$(declare -f record_change | sed "1s/^record_change/original_record_change/")"
            start_autofix_session >/dev/null 2>&1 || exit 1
            record_attempt=0
            record_change() {
                record_attempt=$((record_attempt + 1))
                if [[ $record_attempt -eq 3 ]]; then
                    return 1
                fi
                original_record_change "$@"
            }
            if run_migrations "0.9.0" "1.0.0" >/dev/null 2>&1; then
                result="success"
            else
                result="failure"
            fi
            end_autofix_session >/dev/null 2>&1 || true
            jq -nc \
                --arg result "$result" \
                --arg legacy_exists "$(test -f "$TARGET_HOME/.acfs_config" && echo yes || echo no)" \
                --arg settings_exists "$(test -f "$TARGET_HOME/.acfs/config/settings.toml" && echo yes || echo no)" \
                --arg acfs_home_exists "$(test -d "$TARGET_HOME/.acfs" && echo yes || echo no)" \
                --arg config_dir_exists "$(test -d "$TARGET_HOME/.acfs/config" && echo yes || echo no)" \
                --arg json_exists "$(test -f "$TARGET_HOME/.acfs/config.json" && echo yes || echo no)" \
                --arg migrated_exists "$(test -f "$TARGET_HOME/.acfs/config.json.migrated" && echo yes || echo no)" \
                --arg local_dir_exists "$(test -d "$TARGET_HOME/.local" && echo yes || echo no)" \
                --arg local_bin_exists "$(test -d "$TARGET_HOME/.local/bin" && echo yes || echo no)" \
                --arg legacy_contents "$(cat "$TARGET_HOME/.acfs_config" 2>/dev/null || true)" \
                --arg json_contents "$(cat "$TARGET_HOME/.acfs/config.json" 2>/dev/null || true)" \
                --slurpfile changes "$ACFS_CHANGES_FILE" \
                --slurpfile undos "$ACFS_UNDOS_FILE" \
                "{result: \$result, legacy_exists: \$legacy_exists, settings_exists: \$settings_exists, acfs_home_exists: \$acfs_home_exists, config_dir_exists: \$config_dir_exists, json_exists: \$json_exists, migrated_exists: \$migrated_exists, local_dir_exists: \$local_dir_exists, local_bin_exists: \$local_bin_exists, legacy_contents: \$legacy_contents, json_contents: \$json_contents, changes: \$changes, undos: \$undos}"
        ' _ "$AUTOFIX_EXISTING_SH" 2>/dev/null)

    if printf '%s\n' "$output" | jq -e '
        .result == "failure"
        and .legacy_exists == "yes"
        and .settings_exists == "no"
        and .acfs_home_exists == "yes"
        and .config_dir_exists == "no"
        and .json_exists == "yes"
        and .migrated_exists == "no"
        and .local_dir_exists == "no"
        and .local_bin_exists == "no"
        and .legacy_contents == "legacy-config"
        and .json_contents == "{\"legacy\":true}"
        and (.changes | length == 0)
        and (.undos | length == 0)
    ' >/dev/null 2>&1; then
        harness_pass "autofix_existing run migrations rolls back earlier steps on late failure"
    else
        harness_fail "autofix_existing run migrations rolls back earlier steps on late failure" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_upgrade_restores_version_when_path_repair_fails() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-upgrade-path-fail-target"
    mkdir -p "$target_home/.acfs"
    printf '1.0.0\n' > "$target_home/.acfs/version"

    local output=""
    output=$(HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            start_autofix_session >/dev/null 2>&1 || exit 1
            update_path_entries() { return 1; }
            if upgrade_existing_installation "1.0.0" "1.1.0" >/dev/null 2>&1; then
                result="success"
            else
                result="failure"
            fi
            end_autofix_session >/dev/null 2>&1 || true
            jq -nc \
                --arg result "$result" \
                --arg version_contents "$(cat "$TARGET_HOME/.acfs/version" 2>/dev/null || true)" \
                --slurpfile changes "$ACFS_CHANGES_FILE" \
                "{result: \$result, version_contents: \$version_contents, changes: \$changes}"
        ' _ "$AUTOFIX_EXISTING_SH" 2>/dev/null)

    if printf '%s\n' "$output" | jq -e '
        .result == "failure"
        and .version_contents == "1.0.0"
        and (.changes | length == 0)
    ' >/dev/null 2>&1; then
        harness_pass "autofix_existing upgrade restores version when path repair fails"
    else
        harness_fail "autofix_existing upgrade restores version when path repair fails" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_upgrade_preserves_journal_when_path_recovery_is_incomplete() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-upgrade-path-incomplete-target"
    local state_dir="$TEST_HOME/autofix-state"
    mkdir -p "$target_home/.acfs"
    printf '0.9.0\n' > "$target_home/.acfs/version"
    printf 'legacy-config\n' > "$target_home/.acfs_config"
    printf '# shell config\n' > "$target_home/.bashrc"

    local output=""
    output=$(HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" ACFS_STATE_DIR="$state_dir" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            eval "$(declare -f record_change | sed '\''1s/record_change/original_record_change/'\'')"
            eval "$(declare -f autofix_existing_restore_from_backup | sed '\''1s/autofix_existing_restore_from_backup/original_autofix_existing_restore_from_backup/'\'')"
            record_change() {
                if [[ "${2:-}" == "Added PATH entry to $TARGET_HOME/.bashrc" ]]; then
                    return 1
                fi
                original_record_change "$@"
            }
            autofix_existing_restore_from_backup() {
                if [[ "${2:-}" == "$TARGET_HOME/.bashrc" ]]; then
                    return 1
                fi
                original_autofix_existing_restore_from_backup "$@"
            }
            start_autofix_session >/dev/null 2>&1 || exit 1
            if upgrade_existing_installation "0.9.0" "1.1.0" >/dev/null 2>&1; then
                result="success"
            else
                result="failure"
            fi
            end_autofix_session >/dev/null 2>&1 || true
            jq -nc \
                --arg result "$result" \
                --arg legacy_exists "$(test -f "$TARGET_HOME/.acfs_config" && echo yes || echo no)" \
                --arg settings_exists "$(test -f "$TARGET_HOME/.acfs/config/settings.toml" && echo yes || echo no)" \
                --arg version_contents "$(cat "$TARGET_HOME/.acfs/version" 2>/dev/null || true)" \
                --arg bashrc_contents "$(cat "$TARGET_HOME/.bashrc" 2>/dev/null || true)" \
                --slurpfile changes "$ACFS_CHANGES_FILE" \
                --slurpfile undos "$ACFS_UNDOS_FILE" \
                "{result: \$result, legacy_exists: \$legacy_exists, settings_exists: \$settings_exists, version_contents: \$version_contents, bashrc_contents: \$bashrc_contents, changes: \$changes, undos: \$undos}"
        ' _ "$AUTOFIX_EXISTING_SH" 2>/dev/null)

    if printf '%s\n' "$output" | jq -e '
        .result == "failure"
        and .legacy_exists == "yes"
        and .settings_exists == "no"
        and .version_contents == "0.9.0"
        and (.bashrc_contents | contains("# ACFS PATH"))
        and (.changes | length == 2)
        and any(.changes[]; .description == "Migrated legacy config file to new location")
        and any(.changes[]; .description == "Created ~/.local/bin directory for ACFS PATH support")
        and (.undos | length > 0)
    ' >/dev/null 2>&1; then
        harness_pass "autofix_existing upgrade preserves journal when path recovery is incomplete"
    else
        harness_fail "autofix_existing upgrade preserves journal when path recovery is incomplete" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_upgrade_write_failure_cleans_new_acfs_home() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-upgrade-write-fail-target"
    local state_dir="$TEST_HOME/autofix-state"
    mkdir -p "$target_home"

    local output=""
    output=$(HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" ACFS_STATE_DIR="$state_dir" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            start_autofix_session >/dev/null 2>&1 || exit 1
            printf() {
                if [[ "${1:-}" == "%s\n" && "${2:-}" == "1.1.0" ]]; then
                    builtin printf "$@"
                    return 1
                fi
                builtin printf "$@"
            }
            if upgrade_existing_installation "1.0.0" "1.1.0" >/dev/null 2>&1; then
                result="success"
            else
                result="failure"
            fi
            end_autofix_session >/dev/null 2>&1 || true
            jq -nc \
                --arg result "$result" \
                --arg acfs_home_exists "$(test -d "$TARGET_HOME/.acfs" && echo yes || echo no)" \
                --arg version_exists "$(test -e "$TARGET_HOME/.acfs/version" && echo yes || echo no)" \
                --slurpfile changes "$ACFS_CHANGES_FILE" \
                "{result: \$result, acfs_home_exists: \$acfs_home_exists, version_exists: \$version_exists, changes: \$changes}"
        ' _ "$AUTOFIX_EXISTING_SH" 2>/dev/null)

    if printf '%s\n' "$output" | jq -e '
        .result == "failure"
        and .acfs_home_exists == "no"
        and .version_exists == "no"
        and (.changes | length == 0)
    ' >/dev/null 2>&1; then
        harness_pass "autofix_existing upgrade write failure cleans new acfs home"
    else
        harness_fail "autofix_existing upgrade write failure cleans new acfs home" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_upgrade_version_backup_failure_rolls_back_migrations() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-upgrade-version-backup-fail-target"
    local state_dir="$TEST_HOME/autofix-state"
    mkdir -p "$target_home/.acfs"
    printf '0.9.0\n' > "$target_home/.acfs/version"
    printf 'legacy-config\n' > "$target_home/.acfs_config"

    local output=""
    output=$(HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" ACFS_STATE_DIR="$state_dir" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            eval "$(declare -f create_backup | sed '\''1s/^create_backup/original_create_backup/'\'')"
            create_backup() {
                if [[ "${1:-}" == "$TARGET_HOME/.acfs/version" ]]; then
                    return 1
                fi
                original_create_backup "$@"
            }
            start_autofix_session >/dev/null 2>&1 || exit 1
            if upgrade_existing_installation "0.9.0" "1.1.0" >/dev/null 2>&1; then
                result="success"
            else
                result="failure"
            fi
            end_autofix_session >/dev/null 2>&1 || true
            jq -nc \
                --arg result "$result" \
                --arg legacy_exists "$(test -f "$TARGET_HOME/.acfs_config" && echo yes || echo no)" \
                --arg settings_exists "$(test -f "$TARGET_HOME/.acfs/config/settings.toml" && echo yes || echo no)" \
                --arg local_dir_exists "$(test -d "$TARGET_HOME/.local" && echo yes || echo no)" \
                --arg local_bin_exists "$(test -d "$TARGET_HOME/.local/bin" && echo yes || echo no)" \
                --arg version_contents "$(cat "$TARGET_HOME/.acfs/version" 2>/dev/null || true)" \
                --slurpfile changes "$ACFS_CHANGES_FILE" \
                --slurpfile undos "$ACFS_UNDOS_FILE" \
                "{result: \$result, legacy_exists: \$legacy_exists, settings_exists: \$settings_exists, local_dir_exists: \$local_dir_exists, local_bin_exists: \$local_bin_exists, version_contents: \$version_contents, changes: \$changes, undos: \$undos}"
        ' _ "$AUTOFIX_EXISTING_SH" 2>/dev/null)

    if printf '%s\n' "$output" | jq -e '
        .result == "failure"
        and .legacy_exists == "yes"
        and .settings_exists == "no"
        and .local_dir_exists == "no"
        and .local_bin_exists == "no"
        and .version_contents == "0.9.0"
        and (.changes | length == 0)
        and (.undos | length == 0)
    ' >/dev/null 2>&1; then
        harness_pass "autofix_existing upgrade version backup failure rolls back migrations"
    else
        harness_fail "autofix_existing upgrade version backup failure rolls back migrations" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_upgrade_record_failure_rolls_back_migrations_and_path_updates() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-upgrade-rollback-target"
    local state_dir="$TEST_HOME/autofix-state"
    mkdir -p "$target_home"
    printf 'legacy-config\n' > "$target_home/.acfs_config"
    printf '# shell config\n' > "$target_home/.bashrc"

    local output=""
    output=$(HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" ACFS_STATE_DIR="$state_dir" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            eval "$(declare -f record_change | sed '\''1s/record_change/original_record_change/'\'')"
            record_change() {
                if [[ "${2:-}" == "Upgraded ACFS from 0.9.0 to 1.1.0" ]]; then
                    return 1
                fi
                original_record_change "$@"
            }
            start_autofix_session >/dev/null 2>&1 || exit 1
            if upgrade_existing_installation "0.9.0" "1.1.0" >/dev/null 2>&1; then
                result="success"
            else
                result="failure"
            fi
            end_autofix_session >/dev/null 2>&1 || true
            jq -nc \
                --arg result "$result" \
                --arg legacy_exists "$(test -f "$TARGET_HOME/.acfs_config" && echo yes || echo no)" \
                --arg settings_exists "$(test -f "$TARGET_HOME/.acfs/config/settings.toml" && echo yes || echo no)" \
                --arg acfs_home_exists "$(test -d "$TARGET_HOME/.acfs" && echo yes || echo no)" \
                --arg local_dir_exists "$(test -d "$TARGET_HOME/.local" && echo yes || echo no)" \
                --arg local_bin_exists "$(test -d "$TARGET_HOME/.local/bin" && echo yes || echo no)" \
                --arg bashrc_contents "$(cat "$TARGET_HOME/.bashrc" 2>/dev/null || true)" \
                --slurpfile changes "$ACFS_CHANGES_FILE" \
                --slurpfile undos "$ACFS_UNDOS_FILE" \
                "{result: \$result, legacy_exists: \$legacy_exists, settings_exists: \$settings_exists, acfs_home_exists: \$acfs_home_exists, local_dir_exists: \$local_dir_exists, local_bin_exists: \$local_bin_exists, bashrc_contents: \$bashrc_contents, changes: \$changes, undos: \$undos}"
        ' _ "$AUTOFIX_EXISTING_SH" 2>/dev/null)

    if printf '%s\n' "$output" | jq -e '
        .result == "failure"
        and .legacy_exists == "yes"
        and .settings_exists == "no"
        and .acfs_home_exists == "no"
        and .local_dir_exists == "no"
        and .local_bin_exists == "no"
        and (.bashrc_contents | contains("# ACFS PATH") | not)
        and (.changes | length == 0)
        and (.undos | length == 0)
    ' >/dev/null 2>&1; then
        harness_pass "autofix_existing upgrade record failure rolls back migrations and path updates"
    else
        harness_fail "autofix_existing upgrade record failure rolls back migrations and path updates" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_upgrade_record_failure_cleans_new_acfs_home() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-upgrade-clean-home-target"
    local state_dir="$TEST_HOME/autofix-state"
    mkdir -p "$target_home"

    local output=""
    output=$(HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" ACFS_STATE_DIR="$state_dir" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            start_autofix_session >/dev/null 2>&1 || exit 1
            record_change() { return 1; }
            if upgrade_existing_installation "1.0.0" "1.1.0" >/dev/null 2>&1; then
                result="success"
            else
                result="failure"
            fi
            end_autofix_session >/dev/null 2>&1 || true
            jq -nc \
                --arg result "$result" \
                --arg acfs_home_exists "$(test -d "$TARGET_HOME/.acfs" && echo yes || echo no)" \
                --arg version_exists "$(test -f "$TARGET_HOME/.acfs/version" && echo yes || echo no)" \
                --slurpfile changes "$ACFS_CHANGES_FILE" \
                "{result: \$result, acfs_home_exists: \$acfs_home_exists, version_exists: \$version_exists, changes: \$changes}"
        ' _ "$AUTOFIX_EXISTING_SH" 2>/dev/null)

    if printf '%s\n' "$output" | jq -e '
        .result == "failure"
        and .acfs_home_exists == "no"
        and .version_exists == "no"
        and (.changes | length == 0)
    ' >/dev/null 2>&1; then
        harness_pass "autofix_existing upgrade record failure cleans new acfs home"
    else
        harness_fail "autofix_existing upgrade record failure cleans new acfs home" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_upgrade_restores_version_when_recording_fails() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-upgrade-record-fail-target"
    mkdir -p "$target_home/.acfs"
    printf '1.0.0\n' > "$target_home/.acfs/version"

    local output=""
    output=$(HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            start_autofix_session >/dev/null 2>&1 || exit 1
            record_change() { return 1; }
            if upgrade_existing_installation "1.0.0" "1.1.0" >/dev/null 2>&1; then
                result="success"
            else
                result="failure"
            fi
            end_autofix_session >/dev/null 2>&1 || true
            jq -nc \
                --arg result "$result" \
                --arg version_contents "$(cat "$TARGET_HOME/.acfs/version" 2>/dev/null || true)" \
                --slurpfile changes "$ACFS_CHANGES_FILE" \
                "{result: \$result, version_contents: \$version_contents, changes: \$changes}"
        ' _ "$AUTOFIX_EXISTING_SH" 2>/dev/null)

    if printf '%s\n' "$output" | jq -e '
        .result == "failure"
        and .version_contents == "1.0.0"
        and (.changes | length == 0)
    ' >/dev/null 2>&1; then
        harness_pass "autofix_existing upgrade restores version when recording fails"
    else
        harness_fail "autofix_existing upgrade restores version when recording fails" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_clean_shell_configs_allows_empty_result() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-shell-empty-target"
    mkdir -p "$target_home"
    cat > "$target_home/.zshrc" <<'EOF'
# ACFS PATH
source ~/.acfs/zsh/acfs.zshrc
EOF

    local output=""
    output=$(HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            start_autofix_session >/dev/null 2>&1 || exit 1
            clean_shell_configs >/dev/null 2>&1 || exit 1
            end_autofix_session >/dev/null 2>&1 || true
            jq -nc \
                --arg file_contents "$(cat "$TARGET_HOME/.zshrc")" \
                --slurpfile changes "$ACFS_CHANGES_FILE" \
                "{file_contents: \$file_contents, changes: \$changes}"
        ' _ "$AUTOFIX_EXISTING_SH" 2>/dev/null)

    if printf '%s\n' "$output" | jq -e '
        (.file_contents == "")
        and (.changes | length == 1)
        and (.changes[0].backups | length == 1)
    ' >/dev/null 2>&1; then
        harness_pass "autofix_existing clean shell configs allows empty result"
    else
        harness_fail "autofix_existing clean shell configs allows empty result" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_clean_reinstall_restores_backup_after_shell_cleanup_failure() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-clean-restore-shell-target"
    mkdir -p "$target_home/.acfs" "$target_home/.config/acfs" "$target_home/.local/bin"
    printf 'installed\n' > "$target_home/.acfs/version"
    printf 'config\n' > "$target_home/.config/acfs/settings.toml"
    printf '#!/usr/bin/env bash\n' > "$target_home/.local/bin/acfs"
    chmod +x "$target_home/.local/bin/acfs"
    cat > "$target_home/.bashrc" <<'EOF'
# ACFS PATH
source ~/.acfs/zsh/acfs.zshrc
keep_bash=1
EOF
    cat > "$target_home/.zshrc" <<'EOF'
# ACFS PATH
source ~/.acfs/zsh/acfs.zshrc
keep_zsh=1
EOF

    local output=""
    output=$(HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" ACFS_STATE_DIR="$target_home/.acfs/autofix" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            eval "$(declare -f record_change | sed '\''1s/record_change/original_record_change/'\'')"
            record_change() {
                if [[ "${2:-}" == "Cleaned ACFS entries from $TARGET_HOME/.zshrc" ]]; then
                    return 1
                fi
                original_record_change "$@"
            }
            start_autofix_session >/dev/null 2>&1 || exit 1
            if clean_reinstall >/dev/null 2>&1; then
                result="success"
            else
                result="failure"
            fi
            end_autofix_session >/dev/null 2>&1 || true
            jq -nc \
                --arg result "$result" \
                --arg version_exists "$(test -f "$TARGET_HOME/.acfs/version" && echo yes || echo no)" \
                --arg config_exists "$(test -f "$TARGET_HOME/.config/acfs/settings.toml" && echo yes || echo no)" \
                --arg binary_exists "$(test -f "$TARGET_HOME/.local/bin/acfs" && echo yes || echo no)" \
                --arg state_dir_exists "$(test -d "$TARGET_HOME/.acfs/autofix" && echo yes || echo no)" \
                --arg relocated_state_count "$(find "$TARGET_HOME" -maxdepth 1 -type d -name ".acfs-autofix-clean.*" | wc -l | tr -d " ")" \
                --arg bashrc_contents "$(cat "$TARGET_HOME/.bashrc" 2>/dev/null || true)" \
                --arg zshrc_contents "$(cat "$TARGET_HOME/.zshrc" 2>/dev/null || true)" \
                --slurpfile changes "$ACFS_CHANGES_FILE" \
                --slurpfile undos "$ACFS_UNDOS_FILE" \
                "{result: \$result, version_exists: \$version_exists, config_exists: \$config_exists, binary_exists: \$binary_exists, state_dir_exists: \$state_dir_exists, relocated_state_count: \$relocated_state_count, bashrc_contents: \$bashrc_contents, zshrc_contents: \$zshrc_contents, changes: \$changes, undos: \$undos}"
        ' _ "$AUTOFIX_EXISTING_SH" 2>/dev/null)

    if printf '%s\n' "$output" | jq -e '
        .result == "failure"
        and .version_exists == "yes"
        and .config_exists == "yes"
        and .binary_exists == "yes"
        and .state_dir_exists == "yes"
        and .relocated_state_count == "0"
        and (.bashrc_contents | contains("# ACFS PATH"))
        and (.zshrc_contents | contains("# ACFS PATH"))
        and (.changes | length == 0)
        and (.undos | length == 0)
    ' >/dev/null 2>&1; then
        harness_pass "autofix_existing clean reinstall restores backup after shell cleanup failure"
    else
        harness_fail "autofix_existing clean reinstall restores backup after shell cleanup failure" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_clean_reinstall_preserves_journal_when_shell_cleanup_recovery_fails() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-clean-preserve-shell-journal-target"
    mkdir -p "$target_home/.acfs" "$target_home/.config/acfs" "$target_home/.local/bin"
    printf 'installed\n' > "$target_home/.acfs/version"
    printf 'config\n' > "$target_home/.config/acfs/settings.toml"
    printf '#!/usr/bin/env bash\n' > "$target_home/.local/bin/acfs"
    chmod +x "$target_home/.local/bin/acfs"

    cat > "$target_home/.bashrc" <<'EOF'
# ACFS PATH
source ~/.acfs/zsh/acfs.zshrc
keep_bash=1
EOF
    cat > "$target_home/.zshrc" <<'EOF'
# ACFS PATH
source ~/.acfs/zsh/acfs.zshrc
keep_zsh=1
EOF

    local output=""
    output=$(HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" ACFS_STATE_DIR="$target_home/.acfs/autofix" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            eval "$(declare -f record_change | sed '\''1s/record_change/original_record_change/'\'')"
            record_change() {
                if [[ "${2:-}" == "Cleaned ACFS entries from $TARGET_HOME/.zshrc" ]]; then
                    return 1
                fi
                original_record_change "$@"
            }
            autofix_existing_restore_installation_backup() { return 1; }
            start_autofix_session >/dev/null 2>&1 || exit 1
            if clean_reinstall >/dev/null 2>&1; then
                result="success"
            else
                result="failure"
            fi
            end_autofix_session >/dev/null 2>&1 || true
            jq -nc \
                --arg result "$result" \
                --arg state_dir_exists "$(test -d "$TARGET_HOME/.acfs/autofix" && echo yes || echo no)" \
                --arg relocated_state_count "$(find "$TARGET_HOME" -maxdepth 1 -type d -name ".acfs-autofix-clean.*" | wc -l | tr -d " ")" \
                --slurpfile changes "$ACFS_CHANGES_FILE" \
                --slurpfile undos "$ACFS_UNDOS_FILE" \
                "{result: \$result, state_dir_exists: \$state_dir_exists, relocated_state_count: \$relocated_state_count, changes: \$changes, undos: \$undos}"
        ' _ "$AUTOFIX_EXISTING_SH" 2>/dev/null)

    if printf '%s\n' "$output" | jq -e '
        .result == "failure"
        and .state_dir_exists == "yes"
        and .relocated_state_count == "0"
        and (.changes | length > 0)
        and any(.changes[]; .description == "Clean reinstall - removed existing ACFS installation")
    ' >/dev/null 2>&1; then
        harness_pass "autofix_existing clean reinstall preserves journal when shell cleanup recovery fails"
    else
        harness_fail "autofix_existing clean reinstall preserves journal when shell cleanup recovery fails" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_clean_reinstall_preserves_journal_when_shell_file_recovery_is_incomplete() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-clean-preserve-shell-file-target"
    mkdir -p "$target_home/.acfs" "$target_home/.config/acfs" "$target_home/.local/bin"
    printf 'installed\n' > "$target_home/.acfs/version"
    printf 'config\n' > "$target_home/.config/acfs/settings.toml"
    printf '#!/usr/bin/env bash\n' > "$target_home/.local/bin/acfs"
    chmod +x "$target_home/.local/bin/acfs"

    cat > "$target_home/.bashrc" <<'EOF'
# ACFS PATH
source ~/.acfs/zsh/acfs.zshrc
keep_bash=1
EOF
    cat > "$target_home/.zshrc" <<'EOF'
# ACFS PATH
source ~/.acfs/zsh/acfs.zshrc
keep_zsh=1
EOF

    local output=""
    output=$(HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" ACFS_STATE_DIR="$target_home/.acfs/autofix" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            eval "$(declare -f record_change | sed '\''1s/record_change/original_record_change/'\'')"
            eval "$(declare -f autofix_existing_restore_from_backup | sed '\''1s/autofix_existing_restore_from_backup/original_autofix_existing_restore_from_backup/'\'')"
            record_change() {
                if [[ "${2:-}" == "Cleaned ACFS entries from $TARGET_HOME/.zshrc" ]]; then
                    return 1
                fi
                original_record_change "$@"
            }
            autofix_existing_restore_from_backup() {
                if [[ "${2:-}" == "$TARGET_HOME/.zshrc" ]]; then
                    return 1
                fi
                original_autofix_existing_restore_from_backup "$@"
            }
            start_autofix_session >/dev/null 2>&1 || exit 1
            if clean_reinstall >/dev/null 2>&1; then
                result="success"
            else
                result="failure"
            fi
            end_autofix_session >/dev/null 2>&1 || true
            jq -nc \
                --arg result "$result" \
                --arg version_exists "$(test -f "$TARGET_HOME/.acfs/version" && echo yes || echo no)" \
                --arg config_exists "$(test -f "$TARGET_HOME/.config/acfs/settings.toml" && echo yes || echo no)" \
                --arg binary_exists "$(test -f "$TARGET_HOME/.local/bin/acfs" && echo yes || echo no)" \
                --arg state_dir_exists "$(test -d "$TARGET_HOME/.acfs/autofix" && echo yes || echo no)" \
                --arg relocated_state_count "$(find "$TARGET_HOME" -maxdepth 1 -type d -name ".acfs-autofix-clean.*" | wc -l | tr -d " ")" \
                --arg bashrc_contents "$(cat "$TARGET_HOME/.bashrc" 2>/dev/null || true)" \
                --arg zshrc_contents "$(cat "$TARGET_HOME/.zshrc" 2>/dev/null || true)" \
                --slurpfile changes "$ACFS_CHANGES_FILE" \
                --slurpfile undos "$ACFS_UNDOS_FILE" \
                "{result: \$result, version_exists: \$version_exists, config_exists: \$config_exists, binary_exists: \$binary_exists, state_dir_exists: \$state_dir_exists, relocated_state_count: \$relocated_state_count, bashrc_contents: \$bashrc_contents, zshrc_contents: \$zshrc_contents, changes: \$changes, undos: \$undos}"
        ' _ "$AUTOFIX_EXISTING_SH" 2>/dev/null)

    if printf '%s\n' "$output" | jq -e '
        .result == "failure"
        and .version_exists == "yes"
        and .config_exists == "yes"
        and .binary_exists == "yes"
        and .state_dir_exists == "yes"
        and .relocated_state_count == "0"
        and (.bashrc_contents | contains("# ACFS PATH"))
        and (.zshrc_contents | contains("# ACFS PATH") | not)
        and (.changes | length > 0)
        and any(.changes[]; .description == "Clean reinstall - removed existing ACFS installation")
        and (.undos | length > 0)
    ' >/dev/null 2>&1; then
        harness_pass "autofix_existing clean reinstall preserves journal when shell file recovery is incomplete"
    else
        harness_fail "autofix_existing clean reinstall preserves journal when shell file recovery is incomplete" "$output"
    fi

    cleanup_mock_env
}

test_autofix_existing_remove_artifacts_propagates_rm_failures() {
    setup_mock_env

    local target_home="$TEST_HOME/autofix-existing-rm-target"
    local fake_bin="$TEST_HOME/fake-bin"
    mkdir -p "$target_home/.acfs" "$target_home/.config/acfs" "$target_home/.local/bin" "$fake_bin"
    printf 'version\n' > "$target_home/.acfs/version"
    printf 'config\n' > "$target_home/.config/acfs/settings.toml"
    printf '#!/usr/bin/env bash\n' > "$target_home/.local/bin/acfs"
    chmod +x "$target_home/.local/bin/acfs"

    cat > "$fake_bin/rm" <<EOF
#!/usr/bin/env bash
last="\${@: -1}"
if [[ "\$last" == "$target_home/.config/acfs" ]]; then
    exit 1
fi
exec /bin/rm "\$@"
EOF
    chmod +x "$fake_bin/rm"

    local output=""
    local exit_code=0
    output=$(HOME="$TEST_HOME/root-home" TARGET_HOME="$target_home" PATH="$fake_bin:/usr/bin:/bin" \
        bash -c '
            unset _ACFS_AUTOFIX_SOURCED _ACFS_AUTOFIX_EXISTING_SOURCED
            source "$1"
            remove_acfs_artifacts
        ' _ "$AUTOFIX_EXISTING_SH" 2>&1) || exit_code=$?

    if [[ "$exit_code" -ne 0 ]] && [[ "$output" == *"Failed to remove artifact"* ]]; then
        harness_pass "autofix_existing remove artifacts propagates rm failures"
    else
        harness_fail "autofix_existing remove artifacts propagates rm failures" "$output"
    fi

    cleanup_mock_env
}

test_changelog_defaults_to_last_updated() {
    setup_mock_env

    local output
    output=$(ACFS_HOME="$TEST_ACFS" ACFS_REPO="$TEST_REPO" bash "$CHANGELOG_SH" --json)

    if printf '%s\n' "$output" | jq -e '.changes | (length == 1 and .[0].version == "1.2.3")' >/dev/null 2>&1; then
        harness_pass "changelog defaults to the current state last_updated timestamp"
    else
        harness_fail "changelog defaults to the current state last_updated timestamp"
    fi

    cleanup_mock_env
}

test_export_config_json_is_valid() {
    setup_mock_env

    local output
    output=$(HOME="$TEST_HOME" ACFS_HOME="$TEST_ACFS" \
        ACFS_INSTALL_HELPERS_SH="$TEST_INSTALL_HELPERS" \
        ACFS_MANIFEST_INDEX_SH="$TEST_MANIFEST_INDEX" \
        bash "$EXPORT_CONFIG_SH" --json)

    if printf '%s\n' "$output" | jq -e '.settings.mode == "vibe \"quoted\"" and .modules[0] == "alpha" and .modules[1] == "module \"beta\" \\\\ path" and .metadata.acfs_version == "1.2.3 \"beta\""' >/dev/null 2>&1; then
        harness_pass "export-config JSON escapes state, version, and detected module strings correctly"
    else
        harness_fail "export-config JSON escapes state, version, and detected module strings correctly"
    fi

    cleanup_mock_env
}

test_status_rejects_unknown_flags() {
    setup_mock_env

    local output=""
    local exit_code=0
    output=$(HOME="$TEST_HOME" ACFS_HOME="$TEST_ACFS" bash "$STATUS_SH" --bogus 2>&1) || exit_code=$?

    if [[ "$exit_code" -ne 0 ]] && [[ "$output" == *"Unknown option"* ]]; then
        harness_pass "status rejects unknown flags"
    else
        harness_fail "status rejects unknown flags" "exit=$exit_code output=$output"
    fi

    cleanup_mock_env
}

test_status_plain_output_avoids_ansi_when_not_tty() {
    setup_mock_env

    local output
    output=$(HOME="$TEST_HOME" ACFS_HOME="$TEST_ACFS" bash "$STATUS_SH")

    if [[ "$output" == *$'\033['* ]]; then
        harness_fail "status suppresses ANSI codes when stdout is not a TTY" "$output"
    else
        harness_pass "status suppresses ANSI codes when stdout is not a TTY"
    fi

    cleanup_mock_env
}

test_status_reports_last_updated_timestamp() {
    setup_mock_env

    local output
    output=$(HOME="$TEST_HOME" ACFS_HOME="$TEST_ACFS" bash "$STATUS_SH" --json)

    if printf '%s\n' "$output" | jq -e '.last_update == "2026-03-10T12:34:56Z"' >/dev/null 2>&1; then
        harness_pass "status reports last_updated from the current state schema"
    else
        harness_fail "status reports last_updated from the current state schema"
    fi

    cleanup_mock_env
}

test_status_errors_on_malformed_state_json() {
    setup_mock_env
    printf '{ invalid json\n' > "$TEST_ACFS/state.json"

    local output=""
    local exit_code=0
    output=$(HOME="$TEST_HOME" ACFS_HOME="$TEST_ACFS" bash "$STATUS_SH" --json 2>&1) || exit_code=$?

    if [[ "$exit_code" -eq 2 ]] && printf '%s\n' "$output" | jq -e '.errors | index("state file invalid JSON")' >/dev/null 2>&1; then
        harness_pass "status marks malformed state.json as an error"
    else
        harness_fail "status marks malformed state.json as an error" "exit=$exit_code output=$output"
    fi

    cleanup_mock_env
}

test_dashboard_generation_is_atomic_on_failure() {
    setup_mock_env
    TEST_DEV_REPO="$TEST_HOME/dev-repo-failing-dashboard"
    mkdir -p "$TEST_ACFS/dashboard" "$TEST_DEV_REPO/scripts/lib"
    printf 'existing dashboard\n' > "$TEST_ACFS/dashboard/index.html"
    cp "$DASHBOARD_SH" "$TEST_DEV_REPO/scripts/lib/dashboard.sh"
    cat > "$TEST_DEV_REPO/scripts/lib/info.sh" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x "$TEST_DEV_REPO/scripts/lib/info.sh"

    local output=""
    local exit_code=0
    output=$(HOME="$TEST_HOME" ACFS_HOME="$TEST_ACFS" bash "$TEST_DEV_REPO/scripts/lib/dashboard.sh" generate --force 2>&1) || exit_code=$?
    local current_contents
    current_contents=$(cat "$TEST_ACFS/dashboard/index.html")
    local leftover_tmp
    leftover_tmp=$(find "$TEST_ACFS/dashboard" -maxdepth 1 -name 'index.html.tmp.*' -print -quit 2>/dev/null || true)

    if [[ "$exit_code" -ne 0 ]] && [[ "$current_contents" == "existing dashboard" ]] && [[ -z "$leftover_tmp" ]]; then
        harness_pass "dashboard generation preserves the previous file on failure"
    else
        harness_fail "dashboard generation preserves the previous file on failure" "exit=$exit_code output=$output contents=$current_contents leftover_tmp=$leftover_tmp"
    fi

    cleanup_mock_env
}

test_dashboard_rejects_invalid_ports_before_serving() {
    setup_mock_env
    mkdir -p "$TEST_ACFS/dashboard"
    printf 'existing dashboard\n' > "$TEST_ACFS/dashboard/index.html"

    local output=""
    local exit_code=0
    output=$(HOME="$TEST_HOME" ACFS_HOME="$TEST_ACFS" bash "$DASHBOARD_SH" serve --port not-a-number 2>&1) || exit_code=$?

    if [[ "$exit_code" -ne 0 ]] \
        && [[ "$output" == *"port must be an integer between 1 and 65535"* ]] \
        && [[ "$output" != *"http://localhost:not-a-number"* ]]; then
        harness_pass "dashboard serve rejects invalid ports before printing URLs"
    else
        harness_fail "dashboard serve rejects invalid ports before printing URLs" "exit=$exit_code output=$output"
    fi

    cleanup_mock_env
}

test_dashboard_prefers_repo_local_info_script() {
    setup_installed_layout_env

    TEST_DEV_REPO="$TEST_HOME/dev-repo"
    mkdir -p "$TEST_DEV_REPO/scripts/lib" "$TEST_INSTALLED_ACFS/scripts/lib"
    cp "$DASHBOARD_SH" "$TEST_DEV_REPO/scripts/lib/dashboard.sh"

    cat > "$TEST_DEV_REPO/scripts/lib/info.sh" <<'EOF'
#!/usr/bin/env bash
printf '<html>repo-local-info</html>\n'
EOF
    chmod +x "$TEST_DEV_REPO/scripts/lib/info.sh"

    cat > "$TEST_INSTALLED_ACFS/scripts/lib/info.sh" <<'EOF'
#!/usr/bin/env bash
printf '<html>installed-info</html>\n'
EOF
    chmod +x "$TEST_INSTALLED_ACFS/scripts/lib/info.sh"

    local output
    output=$(HOME="$TEST_ROOT_HOME" ACFS_HOME="$TEST_INSTALLED_ACFS" \
        bash "$TEST_DEV_REPO/scripts/lib/dashboard.sh" generate --force)

    if [[ "$output" == *"Dashboard generated:"* ]] \
        && grep -q 'repo-local-info' "$TEST_INSTALLED_ACFS/dashboard/index.html" \
        && ! grep -q 'installed-info' "$TEST_INSTALLED_ACFS/dashboard/index.html"; then
        harness_pass "dashboard prefers repo-local info.sh over installed copy"
    else
        harness_fail "dashboard prefers repo-local info.sh over installed copy" "$output"
    fi

    cleanup_mock_env
}

test_dashboard_uses_installed_layout_under_root_home() {
    setup_installed_layout_env
    cp "$DASHBOARD_SH" "$TEST_INSTALLED_ACFS/scripts/lib/dashboard.sh"

    local output=""
    output=$(HOME="$TEST_ROOT_HOME" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        bash "$TEST_INSTALLED_ACFS/scripts/lib/dashboard.sh" generate --force)

    if [[ "$output" == *"$TEST_INSTALLED_ACFS/dashboard/index.html"* ]] \
        && [[ -f "$TEST_INSTALLED_ACFS/dashboard/index.html" ]] \
        && [[ ! -e "$TEST_ROOT_HOME/.acfs/dashboard/index.html" ]]; then
        harness_pass "dashboard writes to installed layout under root home"
    else
        harness_fail "dashboard writes to installed layout under root home" "$output"
    fi

    cleanup_mock_env
}

test_dashboard_serve_uses_target_user_in_ssh_hint() {
    setup_installed_layout_env
    cp "$DASHBOARD_SH" "$TEST_INSTALLED_ACFS/scripts/lib/dashboard.sh"
    mkdir -p "$TEST_INSTALLED_ACFS/dashboard"
    printf 'existing dashboard\n' > "$TEST_INSTALLED_ACFS/dashboard/index.html"

    cat > "$TEST_FAKE_BIN/python3" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$TEST_FAKE_BIN/python3"

    local output=""
    output=$(HOME="$TEST_ROOT_HOME" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        bash "$TEST_INSTALLED_ACFS/scripts/lib/dashboard.sh" serve --port 9099 2>&1)

    if [[ "$output" == *"ssh -L 9099:localhost:9099 tester@"* ]] \
        && [[ "$output" != *"ssh -L 9099:localhost:9099 $(whoami 2>/dev/null || echo unknown)@"* ]]; then
        harness_pass "dashboard serve uses target user in SSH hint"
    else
        harness_fail "dashboard serve uses target user in SSH hint" "$output"
    fi

    cleanup_mock_env
}

test_dashboard_copy_install_uses_target_home_only_system_state() {
    setup_system_state_target_home_only_env

    mkdir -p "$TEST_ROOT_HOME/.local/bin" "$TEST_INSTALLED_ACFS/scripts/lib"
    cp "$DASHBOARD_SH" "$TEST_ROOT_HOME/.local/bin/dashboard"
    chmod +x "$TEST_ROOT_HOME/.local/bin/dashboard"

    cat > "$TEST_INSTALLED_ACFS/scripts/lib/info.sh" <<'EOF'
#!/usr/bin/env bash
printf '<html>copied-dashboard-info</html>\n'
EOF
    chmod +x "$TEST_INSTALLED_ACFS/scripts/lib/info.sh"

    local output=""
    output=$(HOME="$TEST_ROOT_HOME" ACFS_SYSTEM_STATE_FILE="$TEST_SYSTEM_STATE_FILE" \
        PATH="$TEST_ROOT_HOME/.local/bin:$TEST_FAKE_BIN:/usr/bin:/bin" \
        dashboard generate --force 2>&1)

    if [[ "$output" == *"$TEST_INSTALLED_ACFS/dashboard/index.html"* ]] \
        && [[ -f "$TEST_INSTALLED_ACFS/dashboard/index.html" ]] \
        && [[ ! -e "$TEST_ROOT_HOME/.acfs/dashboard/index.html" ]]; then
        harness_pass "copied dashboard uses target_home-only system state"
    else
        harness_fail "copied dashboard uses target_home-only system state" "$output"
    fi

    cleanup_mock_env
}

test_cheatsheet_uses_installed_layout_and_target_path_under_root_home() {
    setup_installed_layout_env
    cp "$CHEATSHEET_SH" "$TEST_INSTALLED_ACFS/scripts/lib/cheatsheet.sh"

    mkdir -p "$TEST_INSTALLED_ACFS/zsh"
    cat > "$TEST_INSTALLED_ACFS/zsh/acfs.zshrc" <<'EOF'
if command -v claude >/dev/null 2>&1; then
  alias cc='claude'
fi
alias cod='codex'
EOF

    local output=""
    output=$(HOME="$TEST_ROOT_HOME" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        bash "$TEST_INSTALLED_ACFS/scripts/lib/cheatsheet.sh" --json)

    if printf '%s\n' "$output" | jq -e --arg zshrc "$TEST_INSTALLED_ACFS/zsh/acfs.zshrc" \
        '.source == $zshrc and ([.entries[].name] | index("cc")) != null and ([.entries[].name] | index("cod")) != null' \
        >/dev/null 2>&1; then
        harness_pass "cheatsheet uses installed layout and target-user PATH under root home"
    else
        harness_fail "cheatsheet uses installed layout and target-user PATH under root home" "$output"
    fi

    cleanup_mock_env
}

test_cheatsheet_copy_install_uses_target_home_only_system_state() {
    setup_system_state_target_home_only_env

    mkdir -p "$TEST_ROOT_HOME/.local/bin" "$TEST_INSTALLED_ACFS/zsh"
    cp "$CHEATSHEET_SH" "$TEST_ROOT_HOME/.local/bin/cheatsheet"
    chmod +x "$TEST_ROOT_HOME/.local/bin/cheatsheet"

    cat > "$TEST_INSTALLED_ACFS/zsh/acfs.zshrc" <<'EOF'
alias cod='codex'
EOF
    write_fake_command "$TEST_TARGET_HOME/.local/bin/codex" "codex 1.2.3"

    local output=""
    output=$(HOME="$TEST_ROOT_HOME" ACFS_SYSTEM_STATE_FILE="$TEST_SYSTEM_STATE_FILE" \
        PATH="$TEST_ROOT_HOME/.local/bin:$TEST_FAKE_BIN:/usr/bin:/bin" \
        cheatsheet --json 2>&1)

    if printf '%s\n' "$output" | jq -e --arg zshrc "$TEST_INSTALLED_ACFS/zsh/acfs.zshrc" \
        '.source == $zshrc and ([.entries[].name] | index("cod")) != null' >/dev/null 2>&1; then
        harness_pass "copied cheatsheet uses target_home-only system state"
    else
        harness_fail "copied cheatsheet uses target_home-only system state" "$output"
    fi

    cleanup_mock_env
}

test_doctor_entrypoint_dispatches_helper_commands() {
    setup_mock_env

    local status_output
    status_output=$(HOME="$TEST_HOME" ACFS_HOME="$TEST_ACFS" bash "$DOCTOR_SH" status --short)

    local changelog_output
    changelog_output=$(HOME="$TEST_HOME" ACFS_HOME="$TEST_ACFS" ACFS_REPO="$TEST_REPO" bash "$DOCTOR_SH" changelog --all --json)

    local export_output
    export_output=$(HOME="$TEST_HOME" ACFS_HOME="$TEST_ACFS" \
        ACFS_INSTALL_HELPERS_SH="$TEST_INSTALL_HELPERS" \
        ACFS_MANIFEST_INDEX_SH="$TEST_MANIFEST_INDEX" \
        bash "$DOCTOR_SH" export-config --json)

    if [[ -n "$status_output" ]] \
        && printf '%s\n' "$changelog_output" | jq -e '.changes | length == 2' >/dev/null 2>&1 \
        && printf '%s\n' "$export_output" | jq -e '.modules | length == 2' >/dev/null 2>&1; then
        harness_pass "doctor entrypoint dispatches status, changelog, and export-config"
    else
        harness_fail "doctor entrypoint dispatches status, changelog, and export-config"
    fi

    cleanup_mock_env
}

test_status_uses_installed_layout_under_root_home() {
    setup_installed_layout_env

    local output
    output=$(HOME="$TEST_ROOT_HOME" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        bash "$TEST_INSTALLED_ACFS/scripts/lib/status.sh" --json)

    if printf '%s\n' "$output" | jq -e '.status == "ok" and .last_update == "2026-03-10T12:34:56Z" and (.errors | length == 0)' >/dev/null 2>&1; then
        harness_pass "status resolves installed layout and target-user PATH under root home"
    else
        harness_fail "status resolves installed layout and target-user PATH under root home" "$output"
    fi

    cleanup_mock_env
}

test_status_uses_system_state_when_user_state_missing() {
    setup_system_state_only_env

    local output
    output=$(HOME="$TEST_ROOT_HOME" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        ACFS_SYSTEM_STATE_FILE="$TEST_SYSTEM_STATE_FILE" \
        bash "$TEST_INSTALLED_ACFS/scripts/lib/status.sh" --json)

    if printf '%s\n' "$output" | jq -e '.status == "ok" and .last_update == "2026-03-10T12:34:56Z" and (.errors | length == 0)' >/dev/null 2>&1; then
        harness_pass "status falls back to system state when user state is missing"
    else
        harness_fail "status falls back to system state when user state is missing" "$output"
    fi

    cleanup_mock_env
}

test_status_uses_system_state_target_home_when_getent_unavailable() {
    setup_system_state_target_home_env

    local output=""
    output=$(HOME="$TEST_ROOT_HOME" ACFS_SYSTEM_STATE_FILE="$TEST_SYSTEM_STATE_FILE" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        bash "$STATUS_SH" --json)

    if printf '%s\n' "$output" | jq -e '.status == "ok" and .last_update == "2026-03-10T12:34:56Z" and (.errors | length == 0)' >/dev/null 2>&1; then
        harness_pass "status uses target_home from system state when getent is unavailable"
    else
        harness_fail "status uses target_home from system state when getent is unavailable" "$output"
    fi

    cleanup_mock_env
}

test_status_ignores_relative_home_state_trap() {
    setup_system_state_target_home_only_env
    setup_relative_home_trap

    cat > "$STALE_HOME/.acfs/state.json" <<'JSON'
{
  "mode": "safe",
  "target_user": "tester",
  "target_home": "/trap/home",
  "started_at": "2030-01-01T00:00:00Z",
  "last_updated": "2030-01-02T00:00:00Z"
}
JSON
    printf '9.9.9\n' > "$STALE_HOME/.acfs/VERSION"

    local output=""
    output=$(cd "$TEST_HOME" && HOME="$RELATIVE_HOME" ACFS_SYSTEM_STATE_FILE="$TEST_SYSTEM_STATE_FILE" \
        PATH="$TEST_FAKE_BIN:/usr/bin:/bin" bash "$STATUS_SH" --json)

    if printf '%s\n' "$output" | jq -e '.last_update == "2026-03-10T12:34:56Z" and (.errors | length == 0)' >/dev/null 2>&1; then
        harness_pass "status ignores relative HOME state trap"
    else
        harness_fail "status ignores relative HOME state trap" "$output"
    fi

    cleanup_mock_env
}

test_changelog_uses_installed_layout_under_root_home() {
    setup_installed_layout_env

    local output
    output=$(HOME="$TEST_ROOT_HOME" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        bash "$TEST_INSTALLED_ACFS/scripts/lib/changelog.sh" --json)

    if printf '%s\n' "$output" | jq -e '.changes | (length == 1 and .[0].version == "2.0.0")' >/dev/null 2>&1; then
        harness_pass "changelog uses installed-layout state under root home"
    else
        harness_fail "changelog uses installed-layout state under root home" "$output"
    fi

    cleanup_mock_env
}

test_changelog_uses_system_state_when_user_state_missing() {
    setup_system_state_only_env

    local output
    output=$(HOME="$TEST_ROOT_HOME" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        ACFS_SYSTEM_STATE_FILE="$TEST_SYSTEM_STATE_FILE" \
        bash "$TEST_INSTALLED_ACFS/scripts/lib/changelog.sh" --json)

    if printf '%s\n' "$output" | jq -e '.changes | (length == 1 and .[0].version == "2.0.0")' >/dev/null 2>&1; then
        harness_pass "changelog falls back to system state when user state is missing"
    else
        harness_fail "changelog falls back to system state when user state is missing" "$output"
    fi

    cleanup_mock_env
}

test_changelog_uses_system_state_target_home_when_getent_unavailable() {
    setup_system_state_target_home_env

    local output=""
    output=$(HOME="$TEST_ROOT_HOME" ACFS_SYSTEM_STATE_FILE="$TEST_SYSTEM_STATE_FILE" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        bash "$CHANGELOG_SH" --json)

    if printf '%s\n' "$output" | jq -e '.changes | (length == 1 and .[0].version == "2.0.0")' >/dev/null 2>&1; then
        harness_pass "changelog uses target_home from system state when getent is unavailable"
    else
        harness_fail "changelog uses target_home from system state when getent is unavailable" "$output"
    fi

    cleanup_mock_env
}

test_changelog_ignores_relative_home_trap() {
    setup_system_state_target_home_only_env
    setup_relative_home_trap

    cat > "$STALE_HOME/.acfs/CHANGELOG.md" <<'EOF'
# Changelog

## [9.9.9] - 2030-01-01

### Added
- Trap entry
EOF

    local output=""
    output=$(cd "$TEST_HOME" && HOME="$RELATIVE_HOME" ACFS_SYSTEM_STATE_FILE="$TEST_SYSTEM_STATE_FILE" \
        PATH="$TEST_FAKE_BIN:/usr/bin:/bin" bash "$CHANGELOG_SH" --json)

    if printf '%s\n' "$output" | jq -e '.changes | (length == 1 and .[0].version == "2.0.0")' >/dev/null 2>&1; then
        harness_pass "changelog ignores relative HOME trap"
    else
        harness_fail "changelog ignores relative HOME trap" "$output"
    fi

    cleanup_mock_env
}

test_export_config_uses_installed_layout_under_root_home() {
    setup_installed_layout_env

    local output
    output=$(HOME="$TEST_ROOT_HOME" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        ACFS_INSTALL_HELPERS_SH="$TEST_INSTALLED_HELPERS" \
        ACFS_MANIFEST_INDEX_SH="$TEST_INSTALLED_MANIFEST_INDEX" \
        bash "$TEST_INSTALLED_ACFS/scripts/lib/export-config.sh" --json)

    if printf '%s\n' "$output" | jq -e '.metadata.acfs_version == "2.0.0" and .settings.mode == "safe" and .tools.bun.version == "1.2.3" and .agents.claude.version == "1.2.3" and (.modules | length == 2)' >/dev/null 2>&1; then
        harness_pass "export-config uses installed-layout state and target-user PATH under root home"
    else
        harness_fail "export-config uses installed-layout state and target-user PATH under root home" "$output"
    fi

    cleanup_mock_env
}

test_export_config_uses_system_state_when_user_state_missing() {
    setup_system_state_only_env

    local output
    output=$(HOME="$TEST_ROOT_HOME" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        ACFS_SYSTEM_STATE_FILE="$TEST_SYSTEM_STATE_FILE" \
        ACFS_INSTALL_HELPERS_SH="$TEST_INSTALLED_HELPERS" \
        ACFS_MANIFEST_INDEX_SH="$TEST_INSTALLED_MANIFEST_INDEX" \
        bash "$TEST_INSTALLED_ACFS/scripts/lib/export-config.sh" --json)

    if printf '%s\n' "$output" | jq -e '.metadata.acfs_version == "2.0.0" and .settings.mode == "safe" and .tools.bun.version == "1.2.3" and .agents.claude.version == "1.2.3" and (.modules | length == 2)' >/dev/null 2>&1; then
        harness_pass "export-config falls back to system state when user state is missing"
    else
        harness_fail "export-config falls back to system state when user state is missing" "$output"
    fi

    cleanup_mock_env
}

test_export_config_uses_system_state_target_home_when_getent_unavailable() {
    setup_system_state_target_home_env

    local output=""
    output=$(HOME="$TEST_ROOT_HOME" ACFS_SYSTEM_STATE_FILE="$TEST_SYSTEM_STATE_FILE" \
        ACFS_INSTALL_HELPERS_SH="$TEST_INSTALLED_HELPERS" ACFS_MANIFEST_INDEX_SH="$TEST_INSTALLED_MANIFEST_INDEX" \
        PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        bash "$EXPORT_CONFIG_SH" --json)

    if printf '%s\n' "$output" | jq -e '
        .metadata.acfs_version == "2.0.0" and
        (.modules | length) == 2 and
        .modules == ["alpha", "module \"beta\" \\\\ path"] and
        .tools.bun.version == "1.2.3" and
        .agents.claude.version == "1.2.3"
    ' >/dev/null 2>&1; then
        harness_pass "export-config uses target_home from system state when getent is unavailable"
    else
        harness_fail "export-config uses target_home from system state when getent is unavailable" "$output"
    fi

    cleanup_mock_env
}

test_export_config_ignores_relative_home_state_trap() {
    setup_system_state_target_home_only_env
    setup_relative_home_trap

    cat > "$STALE_HOME/.acfs/state.json" <<'JSON'
{
  "mode": "trap",
  "target_user": "tester",
  "target_home": "/trap/home",
  "started_at": "2030-01-01T00:00:00Z",
  "last_updated": "2030-01-02T00:00:00Z"
}
JSON
    printf '9.9.9\n' > "$STALE_HOME/.acfs/VERSION"

    local output=""
    output=$(cd "$TEST_HOME" && HOME="$RELATIVE_HOME" ACFS_SYSTEM_STATE_FILE="$TEST_SYSTEM_STATE_FILE" \
        ACFS_INSTALL_HELPERS_SH="$TEST_INSTALLED_HELPERS" ACFS_MANIFEST_INDEX_SH="$TEST_INSTALLED_MANIFEST_INDEX" \
        PATH="$TEST_FAKE_BIN:/usr/bin:/bin" bash "$EXPORT_CONFIG_SH" --json)

    if printf '%s\n' "$output" | jq -e '.metadata.acfs_version == "2.0.0" and .settings.mode == "safe"' >/dev/null 2>&1; then
        harness_pass "export-config ignores relative HOME state trap"
    else
        harness_fail "export-config ignores relative HOME state trap" "$output"
    fi

    cleanup_mock_env
}

test_continue_uses_installed_layout_under_root_home() {
    setup_installed_layout_env

    local output
    output=$(HOME="$TEST_ROOT_HOME" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        bash "$TEST_INSTALLED_ACFS/scripts/lib/continue.sh" --status)

    if [[ "$output" == *"Installation in progress"* ]] && [[ "$output" == *"Phase:"*bootstrap* ]]; then
        harness_pass "continue discovers installed-layout state under root home"
    else
        harness_fail "continue discovers installed-layout state under root home" "$output"
    fi

    cleanup_mock_env
}

test_continue_uses_system_state_target_home_when_getent_unavailable() {
    setup_system_state_target_home_env

    local output=""
    output=$(HOME="$TEST_ROOT_HOME" ACFS_SYSTEM_STATE_FILE="$TEST_SYSTEM_STATE_FILE" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        TEST_CONTINUE_SCRIPT="$CONTINUE_SH" \
        bash -lc '
            source "$TEST_CONTINUE_SCRIPT"
            get_install_state_file
        ' 2>&1)

    if [[ "$output" == "$TEST_TARGET_HOME/.acfs/state.json" ]]; then
        harness_pass "continue uses target_home from system state when getent is unavailable"
    else
        harness_fail "continue uses target_home from system state when getent is unavailable" "$output"
    fi

    cleanup_mock_env
}

test_continue_ignores_relative_home_state_trap() {
    setup_system_state_target_home_only_env
    setup_relative_home_trap

    cat > "$STALE_HOME/.acfs/state.json" <<'JSON'
{
  "mode": "safe",
  "target_user": "tester",
  "target_home": "/trap/home",
  "started_at": "2030-01-01T00:00:00Z",
  "last_updated": "2030-01-02T00:00:00Z"
}
JSON

    local output=""
    output=$(cd "$TEST_HOME" && HOME="$RELATIVE_HOME" ACFS_SYSTEM_STATE_FILE="$TEST_SYSTEM_STATE_FILE" \
        PATH="$TEST_FAKE_BIN:/usr/bin:/bin" TEST_CONTINUE_SCRIPT="$CONTINUE_SH" \
        bash -lc '
            source "$TEST_CONTINUE_SCRIPT"
            get_install_state_file
        ' 2>&1)

    if [[ "$output" == "$TEST_TARGET_HOME/.acfs/state.json" ]]; then
        harness_pass "continue ignores relative HOME state trap"
    else
        harness_fail "continue ignores relative HOME state trap" "$output"
    fi

    cleanup_mock_env
}

test_continue_ignores_generic_install_process_matches() {
    setup_installed_layout_env

    cat > "$TEST_INSTALLED_ACFS/state.json" <<'JSON'
{
  "mode": "safe",
  "target_user": "tester",
  "started_at": "2026-03-09T08:00:00Z",
  "last_updated": "2026-03-10T12:34:56Z"
}
JSON

    cat > "$TEST_FAKE_BIN/pgrep" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    *"bash.*install.sh.*--mode"*|*"bash.*install.sh.*--yes"*|*"bash.*install.sh.*--resume"*|*"bash -s -- .*--resume"*)
    exit 0
    ;;
esac
exit 1
EOF
    chmod +x "$TEST_FAKE_BIN/pgrep"

    local output
    output=$(HOME="$TEST_ROOT_HOME" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        bash "$TEST_INSTALLED_ACFS/scripts/lib/continue.sh" --status)

    if [[ "$output" == *"No active installation"* ]] && [[ "$output" != *"Installation in progress"* ]]; then
        harness_pass "continue ignores generic install.sh process matches"
    else
        harness_fail "continue ignores generic install.sh process matches" "$output"
    fi

    cleanup_mock_env
}

test_continue_failed_state_beats_runtime_probe() {
    setup_installed_layout_env

    cat > "$TEST_INSTALLED_ACFS/state.json" <<'JSON'
{
  "mode": "safe",
  "target_user": "tester",
  "started_at": "2026-03-09T08:00:00Z",
  "last_updated": "2026-03-10T12:34:56Z",
  "failed_phase": "agents",
  "failed_step": "install codex"
}
JSON

    cat > "$TEST_FAKE_BIN/pgrep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$TEST_FAKE_BIN/pgrep"

    local output
    output=$(HOME="$TEST_ROOT_HOME" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        bash "$TEST_INSTALLED_ACFS/scripts/lib/continue.sh" --status)

    if [[ "$output" == *"Installation failed"* ]] && \
       [[ "$output" == *"install codex"* ]] && \
       [[ "$output" != *"Installation in progress"* ]]; then
        harness_pass "continue failure status beats loose runtime probes"
    else
        harness_fail "continue failure status beats loose runtime probes" "$output"
    fi

    cleanup_mock_env
}

test_continue_reports_installed_layout_log_locations() {
    setup_installed_layout_env
    mkdir -p "$TEST_INSTALLED_ACFS/logs"
    printf 'install log\n' > "$TEST_INSTALLED_ACFS/logs/install-20260310.log"

    local output
    output=$(HOME="$TEST_ROOT_HOME" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        bash "$TEST_INSTALLED_ACFS/scripts/lib/continue.sh" --status)

    if [[ "$output" == *"$TEST_INSTALLED_ACFS/logs/install-20260310.log"* ]]; then
        harness_pass "continue reports installed-layout log paths"
    else
        harness_fail "continue reports installed-layout log paths" "$output"
    fi

    cleanup_mock_env
}

test_continue_live_log_hint_uses_installed_layout_log_dir() {
    setup_installed_layout_env

    local output=""
    output=$(HOME="$TEST_ROOT_HOME" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        bash -c '
            source "'"$TEST_INSTALLED_ACFS"'/scripts/lib/continue.sh"
            get_log_root_hint
        ' 2>&1)

    if [[ "$output" == "$TEST_INSTALLED_ACFS/logs" ]]; then
        harness_pass "continue live-log hint uses installed-layout log dir"
    else
        harness_fail "continue live-log hint uses installed-layout log dir" "$output"
    fi

    cleanup_mock_env
}

test_continue_scans_nonstandard_homes_via_getent() {
    setup_installed_layout_env

    mkdir -p "$TEST_TARGET_HOME/.acfs"
    cat > "$TEST_TARGET_HOME/.acfs/state.json" <<'JSON'
{
  "mode": "safe",
  "target_user": "tester",
  "started_at": "2026-03-09T08:00:00Z",
  "last_updated": "2026-03-10T12:34:56Z"
}
JSON

    cat > "$TEST_FAKE_BIN/getent" <<EOF
#!/usr/bin/env bash
if [[ "\$1" == "passwd" && \$# -eq 1 ]]; then
    echo "tester:x:1000:1000::${TEST_TARGET_HOME}:/bin/bash"
    exit 0
fi
if [[ "\$1" == "passwd" && "\$2" == "tester" ]]; then
    echo "tester:x:1000:1000::${TEST_TARGET_HOME}:/bin/bash"
    exit 0
fi
exit 2
EOF
    chmod +x "$TEST_FAKE_BIN/getent"

    local output=""
    output=$(HOME="$TEST_ROOT_HOME" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        TEST_CONTINUE_SCRIPT="$CONTINUE_SH" \
        bash -lc '
            source "$TEST_CONTINUE_SCRIPT"
            get_install_state_file
        ' 2>&1)

    if [[ "$output" == "$TEST_TARGET_HOME/.acfs/state.json" ]]; then
        harness_pass "continue scans nonstandard homes via getent"
    else
        harness_fail "continue scans nonstandard homes via getent" "$output"
    fi

    cleanup_mock_env
}

test_info_uses_installed_layout_under_root_home() {
    setup_installed_layout_env

    local output=""
    output=$(HOME="$TEST_ROOT_HOME" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        bash "$TEST_INSTALLED_ACFS/scripts/lib/info.sh" --json)

    if printf '%s\n' "$output" | jq -e \
        '.installation.date == "2026-03-09" and .onboard.total_lessons == 1 and .onboard.next_lesson == "Lesson 1 - Installed Lesson"' \
        >/dev/null 2>&1; then
        harness_pass "info uses installed-layout state and lessons under root home"
    else
        harness_fail "info uses installed-layout state and lessons under root home" "$output"
    fi

    cleanup_mock_env
}

test_info_uses_system_state_target_home_when_getent_unavailable() {
    setup_system_state_target_home_env

    local output=""
    output=$(HOME="$TEST_ROOT_HOME" ACFS_SYSTEM_STATE_FILE="$TEST_SYSTEM_STATE_FILE" \
        PATH="$TEST_TARGET_HOME/.local/bin:$TEST_FAKE_BIN:/usr/bin:/bin" \
        bash "$INFO_SH" --json)

    if printf '%s\n' "$output" | jq -e \
        '.installation.date == "2026-03-09" and .onboard.total_lessons == 1 and .onboard.next_lesson == "Lesson 1 - Installed Lesson"' \
        >/dev/null 2>&1; then
        harness_pass "info uses target_home from system state when getent is unavailable"
    else
        harness_fail "info uses target_home from system state when getent is unavailable" "$output"
    fi

    cleanup_mock_env
}

test_info_ignores_relative_home_state_trap() {
    setup_system_state_target_home_only_env
    setup_relative_home_trap

    mkdir -p "$STALE_HOME/.acfs/onboard/lessons"
    cat > "$STALE_HOME/.acfs/state.json" <<'JSON'
{
  "mode": "safe",
  "target_user": "tester",
  "target_home": "/trap/home",
  "started_at": "2030-01-01T00:00:00Z",
  "last_updated": "2030-01-02T00:00:00Z"
}
JSON
    cat > "$STALE_HOME/.acfs/onboard/lessons/01-trap.md" <<'EOF'
# Trap Lesson
EOF

    local output=""
    output=$(cd "$TEST_HOME" && HOME="$RELATIVE_HOME" ACFS_SYSTEM_STATE_FILE="$TEST_SYSTEM_STATE_FILE" \
        PATH="$TEST_TARGET_HOME/.local/bin:$TEST_FAKE_BIN:/usr/bin:/bin" bash "$INFO_SH" --json)

    if printf '%s\n' "$output" | jq -e \
        '.installation.date == "2026-03-09" and .onboard.next_lesson == "Lesson 1 - Installed Lesson"' \
        >/dev/null 2>&1; then
        harness_pass "info ignores relative HOME state trap"
    else
        harness_fail "info ignores relative HOME state trap" "$output"
    fi

    cleanup_mock_env
}

test_info_uses_target_user_path_under_root_home() {
    setup_installed_layout_env

    local output=""
    output=$(HOME="$TEST_ROOT_HOME" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        TEST_INFO_SCRIPT="$TEST_INSTALLED_ACFS/scripts/lib/info.sh" \
        bash -lc '
            source "$TEST_INFO_SCRIPT"
            info_prepare_context
            info_get_installed_tools_summary
        ' 2>/dev/null)

    if [[ "$output" == "shell:✓|lang:✓|agents:✓|stack:✓" ]]; then
        harness_pass "info augments PATH from target-user install under root home"
    else
        harness_fail "info augments PATH from target-user install under root home" "$output"
    fi

    cleanup_mock_env
}

test_support_bundle_uses_installed_layout_under_root_home() {
    setup_installed_layout_env

    local output_dir="$TEST_HOME/support-out"
    mkdir -p "$output_dir"

    local archive_path=""
    archive_path=$(HOME="$TEST_ROOT_HOME" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        bash "$TEST_INSTALLED_ACFS/scripts/lib/support.sh" --output "$output_dir")

    local bundle_dir="$archive_path"
    if [[ "$bundle_dir" == *.tar.gz ]]; then
        bundle_dir="${bundle_dir%.tar.gz}"
    fi

    if [[ -f "$bundle_dir/environment.json" ]] \
        && [[ -f "$bundle_dir/state.json" ]] \
        && jq -e --arg acfs_home "$TEST_INSTALLED_ACFS" --arg target_home "$TEST_TARGET_HOME" \
            '.acfs_home == $acfs_home and .home == $target_home and .user == "tester"' \
            "$bundle_dir/environment.json" >/dev/null 2>&1; then
        harness_pass "support bundle uses installed-layout home and target user under root home"
    else
        harness_fail "support bundle uses installed-layout home and target user under root home" "$archive_path"
    fi

    cleanup_mock_env
}

test_support_bundle_uses_system_state_target_home_when_getent_unavailable() {
    setup_system_state_target_home_env

    local output_dir="$TEST_HOME/support-out"
    mkdir -p "$output_dir"

    local archive_path=""
    archive_path=$(HOME="$TEST_ROOT_HOME" ACFS_SYSTEM_STATE_FILE="$TEST_SYSTEM_STATE_FILE" SUPPORT_BUNDLE_DOCTOR_TIMEOUT=1 PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        bash "$SUPPORT_SH" --output "$output_dir")

    local bundle_dir="$archive_path"
    if [[ "$bundle_dir" == *.tar.gz ]]; then
        bundle_dir="${bundle_dir%.tar.gz}"
    fi

    if [[ -f "$bundle_dir/environment.json" ]] \
        && [[ -f "$bundle_dir/state.json" ]] \
        && jq -e --arg acfs_home "$TEST_INSTALLED_ACFS" --arg target_home "$TEST_TARGET_HOME" \
            '.acfs_home == $acfs_home and .home == $target_home and .user == "tester"' \
            "$bundle_dir/environment.json" >/dev/null 2>&1; then
        harness_pass "support bundle uses target_home from system state when getent is unavailable"
    else
        harness_fail "support bundle uses target_home from system state when getent is unavailable" "$archive_path"
    fi

    cleanup_mock_env
}

test_dashboard_copy_install_ignores_relative_home_trap() {
    setup_system_state_target_home_only_env
    setup_relative_home_trap

    mkdir -p "$TEST_ROOT_HOME/.local/bin" "$TEST_INSTALLED_ACFS/scripts/lib" "$STALE_HOME/.acfs/scripts/lib"
    cp "$DASHBOARD_SH" "$TEST_ROOT_HOME/.local/bin/dashboard"
    chmod +x "$TEST_ROOT_HOME/.local/bin/dashboard"

    cat > "$TEST_INSTALLED_ACFS/scripts/lib/info.sh" <<'EOF'
#!/usr/bin/env bash
printf '<html>copied-dashboard-info</html>\n'
EOF
    cat > "$STALE_HOME/.acfs/scripts/lib/info.sh" <<'EOF'
#!/usr/bin/env bash
printf '<html>trap-dashboard-info</html>\n'
EOF
    chmod +x "$TEST_INSTALLED_ACFS/scripts/lib/info.sh" "$STALE_HOME/.acfs/scripts/lib/info.sh"

    local output=""
    output=$(cd "$TEST_HOME" && HOME="$RELATIVE_HOME" ACFS_SYSTEM_STATE_FILE="$TEST_SYSTEM_STATE_FILE" \
        PATH="$TEST_ROOT_HOME/.local/bin:$TEST_FAKE_BIN:/usr/bin:/bin" dashboard generate --force 2>&1)

    if [[ "$output" == *"$TEST_INSTALLED_ACFS/dashboard/index.html"* ]] \
        && [[ -f "$TEST_INSTALLED_ACFS/dashboard/index.html" ]] \
        && [[ ! -e "$STALE_HOME/.acfs/dashboard/index.html" ]]; then
        harness_pass "copied dashboard ignores relative HOME trap"
    else
        harness_fail "copied dashboard ignores relative HOME trap" "$output"
    fi

    cleanup_mock_env
}

test_cheatsheet_copy_install_ignores_relative_home_trap() {
    setup_system_state_target_home_only_env
    setup_relative_home_trap

    mkdir -p "$TEST_ROOT_HOME/.local/bin" "$TEST_INSTALLED_ACFS/zsh" "$STALE_HOME/.acfs/zsh"
    cp "$CHEATSHEET_SH" "$TEST_ROOT_HOME/.local/bin/cheatsheet"
    chmod +x "$TEST_ROOT_HOME/.local/bin/cheatsheet"

    cat > "$TEST_INSTALLED_ACFS/zsh/acfs.zshrc" <<'EOF'
alias cod='codex'
EOF
    cat > "$STALE_HOME/.acfs/zsh/acfs.zshrc" <<'EOF'
alias trapcmd='echo trap'
EOF
    write_fake_command "$TEST_TARGET_HOME/.local/bin/codex" "codex 1.2.3"

    local output=""
    output=$(cd "$TEST_HOME" && HOME="$RELATIVE_HOME" ACFS_SYSTEM_STATE_FILE="$TEST_SYSTEM_STATE_FILE" \
        PATH="$TEST_ROOT_HOME/.local/bin:$TEST_FAKE_BIN:/usr/bin:/bin" cheatsheet --json 2>&1)

    if printf '%s\n' "$output" | jq -e --arg zshrc "$TEST_INSTALLED_ACFS/zsh/acfs.zshrc" \
        '.source == $zshrc and ([.entries[].name] | index("cod")) != null and ([.entries[].name] | index("trapcmd")) == null' \
        >/dev/null 2>&1; then
        harness_pass "copied cheatsheet ignores relative HOME trap"
    else
        harness_fail "copied cheatsheet ignores relative HOME trap" "$output"
    fi

    cleanup_mock_env
}

test_state_library_ignores_relative_home_target_resolution() {
    setup_mock_env

    TEST_FAKE_BIN="$TEST_HOME/fake-bin"
    mkdir -p "$TEST_FAKE_BIN"
    cat > "$TEST_FAKE_BIN/getent" <<'EOF'
#!/usr/bin/env bash
exit 2
EOF
    chmod +x "$TEST_FAKE_BIN/getent"

    local output=""
    output=$(HOME="relative-home" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        bash -c 'source "$1"; unset TARGET_HOME; TARGET_USER="$(id -un 2>/dev/null || whoami 2>/dev/null)"; printf "home=%s\n" "$(state_resolve_target_home)"; printf "state=%s\n" "$(state_get_file)"' _ \
        "$STATE_SH")

    local resolved_home=""
    local state_file=""
    resolved_home="$(printf '%s\n' "$output" | sed -n 's/^home=//p' | head -n 1)"
    state_file="$(printf '%s\n' "$output" | sed -n 's/^state=//p' | head -n 1)"

    if [[ "$resolved_home" == /* ]] && [[ "$resolved_home" != "/" ]] \
        && [[ "$resolved_home" != "relative-home" ]] \
        && [[ "$state_file" == "$resolved_home/.acfs/state.json" ]]; then
        harness_pass "state library ignores relative HOME during target resolution"
    else
        harness_fail "state library ignores relative HOME during target resolution" "$output"
    fi

    cleanup_mock_env
}

test_smoke_test_ignores_relative_home_target_resolution() {
    setup_mock_env

    TEST_FAKE_BIN="$TEST_HOME/fake-bin"
    mkdir -p "$TEST_FAKE_BIN"
    cat > "$TEST_FAKE_BIN/getent" <<'EOF'
#!/usr/bin/env bash
exit 2
EOF
    chmod +x "$TEST_FAKE_BIN/getent"

    local output=""
    output=$(HOME="relative-home" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        bash -c 'source "$1"; printf "target_home=%s\n" "$TARGET_HOME"' _ \
        "$SMOKE_TEST_SH")

    local resolved_home=""
    resolved_home="$(printf '%s\n' "$output" | sed -n 's/^target_home=//p' | head -n 1)"

    if [[ "$resolved_home" == /* ]] && [[ "$resolved_home" != "/" ]] && [[ "$resolved_home" != "relative-home" ]]; then
        harness_pass "smoke test ignores relative HOME during target resolution"
    else
        harness_fail "smoke test ignores relative HOME during target resolution" "$output"
    fi

    cleanup_mock_env
}

test_runtime_helpers_resolve_current_home_from_passwd_when_home_invalid() {
    setup_mock_env

    local current_user=""
    local passwd_home=""
    local failures=""

    current_user="$(id -un 2>/dev/null || whoami 2>/dev/null || true)"
    passwd_home="$TEST_HOME/passwd-home"
    TEST_FAKE_BIN="$TEST_HOME/fake-bin"
    mkdir -p "$TEST_FAKE_BIN" "$passwd_home"

    cat > "$TEST_FAKE_BIN/getent" <<EOF
#!/usr/bin/env bash
if [[ "\$1" == "passwd" ]] && [[ "\$2" == "$current_user" ]]; then
    echo "$current_user:x:1000:1000::$passwd_home:/bin/bash"
    exit 0
fi
exit 2
EOF
    chmod +x "$TEST_FAKE_BIN/getent"

    while IFS='|' read -r label script func; do
        [[ -n "$label" ]] || continue
        local output=""
        local status=0
        output=$(HOME="relative-home" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
            bash -c 'script="$1"; func="$2"; shift 2; set --; source "$script"; "$func"' _ \
            "$script" "$func" 2>&1) || status=$?

        if [[ $status -ne 0 ]] || [[ "$output" != "$passwd_home" ]]; then
            failures+="${label}: status=${status} output=${output}"$'\n'
        fi
    done <<EOF
continue|$CONTINUE_SH|continue_resolve_current_home
dashboard|$DASHBOARD_SH|dashboard_resolve_current_home
info|$INFO_SH|info_resolve_current_home
changelog|$CHANGELOG_SH|changelog_resolve_current_home
EOF

    if [[ -z "$failures" ]]; then
        harness_pass "runtime helpers recover current home from passwd when HOME is invalid"
    else
        harness_fail "runtime helpers recover current home from passwd when HOME is invalid" "$failures"
    fi

    cleanup_mock_env
}

test_runtime_helpers_reject_invalid_passwd_home_for_target_user() {
    setup_mock_env

    TEST_FAKE_BIN="$TEST_HOME/fake-bin"
    mkdir -p "$TEST_FAKE_BIN"

    cat > "$TEST_FAKE_BIN/getent" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "passwd" ]] && [[ "$2" == "tester" ]]; then
    echo 'tester:x:1000:1000::relative-home:/bin/bash'
    exit 0
fi
exit 2
EOF
    chmod +x "$TEST_FAKE_BIN/getent"

    local failures=""

    while IFS='|' read -r label script func; do
        [[ -n "$label" ]] || continue
        local output=""
        local status=0
        output=$(HOME="$TEST_HOME" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
            bash -c 'script="$1"; func="$2"; shift 2; set --; source "$script"; "$func" tester' _ \
            "$script" "$func" 2>&1) || status=$?

        if [[ $status -ne 0 ]] || [[ "$output" != "/home/tester" ]]; then
            failures+="${label}: status=${status} output=${output}"$'\n'
        fi
    done <<EOF
continue|$CONTINUE_SH|home_for_user
dashboard|$DASHBOARD_SH|dashboard_home_for_user
info|$INFO_SH|info_home_for_user
changelog|$CHANGELOG_SH|changelog_home_for_user
EOF

    if [[ -z "$failures" ]]; then
        harness_pass "runtime helpers reject malformed passwd homes for target users"
    else
        harness_fail "runtime helpers reject malformed passwd homes for target users" "$failures"
    fi

    cleanup_mock_env
}

test_doctor_dispatches_installed_layout_under_root_home() {
    setup_installed_layout_env

    local output
    output=$(HOME="$TEST_ROOT_HOME" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        bash "$TEST_INSTALLED_ACFS/bin/acfs" version)

    if [[ "$output" == "2.0.0" ]]; then
        harness_pass "installed acfs dispatcher finds VERSION and helper tree under root home"
    else
        harness_fail "installed acfs dispatcher finds VERSION and helper tree under root home" "$output"
    fi

    cleanup_mock_env
}

test_doctor_ignores_relative_home_state_trap() {
    setup_installed_layout_env
    setup_relative_home_trap

    mkdir -p "$STALE_HOME/.local/bin"
    cat > "$STALE_HOME/.acfs/state.json" <<EOF
{
  "target_user": "tester",
  "target_home": "$STALE_HOME"
}
EOF
    write_fake_command "$STALE_HOME/.local/bin/claude" "claude stale"

    local output=""
    output=$(cd "$TEST_HOME" && HOME="$RELATIVE_HOME" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        bash "$TEST_INSTALLED_ACFS/bin/acfs" doctor --json)

    if printf '%s\n' "$output" | jq -e --arg live_path "$TEST_TARGET_HOME/.local/bin/claude" --arg stale_path "$STALE_HOME/.local/bin/claude" '
        ([.checks[] | select(.id == "agent.path.claude") | .details] | first) == ("native (" + $live_path + ")") and
        ([.checks[] | select(.id == "agent.path.claude") | .details] | first) != ("native (" + $stale_path + ")")
    ' >/dev/null 2>&1; then
        harness_pass "doctor ignores relative HOME state trap"
    else
        harness_fail "doctor ignores relative HOME state trap" "$output"
    fi

    cleanup_mock_env
}

test_acfs_update_wrapper_uses_system_state_target_home_when_getent_unavailable() {
    setup_system_state_target_home_env

    mkdir -p "$TEST_TARGET_HOME/.acfs/scripts/lib" "$TEST_HOME/probe"
    printf '#!/usr/bin/env bash\n' > "$TEST_TARGET_HOME/.acfs/scripts/lib/update.sh"
    chmod +x "$TEST_TARGET_HOME/.acfs/scripts/lib/update.sh"
    cp "$REPO_ROOT/scripts/acfs-update" "$TEST_HOME/probe/acfs-update"
    chmod +x "$TEST_HOME/probe/acfs-update"

    cat > "$TEST_FAKE_BIN/sudo" <<'EOF'
#!/usr/bin/env bash
printf 'sudo-argv=%s\n' "$*"
EOF
    cat > "$TEST_FAKE_BIN/stat" <<EOF
#!/usr/bin/env bash
if [[ "\$1" == "-c" ]] && [[ "\$2" == "%U" ]] && [[ "\$3" == "$TEST_TARGET_HOME" ]]; then
    printf 'tester\n'
    exit 0
fi
exec /usr/bin/stat "\$@"
EOF
    chmod +x "$TEST_FAKE_BIN/sudo" "$TEST_FAKE_BIN/stat"

    local output=""
    output=$(HOME="$TEST_ROOT_HOME" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        ACFS_SYSTEM_STATE_FILE="$TEST_SYSTEM_STATE_FILE" \
        bash "$TEST_HOME/probe/acfs-update" --help 2>&1)

    if [[ "$output" == *"ACFS_SYSTEM_STATE_FILE=$TEST_SYSTEM_STATE_FILE"* ]] \
        && [[ "$output" == *"$TEST_TARGET_HOME/.acfs/scripts/lib/update.sh --help"* ]] \
        && [[ "$output" == *"-u tester -H"* ]]; then
        harness_pass "acfs-update wrapper uses system-state target_home when getent is unavailable"
    else
        harness_fail "acfs-update wrapper uses system-state target_home when getent is unavailable" "$output"
    fi

    cleanup_mock_env
}

test_acfs_update_wrapper_repairs_runtime_home_on_direct_exec() {
    setup_system_state_target_home_only_env

    mkdir -p "$TEST_HOME/probe" "$TEST_TARGET_HOME/.acfs/scripts/lib"
    cp "$REPO_ROOT/scripts/acfs-update" "$TEST_HOME/probe/acfs-update"
    chmod +x "$TEST_HOME/probe/acfs-update"

    cat > "$TEST_TARGET_HOME/.acfs/scripts/lib/update.sh" <<'EOF'
#!/usr/bin/env bash
printf 'HOME=%s TARGET_HOME=%s ACFS_HOME=%s ARG1=%s\n' "$HOME" "${TARGET_HOME:-}" "${ACFS_HOME:-}" "${1:-}"
EOF
    chmod +x "$TEST_TARGET_HOME/.acfs/scripts/lib/update.sh"

    local output=""
    output=$(HOME="$TEST_ROOT_HOME" ACFS_HOME="$TEST_ROOT_HOME/.acfs" TARGET_HOME="$TEST_ROOT_HOME" \
        ACFS_STATE_FILE="$TEST_ROOT_HOME/.acfs/state.json" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        ACFS_SYSTEM_STATE_FILE="$TEST_SYSTEM_STATE_FILE" \
        bash "$TEST_HOME/probe/acfs-update" --dry-run 2>&1)

    if [[ "$output" == "HOME=$TEST_TARGET_HOME TARGET_HOME=$TEST_TARGET_HOME ACFS_HOME=$TEST_INSTALLED_ACFS ARG1=--dry-run" ]]; then
        harness_pass "acfs-update wrapper repairs runtime home on direct exec"
    else
        harness_fail "acfs-update wrapper repairs runtime home on direct exec" "$output"
    fi

    cleanup_mock_env
}

test_acfs_update_wrapper_passes_bin_dir_from_state() {
    setup_system_state_target_home_only_env

    mkdir -p "$TEST_HOME/probe" "$TEST_TARGET_HOME/.acfs/scripts/lib"
    cp "$REPO_ROOT/scripts/acfs-update" "$TEST_HOME/probe/acfs-update"
    chmod +x "$TEST_HOME/probe/acfs-update"

    local custom_bin="$TEST_HOME/custom-bin"
    cat > "$TEST_TARGET_HOME/.acfs/state.json" <<EOF
{
  "target_user": "tester",
  "target_home": "$TEST_TARGET_HOME",
  "bin_dir": "$custom_bin"
}
EOF

    cat > "$TEST_TARGET_HOME/.acfs/scripts/lib/update.sh" <<'EOF'
#!/usr/bin/env bash
printf 'ACFS_BIN_DIR=%s TARGET_HOME=%s\n' "${ACFS_BIN_DIR:-}" "${TARGET_HOME:-}"
EOF
    chmod +x "$TEST_TARGET_HOME/.acfs/scripts/lib/update.sh"

    local output=""
    output=$(HOME="$TEST_ROOT_HOME" ACFS_HOME="$TEST_ROOT_HOME/.acfs" TARGET_HOME="$TEST_ROOT_HOME" \
        ACFS_STATE_FILE="$TEST_ROOT_HOME/.acfs/state.json" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        ACFS_SYSTEM_STATE_FILE="$TEST_SYSTEM_STATE_FILE" \
        bash "$TEST_HOME/probe/acfs-update" --dry-run 2>&1)

    if [[ "$output" == "ACFS_BIN_DIR=$custom_bin TARGET_HOME=$TEST_TARGET_HOME" ]]; then
        harness_pass "acfs-update wrapper passes persisted bin_dir from state"
    else
        harness_fail "acfs-update wrapper passes persisted bin_dir from state" "$output"
    fi

    cleanup_mock_env
}

test_acfs_update_wrapper_discards_invalid_env_bin_dir_on_direct_exec() {
    setup_system_state_target_home_only_env

    mkdir -p "$TEST_HOME/probe" "$TEST_TARGET_HOME/.acfs/scripts/lib"
    cp "$REPO_ROOT/scripts/acfs-update" "$TEST_HOME/probe/acfs-update"
    chmod +x "$TEST_HOME/probe/acfs-update"

    cat > "$TEST_TARGET_HOME/.acfs/scripts/lib/update.sh" <<'EOF'
#!/usr/bin/env bash
printf 'ACFS_BIN_DIR=%s TARGET_HOME=%s\n' "${ACFS_BIN_DIR:-}" "${TARGET_HOME:-}"
EOF
    chmod +x "$TEST_TARGET_HOME/.acfs/scripts/lib/update.sh"

    local output=""
    output=$(HOME="$TEST_ROOT_HOME" ACFS_HOME="$TEST_ROOT_HOME/.acfs" TARGET_HOME="$TEST_ROOT_HOME" \
        ACFS_STATE_FILE="$TEST_ROOT_HOME/.acfs/state.json" ACFS_BIN_DIR="relative/bin" \
        PATH="$TEST_FAKE_BIN:/usr/bin:/bin" ACFS_SYSTEM_STATE_FILE="$TEST_SYSTEM_STATE_FILE" \
        bash "$TEST_HOME/probe/acfs-update" --dry-run 2>&1)

    if [[ "$output" == "ACFS_BIN_DIR= TARGET_HOME=$TEST_TARGET_HOME" ]]; then
        harness_pass "acfs-update wrapper discards invalid env bin_dir on direct exec"
    else
        harness_fail "acfs-update wrapper discards invalid env bin_dir on direct exec" "$output"
    fi

    cleanup_mock_env
}

test_acfs_update_wrapper_discards_invalid_env_state_file_on_direct_exec() {
    setup_system_state_target_home_only_env

    mkdir -p "$TEST_HOME/probe" "$TEST_TARGET_HOME/.acfs/scripts/lib"
    cp "$REPO_ROOT/scripts/acfs-update" "$TEST_HOME/probe/acfs-update"
    chmod +x "$TEST_HOME/probe/acfs-update"

    cat > "$TEST_TARGET_HOME/.acfs/scripts/lib/update.sh" <<'EOF'
#!/usr/bin/env bash
printf 'HOME=%s TARGET_HOME=%s ACFS_HOME=%s ARG1=%s\n' "$HOME" "${TARGET_HOME:-}" "${ACFS_HOME:-}" "${1:-}"
EOF
    chmod +x "$TEST_TARGET_HOME/.acfs/scripts/lib/update.sh"

    local output=""
    output=$(HOME="$TEST_ROOT_HOME" ACFS_HOME="$TEST_ROOT_HOME/.acfs" TARGET_HOME="$TEST_ROOT_HOME" \
        ACFS_STATE_FILE="relative-state.json" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        ACFS_SYSTEM_STATE_FILE="$TEST_SYSTEM_STATE_FILE" \
        bash "$TEST_HOME/probe/acfs-update" --dry-run 2>&1)

    if [[ "$output" == "HOME=$TEST_TARGET_HOME TARGET_HOME=$TEST_TARGET_HOME ACFS_HOME=$TEST_INSTALLED_ACFS ARG1=--dry-run" ]]; then
        harness_pass "acfs-update wrapper discards invalid env state file on direct exec"
    else
        harness_fail "acfs-update wrapper discards invalid env state file on direct exec" "$output"
    fi

    cleanup_mock_env
}

test_acfs_update_wrapper_ignores_relative_home_state_trap() {
    setup_system_state_target_home_only_env

    local relative_home="relative-home"
    local stale_home="$TEST_HOME/$relative_home"

    mkdir -p \
        "$TEST_HOME/probe" \
        "$TEST_TARGET_HOME/.acfs/scripts/lib" \
        "$stale_home/.acfs/scripts/lib"
    cp "$REPO_ROOT/scripts/acfs-update" "$TEST_HOME/probe/acfs-update"
    chmod +x "$TEST_HOME/probe/acfs-update"

    cat > "$TEST_TARGET_HOME/.acfs/scripts/lib/update.sh" <<'EOF'
#!/usr/bin/env bash
printf 'TARGET_HOME=%s SOURCE=live\n' "${TARGET_HOME:-}"
EOF
    cat > "$stale_home/.acfs/state.json" <<EOF
{
  "target_user": "tester",
  "target_home": "$stale_home"
}
EOF
    cat > "$stale_home/.acfs/scripts/lib/update.sh" <<'EOF'
#!/usr/bin/env bash
printf 'TARGET_HOME=%s SOURCE=stale\n' "${TARGET_HOME:-}"
EOF
    chmod +x "$TEST_TARGET_HOME/.acfs/scripts/lib/update.sh" "$stale_home/.acfs/scripts/lib/update.sh"

    local output=""
    output=$(cd "$TEST_HOME" && HOME="$relative_home" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        ACFS_SYSTEM_STATE_FILE="$TEST_SYSTEM_STATE_FILE" \
        bash "$TEST_HOME/probe/acfs-update" --dry-run 2>&1)

    if [[ "$output" == "TARGET_HOME=$TEST_TARGET_HOME SOURCE=live" ]]; then
        harness_pass "acfs-update wrapper ignores relative HOME state trap"
    else
        harness_fail "acfs-update wrapper ignores relative HOME state trap" "$output"
    fi

    cleanup_mock_env
}

test_acfs_update_wrapper_ignores_stale_home_adjacent_target_user() {
    setup_mock_env

    TEST_ROOT_HOME="$TEST_HOME/root-home"
    TEST_TARGET_HOME="$TEST_HOME/custom-home"
    TEST_FAKE_BIN="$TEST_HOME/fake-bin"
    local other_home="$TEST_HOME/other-home"

    mkdir -p \
        "$TEST_ROOT_HOME" \
        "$TEST_TARGET_HOME/.acfs/scripts/lib" \
        "$other_home/.acfs/scripts/lib" \
        "$TEST_HOME/probe" \
        "$TEST_FAKE_BIN"

    cat > "$TEST_TARGET_HOME/.acfs/state.json" <<'JSON'
{
  "target_user": "otheruser"
}
JSON
    printf '#!/usr/bin/env bash\n' > "$TEST_TARGET_HOME/.acfs/scripts/lib/update.sh"
    printf '#!/usr/bin/env bash\n' > "$other_home/.acfs/scripts/lib/update.sh"
    chmod +x "$TEST_TARGET_HOME/.acfs/scripts/lib/update.sh" "$other_home/.acfs/scripts/lib/update.sh"
    cp "$REPO_ROOT/scripts/acfs-update" "$TEST_HOME/probe/acfs-update"
    chmod +x "$TEST_HOME/probe/acfs-update"

    cat > "$TEST_FAKE_BIN/getent" <<EOF
#!/usr/bin/env bash
if [[ "\$1" == "passwd" ]] && [[ -z "\${2:-}" ]]; then
    printf 'tester:x:1000:1000::%s:/bin/bash\n' "$TEST_TARGET_HOME"
    printf 'otheruser:x:1001:1001::%s:/bin/bash\n' "$other_home"
    exit 0
fi
if [[ "\$1" == "passwd" ]] && [[ "\$2" == "tester" ]]; then
    printf 'tester:x:1000:1000::%s:/bin/bash\n' "$TEST_TARGET_HOME"
    exit 0
fi
if [[ "\$1" == "passwd" ]] && [[ "\$2" == "otheruser" ]]; then
    printf 'otheruser:x:1001:1001::%s:/bin/bash\n' "$other_home"
    exit 0
fi
exit 2
EOF
    cat > "$TEST_FAKE_BIN/sudo" <<'EOF'
#!/usr/bin/env bash
printf 'sudo-argv=%s\n' "$*"
EOF
    chmod +x "$TEST_FAKE_BIN/getent" "$TEST_FAKE_BIN/sudo"

    local output=""
    output=$(HOME="$TEST_ROOT_HOME" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        ACFS_STATE_FILE="$TEST_TARGET_HOME/.acfs/state.json" \
        bash "$TEST_HOME/probe/acfs-update" --help 2>&1)

    if [[ "$output" == *"$TEST_TARGET_HOME/.acfs/scripts/lib/update.sh --help"* ]] \
        && [[ "$output" == *"-u tester -H"* ]] \
        && [[ "$output" != *"$other_home/.acfs/scripts/lib/update.sh"* ]] \
        && [[ "$output" != *"-u otheruser -H"* ]]; then
        harness_pass "acfs-update wrapper ignores stale home-adjacent target_user"
    else
        harness_fail "acfs-update wrapper ignores stale home-adjacent target_user" "$output"
    fi

    cleanup_mock_env
}

test_acfs_global_wrapper_uses_system_state_target_home_when_getent_unavailable() {
    setup_system_state_target_home_env

    mkdir -p "$TEST_HOME/probe"
    printf '#!/usr/bin/env bash\n' > "$TEST_TARGET_HOME/.local/bin/acfs"
    chmod +x "$TEST_TARGET_HOME/.local/bin/acfs"
    cp "$REPO_ROOT/scripts/acfs-global" "$TEST_HOME/probe/acfs"
    chmod +x "$TEST_HOME/probe/acfs"

    cat > "$TEST_FAKE_BIN/sudo" <<'EOF'
#!/usr/bin/env bash
printf 'sudo-argv=%s\n' "$*"
EOF
    cat > "$TEST_FAKE_BIN/stat" <<EOF
#!/usr/bin/env bash
if [[ "\$1" == "-c" ]] && [[ "\$2" == "%U" ]] && [[ "\$3" == "$TEST_TARGET_HOME" ]]; then
    printf 'tester\n'
    exit 0
fi
exec /usr/bin/stat "\$@"
EOF
    chmod +x "$TEST_FAKE_BIN/sudo" "$TEST_FAKE_BIN/stat"

    local output=""
    output=$(HOME="$TEST_ROOT_HOME" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        ACFS_SYSTEM_STATE_FILE="$TEST_SYSTEM_STATE_FILE" \
        bash "$TEST_HOME/probe/acfs" version 2>&1)

    if [[ "$output" == *"ACFS_SYSTEM_STATE_FILE=$TEST_SYSTEM_STATE_FILE"* ]] \
        && [[ "$output" == *"$TEST_TARGET_HOME/.local/bin/acfs version"* ]] \
        && [[ "$output" == *"-u tester -H"* ]]; then
        harness_pass "global acfs wrapper uses system-state target_home when getent is unavailable"
    else
        harness_fail "global acfs wrapper uses system-state target_home when getent is unavailable" "$output"
    fi

    cleanup_mock_env
}

test_acfs_global_wrapper_repairs_runtime_home_on_direct_exec() {
    setup_system_state_target_home_only_env

    mkdir -p "$TEST_HOME/probe" "$TEST_TARGET_HOME/.local/bin"
    cp "$REPO_ROOT/scripts/acfs-global" "$TEST_HOME/probe/acfs"
    chmod +x "$TEST_HOME/probe/acfs"

    cat > "$TEST_TARGET_HOME/.local/bin/acfs" <<'EOF'
#!/usr/bin/env bash
printf 'HOME=%s TARGET_HOME=%s ACFS_HOME=%s ARG1=%s\n' "$HOME" "${TARGET_HOME:-}" "${ACFS_HOME:-}" "${1:-}"
EOF
    chmod +x "$TEST_TARGET_HOME/.local/bin/acfs"

    local output=""
    output=$(HOME="$TEST_ROOT_HOME" ACFS_HOME="$TEST_ROOT_HOME/.acfs" TARGET_HOME="$TEST_ROOT_HOME" \
        ACFS_STATE_FILE="$TEST_ROOT_HOME/.acfs/state.json" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        ACFS_SYSTEM_STATE_FILE="$TEST_SYSTEM_STATE_FILE" \
        bash "$TEST_HOME/probe/acfs" version 2>&1)

    if [[ "$output" == "HOME=$TEST_TARGET_HOME TARGET_HOME=$TEST_TARGET_HOME ACFS_HOME=$TEST_INSTALLED_ACFS ARG1=version" ]]; then
        harness_pass "global acfs wrapper repairs runtime home on direct exec"
    else
        harness_fail "global acfs wrapper repairs runtime home on direct exec" "$output"
    fi

    cleanup_mock_env
}

test_acfs_global_wrapper_runs_direct_when_owner_unknown_but_target_home_known() {
    setup_system_state_target_home_only_env

    mkdir -p "$TEST_HOME/probe" "$TEST_TARGET_HOME/.local/bin"
    cp "$REPO_ROOT/scripts/acfs-global" "$TEST_HOME/probe/acfs"
    chmod +x "$TEST_HOME/probe/acfs"

    cat > "$TEST_TARGET_HOME/.local/bin/acfs" <<'EOF'
#!/usr/bin/env bash
printf 'HOME=%s TARGET_HOME=%s ACFS_HOME=%s ARG1=%s\n' "$HOME" "${TARGET_HOME:-}" "${ACFS_HOME:-}" "${1:-}"
EOF
    cat > "$TEST_FAKE_BIN/stat" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "-c" ]] && [[ "$2" == "%U" ]]; then
    printf 'UNKNOWN\n'
    exit 0
fi
exec /usr/bin/stat "$@"
EOF
    cat > "$TEST_FAKE_BIN/sudo" <<'EOF'
#!/usr/bin/env bash
printf 'sudo-called=%s\n' "$*"
EOF
    chmod +x "$TEST_TARGET_HOME/.local/bin/acfs" "$TEST_FAKE_BIN/stat" "$TEST_FAKE_BIN/sudo"

    local output=""
    output=$(HOME="$TEST_ROOT_HOME" ACFS_HOME="$TEST_ROOT_HOME/.acfs" TARGET_HOME="$TEST_ROOT_HOME" \
        ACFS_STATE_FILE="$TEST_ROOT_HOME/.acfs/state.json" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        ACFS_SYSTEM_STATE_FILE="$TEST_SYSTEM_STATE_FILE" \
        bash "$TEST_HOME/probe/acfs" version 2>&1)

    if [[ "$output" == "HOME=$TEST_TARGET_HOME TARGET_HOME=$TEST_TARGET_HOME ACFS_HOME=$TEST_INSTALLED_ACFS ARG1=version" ]]; then
        harness_pass "global acfs wrapper runs direct when owner is unknown but target_home is known"
    else
        harness_fail "global acfs wrapper runs direct when owner is unknown but target_home is known" "$output"
    fi

    cleanup_mock_env
}

test_acfs_global_wrapper_passes_bin_dir_from_state() {
    setup_system_state_target_home_only_env

    mkdir -p "$TEST_HOME/probe" "$TEST_TARGET_HOME/.acfs/bin"
    cp "$REPO_ROOT/scripts/acfs-global" "$TEST_HOME/probe/acfs"
    chmod +x "$TEST_HOME/probe/acfs"

    local custom_bin="$TEST_HOME/custom-bin"
    cat > "$TEST_TARGET_HOME/.acfs/state.json" <<EOF
{
  "target_user": "tester",
  "target_home": "$TEST_TARGET_HOME",
  "bin_dir": "$custom_bin"
}
EOF

    cat > "$TEST_TARGET_HOME/.acfs/bin/acfs" <<'EOF'
#!/usr/bin/env bash
printf 'ACFS_BIN_DIR=%s TARGET_HOME=%s\n' "${ACFS_BIN_DIR:-}" "${TARGET_HOME:-}"
EOF
    chmod +x "$TEST_TARGET_HOME/.acfs/bin/acfs"

    local output=""
    output=$(HOME="$TEST_ROOT_HOME" ACFS_HOME="$TEST_ROOT_HOME/.acfs" TARGET_HOME="$TEST_ROOT_HOME" \
        ACFS_STATE_FILE="$TEST_ROOT_HOME/.acfs/state.json" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        ACFS_SYSTEM_STATE_FILE="$TEST_SYSTEM_STATE_FILE" \
        bash "$TEST_HOME/probe/acfs" version 2>&1)

    if [[ "$output" == "ACFS_BIN_DIR=$custom_bin TARGET_HOME=$TEST_TARGET_HOME" ]]; then
        harness_pass "global acfs wrapper passes persisted bin_dir from state"
    else
        harness_fail "global acfs wrapper passes persisted bin_dir from state" "$output"
    fi

    cleanup_mock_env
}

test_acfs_global_wrapper_discards_invalid_env_bin_dir_on_direct_exec() {
    setup_system_state_target_home_only_env

    mkdir -p "$TEST_HOME/probe" "$TEST_TARGET_HOME/.local/bin"
    cp "$REPO_ROOT/scripts/acfs-global" "$TEST_HOME/probe/acfs"
    chmod +x "$TEST_HOME/probe/acfs"

    cat > "$TEST_TARGET_HOME/.local/bin/acfs" <<'EOF'
#!/usr/bin/env bash
printf 'ACFS_BIN_DIR=%s TARGET_HOME=%s\n' "${ACFS_BIN_DIR:-}" "${TARGET_HOME:-}"
EOF
    chmod +x "$TEST_TARGET_HOME/.local/bin/acfs"

    local output=""
    output=$(HOME="$TEST_ROOT_HOME" ACFS_HOME="$TEST_ROOT_HOME/.acfs" TARGET_HOME="$TEST_ROOT_HOME" \
        ACFS_STATE_FILE="$TEST_ROOT_HOME/.acfs/state.json" ACFS_BIN_DIR="relative/bin" \
        PATH="$TEST_FAKE_BIN:/usr/bin:/bin" ACFS_SYSTEM_STATE_FILE="$TEST_SYSTEM_STATE_FILE" \
        bash "$TEST_HOME/probe/acfs" version 2>&1)

    if [[ "$output" == "ACFS_BIN_DIR= TARGET_HOME=$TEST_TARGET_HOME" ]]; then
        harness_pass "global acfs wrapper discards invalid env bin_dir on direct exec"
    else
        harness_fail "global acfs wrapper discards invalid env bin_dir on direct exec" "$output"
    fi

    cleanup_mock_env
}

test_acfs_global_wrapper_discards_invalid_env_state_file_on_direct_exec() {
    setup_system_state_target_home_only_env

    mkdir -p "$TEST_HOME/probe" "$TEST_TARGET_HOME/.local/bin"
    cp "$REPO_ROOT/scripts/acfs-global" "$TEST_HOME/probe/acfs"
    chmod +x "$TEST_HOME/probe/acfs"

    cat > "$TEST_TARGET_HOME/.local/bin/acfs" <<'EOF'
#!/usr/bin/env bash
printf 'HOME=%s TARGET_HOME=%s ACFS_HOME=%s ARG1=%s\n' "$HOME" "${TARGET_HOME:-}" "${ACFS_HOME:-}" "${1:-}"
EOF
    chmod +x "$TEST_TARGET_HOME/.local/bin/acfs"

    local output=""
    output=$(HOME="$TEST_ROOT_HOME" ACFS_HOME="$TEST_ROOT_HOME/.acfs" TARGET_HOME="$TEST_ROOT_HOME" \
        ACFS_STATE_FILE="relative-state.json" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        ACFS_SYSTEM_STATE_FILE="$TEST_SYSTEM_STATE_FILE" \
        bash "$TEST_HOME/probe/acfs" version 2>&1)

    if [[ "$output" == "HOME=$TEST_TARGET_HOME TARGET_HOME=$TEST_TARGET_HOME ACFS_HOME=$TEST_INSTALLED_ACFS ARG1=version" ]]; then
        harness_pass "global acfs wrapper discards invalid env state file on direct exec"
    else
        harness_fail "global acfs wrapper discards invalid env state file on direct exec" "$output"
    fi

    cleanup_mock_env
}

test_acfs_global_wrapper_ignores_relative_home_state_trap() {
    setup_system_state_target_home_only_env

    local relative_home="relative-home"
    local stale_home="$TEST_HOME/$relative_home"

    mkdir -p \
        "$TEST_HOME/probe" \
        "$TEST_TARGET_HOME/.local/bin" \
        "$stale_home/.acfs" \
        "$stale_home/.local/bin"
    cp "$REPO_ROOT/scripts/acfs-global" "$TEST_HOME/probe/acfs"
    chmod +x "$TEST_HOME/probe/acfs"

    cat > "$TEST_TARGET_HOME/.local/bin/acfs" <<'EOF'
#!/usr/bin/env bash
printf 'TARGET_HOME=%s SOURCE=live ARG1=%s\n' "${TARGET_HOME:-}" "${1:-}"
EOF
    cat > "$stale_home/.acfs/state.json" <<EOF
{
  "target_user": "tester",
  "target_home": "$stale_home"
}
EOF
    cat > "$stale_home/.local/bin/acfs" <<'EOF'
#!/usr/bin/env bash
printf 'TARGET_HOME=%s SOURCE=stale ARG1=%s\n' "${TARGET_HOME:-}" "${1:-}"
EOF
    chmod +x "$TEST_TARGET_HOME/.local/bin/acfs" "$stale_home/.local/bin/acfs"

    local output=""
    output=$(cd "$TEST_HOME" && HOME="$relative_home" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        ACFS_SYSTEM_STATE_FILE="$TEST_SYSTEM_STATE_FILE" \
        bash "$TEST_HOME/probe/acfs" version 2>&1)

    if [[ "$output" == "TARGET_HOME=$TEST_TARGET_HOME SOURCE=live ARG1=version" ]]; then
        harness_pass "global acfs wrapper ignores relative HOME state trap"
    else
        harness_fail "global acfs wrapper ignores relative HOME state trap" "$output"
    fi

    cleanup_mock_env
}

test_acfs_global_wrapper_does_not_guess_current_home_when_target_home_is_unresolved() {
    setup_mock_env

    TEST_ROOT_HOME="$TEST_HOME/root-home"
    TEST_FAKE_BIN="$TEST_HOME/fake-bin"

    mkdir -p "$TEST_ROOT_HOME" "$TEST_FAKE_BIN" "$TEST_HOME/probe"
    cp "$REPO_ROOT/scripts/acfs-global" "$TEST_HOME/probe/acfs"
    chmod +x "$TEST_HOME/probe/acfs"

    cat > "$TEST_FAKE_BIN/getent" <<'EOF'
#!/usr/bin/env bash
exit 2
EOF
    chmod +x "$TEST_FAKE_BIN/getent"

    local custom_state="$TEST_HOME/system-state.json"
    cat > "$custom_state" <<'JSON'
{
  "target_user": "ubuntu"
}
JSON

    local output=""
    output=$(HOME="$TEST_ROOT_HOME" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        ACFS_SYSTEM_STATE_FILE="$custom_state" \
        bash "$TEST_HOME/probe/acfs" version 2>&1 || true)

    if [[ "$output" == *"Unable to determine the ACFS owner automatically."* ]] \
        && [[ "$output" != *"Expected at: $TEST_ROOT_HOME/.local/bin/acfs"* ]] \
        && [[ "$output" != *"user 'ubuntu'"* ]]; then
        harness_pass "global acfs wrapper does not guess current HOME when target_home is unresolved"
    else
        harness_fail "global acfs wrapper does not guess current HOME when target_home is unresolved" "$output"
    fi

    cleanup_mock_env
}

test_acfs_global_wrapper_ignores_stale_home_adjacent_target_user() {
    setup_mock_env

    TEST_ROOT_HOME="$TEST_HOME/root-home"
    TEST_TARGET_HOME="$TEST_HOME/custom-home"
    TEST_FAKE_BIN="$TEST_HOME/fake-bin"
    local other_home="$TEST_HOME/other-home"

    mkdir -p \
        "$TEST_ROOT_HOME" \
        "$TEST_TARGET_HOME/.acfs" \
        "$TEST_TARGET_HOME/.local/bin" \
        "$other_home/.local/bin" \
        "$TEST_HOME/probe" \
        "$TEST_FAKE_BIN"

    cat > "$TEST_TARGET_HOME/.acfs/state.json" <<'JSON'
{
  "target_user": "otheruser"
}
JSON
    printf '#!/usr/bin/env bash\n' > "$TEST_TARGET_HOME/.local/bin/acfs"
    printf '#!/usr/bin/env bash\n' > "$other_home/.local/bin/acfs"
    chmod +x "$TEST_TARGET_HOME/.local/bin/acfs" "$other_home/.local/bin/acfs"
    cp "$REPO_ROOT/scripts/acfs-global" "$TEST_HOME/probe/acfs"
    chmod +x "$TEST_HOME/probe/acfs"

    cat > "$TEST_FAKE_BIN/getent" <<EOF
#!/usr/bin/env bash
if [[ "\$1" == "passwd" ]] && [[ -z "\${2:-}" ]]; then
    printf 'tester:x:1000:1000::%s:/bin/bash\n' "$TEST_TARGET_HOME"
    printf 'otheruser:x:1001:1001::%s:/bin/bash\n' "$other_home"
    exit 0
fi
if [[ "\$1" == "passwd" ]] && [[ "\$2" == "tester" ]]; then
    printf 'tester:x:1000:1000::%s:/bin/bash\n' "$TEST_TARGET_HOME"
    exit 0
fi
if [[ "\$1" == "passwd" ]] && [[ "\$2" == "otheruser" ]]; then
    printf 'otheruser:x:1001:1001::%s:/bin/bash\n' "$other_home"
    exit 0
fi
exit 2
EOF
    cat > "$TEST_FAKE_BIN/sudo" <<'EOF'
#!/usr/bin/env bash
printf 'sudo-argv=%s\n' "$*"
EOF
    chmod +x "$TEST_FAKE_BIN/getent" "$TEST_FAKE_BIN/sudo"

    local output=""
    output=$(HOME="$TEST_ROOT_HOME" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        ACFS_STATE_FILE="$TEST_TARGET_HOME/.acfs/state.json" \
        bash "$TEST_HOME/probe/acfs" version 2>&1)

    if [[ "$output" == *"$TEST_TARGET_HOME/.local/bin/acfs version"* ]] \
        && [[ "$output" == *"-u tester -H"* ]] \
        && [[ "$output" != *"$other_home/.local/bin/acfs"* ]] \
        && [[ "$output" != *"-u otheruser -H"* ]]; then
        harness_pass "global acfs wrapper ignores stale home-adjacent target_user"
    else
        harness_fail "global acfs wrapper ignores stale home-adjacent target_user" "$output"
    fi

    cleanup_mock_env
}

test_doctor_agent_checks_use_target_context_under_root_home() {
    setup_installed_layout_env

    mkdir -p \
        "$TEST_INSTALLED_ACFS/zsh" \
        "$TEST_TARGET_HOME/.claude" \
        "$TEST_TARGET_HOME/.oh-my-zsh/custom/themes/powerlevel10k" \
        "$TEST_TARGET_HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" \
        "$TEST_TARGET_HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
    cat > "$TEST_INSTALLED_ACFS/zsh/acfs.zshrc" <<'EOF'
alias cc='claude'
alias cod='codex'
gmi() { gemini "$@"; }
EOF

    cat > "$TEST_TARGET_HOME/.claude/settings.json" <<'JSON'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "dcg test \"$CLAUDE_TOOL_INPUT\""
          }
        ]
      }
    ]
  }
}
JSON

    write_fake_command "$TEST_TARGET_HOME/.local/bin/dcg" "dcg 1.2.3"
    write_fake_command "$TEST_TARGET_HOME/.local/bin/rch" "rch 1.2.3"

    local output=""
    output=$(HOME="$TEST_ROOT_HOME" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        bash "$TEST_INSTALLED_ACFS/bin/acfs" doctor --json)

    if printf '%s\n' "$output" | jq -e --arg native_path "$TEST_TARGET_HOME/.local/bin/claude" '
        ([.checks[] | select(.id == "shell.ohmyzsh") | .status] | first) == "pass" and
        ([.checks[] | select(.id == "shell.p10k") | .status] | first) == "pass" and
        ([.checks[] | select(.id == "shell.plugins.zsh_autosuggestions") | .status] | first) == "pass" and
        ([.checks[] | select(.id == "shell.plugins.zsh_syntax_highlighting") | .status] | first) == "pass" and
        ([.checks[] | select(.id == "agent.alias.cc") | .status] | first) == "pass" and
        ([.checks[] | select(.id == "agent.alias.cod") | .status] | first) == "pass" and
        ([.checks[] | select(.id == "agent.alias.gmi") | .status] | first) == "pass" and
        ([.checks[] | select(.id == "agent.path.claude") | .details] | first) == ("native (" + $native_path + ")") and
        ([.checks[] | select(.id == "stack.dcg") | .status] | first) == "pass" and
        ([.checks[] | select(.id == "stack.rch") | .status] | first) == "pass"
    ' >/dev/null 2>&1; then
        harness_pass "doctor agent checks use installed target context under root home"
    else
        harness_fail "doctor agent checks use installed target context under root home" "$output"
    fi

    cleanup_mock_env
}

test_doctor_deep_agent_auth_uses_target_context_under_root_home() {
    setup_installed_layout_env

    mkdir -p "$TEST_TARGET_HOME/.claude" "$TEST_TARGET_HOME/.codex" "$TEST_TARGET_HOME/.gemini"

    cat > "$TEST_TARGET_HOME/.claude/.credentials.json" <<'JSON'
{
  "claudeAiOauth": {
    "accessToken": "claude-token"
  }
}
JSON

    cat > "$TEST_TARGET_HOME/.codex/auth.json" <<'JSON'
{
  "tokens": {
    "access_token": "codex-token"
  }
}
JSON

    cat > "$TEST_TARGET_HOME/.gemini/.env" <<'EOF'
GEMINI_API_KEY=gemini-token
EOF

    cat > "$TEST_FAKE_BIN/curl" <<'EOF'
#!/usr/bin/env bash
printf '200'
EOF
    chmod +x "$TEST_FAKE_BIN/curl"

    cat > "$TEST_FAKE_BIN/gh" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x "$TEST_FAKE_BIN/gh"

    cat > "$TEST_FAKE_BIN/wrangler" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x "$TEST_FAKE_BIN/wrangler"

    cat > "$TEST_FAKE_BIN/vercel" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x "$TEST_FAKE_BIN/vercel"

    cat > "$TEST_FAKE_BIN/supabase" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x "$TEST_FAKE_BIN/supabase"

    cat > "$TEST_FAKE_BIN/vault" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x "$TEST_FAKE_BIN/vault"

    local output=""
    output=$(HOME="$TEST_ROOT_HOME" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        bash "$TEST_INSTALLED_ACFS/bin/acfs" doctor --deep --json || true)

    if printf '%s\n' "$output" | jq -e '
        .deep_mode == true and
        ([.checks[] | select(.id == "deep.agent.claude_auth") | .status] | first) == "pass" and
        ([.checks[] | select(.id == "deep.agent.codex_auth") | .status] | first) == "pass" and
        ([.checks[] | select(.id == "deep.agent.gemini_auth") | .status] | first) == "pass"
    ' >/dev/null 2>&1; then
        harness_pass "doctor deep agent auth uses installed target context under root home"
    else
        harness_fail "doctor deep agent auth uses installed target context under root home" "$output"
    fi

    cleanup_mock_env
}

test_doctor_deep_optional_probes_use_target_home_under_root_home() {
    setup_installed_layout_env

    mkdir -p "$TEST_TARGET_HOME/.asb"
    cat > "$TEST_TARGET_HOME/.local/bin/asb" <<EOF
#!/usr/bin/env bash
if [[ "\${HOME:-}" != "$TEST_TARGET_HOME" ]]; then
    exit 1
fi
echo "asb ok"
EOF
    chmod +x "$TEST_TARGET_HOME/.local/bin/asb"

    local output=""
    output=$(HOME="$TEST_ROOT_HOME" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        bash "$TEST_INSTALLED_ACFS/bin/acfs" doctor --deep --json || true)

    if printf '%s\n' "$output" | jq -e '
        .deep_mode == true and
        ([.checks[] | select(.id == "deep.stack.asb") | .status] | first) == "pass"
    ' >/dev/null 2>&1; then
        harness_pass "doctor deep optional probes use installed target HOME under root home"
    else
        harness_fail "doctor deep optional probes use installed target HOME under root home" "$output"
    fi

    cleanup_mock_env
}

test_info_zero_lessons_hides_onboard_prompt_and_explains_state() {
    setup_mock_env

    local empty_lessons_dir
    empty_lessons_dir="$(mktemp -d)"
    local progress_file="$empty_lessons_dir/progress.json"

    local terminal_output
    terminal_output=$(HOME="$TEST_HOME" ACFS_HOME="$TEST_ACFS" ACFS_LESSONS_DIR="$empty_lessons_dir" ACFS_PROGRESS_FILE="$progress_file" \
        bash "$REPO_ROOT/scripts/lib/info.sh")

    local html_output
    html_output=$(HOME="$TEST_HOME" ACFS_HOME="$TEST_ACFS" ACFS_LESSONS_DIR="$empty_lessons_dir" ACFS_PROGRESS_FILE="$progress_file" \
        bash "$REPO_ROOT/scripts/lib/info.sh" --html)

    if [[ "$terminal_output" == *"No lessons available"* ]] \
        && [[ "$terminal_output" != *"Run 'onboard' to continue learning"* ]] \
        && [[ "$html_output" == *"No lessons available."* ]] \
        && [[ "$html_output" != *'<div class="progress-fill">0/0</div>'* ]]; then
        harness_pass "info handles zero lessons without misleading onboarding prompts"
    else
        harness_fail "info handles zero lessons without misleading onboarding prompts" "terminal=$terminal_output html=$html_output"
    fi

    cleanup_mock_env
}

test_info_reads_skipped_tools_without_jq() {
    setup_system_state_only_env

    local output
    output=$(HOME="$TEST_ROOT_HOME" ACFS_HOME="$TEST_INSTALLED_ACFS" ACFS_SYSTEM_STATE_FILE="$TEST_SYSTEM_STATE_FILE" \
        TEST_INFO_SCRIPT="$REPO_ROOT/scripts/lib/info.sh" \
        bash -lc '
            command() {
                if [[ "$1" == "-v" && "$2" == "jq" ]]; then
                    return 1
                fi
                builtin command "$@"
            }
            source "$TEST_INFO_SCRIPT"
            info_get_skipped_tools
        ')

    if [[ "$output" == "ntm, bv" ]]; then
        harness_pass "info reads skipped tools without jq from system state"
    else
        harness_fail "info reads skipped tools without jq from system state" "$output"
    fi

    cleanup_mock_env
}

test_onboard_cli_aliases_work_in_zero_lessons_mode() {
    setup_mock_env

    local empty_lessons_dir
    empty_lessons_dir="$(mktemp -d)"
    local progress_file="$empty_lessons_dir/progress.json"

    local help_output=""
    local help_exit=0
    help_output=$(HOME="$TEST_HOME" ACFS_HOME="$TEST_ACFS" ACFS_LESSONS_DIR="$empty_lessons_dir" ACFS_PROGRESS_FILE="$progress_file" \
        bash "$ONBOARD_SH" help 2>&1) || help_exit=$?

    local list_output=""
    local list_exit=0
    list_output=$(HOME="$TEST_HOME" ACFS_HOME="$TEST_ACFS" ACFS_LESSONS_DIR="$empty_lessons_dir" ACFS_PROGRESS_FILE="$progress_file" \
        bash "$ONBOARD_SH" list 2>&1) || list_exit=$?

    local version_output=""
    local version_exit=0
    version_output=$(HOME="$TEST_HOME" ACFS_HOME="$TEST_ACFS" ACFS_LESSONS_DIR="$empty_lessons_dir" ACFS_PROGRESS_FILE="$progress_file" \
        bash "$ONBOARD_SH" version 2>&1) || version_exit=$?

    if [[ "$help_exit" -eq 0 ]] \
        && [[ "$help_output" == *"ACFS Onboarding Tutorial"* ]] \
        && [[ "$list_exit" -eq 0 ]] \
        && [[ "$list_output" == *"No lessons available"* ]] \
        && [[ "$version_exit" -eq 0 ]] \
        && [[ "$version_output" == onboard\ v* ]]; then
        harness_pass "onboard noun-style aliases work in zero-lessons mode"
    else
        harness_fail "onboard noun-style aliases work in zero-lessons mode" "help_exit=$help_exit list_exit=$list_exit version_exit=$version_exit"
    fi

    cleanup_mock_env
}

test_onboard_repairs_malformed_progress_before_showing_lesson() {
    setup_mock_env

    local progress_file="$TEST_HOME/bad-progress.json"
    printf '{not valid json\n' > "$progress_file"

    local output=""
    local exit_code=0
    output=$(HOME="$TEST_HOME" ACFS_HOME="$TEST_ACFS" ACFS_LESSONS_DIR="$REPO_ROOT/acfs/onboard/lessons" ACFS_PROGRESS_FILE="$progress_file" \
        bash "$ONBOARD_SH" 0 2>&1) || exit_code=$?

    if [[ "$exit_code" -eq 0 ]] && [[ "$output" == *"Welcome to ACFS"* ]]; then
        harness_pass "onboard repairs malformed progress before lesson launch"
    else
        harness_fail "onboard repairs malformed progress before lesson launch" "exit=$exit_code output=$output"
    fi

    cleanup_mock_env
}

test_onboard_accepts_sparse_lesson_numbers() {
    setup_mock_env

    local progress_file="$TEST_HOME/progress.json"

    local output=""
    local exit_code=0
    output=$(HOME="$TEST_HOME" ACFS_HOME="$TEST_ACFS" ACFS_LESSONS_DIR="$REPO_ROOT/acfs/onboard/lessons" ACFS_PROGRESS_FILE="$progress_file" \
        bash "$ONBOARD_SH" 33 2>&1) || exit_code=$?

    if [[ "$exit_code" -eq 0 ]] && [[ "$output" == *"Lesson 33: Hybrid Search with FSFS"* ]]; then
        harness_pass "onboard accepts sparse lesson numbers"
    else
        harness_fail "onboard accepts sparse lesson numbers" "exit=$exit_code output=$output"
    fi

    cleanup_mock_env
}

test_onboard_uses_installed_layout_under_root_home() {
    setup_installed_layout_env

    mkdir -p "$TEST_INSTALLED_ACFS/onboard"
    cp "$ONBOARD_SH" "$TEST_INSTALLED_ACFS/onboard/onboard.sh"

    local output=""
    output=$(HOME="$TEST_ROOT_HOME" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        bash "$TEST_INSTALLED_ACFS/onboard/onboard.sh" status 2>&1)

    if [[ -f "$TEST_INSTALLED_ACFS/onboard_progress.json" ]] \
        && [[ ! -e "$TEST_ROOT_HOME/.acfs/onboard_progress.json" ]] \
        && [[ "$output" != *"No lessons available"* ]] \
        && [[ "$output" != *"$TEST_ROOT_HOME/.acfs/onboard/lessons"* ]]; then
        harness_pass "onboard uses installed layout under root home"
    else
        harness_fail "onboard uses installed layout under root home" "$output"
    fi

    cleanup_mock_env
}

test_onboard_cheatsheet_uses_installed_layout_under_root_home() {
    setup_installed_layout_env

    mkdir -p "$TEST_INSTALLED_ACFS/onboard" "$TEST_INSTALLED_ACFS/zsh" "$TEST_INSTALLED_ACFS/scripts/lib"
    cp "$ONBOARD_SH" "$TEST_INSTALLED_ACFS/onboard/onboard.sh"
    cp "$CHEATSHEET_SH" "$TEST_INSTALLED_ACFS/scripts/lib/cheatsheet.sh"

    cat > "$TEST_INSTALLED_ACFS/zsh/acfs.zshrc" <<'EOF'
if command -v claude >/dev/null 2>&1; then
  alias cc='claude'
fi
alias cod='codex'
EOF

    local output=""
    output=$(HOME="$TEST_ROOT_HOME" PATH="$TEST_FAKE_BIN:/usr/bin:/bin" \
        bash "$TEST_INSTALLED_ACFS/onboard/onboard.sh" cheatsheet --json)

    if printf '%s\n' "$output" | jq -e --arg zshrc "$TEST_INSTALLED_ACFS/zsh/acfs.zshrc" '
        .source == $zshrc and ([.entries[].name] | index("cc")) != null and ([.entries[].name] | index("cod")) != null
    ' >/dev/null 2>&1; then
        harness_pass "onboard cheatsheet uses installed layout under root home"
    else
        harness_fail "onboard cheatsheet uses installed layout under root home" "$output"
    fi

    cleanup_mock_env
}

test_onboard_auth_checks_use_installed_target_home_under_root_home() {
    setup_installed_layout_env

    mkdir -p "$TEST_TARGET_HOME/.claude"
    cat > "$TEST_TARGET_HOME/.claude/.credentials.json" <<'JSON'
{
  "claudeAiOauth": {
    "accessToken": "claude-token"
  }
}
JSON
    write_fake_command "$TEST_TARGET_HOME/.local/bin/claude" "claude 1.2.3"

    local output=""
    output=$(HOME="$TEST_ROOT_HOME" ACFS_HOME="$TEST_INSTALLED_ACFS" PATH="$TEST_TARGET_HOME/.local/bin:$TEST_FAKE_BIN:/usr/bin:/bin" \
        bash -lc 'source "'"$ONBOARD_SH"'" help >/dev/null; check_auth_status claude && status=0 || status=$?; printf "%s\n" "$status"')

    if [[ "$output" == "0" ]]; then
        harness_pass "onboard auth checks use installed target home under root home"
    else
        harness_fail "onboard auth checks use installed target home under root home" "$output"
    fi

    cleanup_mock_env
}

test_onboard_copy_install_uses_system_state_under_root_home() {
    setup_mock_env

    local root_home="$TEST_HOME/root-home"
    local target_home="$TEST_HOME/users/tester"
    local installed_acfs="$target_home/.acfs"
    local system_state="$TEST_HOME/system-state/state.json"

    mkdir -p "$root_home/.local/bin" "$installed_acfs/onboard/lessons" "$installed_acfs/scripts/lib" "$(dirname "$system_state")"
    cp "$ONBOARD_SH" "$root_home/.local/bin/onboard"
    chmod +x "$root_home/.local/bin/onboard"
    cp "$CHEATSHEET_SH" "$installed_acfs/scripts/lib/cheatsheet.sh"

    cat > "$installed_acfs/onboard/lessons/01_intro.md" <<'EOF'
# Intro

hello
EOF

    cat > "$system_state" <<EOF
{
  "target_user": "tester",
  "target_home": "$target_home"
}
EOF

    local output=""
    output=$(HOME="$root_home" ACFS_SYSTEM_STATE_FILE="$system_state" PATH="$root_home/.local/bin:/usr/bin:/bin" \
        onboard status 2>&1)

    if [[ -f "$installed_acfs/onboard_progress.json" ]] \
        && [[ ! -e "$root_home/.acfs/onboard_progress.json" ]] \
        && [[ "$output" != *"No lessons available"* ]]; then
        harness_pass "copied onboard binary uses system state under root home"
    else
        harness_fail "copied onboard binary uses system state under root home" "$output"
    fi

    cleanup_mock_env
}

test_onboard_copy_install_uses_target_home_only_system_state_under_root_home() {
    setup_system_state_target_home_only_env

    mkdir -p "$TEST_ROOT_HOME/.local/bin" "$TEST_INSTALLED_ACFS/scripts/lib" "$TEST_INSTALLED_ACFS/zsh"
    cp "$ONBOARD_SH" "$TEST_ROOT_HOME/.local/bin/onboard"
    chmod +x "$TEST_ROOT_HOME/.local/bin/onboard"
    cp "$CHEATSHEET_SH" "$TEST_INSTALLED_ACFS/scripts/lib/cheatsheet.sh"

    cat > "$TEST_INSTALLED_ACFS/zsh/acfs.zshrc" <<'EOF'
alias cod='codex'
EOF
    write_fake_command "$TEST_TARGET_HOME/.local/bin/codex" "codex 1.2.3"

    local status_output=""
    status_output=$(HOME="$TEST_ROOT_HOME" ACFS_SYSTEM_STATE_FILE="$TEST_SYSTEM_STATE_FILE" \
        PATH="$TEST_ROOT_HOME/.local/bin:$TEST_FAKE_BIN:/usr/bin:/bin" \
        onboard status 2>&1)

    local cheatsheet_output=""
    cheatsheet_output=$(HOME="$TEST_ROOT_HOME" ACFS_SYSTEM_STATE_FILE="$TEST_SYSTEM_STATE_FILE" \
        PATH="$TEST_ROOT_HOME/.local/bin:$TEST_FAKE_BIN:/usr/bin:/bin" \
        onboard cheatsheet --json 2>&1)

    if [[ -f "$TEST_INSTALLED_ACFS/onboard_progress.json" ]] \
        && [[ ! -e "$TEST_ROOT_HOME/.acfs/onboard_progress.json" ]] \
        && [[ "$status_output" != *"No lessons available"* ]] \
        && printf '%s\n' "$cheatsheet_output" | jq -e --arg zshrc "$TEST_INSTALLED_ACFS/zsh/acfs.zshrc" \
            '.source == $zshrc and ([.entries[].name] | index("cod")) != null' >/dev/null 2>&1; then
        harness_pass "copied onboard uses target_home-only system state under root home"
    else
        harness_fail "copied onboard uses target_home-only system state under root home" "status=$status_output cheatsheet=$cheatsheet_output"
    fi

    cleanup_mock_env
}

test_onboard_copy_install_ignores_relative_home_trap() {
    setup_system_state_target_home_only_env
    setup_relative_home_trap

    mkdir -p "$TEST_ROOT_HOME/.local/bin" "$STALE_HOME/.acfs/onboard/lessons"
    cp "$ONBOARD_SH" "$TEST_ROOT_HOME/.local/bin/onboard"
    chmod +x "$TEST_ROOT_HOME/.local/bin/onboard"

    cat > "$STALE_HOME/.acfs/onboard/lessons/01_intro.md" <<'EOF'
# Wrong Intro

stale lesson
EOF

    local output=""
    output=$(cd "$TEST_HOME" && HOME="$RELATIVE_HOME" ACFS_SYSTEM_STATE_FILE="$TEST_SYSTEM_STATE_FILE" \
        PATH="$TEST_ROOT_HOME/.local/bin:$TEST_FAKE_BIN:/usr/bin:/bin" \
        onboard status 2>&1)

    if [[ -f "$TEST_INSTALLED_ACFS/onboard_progress.json" ]] \
        && [[ ! -e "$STALE_HOME/.acfs/onboard_progress.json" ]] \
        && [[ "$output" != *"No lessons available"* ]]; then
        harness_pass "copied onboard ignores relative HOME trap"
    else
        harness_fail "copied onboard ignores relative HOME trap" "$output"
    fi

    cleanup_mock_env
}

test_state_driven_helpers_reject_invalid_target_home_from_state() {
    if grep -Fq '[[ "$target_home" != "/" ]] || return 1' "$INFO_SH" \
        && grep -Fq '[[ "$target_home" != "/" ]] || return 1' "$STATUS_SH" \
        && grep -Fq '[[ "$target_home" != "/" ]] || return 1' "$EXPORT_CONFIG_SH" \
        && grep -Fq '[[ "$target_home" != "/" ]] || return 1' "$SUPPORT_SH" \
        && grep -Fq '[[ "$target_home" != "/" ]] || return 1' "$CHANGELOG_SH" \
        && grep -Fq '[[ "$target_home" != "/" ]] || return 1' "$CONTINUE_SH" \
        && grep -Fq 'dashboard_read_target_home_from_state()' "$DASHBOARD_SH" \
        && grep -Fq 'cheatsheet_read_target_home_from_state()' "$CHEATSHEET_SH" \
        && grep -Fq '[[ "$TARGET_HOME" == "/" ]]' "$DOCTOR_SH"; then
        harness_pass "state-driven helpers reject invalid target_home from state"
    else
        harness_fail "state-driven helpers reject invalid target_home from state"
    fi
}

main() {
    harness_init "ACFS Changelog/Export/Status Tests"

    if ! command -v jq >/dev/null 2>&1; then
        harness_warn "jq not available — skipping JSON validation tests"
    fi

    harness_section "Changelog"
    test_changelog_json_is_valid || true
    test_changelog_defaults_to_last_updated || true
    test_changelog_rejects_invalid_duration || true

    harness_section "Services Setup"
    test_services_setup_prefers_target_home_libs_under_root_home || true
    test_services_setup_runs_target_user_commands_with_target_home || true
    test_services_setup_rejects_invalid_target_user_before_sudo || true
    test_services_setup_globals_are_initialized_under_set_u || true
    test_services_setup_setup_flows_tolerate_unset_status_keys || true

    harness_section "Notification Helpers"
    test_notify_uses_target_home_for_config_and_state_when_home_is_relative || true
    test_webhook_reads_config_from_target_home_when_home_is_relative || true
    test_notifications_cli_uses_target_home_when_home_is_relative || true

    harness_section "Autofix"
    test_autofix_uses_target_home_for_state_dir_when_home_is_relative || true
    test_autofix_existing_detects_target_home_install_when_home_is_relative || true
    test_autofix_existing_reads_target_home_version_under_root_home || true
    test_autofix_existing_prefers_target_home_over_poisoned_acfs_home || true
    test_autofix_existing_backup_preserves_distinct_relative_paths || true
    test_autofix_existing_clean_reinstall_records_manifest_backups || true
    test_autofix_existing_clean_reinstall_aborts_when_recording_fails || true
    test_autofix_existing_clean_reinstall_aborts_when_backup_root_creation_fails || true
    test_autofix_existing_clean_reinstall_aborts_when_state_relocation_fails || true
    test_autofix_existing_clean_reinstall_restores_backup_after_artifact_removal_failure || true
    test_autofix_existing_clean_reinstall_preserves_journal_when_artifact_recovery_fails || true
    test_autofix_existing_clean_reinstall_recovery_preserves_preexisting_journal || true
    test_autofix_existing_drop_changes_since_restores_original_journals_on_late_replace_failure || true
    test_autofix_existing_backup_uses_unique_dir_when_timestamp_collides || true
    test_autofix_existing_backup_avoids_broken_symlink_collision || true
    test_autofix_existing_backup_fsyncs_manifest_and_parent_dir || true
    test_autofix_existing_restore_from_backup_fsyncs_restored_path || true
    test_autofix_existing_backup_cleans_partial_dir_after_copy_failure || true
    test_autofix_existing_artifacts_include_global_wrapper || true
    test_autofix_existing_backup_preserves_symlink_artifacts || true
    test_autofix_existing_handles_broken_symlink_artifacts || true
    test_autofix_existing_clean_shell_configs_records_changes || true
    test_autofix_existing_clean_shell_configs_preserves_symlinked_config || true
    test_autofix_existing_clean_shell_configs_preserves_owner_before_move || true
    test_autofix_existing_clean_shell_configs_restores_file_when_recording_fails || true
    test_autofix_existing_update_path_entries_restores_file_when_recording_fails || true
    test_autofix_existing_update_path_entries_restores_symlink_target_when_recording_fails || true
    test_autofix_existing_legacy_config_migration_undo_handles_quoted_paths || true
    test_autofix_existing_legacy_config_migration_undo_cleans_created_dirs || true
    test_autofix_existing_legacy_json_migration_undo_handles_quoted_paths || true
    test_autofix_existing_legacy_config_migration_record_failure_cleans_created_dirs || true
    test_autofix_existing_run_migrations_rolls_back_earlier_steps_on_late_failure || true
    test_autofix_existing_upgrade_restores_version_when_path_repair_fails || true
    test_autofix_existing_upgrade_preserves_journal_when_path_recovery_is_incomplete || true
    test_autofix_existing_upgrade_write_failure_cleans_new_acfs_home || true
    test_autofix_existing_upgrade_version_backup_failure_rolls_back_migrations || true
    test_autofix_existing_upgrade_record_failure_rolls_back_migrations_and_path_updates || true
    test_autofix_existing_upgrade_record_failure_cleans_new_acfs_home || true
    test_autofix_existing_upgrade_restores_version_when_recording_fails || true
    test_autofix_existing_clean_shell_configs_allows_empty_result || true
    test_autofix_existing_clean_reinstall_restores_backup_after_shell_cleanup_failure || true
    test_autofix_existing_clean_reinstall_preserves_journal_when_shell_cleanup_recovery_fails || true
    test_autofix_existing_clean_reinstall_preserves_journal_when_shell_file_recovery_is_incomplete || true
    test_autofix_existing_remove_artifacts_propagates_rm_failures || true

    harness_section "Export Config"
    test_export_config_json_is_valid || true
    test_export_config_uses_installed_layout_under_root_home || true
    test_export_config_uses_system_state_when_user_state_missing || true
    test_export_config_uses_system_state_target_home_when_getent_unavailable || true
    test_export_config_ignores_relative_home_state_trap || true

    harness_section "Status"
    test_status_rejects_unknown_flags || true
    test_status_plain_output_avoids_ansi_when_not_tty || true
    test_status_reports_last_updated_timestamp || true
    test_status_errors_on_malformed_state_json || true
    test_status_uses_installed_layout_under_root_home || true
    test_status_uses_system_state_when_user_state_missing || true
    test_status_uses_system_state_target_home_when_getent_unavailable || true
    test_status_ignores_relative_home_state_trap || true

    harness_section "Changelog Root Context"
    test_changelog_uses_installed_layout_under_root_home || true
    test_changelog_uses_system_state_when_user_state_missing || true
    test_changelog_uses_system_state_target_home_when_getent_unavailable || true
    test_changelog_ignores_relative_home_trap || true

    harness_section "Continue"
    test_continue_uses_installed_layout_under_root_home || true
    test_continue_uses_system_state_target_home_when_getent_unavailable || true
    test_continue_ignores_relative_home_state_trap || true
    test_continue_ignores_generic_install_process_matches || true
    test_continue_failed_state_beats_runtime_probe || true
    test_continue_reports_installed_layout_log_locations || true
    test_continue_live_log_hint_uses_installed_layout_log_dir || true
    test_continue_scans_nonstandard_homes_via_getent || true

    harness_section "Dashboard"
    test_dashboard_generation_is_atomic_on_failure || true
    test_dashboard_rejects_invalid_ports_before_serving || true
    test_dashboard_prefers_repo_local_info_script || true
    test_dashboard_uses_installed_layout_under_root_home || true
    test_dashboard_serve_uses_target_user_in_ssh_hint || true
    test_dashboard_copy_install_uses_target_home_only_system_state || true
    test_dashboard_copy_install_ignores_relative_home_trap || true

    harness_section "Cheatsheet"
    test_state_library_ignores_relative_home_target_resolution || true
    test_smoke_test_ignores_relative_home_target_resolution || true
    test_cheatsheet_uses_installed_layout_and_target_path_under_root_home || true
    test_cheatsheet_copy_install_uses_target_home_only_system_state || true
    test_cheatsheet_copy_install_ignores_relative_home_trap || true

    harness_section "Info / Support / Onboard"
    test_state_driven_helpers_reject_invalid_target_home_from_state || true
    test_runtime_helpers_resolve_current_home_from_passwd_when_home_invalid || true
    test_runtime_helpers_reject_invalid_passwd_home_for_target_user || true
    test_info_uses_installed_layout_under_root_home || true
    test_info_uses_system_state_target_home_when_getent_unavailable || true
    test_info_ignores_relative_home_state_trap || true
    test_info_uses_target_user_path_under_root_home || true
    test_info_zero_lessons_hides_onboard_prompt_and_explains_state || true
    test_info_reads_skipped_tools_without_jq || true
    test_support_bundle_uses_installed_layout_under_root_home || true
    test_support_bundle_uses_system_state_target_home_when_getent_unavailable || true
    test_onboard_cli_aliases_work_in_zero_lessons_mode || true
    test_onboard_repairs_malformed_progress_before_showing_lesson || true
    test_onboard_accepts_sparse_lesson_numbers || true
    test_onboard_uses_installed_layout_under_root_home || true
    test_onboard_cheatsheet_uses_installed_layout_under_root_home || true
    test_onboard_auth_checks_use_installed_target_home_under_root_home || true
    test_onboard_copy_install_uses_system_state_under_root_home || true
    test_onboard_copy_install_uses_target_home_only_system_state_under_root_home || true
    test_onboard_copy_install_ignores_relative_home_trap || true

    harness_section "Entrypoint Dispatch"
    test_doctor_entrypoint_dispatches_helper_commands || true
    test_doctor_dispatches_installed_layout_under_root_home || true
    test_doctor_ignores_relative_home_state_trap || true
    test_acfs_update_wrapper_uses_system_state_target_home_when_getent_unavailable || true
    test_acfs_update_wrapper_repairs_runtime_home_on_direct_exec || true
    test_acfs_update_wrapper_passes_bin_dir_from_state || true
    test_acfs_update_wrapper_discards_invalid_env_bin_dir_on_direct_exec || true
    test_acfs_update_wrapper_discards_invalid_env_state_file_on_direct_exec || true
    test_acfs_update_wrapper_ignores_relative_home_state_trap || true
    test_acfs_update_wrapper_ignores_stale_home_adjacent_target_user || true
    test_acfs_global_wrapper_uses_system_state_target_home_when_getent_unavailable || true
    test_acfs_global_wrapper_repairs_runtime_home_on_direct_exec || true
    test_acfs_global_wrapper_runs_direct_when_owner_unknown_but_target_home_known || true
    test_acfs_global_wrapper_passes_bin_dir_from_state || true
    test_acfs_global_wrapper_discards_invalid_env_bin_dir_on_direct_exec || true
    test_acfs_global_wrapper_discards_invalid_env_state_file_on_direct_exec || true
    test_acfs_global_wrapper_ignores_relative_home_state_trap || true
    test_acfs_global_wrapper_does_not_guess_current_home_when_target_home_is_unresolved || true
    test_acfs_global_wrapper_ignores_stale_home_adjacent_target_user || true
    test_doctor_agent_checks_use_target_context_under_root_home || true
    test_doctor_deep_agent_auth_uses_target_context_under_root_home || true
    test_doctor_deep_optional_probes_use_target_home_under_root_home || true

    harness_summary
}

main "$@"
