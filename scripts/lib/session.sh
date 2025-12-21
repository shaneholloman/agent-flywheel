#!/usr/bin/env bash
# ============================================================
# ACFS Installer - Session Export Library
# Defines schema and validation for agent session exports
# ============================================================
#
# Part of EPIC: Agent Session Sharing and Replay (0sb)
# See bead c61 for design decisions.
#
# ============================================================
# SESSION EXPORT SCHEMA (TypeScript Interface)
# ============================================================
#
# Schema lives inline per AGENTS.md guidance (no separate schema file).
# Version field allows future evolution.
#
# ```typescript
# interface SessionExport {
#     schema_version: 1;              // Always 1 for this version
#     exported_at: string;            // ISO8601 timestamp
#     session_id: string;             // Unique session identifier
#     agent: "claude-code" | "codex" | "gemini";
#     model: string;                  // e.g., "opus-4.5", "gpt-4o"
#     summary: string;                // Brief description of what happened
#     duration_minutes: number;       // Session length
#     stats: {
#         turns: number;              // Conversation turns
#         files_created: number;
#         files_modified: number;
#         commands_run: number;
#     };
#     outcomes: Array<{
#         type: "file_created" | "file_modified" | "command_run";
#         path?: string;              // For file operations
#         description: string;
#     }>;
#     key_prompts: string[];          // Notable prompts for learning
#     sanitized_transcript: Array<{
#         role: "user" | "assistant";
#         content: string;            // Post-sanitization
#         timestamp: string;          // ISO8601
#     }>;
# }
# ```
#
# DESIGN DECISIONS:
# - Schema versioned for evolution (schema_version: 1)
# - Fields designed for post-sanitization data (no raw secrets)
# - Focused on value: outcomes show what happened, key_prompts show how
# - Not a raw dump - curated for learning and replay
#
# ============================================================
# CASS (Coding Agent Session Search) API REFERENCE
# ============================================================
#
# CASS is the backend for session discovery and export. See bead eli for research.
#
# Version Info:
#   API Version: 1, Contract Version: 1, Crate: 0.1.35+
#
# Supported Connectors (agents):
#   claude_code, codex, gemini, cursor, amp, cline, aider, opencode, chatgpt, pi_agent
#
# Key Commands:
#   cass stats --json              # Session counts by agent/workspace
#   cass search "query" --json     # Full-text search with JSON output
#   cass export <path> --format json  # Export session to JSON array
#   cass status --json             # Health check with index freshness
#   cass capabilities --json       # Feature/connector discovery
#
# CASS Export JSON Structure (per message):
#   {
#     "agentId": "abc123",           // Short session identifier
#     "sessionId": "uuid",           // Full session UUID
#     "cwd": "/path/to/project",     // Working directory
#     "gitBranch": "main",           // Git branch (optional)
#     "timestamp": "ISO8601",        // Message timestamp
#     "type": "user|assistant",      // Message type
#     "uuid": "message-uuid",        // Message UUID
#     "parentUuid": "uuid|null",     // For threading
#     "message": {
#       "role": "user|assistant",
#       "content": "...",            // String or array of content blocks
#       "model": "claude-opus-4-5",  // For assistant messages
#       "usage": {...}               // Token usage stats
#     }
#   }
#
# Limitations (see bead eli):
#   - No direct "list sessions" CLI - use `cass search "*" --limit 100`
#   - CASS indexes JSONL files from agent data dirs, not a sessions table
#   - Export requires knowing the session file path
#   - Use stats/search to discover sessions, then export specific ones
#
# Session File Locations:
#   Claude Code: ~/.claude/projects/<project>/agent-*.jsonl
#   Codex: ~/.codex/sessions/<year>/<month>/<day>/*.jsonl
#   Gemini: ~/.gemini/tmp/<hash>/session.jsonl
#
# ============================================================

