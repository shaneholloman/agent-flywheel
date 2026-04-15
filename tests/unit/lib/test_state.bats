#!/usr/bin/env bats

load '../test_helper'

setup() {
    common_setup
    source_lib "logging"
    source_lib "state"
    
    # Setup a temp state file
    export ACFS_HOME=$(create_temp_dir)
    export ACFS_STATE_FILE="$ACFS_HOME/state.json"
}

teardown() {
    common_teardown
}

@test "state: init creates valid json" {
    run state_init
    assert_success
    
    run cat "$ACFS_STATE_FILE"
    assert_output --partial '"version":'
    assert_output --partial '"completed_phases": []'
}

@test "state: save and load round trip" {
    state_init
    
    local content='{"test": "value"}'
    run state_save "$content"
    assert_success
    
    run state_load
    assert_success
    assert_output --partial '"test": "value"'
}

@test "state: phase lifecycle" {
    state_init
    
    # Start
    run state_phase_start "phase1" "step1"
    assert_success
    
    run state_get ".current_phase"
    assert_output "phase1"
    
    # Complete
    run state_phase_complete "phase1"
    assert_success
    
    run state_is_phase_completed "phase1"
    assert_success # Returns 0 (true in bash)
    
    run state_get ".current_phase"
    assert_output ""
}

@test "state: fail records error" {
    state_init
    state_phase_start "phase1"
    
    run state_phase_fail "phase1" "stepX" "Something blew up"
    assert_success
    
    run state_get ".failed_phase"
    assert_output "phase1"
    
    run state_get ".failed_error"
    assert_output "Something blew up"
}

@test "state: skip logic" {
    state_init
    
    run state_phase_skip "skipped_phase"
    assert_success
    
    run state_should_skip_phase "skipped_phase"
    assert_success # Returns 0 (true)
    
    run state_should_skip_phase "other_phase"
    assert_failure # Returns 1 (false)
}

@test "state: update atomic" {
    state_init
    
    run state_update '.new_field = "exists"'
    assert_success
    
    run state_get ".new_field"
    assert_output "exists"
}

@test "state: get file prefers passwd-resolved target home when ACFS_HOME unset" {
    local stub_home
    stub_home=$(create_temp_dir)

    unset ACFS_HOME
    unset ACFS_STATE_FILE
    export TARGET_USER="dummy"
    export TARGET_HOME=""
    export HOME="/tmp/not-the-target-home"

    getent() {
        if [[ "$1" == "passwd" && "$2" == "dummy" ]]; then
            printf "dummy:x:1000:1000::%s:/bin/bash\n" "$stub_home"
            return 0
        fi
        command getent "$@"
    }

    run state_get_file
    assert_success
    assert_output "$stub_home/.acfs/state.json"
}

@test "state: init uses passwd-resolved target home when ACFS_HOME unset" {
    local stub_home
    stub_home=$(create_temp_dir)

    unset ACFS_HOME
    unset ACFS_STATE_FILE
    export TARGET_USER="dummy"
    export TARGET_HOME=""
    export HOME="/tmp/not-the-target-home"

    getent() {
        if [[ "$1" == "passwd" && "$2" == "dummy" ]]; then
            printf "dummy:x:1000:1000::%s:/bin/bash\n" "$stub_home"
            return 0
        fi
        command getent "$@"
    }

    run state_init
    assert_success

    run test -f "$stub_home/.acfs/state.json"
    assert_success
}

@test "state: init persists resolved target home when TARGET_HOME unset" {
    local stub_home
    stub_home=$(create_temp_dir)

    unset ACFS_HOME
    unset ACFS_STATE_FILE
    export TARGET_USER="dummy"
    export TARGET_HOME=""
    export HOME="/tmp/not-the-target-home"

    getent() {
        if [[ "$1" == "passwd" && "$2" == "dummy" ]]; then
            printf "dummy:x:1000:1000::%s:/bin/bash\n" "$stub_home"
            return 0
        fi
        command getent "$@"
    }

    run state_init
    assert_success

    run state_get ".target_home"
    assert_success
    assert_output "$stub_home"
}

@test "state: backup and remove accepts passwd-resolved user state path" {
    local stub_home
    stub_home=$(create_temp_dir)

    unset ACFS_HOME
    unset ACFS_STATE_FILE
    export TARGET_USER="dummy"
    export TARGET_HOME=""
    export HOME="/tmp/not-the-target-home"

    getent() {
        if [[ "$1" == "passwd" && "$2" == "dummy" ]]; then
            printf "dummy:x:1000:1000::%s:/bin/bash\n" "$stub_home"
            return 0
        fi
        command getent "$@"
    }

    mkdir -p "$stub_home/.acfs"
    printf '{"schema_version":3}\n' > "$stub_home/.acfs/state.json"

    run state_backup_and_remove
    assert_success

    run test ! -f "$stub_home/.acfs/state.json"
    assert_success

    run bash -lc "shopt -s nullglob; files=(\"$stub_home/.acfs/state.json.backup.\"*); [[ \${#files[@]} -eq 1 ]]"
    assert_success
}

@test "state: resolve target home rejects invalid fallback usernames" {
    unset ACFS_HOME
    unset ACFS_STATE_FILE
    export TARGET_HOME=""
    export TARGET_USER="../bad-user"
    export HOME="/"

    getent() {
        return 2
    }

    run state_resolve_target_home
    assert_failure
}

@test "state: resolve target home accepts dotted fallback usernames" {
    unset ACFS_HOME
    unset ACFS_STATE_FILE
    export TARGET_HOME=""
    export TARGET_USER="john.doe"
    export HOME="/"

    getent() {
        return 2
    }

    run state_resolve_target_home
    assert_success
    assert_output "/home/john.doe"
}
