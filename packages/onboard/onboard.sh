#!/usr/bin/env bash
#
# onboard - ACFS Interactive Onboarding TUI
#
# Teaches users the ACFS workflow through 8 interactive lessons.
# Uses gum for TUI elements with fallback to basic bash menus.
#
# Usage:
#   onboard           # Launch interactive menu
#   onboard lesson N  # Jump to lesson N (0-7)
#   onboard reset     # Reset progress
#   onboard status    # Show completion status
#

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

LESSONS_DIR="${ACFS_LESSONS_DIR:-$HOME/.acfs/onboard/lessons}"
PROGRESS_FILE="${ACFS_PROGRESS_FILE:-$HOME/.acfs/onboard_progress.json}"
VERSION="0.1.0"

# Lesson titles (indexed 0-7)
declare -a LESSON_TITLES=(
    "Welcome & Overview"
    "Linux Navigation"
    "SSH & Persistence"
    "tmux Basics"
    "Agent Commands (cc, cod, gmi)"
    "NTM Command Center"
    "NTM Prompt Palette"
    "The Flywheel Loop"
)

# Lesson files (indexed 0-7)
declare -a LESSON_FILES=(
    "00_welcome.md"
    "01_linux_basics.md"
    "02_ssh_basics.md"
    "03_tmux_basics.md"
    "04_agents_login.md"
    "05_ntm_core.md"
    "06_ntm_command_palette.md"
    "07_flywheel_loop.md"
)

# Colors (works in most terminals)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
# BLUE='\033[0;34m'  # Currently unused
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# ─────────────────────────────────────────────────────────────────────────────
# Utility Functions
# ─────────────────────────────────────────────────────────────────────────────

# Check if gum is available
has_gum() {
    command -v gum &>/dev/null
}

# Check if glow is available (for markdown rendering)
has_glow() {
    command -v glow &>/dev/null
}

# Initialize progress file if it doesn't exist
init_progress() {
    local dir
    dir=$(dirname "$PROGRESS_FILE")
    mkdir -p "$dir"

    if [[ ! -f "$PROGRESS_FILE" ]]; then
        cat > "$PROGRESS_FILE" <<EOF
{
  "completed": [],
  "current": 0,
  "started_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "last_accessed": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
    fi
}

# Get list of completed lessons
get_completed() {
    if [[ -f "$PROGRESS_FILE" ]]; then
        # Parse JSON with jq if available, otherwise use grep
        if command -v jq &>/dev/null; then
            jq -r '.completed | @csv' "$PROGRESS_FILE" 2>/dev/null | tr -d '"' || echo ""
        else
            grep -oP '"completed":\s*\[\K[^\]]*' "$PROGRESS_FILE" 2>/dev/null || echo ""
        fi
    else
        echo ""
    fi
}

# Check if a lesson is completed
is_completed() {
    local lesson=$1
    local completed
    completed=$(get_completed)
    [[ "$completed" =~ (^|,)$lesson(,|$) ]]
}

# Get current lesson
get_current() {
    if [[ -f "$PROGRESS_FILE" ]] && command -v jq &>/dev/null; then
        jq -r '.current // 0' "$PROGRESS_FILE" 2>/dev/null || echo "0"
    else
        grep -oP '"current":\s*\K\d+' "$PROGRESS_FILE" 2>/dev/null || echo "0"
    fi
}

# Mark a lesson as completed
mark_completed() {
    local lesson=$1

    if command -v jq &>/dev/null; then
        local tmp
        tmp=$(mktemp)
        jq --argjson lesson "$lesson" '
            .completed = (.completed + [$lesson] | unique | sort) |
            .current = (if $lesson < 7 then $lesson + 1 else $lesson end) |
            .last_accessed = now | todate
        ' "$PROGRESS_FILE" > "$tmp" && mv "$tmp" "$PROGRESS_FILE"
    else
        # Fallback: simple append (not perfect but works)
        echo "Note: Install jq for better progress tracking"
    fi
}

# Update current lesson without marking complete
set_current() {
    local lesson=$1

    if command -v jq &>/dev/null; then
        local tmp
        tmp=$(mktemp)
        jq --argjson lesson "$lesson" '
            .current = $lesson |
            .last_accessed = now | todate
        ' "$PROGRESS_FILE" > "$tmp" && mv "$tmp" "$PROGRESS_FILE"
    fi
}

# Reset progress
reset_progress() {
    rm -f "$PROGRESS_FILE"
    init_progress
    echo -e "${GREEN}Progress reset!${NC}"
}

# ─────────────────────────────────────────────────────────────────────────────
# Display Functions
# ─────────────────────────────────────────────────────────────────────────────

# Print header
print_header() {
    clear
    if has_gum; then
        gum style \
            --border rounded \
            --border-foreground 212 \
            --padding "1 4" \
            --margin "1" \
            "$(gum style --foreground 212 --bold 'ACFS Onboarding')" \
            "$(gum style --foreground 245 --italic "Learn the agentic coding workflow")"
    else
        echo ""
        echo -e "${BOLD}${MAGENTA}╭─────────────────────────────────────────╮${NC}"
        echo -e "${BOLD}${MAGENTA}│       ACFS Onboarding Tutorial          │${NC}"
        echo -e "${BOLD}${MAGENTA}│  Learn the agentic coding workflow      │${NC}"
        echo -e "${BOLD}${MAGENTA}╰─────────────────────────────────────────╯${NC}"
        echo ""
    fi
}

# Format lesson title with status
format_lesson() {
    local idx=$1
    local title="${LESSON_TITLES[$idx]}"
    local status=""
    local current
    current=$(get_current)

    if is_completed "$idx"; then
        status="${GREEN}✓${NC}"
    elif [[ "$idx" == "$current" ]]; then
        status="${YELLOW}●${NC}"
    else
        status="${DIM}○${NC}"
    fi

    printf "%s [%d] %s" "$status" "$((idx + 1))" "$title"
}

# Show lesson menu with gum
show_menu_gum() {
    local current
    current=$(get_current)

    # Build menu items
    local -a items=()
    for i in {0..7}; do
        local status=""
        if is_completed "$i"; then
            status="✓ "
        elif [[ "$i" == "$current" ]]; then
            status="● "
        else
            status="  "
        fi
        items+=("${status}[$((i + 1))] ${LESSON_TITLES[$i]}")
    done
    items+=("")
    items+=("  [r] Restart from beginning")
    items+=("  [s] Show status")
    items+=("  [q] Quit")

    # Show menu with gum
    local choice
    choice=$(printf '%s\n' "${items[@]}" | gum choose --cursor.foreground 212 --selected.foreground 212)

    # Parse choice
    if [[ "$choice" =~ \[([0-9])\] ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ "$choice" =~ \[r\] ]]; then
        echo "r"
    elif [[ "$choice" =~ \[s\] ]]; then
        echo "s"
    else
        echo "q"
    fi
}

# Show lesson menu with basic bash
show_menu_basic() {
    echo -e "${BOLD}Choose a lesson:${NC}"
    echo ""

    for i in {0..7}; do
        echo -e "  $(format_lesson "$i")"
    done

    echo ""
    echo -e "  ${DIM}[r] Restart from beginning${NC}"
    echo -e "  ${DIM}[s] Show status${NC}"
    echo -e "  ${DIM}[q] Quit${NC}"
    echo ""

    read -rp "$(echo -e "${CYAN}Choose [1-8, r, s, q]:${NC} ")" choice

    case "$choice" in
        [1-8]) echo "$choice" ;;
        r|R) echo "r" ;;
        s|S) echo "s" ;;
        q|Q|"") echo "q" ;;
        *) echo "invalid" ;;
    esac
}

