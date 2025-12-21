#!/usr/bin/env bash
# ============================================================
# ACFS Onboarding TUI
# Interactive tutorial teaching the ACFS workflow
# ============================================================
set -euo pipefail

# ============================================================
# Configuration
# ============================================================

ACFS_HOME="${ACFS_HOME:-$HOME/.acfs}"
LESSONS_DIR="$ACFS_HOME/onboard/lessons"
PROGRESS_FILE="$ACFS_HOME/onboard_progress.json"

# Lesson definitions: filename|title|duration
LESSONS=(
    "00_welcome.md|Welcome & Overview|2 min"
    "01_linux_basics.md|Linux Navigation|5 min"
    "02_ssh_basics.md|SSH & Persistence|4 min"
    "03_tmux_basics.md|tmux Basics|6 min"
    "04_agents_login.md|Agent Commands (cc, cod, gmi)|5 min"
    "05_ntm_core.md|NTM Command Center|7 min"
    "06_ntm_command_palette.md|NTM Prompt Palette|5 min"
    "07_flywheel_loop.md|The Flywheel Loop|8 min"
)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# ============================================================
# Helper Functions
# ============================================================

# Check if gum is available
_has_gum() {
    command -v gum &>/dev/null
}

# Check if jq is available
_has_jq() {
    command -v jq &>/dev/null
}

# Get lesson filename from index
_get_lesson_file() {
    local idx="$1"
    echo "${LESSONS[$idx]}" | cut -d'|' -f1
}

# Get lesson title from index
_get_lesson_title() {
    local idx="$1"
    echo "${LESSONS[$idx]}" | cut -d'|' -f2
}

# Get lesson duration from index
_get_lesson_duration() {
    local idx="$1"
    echo "${LESSONS[$idx]}" | cut -d'|' -f3
}

# ============================================================
# Progress Tracking
# ============================================================

# Initialize progress file if it doesn't exist
_init_progress() {
    if [[ ! -f "$PROGRESS_FILE" ]]; then
        mkdir -p "$(dirname "$PROGRESS_FILE")"
        cat > "$PROGRESS_FILE" <<EOF
{
  "completed": [],
  "current": 0,
  "started_at": "$(date -Iseconds)"
}
EOF
    fi
}

# Get completed lessons as space-separated list
_get_completed() {
    if [[ ! -f "$PROGRESS_FILE" ]]; then
        echo ""
        return
    fi

    if _has_jq; then
        jq -r '.completed | @sh' "$PROGRESS_FILE" 2>/dev/null | tr -d "'" || echo ""
    else
        # Fallback: parse with grep/sed
        grep -o '"completed":\s*\[[^]]*\]' "$PROGRESS_FILE" 2>/dev/null | \
            grep -oE '[0-9]+' | tr '\n' ' ' || echo ""
    fi
}

# Check if a lesson is completed
_is_completed() {
    local idx="$1"
    local completed
    completed=$(_get_completed)

    for c in $completed; do
        if [[ "$c" == "$idx" ]]; then
            return 0
        fi
    done
    return 1
}

# Get current lesson index
_get_current() {
    if [[ ! -f "$PROGRESS_FILE" ]]; then
        echo "0"
        return
    fi

    if _has_jq; then
        jq -r '.current // 0' "$PROGRESS_FILE" 2>/dev/null || echo "0"
    else
        grep -o '"current":\s*[0-9]*' "$PROGRESS_FILE" 2>/dev/null | \
            grep -oE '[0-9]+' || echo "0"
    fi
}

# Mark a lesson as completed
_mark_completed() {
    local idx="$1"

    _init_progress

    if _has_jq; then
        local tmp
        tmp=$(mktemp)
        jq --argjson idx "$idx" \
            'if (.completed | index($idx)) then . else .completed += [$idx] end | .current = ($idx + 1)' \
            "$PROGRESS_FILE" > "$tmp" && mv "$tmp" "$PROGRESS_FILE"
    else
        # Fallback: simple append (may have duplicates but that's okay)
        local completed
        completed=$(_get_completed)
        local already=false
        for c in $completed; do
            [[ "$c" == "$idx" ]] && already=true
        done

        if [[ "$already" == "false" ]]; then
            # Rewrite the file with new completed entry
            # Trim leading/trailing whitespace and handle empty $completed
            local new_completed
            if [[ -z "${completed// }" ]]; then
                new_completed="$idx"
            else
                new_completed="$completed $idx"
            fi
            # Convert spaces to commas, trim leading/trailing commas
            local json_array
            json_array=$(echo "$new_completed" | tr -s ' ' ',' | sed 's/^,//;s/,$//')
            local next=$((idx + 1))
            cat > "$PROGRESS_FILE" <<EOF
{
  "completed": [$json_array],
  "current": $next,
  "started_at": "$(date -Iseconds)"
}
EOF
        fi
    fi
}

