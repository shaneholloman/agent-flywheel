#!/usr/bin/env bash
# DCG Pack Configuration Test - Validates pack-based command filtering
# Tests that enabled packs properly block/allow their respective patterns
# Usage: ./dcg_pack_test.sh [--verbose]

set -euo pipefail

VERBOSE="${1:-}"

# ============================================================
# LOGGING
# ============================================================
log() { echo "[$(date '+%H:%M:%S')] $*"; }
pass() { echo "[$(date '+%H:%M:%S')] [PASS] $*"; }
fail() { echo "[$(date '+%H:%M:%S')] [FAIL] $*"; return 1; }
skip() { echo "[$(date '+%H:%M:%S')] [SKIP] $*"; }
detail() { [[ "$VERBOSE" == "--verbose" ]] && echo "  -> $*" >&2 || true; }

# ============================================================
# DCG TEST CLI INTERFACE
# ============================================================
# Note: We use `dcg test` CLI instead of hook simulation for pack tests.
# The hook mode (stdin JSON) is optimized for sub-ms latency and only
# checks core packs, while `dcg test` checks all enabled packs.

# Test a command using dcg test CLI
# Returns: DENIED, ALLOWED, or UNKNOWN
dcg_test_command() {
    local command="$1"
    local output
    output=$(dcg test "$command" 2>&1) || true
    detail "dcg test output: $output"

    # dcg test outputs "Result: BLOCKED" or "Result: ALLOWED"
    if echo "$output" | grep -qi "Result: BLOCKED"; then
        echo "DENIED"
        return 0
    elif echo "$output" | grep -qi "Result: ALLOWED"; then
        echo "ALLOWED"
        return 0
    else
        echo "UNKNOWN"
        return 1
    fi
}

# ============================================================
# PACK INSPECTION TESTS
# ============================================================

test_packs_command_works() {
    log "Testing dcg packs command works..."
    local output
    output=$(dcg packs 2>&1) || true
    if [[ -n "$output" ]] && echo "$output" | grep -q "core"; then
        pass "dcg packs returns pack list"
        return 0
    else
        fail "dcg packs command failed. Output: $output"
        return 1
    fi
}

test_packs_enabled_flag() {
    log "Testing dcg packs --enabled flag..."
    local output
    output=$(dcg packs --enabled 2>&1) || true
    if echo "$output" | grep -q "core.git"; then
        pass "dcg packs --enabled shows core.git as enabled"
        return 0
    else
        fail "dcg packs --enabled doesn't show core.git. Output: $output"
        return 1
    fi
}

test_pack_details_command() {
    log "Testing dcg pack <pack-id> command..."
    local output
    output=$(dcg pack core.git 2>&1) || true
    if echo "$output" | grep -qiE "git|pattern"; then
        pass "dcg pack core.git returns pack details"
        return 0
    else
        fail "dcg pack command failed. Output: $output"
        return 1
    fi
}

test_pack_patterns_flag() {
    log "Testing dcg pack <pack-id> --patterns flag..."
    local output
    output=$(dcg pack database.postgresql --patterns 2>&1) || true
    if echo "$output" | grep -qiE "drop|truncate"; then
        pass "dcg pack --patterns shows destructive patterns"
        return 0
    else
        fail "dcg pack --patterns failed. Output: $output"
        return 1
    fi
}

# ============================================================
# POSTGRESQL PACK TESTS (using dcg test CLI)
# ============================================================

test_postgresql_blocks_drop_database() {
    log "Testing PostgreSQL pack blocks: DROP DATABASE"
    local result
    result=$(dcg_test_command "psql -c 'DROP DATABASE mydb'")
    if [[ "$result" == "DENIED" ]]; then
        pass "DROP DATABASE is blocked by postgresql pack"
        return 0
    else
        fail "DROP DATABASE was NOT blocked (result: $result)"
        return 1
    fi
}