# Source logging if not already loaded
if [[ -z "${ACFS_LOG_LOADED:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # shellcheck source=logging.sh
    source "${SCRIPT_DIR}/logging.sh" 2>/dev/null || true
fi

# ============================================================
# VALIDATION
# ============================================================

# Validate a session export JSON file against the schema
# Usage: validate_session_export "/path/to/export.json"
# Returns: 0 on success, 1 on validation failure
validate_session_export() {
    local file="$1"

    # Check file exists
    if [[ ! -f "$file" ]]; then
        log_error "Session export file not found: $file"
        return 1
    fi

    # Check it's valid JSON
    if ! jq -e . "$file" >/dev/null 2>&1; then
        log_error "Invalid JSON in session export: $file"
        return 1
    fi

    # Check required top-level fields exist
    if ! jq -e '.schema_version and .session_id and .agent' "$file" >/dev/null 2>&1; then
        log_error "Invalid session export: missing required fields (schema_version, session_id, agent)"
        return 1
    fi

    # Check schema version compatibility
    local version
    version=$(jq -r '.schema_version' "$file")
    if [[ "$version" != "1" ]]; then
        log_warn "Session schema version $version may not be fully compatible (expected: 1)"
    fi

    # Validate agent field is one of the known agents
    local agent
    agent=$(jq -r '.agent' "$file")
    case "$agent" in
        claude-code|codex|gemini)
            ;;
        *)
            log_warn "Unknown agent type: $agent (expected: claude-code, codex, or gemini)"
            ;;
    esac

    # Validate stats object exists and has expected fields
    if ! jq -e '.stats.turns != null' "$file" >/dev/null 2>&1; then
        log_warn "Session export missing stats.turns field"
    fi

    return 0
}

# Get schema version from a session export
# Usage: get_session_schema_version "/path/to/export.json"
# Returns: schema version number or "unknown"
get_session_schema_version() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        echo "unknown"
        return 1
    fi

    jq -r '.schema_version // "unknown"' "$file" 2>/dev/null || echo "unknown"
}

# Get session summary from an export
# Usage: get_session_summary "/path/to/export.json"
get_session_summary() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        echo ""
        return 1
    fi

    jq -r '.summary // ""' "$file" 2>/dev/null || echo ""
}

# Get session agent from an export
# Usage: get_session_agent "/path/to/export.json"
get_session_agent() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        echo ""
        return 1
    fi

    jq -r '.agent // ""' "$file" 2>/dev/null || echo ""
}

# Check if jq is available (required for session operations)
# Usage: check_session_deps
check_session_deps() {
    if ! command -v jq >/dev/null 2>&1; then
        log_error "jq is required for session operations but not installed"
        return 1
    fi
    return 0
}

# ============================================================
# SANITIZATION
# ============================================================
#
# Sanitization patterns for removing secrets from session exports.
# See bead 1xq for design decisions.
#
# ACFS_SANITIZE_OPTIONAL=1 enables optional patterns (IPs, emails)

# Core redaction patterns - always applied
# These patterns detect secrets that MUST be redacted
readonly REDACT_PATTERNS=(
    # OpenAI API keys (sk-...)
    'sk-[a-zA-Z0-9]{20,}'

    # Anthropic API keys (sk-ant-...)
    'sk-ant-[a-zA-Z0-9_-]{20,}'

    # Google API keys (AIza...)
    'AIza[a-zA-Z0-9_-]{35}'

    # GitHub Personal Access Tokens
    'ghp_[a-zA-Z0-9]{36}'

    # GitHub OAuth tokens
    'gho_[a-zA-Z0-9]{36}'

    # GitHub App tokens
    'ghs_[a-zA-Z0-9]{36}'

    # GitHub Refresh tokens
    'ghr_[a-zA-Z0-9]{36}'

    # Slack Bot tokens
    'xoxb-[a-zA-Z0-9-]+'

    # Slack User tokens
    'xoxp-[a-zA-Z0-9-]+'

    # AWS Access Keys
    'AKIA[A-Z0-9]{16}'

    # Generic password/secret patterns (key=value or key: value)
    # Using [[:space:]] for portability instead of \s
    'password["[:space:]:=]+[^[:space:]"'\'']{8,}'
    'secret["[:space:]:=]+[^[:space:]"'\'']{8,}'
    'api_key["[:space:]:=]+[^[:space:]"'\'']{8,}'
    'apikey["[:space:]:=]+[^[:space:]"'\'']{8,}'
    'auth_token["[:space:]:=]+[^[:space:]"'\'']{8,}'
    'access_token["[:space:]:=]+[^[:space:]"'\'']{8,}'
)