# Reset all progress
_reset_progress() {
    rm -f "$PROGRESS_FILE"
    _init_progress
    echo -e "${GREEN}Progress reset. Starting fresh!${NC}"
}

# ============================================================
# Display Functions
# ============================================================

# Display the pager for a lesson
_pager() {
    if command -v bat &>/dev/null; then
        bat --paging=always --style=plain --language=markdown
        return 0
    fi
    if command -v less &>/dev/null; then
        less -R
        return 0
    fi
    cat
}

# Show a single lesson
_show_lesson() {
    local idx="$1"
    local lesson_file
    local lesson_title
    local path

    lesson_file=$(_get_lesson_file "$idx")
    lesson_title=$(_get_lesson_title "$idx")
    path="$LESSONS_DIR/$lesson_file"

    if [[ ! -f "$path" ]]; then
        echo -e "${RED}Lesson not found:${NC} $path" >&2
        echo "    Fix: re-run the ACFS installer to (re)install onboarding lessons." >&2
        return 1
    fi

    clear
    echo ""
    echo -e "${BOLD}${CYAN}============================================================${NC}"
    echo -e "${BOLD}  Lesson $((idx + 1)): $lesson_title${NC}"
    echo -e "${BOLD}${CYAN}============================================================${NC}"
    echo ""

    _pager < "$path"
}

# Show lesson and handle completion
_run_lesson() {
    local idx="$1"
    local lesson_title
    lesson_title=$(_get_lesson_title "$idx")

    # If show lesson fails (file not found), return immediately
    # Do not show the completion menu
    if ! _show_lesson "$idx"; then
        read -r -p "Press Enter to return to menu..." || true
        return 1
    fi

    echo ""
    echo -e "${CYAN}------------------------------------------------------------${NC}"

    if _has_gum; then
        local choice
        choice=$(gum choose --header="Lesson $((idx + 1)): $lesson_title" \
            "Mark as completed and continue" \
            "Return to menu" \
            "View lesson again")

        case "$choice" in
            "Mark as completed and continue")
                _mark_completed "$idx"
                echo -e "${GREEN}Lesson $((idx + 1)) completed!${NC}"
                sleep 1

                # Auto-advance to next lesson if available
                local next=$((idx + 1))
                if (( next < ${#LESSONS[@]} )); then
                    _run_lesson "$next"
                else
                    echo -e "${GREEN}${BOLD}Congratulations! You've completed all lessons!${NC}"
                    sleep 2
                fi
                ;;
            "View lesson again")
                _run_lesson "$idx"
                ;;
            *)
                return 0
                ;;
        esac
    else
        # Fallback: simple prompt
        echo ""
        echo -e "  ${BOLD}[c]${NC} Mark as completed and continue"
        echo -e "  ${BOLD}[m]${NC} Return to menu"
        echo -e "  ${BOLD}[r]${NC} View lesson again"
        echo ""
        read -r -p "Choose: " choice </dev/tty || true

        case "$choice" in
            c|C)
                _mark_completed "$idx"
                echo -e "${GREEN}Lesson $((idx + 1)) completed!${NC}"
                sleep 1

                local next=$((idx + 1))
                if (( next < ${#LESSONS[@]} )); then
                    _run_lesson "$next"
                else
                    echo -e "${GREEN}${BOLD}Congratulations! You've completed all lessons!${NC}"
                    sleep 2
                fi
                ;;
            r|R)
                _run_lesson "$idx"
                ;;
            *)
                return 0
                ;;
        esac
    fi
}

# ============================================================
# Menu Functions
# ============================================================

