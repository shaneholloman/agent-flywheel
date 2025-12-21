#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2034
# ============================================================
# Test script for selection.sh
# Run: bash scripts/lib/test_selection.sh
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source required files
source "$SCRIPT_DIR/logging.sh"
source "$PROJECT_ROOT/scripts/generated/manifest_index.sh"
source "$SCRIPT_DIR/selection.sh"

TESTS_PASSED=0
TESTS_FAILED=0

test_pass() {
    local name="$1"
    echo -e "\033[32m[PASS]\033[0m $name"
    ((++TESTS_PASSED))  # Use ++X to avoid exit on zero under set -e
}

test_fail() {
    local name="$1"
    local reason="${2:-}"
    echo -e "\033[31m[FAIL]\033[0m $name"
    [[ -n "$reason" ]] && echo "       Reason: $reason"
    ((++TESTS_FAILED))  # Use ++X to avoid exit on zero under set -e
}

# Reset selection state for each test
reset_selection() {
    ONLY_MODULES=()
    ONLY_PHASES=()
    SKIP_MODULES=()
    NO_DEPS=false
    PRINT_PLAN=false
    ACFS_EFFECTIVE_PLAN=()
    ACFS_EFFECTIVE_RUN=()
}

# ============================================================
# Test Cases
# ============================================================

test_default_selection() {
    local name="Default selection includes enabled_by_default modules"
    reset_selection

    if acfs_resolve_selection; then
        # Check that default modules are included
        if should_run_module "lang.bun" && should_run_module "agents.claude"; then
            # Check that non-default modules are excluded
            if ! should_run_module "db.postgres18" && ! should_run_module "tools.vault"; then
                test_pass "$name"
                return
            fi
        fi
    fi
    test_fail "$name"
}

test_only_modules() {
    local name="--only selects specific modules with deps"
    reset_selection
    ONLY_MODULES=("agents.claude")

    if acfs_resolve_selection; then
        # Should include agents.claude and its deps (lang.bun, base.system)
        if should_run_module "agents.claude" && should_run_module "lang.bun" && should_run_module "base.system"; then
            # Should NOT include unrelated modules
            if ! should_run_module "lang.rust" && ! should_run_module "agents.codex"; then
                test_pass "$name"
                return
            fi
        fi
    fi
    test_fail "$name"
}

test_only_modules_no_deps() {
    local name="--only with --no-deps excludes dependencies"
    reset_selection
    ONLY_MODULES=("agents.claude")
    NO_DEPS=true

    if acfs_resolve_selection 2>/dev/null; then
        # Should include only agents.claude
        if should_run_module "agents.claude"; then
            # Should NOT include deps
            if ! should_run_module "lang.bun"; then
                test_pass "$name"
                return
            fi
        fi
    fi
    test_fail "$name"
}

test_skip_modules() {
    local name="--skip removes modules from plan"
    reset_selection
    SKIP_MODULES=("tools.atuin" "tools.zoxide")

    if acfs_resolve_selection; then
        # Should not include skipped modules
        if ! should_run_module "tools.atuin" && ! should_run_module "tools.zoxide"; then
            # Should still include other default modules
            if should_run_module "lang.bun"; then
                test_pass "$name"
                return
            fi
        fi
    fi
    test_fail "$name"
}

test_skip_safety_violation() {
    local name="--skip fails when breaking dependencies"
    reset_selection
    ONLY_MODULES=("agents.claude")
    SKIP_MODULES=("lang.bun")  # agents.claude depends on lang.bun

    # This should fail because skipping lang.bun breaks agents.claude
    if ! acfs_resolve_selection 2>/dev/null; then
        test_pass "$name"
    else
        test_fail "$name" "Should have failed due to dependency violation"
    fi
}

test_phase_selection() {
    local name="--only-phase selects all modules in phase"
    reset_selection
    ONLY_PHASES=("6")  # Phase 6: lang.*, tools.atuin, tools.zoxide, tools.ast_grep

    if acfs_resolve_selection; then
        # Should include phase 6 modules
        if should_run_module "lang.bun" && should_run_module "lang.rust" && should_run_module "tools.atuin"; then
            # Should also include dependencies (base.system is phase 1)
            if should_run_module "base.system"; then
                test_pass "$name"
                return
            fi
        fi
    fi
    test_fail "$name"
}

test_unknown_module_error() {
    local name="Unknown module in --only returns error"
    reset_selection
    ONLY_MODULES=("nonexistent.module")

    if ! acfs_resolve_selection 2>/dev/null; then
        test_pass "$name"
    else
        test_fail "$name" "Should have failed for unknown module"
    fi
}

test_unknown_skip_error() {
    local name="Unknown module in --skip returns error"
    reset_selection
    SKIP_MODULES=("nonexistent.module")

    if ! acfs_resolve_selection 2>/dev/null; then
        test_pass "$name"
    else
        test_fail "$name" "Should have failed for unknown module"
    fi
}

test_plan_order() {
    local name="Plan follows manifest order (deps before dependents)"
    reset_selection
    ONLY_MODULES=("stack.ultimate_bug_scanner")  # deps: lang.bun, lang.uv, tools.ast_grep, lang.rust, base.system

    if acfs_resolve_selection; then
        # Find positions in plan
        local base_pos=-1 bun_pos=-1 rust_pos=-1 ast_pos=-1 ubs_pos=-1
        local i=0
        for module_id in "${ACFS_EFFECTIVE_PLAN[@]}"; do
            case "$module_id" in
                "base.system") base_pos=$i ;;
                "lang.bun") bun_pos=$i ;;
                "lang.rust") rust_pos=$i ;;
                "tools.ast_grep") ast_pos=$i ;;
                "stack.ultimate_bug_scanner") ubs_pos=$i ;;
            esac
            ((++i))  # Use ++i to avoid exit on zero under set -e
        done

        # Verify order: base < bun < rust < ast_grep < ubs
        if [[ $base_pos -lt $bun_pos && $bun_pos -lt $ubs_pos &&
              $base_pos -lt $rust_pos && $rust_pos -lt $ast_pos && $ast_pos -lt $ubs_pos ]]; then
            test_pass "$name"
            return
        fi
    fi
    test_fail "$name"
}

test_should_run_module() {
    local name="should_run_module returns correct results"
    reset_selection
    ONLY_MODULES=("lang.bun")

    if acfs_resolve_selection; then
        if should_run_module "lang.bun" && should_run_module "base.system"; then
            if ! should_run_module "lang.rust"; then
                test_pass "$name"
                return
            fi
        fi
    fi
    test_fail "$name"
}

# ============================================================
# Run Tests
# ============================================================

echo ""
echo "ACFS Selection Tests"
echo "===================="
echo ""

test_default_selection
test_only_modules
test_only_modules_no_deps
test_skip_modules
test_skip_safety_violation
test_phase_selection
test_unknown_module_error
test_unknown_skip_error
test_plan_order
test_should_run_module

echo ""
echo "===================="
echo "Passed: $TESTS_PASSED, Failed: $TESTS_FAILED"
echo ""

[[ $TESTS_FAILED -eq 0 ]]