# Optional redaction patterns - applied when ACFS_SANITIZE_OPTIONAL=1
# These may have higher false positive rates
readonly OPTIONAL_REDACT_PATTERNS=(
    # IPv4 addresses
    '\b[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\b'

    # Email addresses
    '\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\b'
)

# Sanitize content by applying redaction patterns
# Usage: sanitize_content "content string"
# Returns: sanitized content via stdout
sanitize_content() {
    local content="$1"
    local result="$content"

    # Apply core redaction patterns
    for pattern in "${REDACT_PATTERNS[@]}"; do
        # Use sed with extended regex for pattern replacement
        result=$(echo "$result" | sed -E "s/${pattern}/[REDACTED]/gi" 2>/dev/null || echo "$result")
    done

    # Apply optional patterns if enabled
    if [[ "${ACFS_SANITIZE_OPTIONAL:-0}" == "1" ]]; then
        for pattern in "${OPTIONAL_REDACT_PATTERNS[@]}"; do
            result=$(echo "$result" | sed -E "s/${pattern}/[REDACTED]/gi" 2>/dev/null || echo "$result")
        done
    fi

    echo "$result"
}

# Sanitize a session export JSON file in place
# Usage: sanitize_session_export "/path/to/export.json"
# Returns: 0 on success, 1 on failure
sanitize_session_export() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        log_error "Session export file not found: $file"
        return 1
    fi

    # Validate it's valid JSON first
    if ! jq -e . "$file" >/dev/null 2>&1; then
        log_error "Invalid JSON in session export: $file"
        return 1
    fi

    # Create temp file for atomic write
    local tmpfile
    tmpfile=$(mktemp)

    # Sanitize all string values in the JSON
    # This processes the transcript content, summary, key_prompts, etc.
    # Using heredoc to avoid shell quoting issues with jq regex patterns
    local jq_filter
    read -r -d '' jq_filter <<'JQ_EOF'
def sanitize_string:
    if type == "string" then
        gsub("sk-[a-zA-Z0-9]{20,}"; "[REDACTED]") |
        gsub("sk-ant-[a-zA-Z0-9_-]{20,}"; "[REDACTED]") |
        gsub("AIza[a-zA-Z0-9_-]{35}"; "[REDACTED]") |
        gsub("ghp_[a-zA-Z0-9]{36}"; "[REDACTED]") |
        gsub("gho_[a-zA-Z0-9]{36}"; "[REDACTED]") |
        gsub("ghs_[a-zA-Z0-9]{36}"; "[REDACTED]") |
        gsub("ghr_[a-zA-Z0-9]{36}"; "[REDACTED]") |
        gsub("xoxb-[a-zA-Z0-9-]+"; "[REDACTED]") |
        gsub("xoxp-[a-zA-Z0-9-]+"; "[REDACTED]") |
        gsub("AKIA[A-Z0-9]{16}"; "[REDACTED]") |
        gsub("(?i)password[\"\\s:=]+[^\\s\"']{8,}"; "[REDACTED]") |
        gsub("(?i)secret[\"\\s:=]+[^\\s\"']{8,}"; "[REDACTED]") |
        gsub("(?i)api_key[\"\\s:=]+[^\\s\"']{8,}"; "[REDACTED]") |
        gsub("(?i)apikey[\"\\s:=]+[^\\s\"']{8,}"; "[REDACTED]") |
        gsub("(?i)auth_token[\"\\s:=]+[^\\s\"']{8,}"; "[REDACTED]") |
        gsub("(?i)access_token[\"\\s:=]+[^\\s\"']{8,}"; "[REDACTED]")
    elif type == "array" then
        map(sanitize_string)
    elif type == "object" then
        with_entries(.value |= sanitize_string)
    else
        .
    end;
