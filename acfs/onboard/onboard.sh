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
    "08_keeping_updated.md|Keeping Updated|4 min"
)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# Lesson summaries: key learning points for each lesson (pipe-separated)
declare -A LESSON_SUMMARIES
LESSON_SUMMARIES=(
    [0]="Understanding the ACFS philosophy|How AI agents fit into development|Your path to productivity"
    [1]="Navigating with pwd, ls, cd|Creating files and directories|Understanding file paths"
    [2]="SSH key generation and usage|Persistent connections|Managing remote sessions"
    [3]="Creating sessions with ntm new|Detaching with Ctrl+B, D|Resuming with ntm attach"
    [4]="Launching Claude Code with cc|Using Codex with cod|Gemini CLI with gmi"
    [5]="NTM as your command center|Managing multiple sessions|Session naming conventions"
    [6]="Quick command palette|Fast task switching|Workflow optimization"
    [7]="The agent flywheel loop|Iterating with AI feedback|Building momentum"
    [8]="Keeping tools updated|Managing configurations|Staying current"
)

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

# Calculate progress statistics
_calc_progress() {
    local completed_count=0
    local total=${#LESSONS[@]}
    local completed
    completed=$(_get_completed)

    for c in $completed; do
        ((completed_count++)) || true
    done

    local percent=0
    if [[ $total -gt 0 ]]; then
        percent=$((completed_count * 100 / total))
    fi

    echo "$completed_count|$total|$percent"
}

# Render a progress bar
_render_progress_bar() {
    local current=$1
    local total=$2
    local width=${3:-20}

    # Guard against division by zero
    if [[ $total -eq 0 ]]; then
        local bar=""
        for ((i=0; i<width; i++)); do bar+="░"; done
        echo -e "${GREEN}${bar}${NC}"
        return
    fi

    local filled=$((current * width / total))
    [[ $filled -gt $width ]] && filled=$width
    local empty=$((width - filled))

    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done

    echo -e "${GREEN}${bar}${NC}"
}

# Estimate remaining time
_estimate_remaining() {
    local completed=$1
    local total=$2

    local remaining=$((total - completed))
    # Average 5 minutes per lesson
    local minutes=$((remaining * 5))

    if [[ $minutes -eq 0 ]]; then
        echo "Complete!"
    elif [[ $minutes -lt 60 ]]; then
        echo "~${minutes} min"
    else
        echo "~$((minutes / 60))h ${minutes % 60}m"
    fi
}

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
# Celebration Screen
# ============================================================

# Show celebration screen after lesson completion
_show_celebration() {
    local idx="$1"
    local lesson_title
    lesson_title=$(_get_lesson_title "$idx")

    # Get progress stats
    local progress_data completed_count total percent
    progress_data=$(_calc_progress)
    completed_count=$(echo "$progress_data" | cut -d'|' -f1)
    total=$(echo "$progress_data" | cut -d'|' -f2)
    percent=$(echo "$progress_data" | cut -d'|' -f3)

    # Get lesson summary points
    local summary_raw="${LESSON_SUMMARIES[$idx]:-}"
    local -a summary_points=()
    if [[ -n "$summary_raw" ]]; then
        IFS='|' read -ra summary_points <<< "$summary_raw"
    fi

    # Render progress bar
    local progress_bar
    progress_bar=$(_render_progress_bar "$completed_count" "$total" 20)

    clear
    echo ""

    if _has_gum; then
        # Gum-enhanced celebration
        gum style \
            --border rounded \
            --border-foreground "#89b4fa" \
            --padding "1 2" \
            --margin "1" \
            "$(echo -e "🎉 ${BOLD}Lesson Complete: ${lesson_title}${NC}")"

        echo ""

        if [[ ${#summary_points[@]} -gt 0 ]]; then
            echo -e "  ${BOLD}You learned:${NC}"
            for point in "${summary_points[@]}"; do
                echo -e "  ${GREEN}•${NC} $point"
            done
            echo ""
        fi

        echo -e "  ${BOLD}Progress:${NC} $progress_bar ${completed_count}/${total} (${percent}%)"
        echo ""

        local next=$((idx + 1))
        if (( next >= ${#LESSONS[@]} )); then
            gum style \
                --foreground "#a6e3a1" \
                --bold \
                "🏆 You've completed all lessons!"
            echo ""
            echo -e "  You're now ready to use the full ACFS workflow."
            echo -e "  Run ${CYAN}acfs cheatsheet${NC} for quick command reference."
            echo ""
            gum confirm "Return to menu?" && return 0
        else
            local choice
            choice=$(gum choose \
                "Continue to next lesson" \
                "Return to menu")

            case "$choice" in
                "Continue to next lesson")
                    return 1  # Signal to continue
                    ;;
                *)
                    return 0  # Return to menu
                    ;;
            esac
        fi
    else
        # Plain text celebration
        echo -e "${CYAN}+-------------------------------------------------------------+${NC}"
        echo -e "${CYAN}|${NC}  🎉 ${BOLD}Lesson Complete: ${lesson_title}${NC}"
        echo -e "${CYAN}|${NC}"

        if [[ ${#summary_points[@]} -gt 0 ]]; then
            echo -e "${CYAN}|${NC}  ${BOLD}You learned:${NC}"
            for point in "${summary_points[@]}"; do
                echo -e "${CYAN}|${NC}    ${GREEN}•${NC} $point"
            done
        fi

        echo -e "${CYAN}|${NC}"
        echo -e "${CYAN}|${NC}  ${BOLD}Progress:${NC} $progress_bar ${completed_count}/${total} (${percent}%)"
        echo -e "${CYAN}|${NC}"

        local next=$((idx + 1))
        if (( next >= ${#LESSONS[@]} )); then
            echo -e "${CYAN}|${NC}  ${GREEN}${BOLD}🏆 You've completed all lessons!${NC}"
            echo -e "${CYAN}|${NC}"
            echo -e "${CYAN}|${NC}  You're now ready to use the full ACFS workflow."
            echo -e "${CYAN}|${NC}  Run ${CYAN}acfs cheatsheet${NC} for quick command reference."
            echo -e "${CYAN}+-------------------------------------------------------------+${NC}"
            echo ""
            read -r -p "Press Enter to return to menu..." </dev/tty || true
            return 0
        else
            echo -e "${CYAN}|${NC}  ${BOLD}[Enter]${NC} Continue to next lesson"
            echo -e "${CYAN}|${NC}  ${BOLD}[m]${NC}     Return to menu"
            echo -e "${CYAN}+-------------------------------------------------------------+${NC}"
            echo ""
            read -r -p "Choice: " choice </dev/tty || true

            case "$choice" in
                m|M)
                    return 0
                    ;;
                *)
                    return 1  # Continue to next
                    ;;
            esac
        fi
    fi
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

                # Show celebration screen
                if _show_celebration "$idx"; then
                    # Return 0 means go to menu
                    return 0
                else
                    # Return 1 means continue to next lesson
                    local next=$((idx + 1))
                    if (( next < ${#LESSONS[@]} )); then
                        _run_lesson "$next"
                    fi
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

                # Show celebration screen
                if _show_celebration "$idx"; then
                    # Return 0 means go to menu
                    return 0
                else
                    # Return 1 means continue to next lesson
                    local next=$((idx + 1))
                    if (( next < ${#LESSONS[@]} )); then
                        _run_lesson "$next"
                    fi
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

    # Get progress stats
    local progress_data completed_count total percent
    progress_data=$(_calc_progress)
    completed_count=$(echo "$progress_data" | cut -d'|' -f1)
    total=$(echo "$progress_data" | cut -d'|' -f2)
    percent=$(echo "$progress_data" | cut -d'|' -f3)
    local remaining_time
    remaining_time=$(_estimate_remaining "$completed_count" "$total")
    local progress_bar
    progress_bar=$(_render_progress_bar "$completed_count" "$total" 20)

    clear
    echo ""
    echo -e "${BOLD}${CYAN}+-------------------------------------------------------------+${NC}"
    echo -e "${BOLD}${CYAN}|${NC}           ${BOLD}Welcome to ACFS Onboarding${NC}                        ${BOLD}${CYAN}|${NC}"
    echo -e "${BOLD}${CYAN}|${NC}                                                             ${BOLD}${CYAN}|${NC}"
    echo -e "${BOLD}${CYAN}|${NC}  Learn the ACFS workflow step by step                       ${BOLD}${CYAN}|${NC}"
    echo -e "${BOLD}${CYAN}+-------------------------------------------------------------+${NC}"
    echo ""
    echo -e "  ${BOLD}Progress:${NC} $progress_bar ${completed_count}/${total} lessons (${percent}%)"
    echo -e "  ${DIM}Estimated time remaining: ${remaining_time}${NC}"
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
            [1-9])
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
  onboard <n>            Run a single lesson (1-9)
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

    # Get progress stats
    local progress_data completed_count total percent
    progress_data=$(_calc_progress)
    completed_count=$(echo "$progress_data" | cut -d'|' -f1)
    total=$(echo "$progress_data" | cut -d'|' -f2)
    percent=$(echo "$progress_data" | cut -d'|' -f3)
    local remaining_time
    remaining_time=$(_estimate_remaining "$completed_count" "$total")
    local progress_bar
    progress_bar=$(_render_progress_bar "$completed_count" "$total" 20)

    echo ""
    echo -e "${BOLD}ACFS Onboarding Lessons${NC}"
    echo -e "Progress: $progress_bar ${completed_count}/${total} (${percent}%) - ${remaining_time}"
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
        [1-9])
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