# Build the interactive menu
_show_menu() {
    local current
    current=$(_get_current)

    clear
    echo ""
    echo -e "${BOLD}${CYAN}+-------------------------------------------------------------+${NC}"
    echo -e "${BOLD}${CYAN}|${NC}           ${BOLD}Welcome to ACFS Onboarding${NC}                        ${BOLD}${CYAN}|${NC}"
    echo -e "${BOLD}${CYAN}|${NC}                                                             ${BOLD}${CYAN}|${NC}"
    echo -e "${BOLD}${CYAN}|${NC}  Learn the ACFS workflow step by step                       ${BOLD}${CYAN}|${NC}"
    echo -e "${BOLD}${CYAN}+-------------------------------------------------------------+${NC}"
    echo ""

    # Build menu options
    local options=()
    local i=0
    for lesson_def in "${LESSONS[@]}"; do
        local title duration status_icon
        title=$(echo "$lesson_def" | cut -d'|' -f2)
        duration=$(echo "$lesson_def" | cut -d'|' -f3)

        if _is_completed "$i"; then
            status_icon="${GREEN}[done]${NC}"
        elif [[ "$i" == "$current" ]]; then
            status_icon="${YELLOW}[next]${NC}"
        else
            status_icon="${DIM}[ ]${NC}"
        fi

        # Format: [n] Title (duration) status
        options+=("$((i + 1)). $title ($duration)|$status_icon|$i")
        i=$((i + 1))
    done

    if _has_gum; then
        # Build display list for gum
        local display_options=()
        for opt in "${options[@]}"; do
            local text
            text=$(echo "$opt" | cut -d'|' -f1)
            local idx
            idx=$(echo "$opt" | cut -d'|' -f3)

            if _is_completed "$idx"; then
                display_options+=("$text  [done]")
            elif [[ "$idx" == "$current" ]]; then
                display_options+=("$text  [next]")
            else
                display_options+=("$text")
            fi
        done

        display_options+=("-------------------------")
        display_options+=("Reset progress")
        display_options+=("Quit")

        local choice
        choice=$(gum choose --header="Choose a lesson:" "${display_options[@]}")

        case "$choice" in
            "Reset progress")
                _reset_progress
                sleep 1
                _show_menu
                ;;
            "Quit")
                echo -e "${CYAN}See you next time!${NC}"
                exit 0
                ;;
            "-------------------------")
                _show_menu
                ;;
            *)
                # Extract lesson number from choice
                local num
                num=$(echo "$choice" | grep -oE '^[0-9]+' || echo "")
                if [[ -n "$num" ]] && (( num >= 1 && num <= ${#LESSONS[@]} )); then
                    _run_lesson "$((num - 1))"
                    _show_menu
                fi
                ;;
        esac
    else
        # Fallback: simple numbered menu
        echo "  ${BOLD}Choose a lesson:${NC}"
        echo ""

        local i=0
        for lesson_def in "${LESSONS[@]}"; do
            local title duration status
            title=$(echo "$lesson_def" | cut -d'|' -f2)
            duration=$(echo "$lesson_def" | cut -d'|' -f3)

            if _is_completed "$i"; then
                status="${GREEN}[done]${NC}"
            elif [[ "$i" == "$current" ]]; then
                status="${YELLOW}[next]${NC}"
            else
                status="${DIM}[ ]${NC}"
            fi

            printf "  ${BOLD}[%d]${NC} %-35s ${DIM}(%s)${NC}  %b\n" "$((i + 1))" "$title" "$duration" "$status"
            i=$((i + 1))
        done

        echo ""
        echo -e "  ${BOLD}[r]${NC} Reset progress"
        echo -e "  ${BOLD}[q]${NC} Quit"
        echo ""

        read -r -p "Choose: " choice </dev/tty || true

        case "$choice" in
            [1-8])
                local idx=$((choice - 1))
                if (( idx >= 0 && idx < ${#LESSONS[@]} )); then
                    _run_lesson "$idx"
                    _show_menu
                fi
                ;;
            r|R)
                _reset_progress
                sleep 1
                _show_menu
                ;;
            q|Q|"")
                echo -e "${CYAN}See you next time!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice.${NC} Try again."
                sleep 1
                _show_menu
                ;;
        esac
    fi
}

# ============================================================
# CLI Interface
# ============================================================

usage() {
    cat <<'EOF'
onboard - ACFS onboarding tutorial

Usage:
  onboard                Interactive TUI menu
  onboard --list         List lessons with completion status
  onboard <n>            Run a single lesson (1-8)
  onboard --reset        Reset all progress
  onboard --help         Show this help

Features:
  - Interactive menu (with gum for enhanced UX)
  - Progress tracking (saved between runs)
  - Completion markers for finished lessons

Notes:
  - Lessons live in ~/.acfs/onboard/lessons
  - Progress saved in ~/.acfs/onboard_progress.json
  - Install gum for best experience: https://github.com/charmbracelet/gum
EOF
}

print_list() {
    _init_progress

    echo ""
    echo -e "${BOLD}ACFS Onboarding Lessons${NC}"
    echo ""

    local i=0
    for lesson_def in "${LESSONS[@]}"; do
        local title duration status
        title=$(echo "$lesson_def" | cut -d'|' -f2)
        duration=$(echo "$lesson_def" | cut -d'|' -f3)

        if _is_completed "$i"; then
            status="${GREEN}[done]${NC}"
        elif [[ "$i" == "$(_get_current)" ]]; then
            status="${YELLOW}[next]${NC}"
        else
            status="${DIM}[ ]${NC}"
        fi

        printf "  %d. %-30s ${DIM}(%s)${NC}  %b\n" "$((i + 1))" "$title" "$duration" "$status"
        i=$((i + 1))
    done
    echo ""
}

# ============================================================
# Main
# ============================================================

main() {
    _init_progress

    case "${1:-}" in
        "")
            _show_menu
            ;;
        --help|-h)
            usage
            ;;
        --list|-l)
            print_list
            ;;
        --reset)
            _reset_progress
            ;;
        [1-8])
            local idx=$(($1 - 1))
            _run_lesson "$idx"
            ;;
        *)
            echo -e "${RED}Unknown argument:${NC} $1" >&2
            echo "    Try: onboard --help" >&2
            exit 1
            ;;
    esac
}

main "$@"
