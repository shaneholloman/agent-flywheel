#!/usr/bin/env bats

load '../test_helper'

setup() {
    common_setup
    source_lib "logging"
    source_lib "error_tracking"
}

teardown() {
    common_teardown
}

@test "failed-tools retry defaults fail clearly without HOME context" {
    run env -i PATH="/usr/bin:/bin" bash -c 'set -euo pipefail; source "$1"; source "$2"; save_failed_tools_for_retry' _ "$PROJECT_ROOT/scripts/lib/logging.sh" "$PROJECT_ROOT/scripts/lib/error_tracking.sh"
    assert_failure
    assert_output --partial "Unable to resolve failed-tools retry file"
    refute_output --partial "unbound variable"

    run env -i PATH="/usr/bin:/bin" bash -c 'set -euo pipefail; source "$1"; source "$2"; load_failed_tools_for_retry' _ "$PROJECT_ROOT/scripts/lib/logging.sh" "$PROJECT_ROOT/scripts/lib/error_tracking.sh"
    assert_failure
    assert_output --partial "Unable to resolve failed-tools retry file"
    refute_output --partial "unbound variable"
}

@test "failed-tools retry defaults use TARGET_HOME when HOME is absent" {
    local target_home
    target_home="$(create_temp_dir)"

    run env -i PATH="/usr/bin:/bin" TARGET_HOME="$target_home" bash -c 'set -euo pipefail; source "$1"; source "$2"; track_failed_tool atuin "hook missing"; save_failed_tools_for_retry; clear_install_tracking; load_failed_tools_for_retry; get_failed_tools_list' _ "$PROJECT_ROOT/scripts/lib/logging.sh" "$PROJECT_ROOT/scripts/lib/error_tracking.sh"
    assert_success
    assert_output --partial "atuin"
}
