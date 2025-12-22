#!/usr/bin/env bash
# ============================================================
# ACFS Continue - View Installation Progress
#
# This script allows users to monitor ongoing ACFS installation
# progress, especially after Ubuntu upgrades complete and the
# installer continues in the background.
#
# Usage:
#   acfs continue           # Show status and attach to logs
#   acfs continue --status  # Just show current status
#   acfs continue --help    # Show help
#
# Related bead: hun4
# ============================================================

set -euo pipefail

# Constants
ACFS_LOG_DIR="/var/log/acfs"
ACFS_INSTALL_LOG="${ACFS_LOG_DIR}/install.log"
ACFS_UPGRADE_LOG="${ACFS_LOG_DIR}/upgrade_resume.log"
ACFS_STATE_FILE="/var/lib/acfs/state.json"
USER_STATE_FILE="${HOME}/.acfs/state.json"
SERVICE_NAME="acfs-upgrade-resume"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ============================================================
# Helper Functions
# ============================================================

print_header() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}ACFS Installation Progress${NC}                                 ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Check if the upgrade service is running
is_upgrade_service_running() {
    systemctl is-active --quiet "${SERVICE_NAME}.service" 2>/dev/null
}

# Check if the installer process is running
is_installer_running() {
    # Check for ACFS installer specifically (not just any install.sh)
    # Look for bash running the continue_install.sh or install.sh with ACFS args
    pgrep -f "bash.*/var/lib/acfs/continue_install.sh" &>/dev/null || \
    pgrep -f "bash.*install.sh.*--mode" &>/dev/null || \
    pgrep -f "bash.*install.sh.*--yes" &>/dev/null
}

# Get state from state.json
get_state_value() {
    local key="$1"
    local state_file=""

    # Try system state file first, then user state file
    if [[ -f "$ACFS_STATE_FILE" ]]; then
        state_file="$ACFS_STATE_FILE"
    elif [[ -f "$USER_STATE_FILE" ]]; then
        state_file="$USER_STATE_FILE"
    else
        return 1
    fi

    command -v jq &>/dev/null || return 1

    # Never crash on jq errors (schema drift / partial state files during boot).
    jq -r "$key" "$state_file" 2>/dev/null || true
}

# Get current phase info
get_current_phase() {
    local phase
    phase=$(get_state_value '.current_phase.id? // .current_phase // empty')
    if [[ -n "$phase" ]]; then
        echo "$phase"
    else
        echo "unknown"
    fi
}

# Get current step info
get_current_step() {
    local step
    step=$(get_state_value '.current_step // empty')
    if [[ -n "$step" ]]; then
        echo "$step"
    else
        echo ""
    fi
}

# Get installation status
get_install_status() {
    local failed_phase current_phase finalize_completed
    failed_phase=$(get_state_value '.failed_phase // empty')
    if [[ -n "$failed_phase" ]] && [[ "$failed_phase" != "null" ]]; then
        echo "failed"
        return 0
    fi

    current_phase=$(get_state_value '.current_phase // empty')
    if [[ -n "$current_phase" ]] && [[ "$current_phase" != "null" ]]; then
        echo "running"
        return 0
    fi

    finalize_completed=$(get_state_value '(.completed_phases // []) | index("finalize") != null')
    if [[ "$finalize_completed" == "true" ]]; then
        echo "complete"
        return 0
    fi

    echo "unknown"
}

# Get Ubuntu upgrade status
get_upgrade_status() {
    local stage
    stage=$(get_state_value '.ubuntu_upgrade.current_stage // empty')
    if [[ -n "$stage" ]]; then
        echo "$stage"
    else
        echo ""
    fi
}

# Determine which log file to tail
get_active_log() {
    local upgrade_stage
    upgrade_stage=$(get_upgrade_status)

    # If upgrade is in progress, show upgrade log
    if [[ -n "$upgrade_stage" ]] && [[ "$upgrade_stage" != "completed" ]]; then
        if [[ -f "$ACFS_UPGRADE_LOG" ]]; then
            echo "$ACFS_UPGRADE_LOG"
            return 0
        fi
    fi

    # Otherwise show install log
    if [[ -f "$ACFS_INSTALL_LOG" ]]; then
        echo "$ACFS_INSTALL_LOG"
        return 0
    fi

    # Check for any log file
    if [[ -f "$ACFS_UPGRADE_LOG" ]]; then
        echo "$ACFS_UPGRADE_LOG"
        return 0
    fi

    return 1
}

# ============================================================
# Status Display
# ============================================================