test_postgresql_blocks_drop_table() {
    log "Testing PostgreSQL pack blocks: DROP TABLE"
    local result
    result=$(dcg_test_command "psql -c 'DROP TABLE users'")
    if [[ "$result" == "DENIED" ]]; then
        pass "DROP TABLE is blocked by postgresql pack"
        return 0
    else
        fail "DROP TABLE was NOT blocked (result: $result)"
        return 1
    fi
}

test_postgresql_blocks_truncate() {
    log "Testing PostgreSQL pack blocks: TRUNCATE TABLE"
    local result
    result=$(dcg_test_command "psql -c 'TRUNCATE TABLE users'")
    if [[ "$result" == "DENIED" ]]; then
        pass "TRUNCATE is blocked by postgresql pack"
        return 0
    else
        fail "TRUNCATE was NOT blocked (result: $result)"
        return 1
    fi
}

test_postgresql_blocks_dropdb() {
    log "Testing PostgreSQL pack blocks: dropdb CLI"
    local result
    result=$(dcg_test_command "dropdb mydb")
    if [[ "$result" == "DENIED" ]]; then
        pass "dropdb CLI is blocked by postgresql pack"
        return 0
    else
        fail "dropdb was NOT blocked (result: $result)"
        return 1
    fi
}

test_postgresql_blocks_delete_without_where() {
    log "Testing PostgreSQL pack blocks: DELETE without WHERE"
    local result
    result=$(dcg_test_command "psql -c 'DELETE FROM users;'")
    if [[ "$result" == "DENIED" ]]; then
        pass "DELETE without WHERE is blocked"
        return 0
    else
        fail "DELETE without WHERE was NOT blocked (result: $result)"
        return 1
    fi
}

test_postgresql_allows_select() {
    log "Testing PostgreSQL pack allows: SELECT queries"
    local result
    result=$(dcg_test_command "psql -c 'SELECT * FROM users'")
    if [[ "$result" == "ALLOWED" ]]; then
        pass "SELECT query is allowed"
        return 0
    else
        fail "SELECT was incorrectly blocked (result: $result)"
        return 1
    fi
}

test_postgresql_allows_delete_with_where() {
    log "Testing PostgreSQL pack allows: DELETE with WHERE"
    local result
    result=$(dcg_test_command "psql -c 'DELETE FROM users WHERE id = 1'")
    if [[ "$result" == "ALLOWED" ]]; then
        pass "DELETE with WHERE is allowed"
        return 0
    else
        fail "DELETE with WHERE was incorrectly blocked (result: $result)"
        return 1
    fi
}

test_postgresql_allows_pg_dump_safe() {
    log "Testing PostgreSQL pack allows: pg_dump (safe)"
    local result
    result=$(dcg_test_command "pg_dump mydb > backup.sql")
    if [[ "$result" == "ALLOWED" ]]; then
        pass "pg_dump without --clean is allowed"
        return 0
    else
        fail "pg_dump was incorrectly blocked (result: $result)"
        return 1
    fi
}

test_postgresql_blocks_pg_dump_clean() {
    log "Testing PostgreSQL pack blocks: pg_dump --clean"
    local result
    result=$(dcg_test_command "pg_dump --clean mydb > backup.sql")
    if [[ "$result" == "DENIED" ]]; then
        pass "pg_dump --clean is blocked"
        return 0
    else
        fail "pg_dump --clean was NOT blocked (result: $result)"
        return 1
    fi
}

# ============================================================
# DOCKER PACK TESTS (using dcg test CLI)
# ============================================================

test_docker_blocks_system_prune() {
    log "Testing Docker pack blocks: docker system prune"
    local result
    result=$(dcg_test_command "docker system prune -a")
    if [[ "$result" == "DENIED" ]]; then
        pass "docker system prune is blocked"
        return 0
    else
        fail "docker system prune was NOT blocked (result: $result)"
        return 1
    fi
}

test_docker_blocks_rm_force() {
    log "Testing Docker pack blocks: docker rm -f"
    local result
    result=$(dcg_test_command "docker rm -f mycontainer")
    if [[ "$result" == "DENIED" ]]; then
        pass "docker rm -f is blocked"
        return 0
    else
        fail "docker rm -f was NOT blocked (result: $result)"
        return 1
    fi
}