# Render markdown content
render_markdown() {
    local file=$1

    if has_glow; then
        glow -s dark "$file"
    elif command -v bat &>/dev/null; then
        bat --style=plain --language=markdown "$file"
    else
        # Basic markdown rendering with sed
        sed \
            -e "s/^# \(.*\)$/$(printf '\033[1;35m')\\1$(printf '\033[0m')/" \
            -e "s/^## \(.*\)$/$(printf '\033[1;36m')\\1$(printf '\033[0m')/" \
            -e "s/^### \(.*\)$/$(printf '\033[1;33m')\\1$(printf '\033[0m')/" \
            -e "s/\*\*\([^*]*\)\*\*/$(printf '\033[1m')\\1$(printf '\033[0m')/g" \
            -e "s/\`\([^\`]*\)\`/$(printf '\033[36m')\\1$(printf '\033[0m')/g" \
            -e "s/^---$/$(printf '\033[90m')────────────────────────────────────────$(printf '\033[0m')/" \
            -e "s/^- /  • /" \
            "$file"
    fi
}

# Show a lesson
show_lesson() {
    local idx=$1
    local file="${LESSONS_DIR}/${LESSON_FILES[$idx]}"

    if [[ ! -f "$file" ]]; then
        echo -e "${RED}Error: Lesson file not found: $file${NC}"
        echo "Please ensure ACFS is properly installed."
        return 1
    fi

    clear

    # Header
    echo -e "${BOLD}${MAGENTA}Lesson $((idx + 1)): ${LESSON_TITLES[$idx]}${NC}"
    echo -e "${DIM}─────────────────────────────────────────${NC}"
    echo ""

    # Content
    render_markdown "$file"

    echo ""
    echo -e "${DIM}─────────────────────────────────────────${NC}"

    # Navigation
    local nav_options="[m] Menu"
    if [[ $idx -gt 0 ]]; then
        nav_options+="  [p] Previous"
    fi
    if [[ $idx -lt 7 ]]; then
        nav_options+="  [n] Next"
    fi
    nav_options+="  [c] Mark complete  [q] Quit"

    echo -e "${DIM}$nav_options${NC}"
    echo ""

    while true; do
        read -rp "$(echo -e "${CYAN}Action:${NC} ")" action
        case "$action" in
            m|M) return 0 ;;
            p|P)
                if [[ $idx -gt 0 ]]; then
                    set_current $((idx - 1))
                    show_lesson $((idx - 1))
                    return $?
                fi
                ;;
            n|N)
                if [[ $idx -lt 7 ]]; then
                    set_current $((idx + 1))
                    show_lesson $((idx + 1))
                    return $?
                fi
                ;;
            c|C)
                mark_completed "$idx"
                echo -e "${GREEN}Lesson $((idx + 1)) marked complete!${NC}"
                sleep 1
                if [[ $idx -lt 7 ]]; then
                    show_lesson $((idx + 1))
                    return $?
                else
                    echo -e "${GREEN}${BOLD}Congratulations! You've completed all lessons!${NC}"
                    sleep 2
                    return 0
                fi
                ;;
            q|Q) exit 0 ;;
            "") ;;
            *) echo -e "${YELLOW}Invalid option. Use m/p/n/c/q${NC}" ;;
        esac
    done
}

