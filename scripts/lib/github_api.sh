#!/usr/bin/env bash
# ============================================================
# ACFS Installer - GitHub API Helpers with Rate Limit Backoff
# Provides exponential backoff for GitHub API rate limits
#
# Related: bd-1lug
# ============================================================

GITHUB_API_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ensure we have logging functions available
if [[ -z "${ACFS_BLUE:-}" ]]; then
    # shellcheck source=logging.sh
    source "$GITHUB_API_SCRIPT_DIR/logging.sh" 2>/dev/null || true
fi

# Source security.sh for acfs_curl if not already loaded
if ! declare -f acfs_curl &>/dev/null; then
    # shellcheck source=security.sh
    source "$GITHUB_API_SCRIPT_DIR/security.sh" 2>/dev/null || true
fi

# ============================================================
# Configuration
# ============================================================

# Default backoff settings
GITHUB_BACKOFF_INITIAL=1       # Initial delay in seconds
GITHUB_BACKOFF_MAX=60          # Maximum delay in seconds
GITHUB_BACKOFF_MULTIPLIER=2    # Multiplier for exponential backoff
GITHUB_MAX_RETRIES=5           # Maximum number of retries

# Rate limit detection patterns
GITHUB_RATE_LIMIT_PATTERNS=(
    "rate limit"
    "API rate limit exceeded"
    "You have exceeded a secondary rate limit"
    "abuse detection"
)

# ============================================================
# Rate Limit Detection
# ============================================================

# Check if response indicates a rate limit error
# Arguments:
#   $1 - HTTP status code
#   $2 - Response body (optional)
#   $3 - X-RateLimit-Remaining header value (optional)
# Returns: 0 if rate limited, 1 otherwise
_is_rate_limited() {
    local http_code="$1"
    local body="${2:-}"
    local rate_remaining="${3:-}"

    # Check HTTP 403 (rate limit) or 429 (too many requests)
    if [[ "$http_code" != "403" && "$http_code" != "429" ]]; then
        return 1
    fi

    # Check X-RateLimit-Remaining header
    if [[ -n "$rate_remaining" && "$rate_remaining" == "0" ]]; then
        return 0
    fi

    # Check response body for rate limit patterns
    local body_lower="${body,,}"  # lowercase
    for pattern in "${GITHUB_RATE_LIMIT_PATTERNS[@]}"; do
        if [[ "$body_lower" == *"${pattern,,}"* ]]; then
            return 0
        fi
    done

    # 403/429 without rate limit indicators - might be auth issue
    return 1
}

# Parse X-RateLimit-Reset header to get seconds until reset
# Arguments:
#   $1 - X-RateLimit-Reset header value (Unix timestamp)
# Returns: Seconds until reset (minimum 1)
_get_reset_wait_time() {
    local reset_timestamp="$1"
    local now
    now=$(date +%s)

    if [[ -n "$reset_timestamp" && "$reset_timestamp" =~ ^[0-9]+$ ]]; then
        local wait_time=$((reset_timestamp - now + 1))  # +1 for safety
        if (( wait_time > 0 && wait_time <= GITHUB_BACKOFF_MAX )); then
            echo "$wait_time"
            return
        fi
    fi

    # Fallback to max backoff if reset time is invalid or too long
    echo "$GITHUB_BACKOFF_MAX"
}