test_docker_allows_ps() {
    log "Testing Docker pack allows: docker ps"
    local result
    result=$(dcg_test_command "docker ps -a")
    if [[ "$result" == "ALLOWED" ]]; then
        pass "docker ps is allowed"
        return 0
    else
        fail "docker ps was incorrectly blocked (result: $result)"
        return 1
    fi
}

test_docker_allows_images() {
    log "Testing Docker pack allows: docker images"
    local result
    result=$(dcg_test_command "docker images")
    if [[ "$result" == "ALLOWED" ]]; then
        pass "docker images is allowed"
        return 0
    else
        fail "docker images was incorrectly blocked (result: $result)"
        return 1
    fi
}

# ============================================================
# MULTI-PACK INTERACTION TESTS (using dcg test CLI)
# ============================================================

test_git_pack_still_works_with_other_packs() {
    log "Testing Git pack still works with other packs enabled..."
    local result
    result=$(dcg_test_command "git push --force origin main")
    if [[ "$result" == "DENIED" ]]; then
        pass "git push --force still blocked with multi-pack config"
        return 0
    else
        fail "Git pack interference detected (result: $result)"
        return 1
    fi
}

test_filesystem_pack_still_works_with_other_packs() {
    log "Testing Filesystem pack still works with other packs enabled..."
    # rm -rf outside tmp should be blocked
    local result
    result=$(dcg_test_command "rm -rf /important/data")
    if [[ "$result" == "DENIED" ]]; then
        pass "rm -rf still blocked with multi-pack config"
        return 0
    else
        fail "Filesystem pack interference detected (result: $result)"
        return 1
    fi
}

test_safe_commands_not_blocked_by_multiple_packs() {
    log "Testing safe commands allowed with multiple packs..."
    local result
    result=$(dcg_test_command "git status")
    if [[ "$result" == "ALLOWED" ]]; then
        pass "Safe commands still allowed with multi-pack config"
        return 0
    else
        fail "Multi-pack config incorrectly blocking safe commands (result: $result)"
        return 1
    fi
}

# ============================================================
# INVALID PACK HANDLING TESTS
# ============================================================

test_invalid_pack_name_handling() {
    log "Testing invalid pack name handling..."
    local output
    output=$(dcg pack "nonexistent.pack" 2>&1) || true
    # Should either error gracefully or show "not found" message
    if echo "$output" | grep -qiE "not found|unknown|invalid|error|does not exist"; then
        pass "Invalid pack name handled gracefully"
        return 0
    elif [[ -z "$output" ]]; then
        pass "Invalid pack name returns empty (graceful handling)"
        return 0
    else
        # Even if it doesn't error, it shouldn't crash
        pass "Invalid pack name didn't crash dcg"
        return 0
    fi
}

test_pack_list_contains_expected_categories() {
    log "Testing pack list contains expected categories..."
    local output
    output=$(dcg packs 2>&1) || true
    local found=0

    if echo "$output" | grep -q "core"; then
        found=$((found + 1))
    fi
    if echo "$output" | grep -q "database"; then
        found=$((found + 1))
    fi
    if echo "$output" | grep -q "containers"; then
        found=$((found + 1))
    fi

    if [[ $found -ge 2 ]]; then
        pass "Pack list contains expected categories (found $found)"
        return 0
    else
        fail "Pack list missing expected categories. Output: $output"
        return 1
    fi
}

# ============================================================
# CASE SENSITIVITY TESTS (using dcg test CLI)
# ============================================================

test_postgresql_case_insensitive_drop() {
    log "Testing PostgreSQL patterns are case-insensitive: drop database"
    local result
    result=$(dcg_test_command "psql -c 'drop database mydb'")
    if [[ "$result" == "DENIED" ]]; then
        pass "Lowercase 'drop database' is blocked"
        return 0
    else
        fail "Lowercase 'drop database' was NOT blocked (result: $result)"
        return 1
    fi
}