# Show completion status
show_status() {
    print_header

    local completed_count=0
    for i in {0..7}; do
        if is_completed "$i"; then
            ((completed_count += 1))
        fi
    done

    echo -e "${BOLD}Progress: $completed_count/8 lessons completed${NC}"
    echo ""

    # Progress bar
    local filled=$((completed_count * 5))
    local empty=$((40 - filled))
    printf '%s' "${GREEN}"
    printf '█%.0s' $(seq 1 $filled) 2>/dev/null || true
    printf '%s' "${DIM}"
    printf '░%.0s' $(seq 1 $empty) 2>/dev/null || true
    printf '%s' "${NC}"
    echo " $((completed_count * 100 / 8))%"
    echo ""

    for i in {0..7}; do
        echo -e "  $(format_lesson "$i")"
    done

    echo ""

    if [[ $completed_count -eq 8 ]]; then
        echo -e "${GREEN}${BOLD}All lessons complete! You're ready to fly!${NC}"
    else
        local current
        current=$(get_current)
        echo -e "${CYAN}Next up: Lesson $((current + 1)) - ${LESSON_TITLES[$current]}${NC}"
    fi

    echo ""
    read -rp "Press Enter to continue..."
}

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

main_menu() {
    while true; do
        print_header

        local choice
        if has_gum; then
            choice=$(show_menu_gum)
        else
            choice=$(show_menu_basic)
        fi

        case "$choice" in
            [1-8])
                local idx=$((choice - 1))
                set_current "$idx"
                show_lesson "$idx"
                ;;
            r)
                if has_gum; then
                    if gum confirm "Reset all progress?"; then
                        reset_progress
                    fi
                else
                    read -rp "Reset all progress? [y/N] " confirm
                    if [[ "$confirm" =~ ^[Yy]$ ]]; then
                        reset_progress
                    fi
                fi
                ;;
            s)
                show_status
                ;;
            q)
                echo -e "${GREEN}Happy coding!${NC}"
                exit 0
                ;;
            invalid)
                echo -e "${YELLOW}Invalid choice. Please try again.${NC}"
                sleep 1
                ;;
        esac
    done
}

# Handle command line arguments
case "${1:-}" in
    lesson)
        if [[ -z "${2:-}" ]] || ! [[ "$2" =~ ^[0-7]$ ]]; then
            echo "Usage: onboard lesson N (where N is 0-7)"
            exit 1
        fi
        init_progress
        show_lesson "$2"
        ;;
    reset)
        init_progress
        reset_progress
        ;;
    status)
        init_progress
        show_status
        ;;
    --version|-v)
        echo "onboard v$VERSION"
        ;;
    --help|-h)
        cat <<EOF
ACFS Onboarding Tutorial

Usage:
  onboard           Launch interactive menu
  onboard lesson N  Jump to lesson N (0-7)
  onboard reset     Reset all progress
  onboard status    Show completion status
  onboard --help    Show this help

Lessons:
  0 - Welcome & Overview
  1 - Linux Navigation
  2 - SSH & Persistence
  3 - tmux Basics
  4 - Agent Commands
  5 - NTM Command Center
  6 - NTM Prompt Palette
  7 - The Flywheel Loop

Environment:
  ACFS_LESSONS_DIR   Path to lesson files (default: ~/.acfs/onboard/lessons)
  ACFS_PROGRESS_FILE Path to progress file (default: ~/.acfs/onboard_progress.json)
EOF
        ;;
    "")
        init_progress
        main_menu
        ;;
    *)
        echo "Unknown command: $1"
        echo "Run 'onboard --help' for usage."
        exit 1
        ;;
esac