_github_api_existing_abs_home() {
    local home_candidate="${1:-}"

    [[ -n "$home_candidate" ]] || return 1
    home_candidate="${home_candidate%/}"
    [[ -n "$home_candidate" ]] || return 1
    [[ "$home_candidate" == /* ]] || return 1
    [[ "$home_candidate" != "/" ]] || return 1
    [[ -d "$home_candidate" ]] || return 1
    printf '%s\n' "$home_candidate"
}

_github_api_runtime_home() {
    local runtime_home=""

    runtime_home="$(_github_api_existing_abs_home "${TARGET_HOME:-}" 2>/dev/null || true)"
    if [[ -n "$runtime_home" ]]; then
        printf '%s\n' "$runtime_home"
        return 0
    fi

    runtime_home="$(_github_api_existing_abs_home "${HOME:-}" 2>/dev/null || true)"
    if [[ -n "$runtime_home" ]]; then
        printf '%s\n' "$runtime_home"
        return 0
    fi

    return 1
}

_github_api_binary_path() {
    local name="${1:-}"
    local runtime_home=""
    local primary_bin_dir=""
    local candidate=""

    [[ -n "$name" ]] || return 1

    runtime_home="$(_github_api_runtime_home 2>/dev/null || true)"
    if [[ -n "$runtime_home" ]]; then
        primary_bin_dir="${ACFS_BIN_DIR:-$runtime_home/.local/bin}"
        for candidate in \
            "$primary_bin_dir/$name" \
            "$runtime_home/.local/bin/$name" \
            "$runtime_home/.acfs/bin/$name" \
            "$runtime_home/.bun/bin/$name" \
            "$runtime_home/.cargo/bin/$name" \
            "$runtime_home/.atuin/bin/$name" \
            "$runtime_home/go/bin/$name"; do
            [[ -x "$candidate" ]] || continue
            printf '%s\n' "$candidate"
            return 0
        done
    fi

    for candidate in \
        "/usr/local/bin/$name" \
        "/usr/bin/$name" \
        "/bin/$name" \
        "/snap/bin/$name"; do
        [[ -x "$candidate" ]] || continue
        printf '%s\n' "$candidate"
        return 0
    done

    return 1
}

# Check if user has GitHub CLI authenticated
# Returns: 0 if authenticated, 1 otherwise
_has_gh_auth() {
    local gh_bin=""
    gh_bin="$(_github_api_binary_path gh 2>/dev/null || true)"
    [[ -n "$gh_bin" ]] && "$gh_bin" auth status &>/dev/null 2>&1
}

# ============================================================
# User-Friendly Messages
# ============================================================

# Display rate limit wait message
# Arguments:
#   $1 - Wait time in seconds
#   $2 - Attempt number
#   $3 - Max attempts
_show_rate_limit_wait() {
    local wait_time="$1"
    local attempt="$2"
    local max_attempts="$3"

    local msg="GitHub rate limit reached. Waiting ${wait_time}s before retry (${attempt}/${max_attempts})..."

    if declare -f log_warn &>/dev/null; then
        log_warn "$msg"
    else
        # Respect NO_COLOR standard (https://no-color.org/)
        if [[ -z "${NO_COLOR:-}" ]] && [[ -t 2 ]]; then
            echo -e "\033[0;33m$msg\033[0m" >&2
        else
            echo "$msg" >&2
        fi
    fi

    # Suggest gh auth if not authenticated and this is first wait
    if [[ "$attempt" -eq 1 ]] && ! _has_gh_auth; then
        local tip="Run 'gh auth login' for higher rate limits (5000/hr vs 60/hr)"
        if declare -f log_detail &>/dev/null; then
            log_detail "Tip: $tip"
        else
            # Respect NO_COLOR standard
            if [[ -z "${NO_COLOR:-}" ]] && [[ -t 2 ]]; then
                echo -e "\033[0;90m  Tip: $tip\033[0m" >&2
            else
                echo "  Tip: $tip" >&2
            fi
        fi
    fi
}

# ============================================================
# Fetch with Rate Limit Backoff
# ============================================================

# Fetch URL with exponential backoff for rate limits
#
# Arguments:
#   $1 - URL to fetch
#   $2 - Output file path (optional, stdout if not provided)
#   $3 - Description for logging (optional)
#
# Environment:
#   GITHUB_TOKEN - If set, used for authentication
#   GH_TOKEN - Alternative token (used by gh CLI)
#
# Returns:
#   0 - Success
#   1 - Rate limit exhausted after max retries
#   2 - Non-rate-limit error (network, 404, etc.)
#
github_fetch_with_backoff() {
    local url="$1"
    local output_file="${2:-}"
    local description="${3:-$url}"

    local delay="$GITHUB_BACKOFF_INITIAL"
    local attempt=0
    local max_attempts="$GITHUB_MAX_RETRIES"
    local -a curl_base_args=()

    # Build curl base args safely.
    # Avoid "${array[@]:-}" here because it expands to a blank argument when the
    # array is unset, which causes curl to fail before making a request.
    if declare -p ACFS_CURL_BASE_ARGS &>/dev/null && (( ${#ACFS_CURL_BASE_ARGS[@]} > 0 )); then
        curl_base_args=("${ACFS_CURL_BASE_ARGS[@]}")
    else
        curl_base_args=(--connect-timeout 30 --max-time 300 -fsSL)
        if command -v curl &>/dev/null && curl --help all 2>/dev/null | grep -q -- '--proto'; then
            curl_base_args=(--proto '=https' --proto-redir '=https' --connect-timeout 30 --max-time 300 -fsSL)
        fi
    fi

    # Prepare auth header if token available
    local auth_header=()
    local token="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
    if [[ -n "$token" ]]; then
        auth_header=(-H "Authorization: token $token")
    fi

    # Temp files for response handling
    local tmp_body tmp_headers
    tmp_body="$(mktemp "${TMPDIR:-/tmp}/gh-body.XXXXXX")" || return 2
    tmp_headers="$(mktemp "${TMPDIR:-/tmp}/gh-headers.XXXXXX")" || { rm -f "$tmp_body"; return 2; }

    # Cleanup on exit
    # shellcheck disable=SC2064
    trap "rm -f '$tmp_body' '$tmp_headers'" RETURN

    while (( attempt < max_attempts )); do
        attempt=$((attempt + 1))

        # Fetch with headers dumped to file
        local http_code
        http_code=$(curl -sS -w '%{http_code}' \
            "${curl_base_args[@]}" \
            "${auth_header[@]}" \
            -D "$tmp_headers" \
            -o "$tmp_body" \
            "$url" 2>/dev/null) || http_code="000"

        # Success
        if [[ "$http_code" == "200" ]]; then
            if [[ -n "$output_file" ]]; then
                mv "$tmp_body" "$output_file"
            else
                cat "$tmp_body"
            fi
            return 0
        fi

        # Parse rate limit headers.
        # Note: Use tail -1 to get headers from the final response in case of redirects.
        local rate_remaining="" rate_reset=""
        if [[ -r "$tmp_headers" ]]; then
            rate_remaining=$(grep -i "^x-ratelimit-remaining:" "$tmp_headers" 2>/dev/null | tail -n 1 | cut -d: -f2- | tr -d ' \r\n')
            rate_reset=$(grep -i "^x-ratelimit-reset:" "$tmp_headers" 2>/dev/null | tail -n 1 | cut -d: -f2- | tr -d ' \r\n')
        fi

        # Check if this is a rate limit error
        local body
        body=$(cat "$tmp_body" 2>/dev/null || echo "")

        if _is_rate_limited "$http_code" "$body" "$rate_remaining"; then
            # Calculate wait time
            local wait_time
            if [[ -n "$rate_reset" ]]; then
                wait_time=$(_get_reset_wait_time "$rate_reset")
            else
                wait_time="$delay"
            fi

            # Don't wait on last attempt
            if (( attempt >= max_attempts )); then
                break
            fi

            _show_rate_limit_wait "$wait_time" "$attempt" "$max_attempts"
            sleep "$wait_time"

            # Exponential backoff for next iteration (capped)
            delay=$((delay * GITHUB_BACKOFF_MULTIPLIER))
            if (( delay > GITHUB_BACKOFF_MAX )); then
                delay="$GITHUB_BACKOFF_MAX"
            fi

            continue
        fi

        # Non-rate-limit error - don't retry
        local err_msg="GitHub fetch failed: HTTP $http_code"
        if declare -f log_error &>/dev/null; then
            log_error "$err_msg for $description"
        else
            echo -e "\033[0;31m$err_msg\033[0m" >&2
        fi
        return 2
    done

    # Max retries exhausted
    local err_msg="GitHub rate limit: max retries ($max_attempts) exhausted"
    if declare -f log_error &>/dev/null; then
        log_error "$err_msg for $description"
    else
        echo -e "\033[0;31m$err_msg\033[0m" >&2
    fi
    return 1
}

# ============================================================
# GitHub API Convenience Functions
# ============================================================

# Fetch GitHub API endpoint with rate limit handling
# Arguments:
#   $1 - API path (e.g., "/repos/owner/repo/releases/latest")
#   $2 - Output file (optional)
# Returns: Same as github_fetch_with_backoff
github_api_fetch() {
    local path="$1"
    local output="${2:-}"

    # Ensure path starts with /
    [[ "$path" != /* ]] && path="/$path"

    github_fetch_with_backoff "https://api.github.com${path}" "$output" "GitHub API: $path"
}

# Get latest release version for a repo
# Arguments:
#   $1 - Repository (e.g., "owner/repo")
# Returns: Version tag (e.g., "v1.2.3") on stdout, or empty if failed
github_get_latest_release() {
    local repo="$1"
    local tmp_response
    tmp_response="$(mktemp "${TMPDIR:-/tmp}/gh-release.XXXXXX")" || return 1

    # shellcheck disable=SC2064
    trap "rm -f '$tmp_response'" RETURN

    if github_api_fetch "/repos/$repo/releases/latest" "$tmp_response"; then
        # Use jq for robust parsing if available, fall back to grep/sed
        if command -v jq &>/dev/null; then
            jq -r '.tag_name // empty' "$tmp_response"
        else
            grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' "$tmp_response" \
                | head -1 \
                | sed 's/.*"\([^"]*\)"$/\1/'
        fi
    fi
}

# Download release asset with rate limit handling
# Arguments:
#   $1 - Full URL to asset
#   $2 - Output file path
#   $3 - Description (optional)
# Returns: Same as github_fetch_with_backoff
github_download_release_asset() {
    local url="$1"
    local output="$2"
    local description="${3:-release asset}"

    # Ensure parent directory exists
    mkdir -p "$(dirname "$output")"

    github_fetch_with_backoff "$url" "$output" "$description"
}

# ============================================================
# Integration with security.sh
# ============================================================

# Fetch installer script from GitHub with rate limit handling
# This wraps github_fetch_with_backoff for use with fetch_with_checksum
# Arguments:
#   $1 - URL
#   $2 - Output file
#   $3 - Name for logging
# Returns: 0 on success, non-zero on failure
github_download_installer() {
    local url="$1"
    local output="$2"
    local name="${3:-installer}"

    # Only use backoff for GitHub URLs
    if [[ "$url" == *"github.com"* || "$url" == *"githubusercontent.com"* ]]; then
        github_fetch_with_backoff "$url" "$output" "$name"
    else
        # Fall back to regular download for non-GitHub URLs
        if declare -f acfs_download_to_file &>/dev/null; then
            acfs_download_to_file "$url" "$output" "$name"
        else
            curl --connect-timeout 30 --max-time 300 -fsSL "$url" -o "$output"
        fi
    fi
}

# ============================================================
# CLI Interface
# ============================================================

_github_api_usage() {
    cat << 'EOF'
github_api.sh - GitHub API helpers with rate limit backoff

Usage:
  github_api.sh [command] [options]

Commands:
  fetch URL [OUTPUT]       Fetch URL with rate limit backoff
  api PATH [OUTPUT]        Fetch from GitHub API with backoff
  latest-release REPO      Get latest release version for repo
  --help                   Show this help

Examples:
  ./github_api.sh fetch https://raw.githubusercontent.com/user/repo/main/install.sh
  ./github_api.sh api /repos/Dicklesworthstone/beads_rust/releases/latest
  ./github_api.sh latest-release Dicklesworthstone/beads_rust

Environment:
  GITHUB_TOKEN       Authentication token for higher rate limits
  GH_TOKEN           Alternative token (gh CLI compatible)
EOF
}

_github_api_main() {
    case "${1:-}" in
        fetch)
            shift
            if [[ -z "${1:-}" ]]; then
                echo "Usage: github_api.sh fetch URL [OUTPUT]" >&2
                exit 1
            fi
            github_fetch_with_backoff "$@"
            ;;
        api)
            shift
            if [[ -z "${1:-}" ]]; then
                echo "Usage: github_api.sh api PATH [OUTPUT]" >&2
                exit 1
            fi
            github_api_fetch "$@"
            ;;
        latest-release)
            shift
            if [[ -z "${1:-}" ]]; then
                echo "Usage: github_api.sh latest-release REPO" >&2
                exit 1
            fi
            github_get_latest_release "$1"
            ;;
        --help|-h)
            _github_api_usage
            ;;
        "")
            _github_api_usage
            ;;
        *)
            echo "Unknown command: $1" >&2
            _github_api_usage >&2
            exit 1
            ;;
    esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -euo pipefail
    _github_api_main "$@"
fi