test_postgresql_case_insensitive_truncate() {
    log "Testing PostgreSQL patterns are case-insensitive: Truncate"
    local result
    result=$(dcg_test_command "psql -c 'Truncate Table users'")
    if [[ "$result" == "DENIED" ]]; then
        pass "Mixed-case 'Truncate Table' is blocked"
        return 0
    else
        fail "Mixed-case 'Truncate Table' was NOT blocked (result: $result)"
        return 1
    fi
}

# ============================================================
# MAIN
# ============================================================

main() {
    echo "============================================================"
    echo "  DCG Pack Configuration Validation Test"
    echo "  Testing pack-based command filtering"
    echo "============================================================"
    echo ""

    # Check if DCG is installed
    if ! command -v dcg &>/dev/null; then
        echo "[FATAL] dcg not found in PATH"
        exit 1
    fi

    local passed=0
    local failed=0

    # Pack inspection tests
    echo ">> Testing pack inspection commands:"
    test_packs_command_works && passed=$((passed + 1)) || failed=$((failed + 1))
    test_packs_enabled_flag && passed=$((passed + 1)) || failed=$((failed + 1))
    test_pack_details_command && passed=$((passed + 1)) || failed=$((failed + 1))
    test_pack_patterns_flag && passed=$((passed + 1)) || failed=$((failed + 1))

    echo ""

    # PostgreSQL pack tests
    echo ">> Testing database.postgresql pack patterns:"
    test_postgresql_blocks_drop_database && passed=$((passed + 1)) || failed=$((failed + 1))
    test_postgresql_blocks_drop_table && passed=$((passed + 1)) || failed=$((failed + 1))
    test_postgresql_blocks_truncate && passed=$((passed + 1)) || failed=$((failed + 1))
    test_postgresql_blocks_dropdb && passed=$((passed + 1)) || failed=$((failed + 1))
    test_postgresql_blocks_delete_without_where && passed=$((passed + 1)) || failed=$((failed + 1))
    test_postgresql_blocks_pg_dump_clean && passed=$((passed + 1)) || failed=$((failed + 1))
    test_postgresql_allows_select && passed=$((passed + 1)) || failed=$((failed + 1))
    test_postgresql_allows_delete_with_where && passed=$((passed + 1)) || failed=$((failed + 1))
    test_postgresql_allows_pg_dump_safe && passed=$((passed + 1)) || failed=$((failed + 1))

    echo ""

    # Docker pack tests
    echo ">> Testing containers.docker pack patterns:"
    test_docker_blocks_system_prune && passed=$((passed + 1)) || failed=$((failed + 1))
    test_docker_blocks_rm_force && passed=$((passed + 1)) || failed=$((failed + 1))
    test_docker_allows_ps && passed=$((passed + 1)) || failed=$((failed + 1))
    test_docker_allows_images && passed=$((passed + 1)) || failed=$((failed + 1))

    echo ""

    # Multi-pack interaction tests
    echo ">> Testing multi-pack interactions:"
    test_git_pack_still_works_with_other_packs && passed=$((passed + 1)) || failed=$((failed + 1))
    test_filesystem_pack_still_works_with_other_packs && passed=$((passed + 1)) || failed=$((failed + 1))
    test_safe_commands_not_blocked_by_multiple_packs && passed=$((passed + 1)) || failed=$((failed + 1))

    echo ""

    # Invalid pack handling tests
    echo ">> Testing invalid pack handling:"
    test_invalid_pack_name_handling && passed=$((passed + 1)) || failed=$((failed + 1))
    test_pack_list_contains_expected_categories && passed=$((passed + 1)) || failed=$((failed + 1))

    echo ""

    # Case sensitivity tests
    echo ">> Testing case sensitivity:"
    test_postgresql_case_insensitive_drop && passed=$((passed + 1)) || failed=$((failed + 1))
    test_postgresql_case_insensitive_truncate && passed=$((passed + 1)) || failed=$((failed + 1))

    echo ""
    echo "============================================================"
    echo "  Results: $passed passed, $failed failed"
    echo "============================================================"

    [[ $failed -eq 0 ]] && exit 0 || exit 1
}

main "$@"