show_status() {
    print_header

    local is_running=false
    local status_msg=""

    # Check if upgrade service is running
    if is_upgrade_service_running; then
        is_running=true
        status_msg="${YELLOW}Ubuntu upgrade in progress${NC}"
    # Check if installer process is running
    elif is_installer_running; then
        is_running=true
        status_msg="${BLUE}Installation in progress${NC}"
    else
        status_msg="${GREEN}No active installation${NC}"
    fi

    echo -e "  ${BOLD}Status:${NC} $status_msg"

    # Show current phase if available
    local phase
    phase=$(get_current_phase)
    if [[ "$phase" != "unknown" ]]; then
        echo -e "  ${BOLD}Phase:${NC}  $phase"
    fi

    # Show current step if available
    local step
    step=$(get_current_step)
    if [[ -n "$step" ]]; then
        echo -e "  ${BOLD}Step:${NC}   $step"
    fi

    # Show upgrade status if relevant
    local upgrade_stage
    upgrade_stage=$(get_upgrade_status)
    if [[ -n "$upgrade_stage" ]] && [[ "$upgrade_stage" != "completed" ]]; then
        echo -e "  ${BOLD}Ubuntu:${NC} Upgrade stage: ${YELLOW}$upgrade_stage${NC}"
    fi

    echo ""

    # Show log file locations (only if any exist)
    if [[ -f "$ACFS_INSTALL_LOG" ]] || [[ -f "$ACFS_UPGRADE_LOG" ]]; then
        echo -e "  ${DIM}Log files:${NC}"
        if [[ -f "$ACFS_INSTALL_LOG" ]]; then
            echo -e "    ${DIM}Install:  $ACFS_INSTALL_LOG${NC}"
        fi
        if [[ -f "$ACFS_UPGRADE_LOG" ]]; then
            echo -e "    ${DIM}Upgrade:  $ACFS_UPGRADE_LOG${NC}"
        fi
        echo ""
    fi

    # Return whether installation is running
    $is_running
}

# ============================================================
# Live Log Viewing
# ============================================================

show_live_log() {
    local log_file
    log_file=$(get_active_log) || {
        echo -e "${YELLOW}No log files found yet.${NC}"
        echo -e "${DIM}Logs will appear at: $ACFS_LOG_DIR${NC}"
        return 1
    }

    echo -e "${BOLD}Showing live output from:${NC} $log_file"
    echo -e "${DIM}Press Ctrl+C to stop watching${NC}"
    echo ""
    echo "────────────────────────────────────────────────────────────────"

    # Use tail -f to show live output
    # Show last 20 lines first, then follow
    tail -n 20 -f "$log_file" 2>/dev/null || {
        echo -e "${RED}Unable to read log file${NC}"
        echo -e "${DIM}You may need to run with sudo: sudo acfs continue${NC}"
        return 1
    }
}

# ============================================================
# Help
# ============================================================

show_help() {
    echo "ACFS Continue - View Installation Progress"
    echo ""
    echo "Usage: acfs continue [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --status, -s    Show current status only (don't attach to logs)"
    echo "  --help, -h      Show this help message"
    echo ""
    echo "Description:"
    echo "  After Ubuntu upgrades complete, the ACFS installer continues"
    echo "  running in the background. This command lets you see what's"
    echo "  happening and attach to the live log output."
    echo ""
    echo "Examples:"
    echo "  acfs continue           # Show status and watch live logs"
    echo "  acfs continue --status  # Just show current status"
    echo "  sudo acfs continue      # If you get permission errors"
    echo ""
}

# ============================================================
# Main
# ============================================================

main() {
    local status_only=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --status|-s)
                status_only=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                echo "Use 'acfs continue --help' for usage"
                exit 1
                ;;
        esac
    done

    # Show status
    if show_status; then
        # Installation is running
        if ! $status_only; then
            show_live_log
        fi
    else
        # Installation is not running - check if it was completed
        local status
        status=$(get_install_status)
        if [[ "$status" == "complete" ]]; then
            echo -e "${GREEN}${BOLD}Installation completed successfully!${NC}"
            echo ""
            echo "Next steps:"
            echo "  1. Log out and back in (or run: source ~/.zshrc)"
            echo "  2. Run: onboard"
            echo "  3. Start coding with: cc, cod, or gmi"
        else
            # Only show log viewing instructions if logs exist
            if [[ -f "$ACFS_INSTALL_LOG" ]] || [[ -f "$ACFS_UPGRADE_LOG" ]]; then
                echo "To view past logs:"
                if [[ -f "$ACFS_INSTALL_LOG" ]]; then
                    echo "  cat $ACFS_INSTALL_LOG"
                fi
                if [[ -f "$ACFS_UPGRADE_LOG" ]]; then
                    echo "  cat $ACFS_UPGRADE_LOG"
                fi
            else
                echo "No ACFS installation logs found."
                echo "Run the ACFS installer to get started."
            fi
        fi
    fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