sanitize_string
JQ_EOF

    if ! jq "$jq_filter" "$file" > "$tmpfile"; then
        rm -f "$tmpfile"
        log_error "Failed to sanitize session export"
        return 1
    fi

    # Atomic replace
    mv "$tmpfile" "$file"
    return 0
}

# Check if content contains potential secrets (pre-sanitization check)
# Usage: contains_secrets "content string"
# Returns: 0 if secrets detected, 1 if clean
contains_secrets() {
    local content="$1"

    for pattern in "${REDACT_PATTERNS[@]}"; do
        if echo "$content" | grep -qE "$pattern" 2>/dev/null; then
            return 0
        fi
    done

    return 1
}

# ============================================================
# SESSION LISTING (via CASS)
# ============================================================

# Check if CASS is installed
# Usage: check_cass_installed
# Returns: 0 if installed, 1 otherwise
check_cass_installed() {
    if ! command -v cass >/dev/null 2>&1; then
        return 1
    fi
    return 0
}

# List recent sessions via CASS search
# Usage: list_sessions [--json] [--days N] [--agent AGENT] [--limit N]
# Returns: Session list to stdout
list_sessions() {
    local output_json=false
    local days=30
    local agent=""
    local limit=20

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json)
                output_json=true
                shift
                ;;
            --days)
                days="$2"
                shift 2
                ;;
            --agent)
                agent="$2"
                shift 2
                ;;
            --limit)
                limit="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    # Check CASS is installed
    if ! check_cass_installed; then
        if [[ "$output_json" == "true" ]]; then
            echo '{"error": "CASS not installed", "install": "See https://github.com/Dicklesworthstone/coding_agent_session_search"}'
        else
            log_error "CASS (Coding Agent Session Search) is not installed"
            log_info "Install from: https://github.com/Dicklesworthstone/coding_agent_session_search"
        fi
        return 1
    fi

    # Build CASS search command
    local cass_args=("search" "*" "--limit" "$limit" "--days" "$days")

    if [[ -n "$agent" ]]; then
        cass_args+=("--agent" "$agent")
    fi

    if [[ "$output_json" == "true" ]]; then
        # JSON output: aggregate by session with stats
        cass "${cass_args[@]}" --json --aggregate agent,workspace 2>/dev/null | jq '
            {
                sessions: (.aggregations // []) | map({
                    agent: .agent,
                    workspace: .workspace,
                    count: .count
                }),
                total: .count,
                query_info: {
                    limit: .limit,
                    offset: .offset
                }
            }
        ' 2>/dev/null || echo '{"error": "Failed to query CASS"}'
    else
        # Human-readable output
        echo ""
        echo "Recent Sessions (last ${days} days):"
        echo ""

        # Get stats by agent
        local stats
        stats=$(cass stats --json 2>/dev/null)

        if [[ -n "$stats" ]]; then
            echo "$stats" | jq -r '
                "  By Agent:",
                (.by_agent[] | "    \(.agent): \(.count) sessions"),
                "",
                "  Top Workspaces:",
                (.top_workspaces[:5][] | "    \(.workspace): \(.count) sessions")
            ' 2>/dev/null

            echo ""
            echo "  Date Range: $(echo "$stats" | jq -r '.date_range.oldest[:10]') to $(echo "$stats" | jq -r '.date_range.newest[:10]')"
            echo "  Total Conversations: $(echo "$stats" | jq -r '.conversations')"
            echo "  Total Messages: $(echo "$stats" | jq -r '.messages')"
        fi

        echo ""
        echo "Use: cass search \"<query>\" to find specific sessions"
        echo "Use: cass export <session-path> --format json to export"
    fi
}

# Get session details for a specific workspace
# Usage: get_workspace_sessions <workspace_path> [--limit N]
get_workspace_sessions() {
    local workspace="$1"
    local limit="${2:-10}"

    if ! check_cass_installed; then
        log_error "CASS not installed"
        return 1
    fi

    cass search "*" --workspace "$workspace" --limit "$limit" --json 2>/dev/null
}
