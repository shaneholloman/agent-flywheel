#!/usr/bin/env bash
# ============================================================
# ACFS Installer - Webhook Notification Library
#
# Provides webhook notification for installation completion,
# useful for fleet management, monitoring, and personal alerts.
#
# Related bead: bd-2zqr
# ============================================================

# Prevent multiple sourcing
if [[ -n "${_ACFS_WEBHOOK_SH_LOADED:-}" ]]; then
    return 0
fi
_ACFS_WEBHOOK_SH_LOADED=1

# ============================================================
# Configuration Sources (priority order)
# ============================================================
# 1. CLI flag: --webhook <url>
# 2. Environment variable: ACFS_WEBHOOK_URL
# 3. Config file: ~/.config/acfs/config.yaml (webhook_url key)

# Global webhook URL - set by parse_webhook_args or read_webhook_config
ACFS_WEBHOOK_URL="${ACFS_WEBHOOK_URL:-}"

webhook_sanitize_abs_nonroot_path() {
    local path_value="${1:-}"

    [[ -n "$path_value" ]] || return 1
    path_value="${path_value%/}"
    [[ -n "$path_value" ]] || return 1
    [[ "$path_value" == /* ]] || return 1
    [[ "$path_value" != "/" ]] || return 1
    printf '%s\n' "$path_value"
}

webhook_resolve_current_home() {
    local current_user=""
    local home_candidate=""
    local passwd_entry=""

    home_candidate="$(webhook_sanitize_abs_nonroot_path "${HOME:-}" 2>/dev/null || true)"
    if [[ -n "$home_candidate" ]]; then
        printf '%s\n' "$home_candidate"
        return 0
    fi

    current_user="$(id -un 2>/dev/null || whoami 2>/dev/null || true)"
    if [[ "$current_user" == "root" ]]; then
        printf '/root\n'
        return 0
    fi

    if [[ -n "$current_user" ]]; then
        passwd_entry="$(getent passwd "$current_user" 2>/dev/null || true)"
        if [[ -n "$passwd_entry" ]]; then
            home_candidate="$(printf '%s\n' "$passwd_entry" | cut -d: -f6)"
            home_candidate="$(webhook_sanitize_abs_nonroot_path "$home_candidate" 2>/dev/null || true)"
            if [[ -n "$home_candidate" ]]; then
                printf '%s\n' "$home_candidate"
                return 0
            fi
        fi

        if [[ "$current_user" =~ ^[a-z_][a-z0-9._-]*$ ]]; then
            printf '/home/%s\n' "$current_user"
            return 0
        fi
    fi

    return 1
}

webhook_runtime_home() {
    local target_home=""

    target_home="$(webhook_sanitize_abs_nonroot_path "${TARGET_HOME:-}" 2>/dev/null || true)"
    if [[ -n "$target_home" ]]; then
        printf '%s\n' "$target_home"
        return 0
    fi

    webhook_resolve_current_home
}

_ACFS_WEBHOOK_RUNTIME_HOME="$(webhook_runtime_home 2>/dev/null || true)"

# ============================================================
# Webhook URL Validation
# ============================================================

# Validate webhook URL - HTTPS only for security
# Usage: webhook_validate_url <url>
# Returns: 0 if valid, 1 if invalid
webhook_validate_url() {
    local url="$1"

    # Empty URL is valid (means no webhook)
    if [[ -z "$url" ]]; then
        return 0
    fi

    # Must start with https://
    if [[ ! "$url" =~ ^https:// ]]; then
        log_warn "Webhook URL rejected: HTTPS required (got: ${url:0:50}...)"
        return 1
    fi

    # Basic URL structure check
    if [[ ! "$url" =~ ^https://[^/]+(/|$) ]]; then
        log_warn "Webhook URL rejected: Invalid URL format"
        return 1
    fi

    return 0
}

# ============================================================
# Configuration Reading
# ============================================================

# Read webhook URL from config file if not already set
# Config file: ~/.config/acfs/config.yaml
# Format: webhook_url: "https://..."
webhook_read_config() {
    # Skip if already set via env or CLI
    if [[ -n "${ACFS_WEBHOOK_URL:-}" ]]; then
        return 0
    fi

    local config_home="${_ACFS_WEBHOOK_RUNTIME_HOME:-}"
    local config_file=""

    if [[ -z "$config_home" ]]; then
        return 0
    fi
    config_file="${config_home}/.config/acfs/config.yaml"

    if [[ ! -f "$config_file" ]]; then
        return 0
    fi

    # Simple YAML parsing for webhook_url key
    # Handles: webhook_url: "https://..." or webhook_url: 'https://...' or webhook_url: https://...
    local url
    url=$(grep -E '^\s*webhook_url\s*:' "$config_file" 2>/dev/null | head -1 | \
          sed -E 's/^\s*webhook_url\s*:\s*//; s/^["'"'"']//; s/["'"'"']$//' | \
          tr -d '[:space:]') || true

    if [[ -n "$url" ]]; then
        if webhook_validate_url "$url"; then
            ACFS_WEBHOOK_URL="$url"
            log_detail "Webhook URL loaded from config file"
        fi
    fi
}

# ============================================================
# Payload Formatting
# ============================================================

# Detect webhook platform and format appropriately
# Usage: webhook_format_payload <status> <json_summary_file>
# Returns: JSON payload on stdout
webhook_format_payload() {
    local status="$1"
    local summary_file="$2"
    local url="${ACFS_WEBHOOK_URL:-}"

    # Read summary data
    local hostname ip duration_seconds tools_installed acfs_version timestamp
    hostname=$(hostname 2>/dev/null || echo "unknown")
    # Use an explicit HTTPS endpoint that returns only the IP body.
    ip=$(curl -s --max-time 2 https://ifconfig.me/ip 2>/dev/null || echo "unknown")

    if [[ -f "$summary_file" ]] && command -v jq &>/dev/null; then
        duration_seconds=$(jq -r '.total_seconds // 0' "$summary_file" 2>/dev/null) || duration_seconds=0
        tools_installed=$(jq -r '.phases | length // 0' "$summary_file" 2>/dev/null) || tools_installed=0
        acfs_version=$(jq -r '.environment.acfs_version // "unknown"' "$summary_file" 2>/dev/null) || acfs_version="unknown"
        timestamp=$(jq -r '.timestamp // empty' "$summary_file" 2>/dev/null) || timestamp=$(date -Iseconds)
    else
        duration_seconds=0
        tools_installed=0
        acfs_version="${ACFS_VERSION:-unknown}"
        timestamp=$(date -Iseconds)
    fi

    # Detect platform and format appropriately
    if [[ "$url" == *"hooks.slack.com"* ]]; then
        # Slack webhook format
        _webhook_format_slack "$status" "$hostname" "$ip" "$duration_seconds" "$tools_installed" "$acfs_version" "$timestamp"
    elif [[ "$url" == *"discord.com/api/webhooks"* ]]; then
        # Discord webhook format
        _webhook_format_discord "$status" "$hostname" "$ip" "$duration_seconds" "$tools_installed" "$acfs_version" "$timestamp"
    else
        # Generic JSON format
        _webhook_format_generic "$status" "$hostname" "$ip" "$duration_seconds" "$tools_installed" "$acfs_version" "$timestamp"
    fi
}

# Generic JSON payload
_webhook_format_generic() {
    local status="$1" hostname="$2" ip="$3" duration="$4" tools="$5" version="$6" timestamp="$7"

    jq -n \
        --arg event "install_${status}" \
        --arg timestamp "$timestamp" \
        --arg hostname "$hostname" \
        --arg ip "$ip" \
        --argjson duration_seconds "$duration" \
        --argjson tools_installed "$tools" \
        --argjson tools_failed 0 \
        --arg version "$version" \
        '{
            event: $event,
            timestamp: $timestamp,
            hostname: $hostname,
            ip: $ip,
            duration_seconds: $duration_seconds,
            tools_installed: $tools_installed,
            tools_failed: $tools_failed,
            version: $version,
            errors: []
        }'
}

# Slack webhook format
_webhook_format_slack() {
    local status="$1" hostname="$2" ip="$3" duration="$4" tools="$5" version="$6" timestamp="$7"

    local emoji color text
    if [[ "$status" == "success" ]]; then
        emoji=":white_check_mark:"
        color="good"
        text="ACFS installation completed successfully!"
    else
        emoji=":x:"
        color="danger"
        text="ACFS installation failed"
    fi

    local duration_human
    if [[ "$duration" -ge 60 ]]; then
        duration_human="$((duration / 60))m $((duration % 60))s"
    else
        duration_human="${duration}s"
    fi

    jq -n \
        --arg text "$emoji $text" \
        --arg color "$color" \
        --arg hostname "$hostname" \
        --arg ip "$ip" \
        --arg duration "$duration_human" \
        --arg tools "$tools" \
        --arg version "$version" \
        '{
            attachments: [{
                color: $color,
                text: $text,
                fields: [
                    {title: "Host", value: $hostname, short: true},
                    {title: "IP", value: $ip, short: true},
                    {title: "Duration", value: $duration, short: true},
                    {title: "Phases", value: $tools, short: true},
                    {title: "Version", value: $version, short: true}
                ],
                footer: "ACFS Installer"
            }]
        }'
}

