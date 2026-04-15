#!/usr/bin/env bats

load '../test_helper'

setup() {
    common_setup
    source_lib "logging"
    source_lib "user"
    
    # Overwrite SUDO to avoid actual sudo calls
    SUDO=""
    
    # Mock system commands
    stub_command "useradd" ""
    stub_command "usermod" ""
    stub_command "chpasswd" ""
    stub_command "visudo" ""
    stub_command "chown" ""
    stub_command "chmod" ""
    
    # Mock environment
    # Note: user.sh uses TARGET_USER not ACFS_TARGET_USER
    export TARGET_USER="testuser"
    export ACFS_TARGET_HOME=$(create_temp_dir)
    export TARGET_HOME="$ACFS_TARGET_HOME"
    export HOME=$(create_temp_dir)
    
    # We need mkdir and touch to work for some tests, so we won't stub them globally
    # unless specific tests need to verify they are called.
}

teardown() {
    common_teardown
}

@test "ensure_user: creates user if missing" {
    # Mock id to fail (user missing)
    stub_command "id" "" 1
    
    # Spy on useradd
    spy_command "useradd"
    
    # Mock openssl for password gen (optional but good to avoid dependency)
    stub_command "openssl" "randpass"
    
    run ensure_user
    assert_success
    
    run cat "$STUB_DIR/useradd.log"
    assert_output --partial "-m -s /bin/bash -G sudo testuser"
}

@test "ensure_user: skips if exists" {
    # Mock id to succeed
    stub_command "id" "uid=1000(testuser)" 0
    
    spy_command "useradd"
    
    run ensure_user
    assert_success
    
    if [[ -f "$STUB_DIR/useradd.log" ]]; then
        fail "useradd should not be called"
    fi
}

@test "ensure_user: rejects invalid TARGET_USER before useradd" {
    export TARGET_USER="../bad user"
    spy_command "useradd"

    run ensure_user
    assert_failure
    assert_output --partial "Invalid TARGET_USER '../bad user'"

    if [[ -f "$STUB_DIR/useradd.log" ]] && [[ -s "$STUB_DIR/useradd.log" ]]; then
        fail "useradd should not be called for invalid TARGET_USER"
    fi
}

@test "enable_passwordless_sudo: writes sudoers" {
    # Stub tee to write to file
    local capture_file="$ACFS_TARGET_HOME/sudoers_capture"
    cat > "$STUB_DIR/tee" <<EOF
#!/bin/bash
cat > "$capture_file"
EOF
    chmod +x "$STUB_DIR/tee"
    
    # Stub visudo to succeed
    stub_command "visudo" "" 0
    
    run enable_passwordless_sudo
    assert_success
    
    run cat "$capture_file"
    assert_output "testuser ALL=(ALL) NOPASSWD:ALL"
}

@test "enable_passwordless_sudo: rejects invalid TARGET_USER before tee" {
    export TARGET_USER="../bad user"
    spy_command "tee"

    run enable_passwordless_sudo
    assert_failure
    assert_output --partial "Invalid TARGET_USER '../bad user'"

    if [[ -f "$STUB_DIR/tee.log" ]] && [[ -s "$STUB_DIR/tee.log" ]]; then
        fail "tee should not be called for invalid TARGET_USER"
    fi
}

@test "migrate_ssh_keys: copies keys" {
    # Setup source keys
    mkdir -p "$HOME/.ssh"
    echo "ssh-rsa TESTKEY" > "$HOME/.ssh/authorized_keys"
    
    # Mock whoami to return something other than testuser
    stub_command "whoami" "otheruser"
    
    # Use real tee for this test (remove stub if it exists from previous tests? No, separate processes)
    # But wait, tee writes to a file owned by root usually?
    # No, we set SUDO="", so it writes as current user.
    # ACFS_TARGET_HOME is a temp dir owned by current user.
    # So real tee works.
    
    # Ensure grep is real (we didn't stub it)
    
    run migrate_ssh_keys
    assert_success
    
    assert_equal "$(cat "$ACFS_TARGET_HOME/.ssh/authorized_keys")" "ssh-rsa TESTKEY"
}

@test "migrate_ssh_keys: skips if already target user" {
    stub_command "whoami" "testuser"
    
    # Spy on mkdir to ensure it wasn't called
    spy_command "mkdir"
    
    run migrate_ssh_keys
    assert_success
    
    if [[ -f "$STUB_DIR/mkdir.log" ]]; then
        fail "mkdir should not be called"
    fi
}

@test "user_home_for_user: rejects invalid fallback usernames" {
    export HOME="/"

    getent() {
        return 2
    }

    run user_home_for_user "../bad-user"
    assert_failure
}

@test "user_home_for_user: accepts dotted fallback usernames" {
    export HOME="/"

    getent() {
        return 2
    }

    run user_home_for_user "john.doe"
    assert_success
    assert_output "/home/john.doe"
}