# Discord webhook format
_webhook_format_discord() {
    local status="$1" hostname="$2" ip="$3" duration="$4" tools="$5" version="$6" timestamp="$7"

    local emoji color title
    if [[ "$status" == "success" ]]; then
        emoji=":white_check_mark:"
        color=5763719  # Green
        title="ACFS Installation Complete"
    else
        emoji=":x:"
        color=15548997  # Red
        title="ACFS Installation Failed"
    fi

    local duration_human
    if [[ "$duration" -ge 60 ]]; then
        duration_human="$((duration / 60))m $((duration % 60))s"
    else
        duration_human="${duration}s"
    fi

    jq -n \
        --arg title "$title" \
        --argjson color "$color" \
        --arg hostname "$hostname" \
        --arg ip "$ip" \
        --arg duration "$duration_human" \
        --arg tools "$tools" \
        --arg version "$version" \
        --arg timestamp "$timestamp" \
        '{
            embeds: [{
                title: $title,
                color: $color,
                fields: [
                    {name: "Host", value: $hostname, inline: true},
                    {name: "IP", value: $ip, inline: true},
                    {name: "Duration", value: $duration, inline: true},
                    {name: "Phases", value: $tools, inline: true},
                    {name: "Version", value: $version, inline: true}
                ],
                footer: {text: "ACFS Installer"},
                timestamp: $timestamp
            }]
        }'
}

# ============================================================
# Webhook Sending
# ============================================================

# Send webhook notification (non-blocking, best-effort)
# Usage: webhook_send <status> [summary_file]
# Returns: 0 always (non-blocking, don't fail install)
webhook_send() {
    local status="${1:-success}"
    local summary_file="${2:-${ACFS_SUMMARY_FILE:-}}"
    local url="${ACFS_WEBHOOK_URL:-}"

    # No webhook configured - silently skip
    if [[ -z "$url" ]]; then
        return 0
    fi

    # Validate URL
    if ! webhook_validate_url "$url"; then
        return 0
    fi

    # Require curl
    if ! command -v curl &>/dev/null; then
        log_warn "Webhook skipped: curl not available"
        return 0
    fi

    # Require jq for payload formatting
    if ! command -v jq &>/dev/null; then
        log_warn "Webhook skipped: jq not available"
        return 0
    fi

    log_detail "Sending webhook notification..."

    # Format payload
    local payload
    payload=$(webhook_format_payload "$status" "$summary_file") || {
        log_warn "Webhook skipped: failed to format payload"
        return 0
    }

    # Send webhook (non-blocking with 5s timeout)
    # Runs in background to not block install completion
    (
        local http_code
        http_code=$(curl -s -o /dev/null -w '%{http_code}' \
            --max-time 5 \
            -X POST \
            -H "Content-Type: application/json" \
            -d "$payload" \
            "$url" 2>/dev/null) || http_code="000"

        if [[ "$http_code" =~ ^2 ]]; then
            # Success - log only if debug mode
            [[ "${ACFS_DEBUG:-}" == "true" ]] && echo "Webhook sent (HTTP $http_code)" >&2
        else
            # Failure - log warning but don't fail
            echo "Webhook failed (HTTP $http_code)" >&2
        fi
    ) &

    # Don't wait for background process
    disown 2>/dev/null || true

    return 0
}

# ============================================================
# Convenience Function
# ============================================================

# Initialize and send webhook (call this from install.sh)
# Usage: webhook_notify <status> [summary_file]
webhook_notify() {
    # Read config if not already set
    webhook_read_config

    # Send notification
    webhook_send "$@"
}
