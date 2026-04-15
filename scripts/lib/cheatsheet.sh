#!/usr/bin/env bash
# ============================================================
# ACFS Cheatsheet - discover installed aliases/commands
# Source of truth: ~/.acfs/zsh/acfs.zshrc
# ============================================================

set -euo pipefail

cheatsheet_sanitize_abs_nonroot_path() {
  local path_value="${1:-}"

  [[ -n "$path_value" ]] || return 1
  path_value="${path_value%/}"
  [[ -n "$path_value" ]] || return 1
  [[ "$path_value" == /* ]] || return 1
  [[ "$path_value" != "/" ]] || return 1
  printf '%s\n' "$path_value"
}

cheatsheet_resolve_current_home() {
  local current_user=""
  local home_candidate=""
  local passwd_entry=""

  home_candidate="$(cheatsheet_sanitize_abs_nonroot_path "${HOME:-}" 2>/dev/null || true)"
  if [[ -n "$home_candidate" ]]; then
    printf '%s\n' "$home_candidate"
    return 0
  fi

  current_user="$(id -un 2>/dev/null || whoami 2>/dev/null || true)"
  if [[ "$current_user" == "root" ]]; then
    printf '/root\n'
    return 0
  fi

  if [[ -n "$current_user" ]] && command -v getent &>/dev/null; then
    passwd_entry="$(getent passwd "$current_user" 2>/dev/null || true)"
    if [[ -n "$passwd_entry" ]]; then
      home_candidate="$(cheatsheet_sanitize_abs_nonroot_path "$(printf '%s\n' "$passwd_entry" | cut -d: -f6)" 2>/dev/null || true)"
      if [[ -n "$home_candidate" ]]; then
        printf '%s\n' "$home_candidate"
        return 0
      fi
    fi
  fi

  if [[ "$current_user" =~ ^[a-z_][a-z0-9._-]*$ ]]; then
    printf '/home/%s\n' "$current_user"
    return 0
  fi

  return 1
}

_CHEATSHEET_CURRENT_HOME="$(cheatsheet_resolve_current_home 2>/dev/null || true)"
if [[ -n "$_CHEATSHEET_CURRENT_HOME" ]]; then
  HOME="$_CHEATSHEET_CURRENT_HOME"
  export HOME
fi

_CHEATSHEET_EXPLICIT_ACFS_HOME="$(cheatsheet_sanitize_abs_nonroot_path "${ACFS_HOME:-}" 2>/dev/null || true)"
_CHEATSHEET_DEFAULT_ACFS_HOME=""
[[ -n "$_CHEATSHEET_CURRENT_HOME" ]] && _CHEATSHEET_DEFAULT_ACFS_HOME="${_CHEATSHEET_CURRENT_HOME}/.acfs"
ACFS_HOME="${_CHEATSHEET_EXPLICIT_ACFS_HOME:-$_CHEATSHEET_DEFAULT_ACFS_HOME}"
ACFS_VERSION="${ACFS_VERSION:-0.1.0}"
CHEATSHEET_DELIM=$'\t'
_CHEATSHEET_SYSTEM_STATE_FILE="$(cheatsheet_sanitize_abs_nonroot_path "${ACFS_SYSTEM_STATE_FILE:-/var/lib/acfs/state.json}" 2>/dev/null || true)"
if [[ -z "$_CHEATSHEET_SYSTEM_STATE_FILE" ]]; then
  _CHEATSHEET_SYSTEM_STATE_FILE="/var/lib/acfs/state.json"
fi
_CHEATSHEET_RESOLVED_ACFS_HOME=""
_CHEATSHEET_RESOLVED_TARGET_USER=""
_CHEATSHEET_RESOLVED_TARGET_HOME=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source output formatting library (for TOON support)
if [[ -f "$SCRIPT_DIR/output.sh" ]]; then
    # shellcheck source=output.sh
    source "$SCRIPT_DIR/output.sh"
fi

# Global format options (set by argument parsing)
_CHEATSHEET_OUTPUT_FORMAT=""
_CHEATSHEET_SHOW_STATS=false

if [[ -f "$SCRIPT_DIR/../../VERSION" ]]; then
  ACFS_VERSION="$(cat "$SCRIPT_DIR/../../VERSION" 2>/dev/null || echo "$ACFS_VERSION")"
elif [[ -f "$ACFS_HOME/VERSION" ]]; then
  ACFS_VERSION="$(cat "$ACFS_HOME/VERSION" 2>/dev/null || echo "$ACFS_VERSION")"
fi

HAS_GUM=false
command -v gum &>/dev/null && HAS_GUM=true

print_help() {
  cat <<'EOF'
ACFS Cheatsheet (aliases + quick commands)

Usage:
  acfs cheatsheet [query]
  acfs cheatsheet --category <name>
  acfs cheatsheet --search <pattern>
  acfs cheatsheet --json
  acfs cheatsheet --format <json|toon>
  acfs cheatsheet --stats
  acfs cheatsheet --zshrc <path>

Options:
  --json           Output as JSON
  --format <fmt>   Output format: json or toon (env: ACFS_OUTPUT_FORMAT, TOON_DEFAULT_FORMAT)
  --toon, -t       Shorthand for --format toon
  --stats          Show token savings statistics (JSON vs TOON bytes)

Examples:
  acfs cheatsheet
  acfs cheatsheet git
  acfs cheatsheet "push"
  acfs cheatsheet --category Agents
  acfs cheatsheet --search docker
  acfs cheatsheet --format toon --stats
EOF
}

cheatsheet_home_for_user() {
  local user="$1"
  local passwd_entry=""
  local home_candidate=""

  [[ -n "$user" ]] || return 1

  if command -v getent &>/dev/null; then
    passwd_entry=$(getent passwd "$user" 2>/dev/null || true)
    if [[ -n "$passwd_entry" ]]; then
      home_candidate="$(cheatsheet_sanitize_abs_nonroot_path "$(printf '%s\n' "$passwd_entry" | cut -d: -f6)" 2>/dev/null || true)"
      if [[ -n "$home_candidate" ]]; then
        printf '%s\n' "$home_candidate"
        return 0
      fi
    fi
  fi

  if [[ "$user" == "root" ]]; then
    echo "/root"
    return 0
  fi

  if [[ "$user" =~ ^[a-z_][a-z0-9._-]*$ ]]; then
    echo "/home/$user"
    return 0
  fi

  return 1
}

cheatsheet_read_state_string() {
  local state_file="$1"
  local key="$2"
  local value=""

  [[ -f "$state_file" ]] || return 1

  if command -v jq &>/dev/null; then
    value=$(jq -r --arg key "$key" '.[$key] // empty' "$state_file" 2>/dev/null || true)
  else
    value=$(sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" "$state_file" 2>/dev/null | head -n 1)
  fi

  [[ -n "$value" ]] && [[ "$value" != "null" ]] || return 1
  printf '%s\n' "$value"
}

cheatsheet_read_target_home_from_state() {
  local state_file="$1"
  local target_home=""

  target_home="$(cheatsheet_read_state_string "$state_file" "target_home" 2>/dev/null || true)"
  [[ -n "$target_home" ]] || return 1
  [[ "$target_home" == /* ]] || return 1
  [[ "$target_home" != "/" ]] || return 1
  printf '%s\n' "${target_home%/}"
}

cheatsheet_candidate_has_acfs_data() {
  local candidate="$1"
  [[ -n "$candidate" ]] || return 1
  [[ -f "$candidate/state.json" || -f "$candidate/VERSION" || -f "$candidate/zsh/acfs.zshrc" ]]
}

cheatsheet_script_acfs_home() {
  local candidate=""
  candidate=$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd) || return 1
  [[ "$(basename "$candidate")" == ".acfs" ]] || return 1
  printf '%s\n' "$candidate"
}

cheatsheet_resolve_acfs_home() {
  if [[ -n "$_CHEATSHEET_RESOLVED_ACFS_HOME" ]]; then
    printf '%s\n' "$_CHEATSHEET_RESOLVED_ACFS_HOME"
    return 0
  fi

  local candidate=""
  local target_home=""
  local target_user=""

  if [[ -n "$_CHEATSHEET_EXPLICIT_ACFS_HOME" ]]; then
    _CHEATSHEET_RESOLVED_ACFS_HOME="$_CHEATSHEET_EXPLICIT_ACFS_HOME"
    printf '%s\n' "$_CHEATSHEET_RESOLVED_ACFS_HOME"
    return 0
  fi

  candidate=$(cheatsheet_script_acfs_home 2>/dev/null || true)
  if cheatsheet_candidate_has_acfs_data "$candidate"; then
    _CHEATSHEET_RESOLVED_ACFS_HOME="$candidate"
    printf '%s\n' "$_CHEATSHEET_RESOLVED_ACFS_HOME"
    return 0
  fi

  if [[ -n "${SUDO_USER:-}" ]]; then
    target_home=$(cheatsheet_home_for_user "$SUDO_USER" 2>/dev/null || true)
    candidate="${target_home}/.acfs"
    if [[ -n "$target_home" ]] && cheatsheet_candidate_has_acfs_data "$candidate"; then
      _CHEATSHEET_RESOLVED_ACFS_HOME="$candidate"
      printf '%s\n' "$_CHEATSHEET_RESOLVED_ACFS_HOME"
      return 0
    fi
  fi

  target_home=$(cheatsheet_read_target_home_from_state "$_CHEATSHEET_SYSTEM_STATE_FILE" 2>/dev/null || true)
  candidate="${target_home}/.acfs"
  if [[ -n "$target_home" ]] && cheatsheet_candidate_has_acfs_data "$candidate"; then
    _CHEATSHEET_RESOLVED_ACFS_HOME="$candidate"
    printf '%s\n' "$_CHEATSHEET_RESOLVED_ACFS_HOME"
    return 0
  fi

  target_user=$(cheatsheet_read_state_string "$_CHEATSHEET_SYSTEM_STATE_FILE" "target_user" 2>/dev/null || true)
  if [[ -n "$target_user" ]]; then
    if [[ -z "$target_home" ]]; then
      target_home=$(cheatsheet_home_for_user "$target_user" 2>/dev/null || true)
    fi
    candidate="${target_home}/.acfs"
    if [[ -n "$target_home" ]] && cheatsheet_candidate_has_acfs_data "$candidate"; then
      _CHEATSHEET_RESOLVED_ACFS_HOME="$candidate"
      printf '%s\n' "$_CHEATSHEET_RESOLVED_ACFS_HOME"
      return 0
    fi
  fi

  if [[ -n "$ACFS_HOME" ]] && cheatsheet_candidate_has_acfs_data "$ACFS_HOME"; then
    _CHEATSHEET_RESOLVED_ACFS_HOME="$ACFS_HOME"
    printf '%s\n' "$_CHEATSHEET_RESOLVED_ACFS_HOME"
    return 0
  fi

  _CHEATSHEET_RESOLVED_ACFS_HOME="$ACFS_HOME"
  printf '%s\n' "$_CHEATSHEET_RESOLVED_ACFS_HOME"
}

cheatsheet_resolve_state_file() {
  local candidate=""

  if [[ -n "$ACFS_HOME" ]]; then
    candidate="${ACFS_HOME}/state.json"
  fi

  if [[ -n "$candidate" ]] && [[ -f "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  if [[ -f "$_CHEATSHEET_SYSTEM_STATE_FILE" ]]; then
    printf '%s\n' "$_CHEATSHEET_SYSTEM_STATE_FILE"
    return 0
  fi

  printf '%s\n' "$candidate"
}

cheatsheet_prepend_user_paths() {
  local base_home="$1"
  local dir=""

  [[ -n "$base_home" ]] || return 0

  for dir in \
    "$base_home/.local/bin" \
    "$base_home/.bun/bin" \
    "$base_home/.cargo/bin" \
    "$base_home/go/bin" \
    "$base_home/.atuin/bin"; do
    case ":$PATH:" in
      *":$dir:"*) ;;
      *) export PATH="$dir:$PATH" ;;
    esac
  done
}

cheatsheet_prepare_context() {
  local state_file=""

  ACFS_HOME="$(cheatsheet_resolve_acfs_home)"
  state_file="$(cheatsheet_resolve_state_file)"

  if [[ -z "$_CHEATSHEET_RESOLVED_TARGET_USER" ]]; then
    _CHEATSHEET_RESOLVED_TARGET_USER="$(cheatsheet_read_state_string "$state_file" "target_user" 2>/dev/null || \
      cheatsheet_read_state_string "$_CHEATSHEET_SYSTEM_STATE_FILE" "target_user" 2>/dev/null || true)"
  fi

  if [[ -z "$_CHEATSHEET_RESOLVED_TARGET_HOME" ]]; then
    _CHEATSHEET_RESOLVED_TARGET_HOME="$(cheatsheet_read_target_home_from_state "$state_file" 2>/dev/null || \
      cheatsheet_read_target_home_from_state "$_CHEATSHEET_SYSTEM_STATE_FILE" 2>/dev/null || true)"
    if [[ -z "$_CHEATSHEET_RESOLVED_TARGET_HOME" ]] && [[ -n "$_CHEATSHEET_RESOLVED_TARGET_USER" ]]; then
      _CHEATSHEET_RESOLVED_TARGET_HOME="$(cheatsheet_home_for_user "$_CHEATSHEET_RESOLVED_TARGET_USER" 2>/dev/null || true)"
    fi
    if [[ -z "$_CHEATSHEET_RESOLVED_TARGET_HOME" ]] && [[ "$ACFS_HOME" == */.acfs ]]; then
      _CHEATSHEET_RESOLVED_TARGET_HOME="${ACFS_HOME%/.acfs}"
    fi
  fi

  cheatsheet_prepend_user_paths "$_CHEATSHEET_CURRENT_HOME"
  if [[ -n "$_CHEATSHEET_RESOLVED_TARGET_HOME" ]] && [[ "$_CHEATSHEET_RESOLVED_TARGET_HOME" != "$_CHEATSHEET_CURRENT_HOME" ]]; then
    cheatsheet_prepend_user_paths "$_CHEATSHEET_RESOLVED_TARGET_HOME"
  fi
}

json_escape() {
  local s="${1:-}"
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  s=${s//$'\t'/\\t}
  printf '%s' "$s"
}

normalize_category() {
  local raw="${1:-}"
  raw="${raw%% (*}"
  raw="${raw#--- }"
  raw="${raw% ---}"
  raw="${raw//aliases/}"
  raw="${raw//alias/}"
  raw="${raw//  / }"
  raw="${raw#"${raw%%[![:space:]]*}"}"
  raw="${raw%"${raw##*[![:space:]]}"}"

  case "${raw,,}" in
    *agent*) echo "Agents" ;;
    *git*) echo "Git" ;;
    *docker*) echo "Docker" ;;
    *directory*) echo "Directories" ;;
    bun*) echo "Bun" ;;
    *ubuntu*|*debian*|*convenience*) echo "System" ;;
    *modern*cli*) echo "Modern CLI" ;;
    *) [[ -n "$raw" ]] && echo "$raw" || echo "Misc" ;;
  esac
}

infer_category() {
  local name="${1:-}"
  local cmd="${2:-}"
  case "$name" in
    cc|cod|gmi|am) echo "Agents" ;;
    br|bl|bt) echo "Bun" ;;
    dev|proj|dots|p) echo "Directories" ;;
    g*) [[ "$cmd" == git* ]] && { echo "Git"; return 0; } ;;
    d*) [[ "$cmd" == docker* ]] && { echo "Docker"; return 0; } ;;
  esac
  echo "Misc"
}

cheatsheet_parse_zshrc() {
  local zshrc="${1:-$ACFS_HOME/zsh/acfs.zshrc}"
  [[ -f "$zshrc" ]] || return 1

  local current_category="Misc"
  local line rest
  local overall_active=true
  local -a if_parent_active=()
  local -a if_branch_taken=()

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Section markers
    if [[ "$line" =~ ^#[[:space:]]*---[[:space:]]*(.+)[[:space:]]*---[[:space:]]*$ ]]; then
      current_category="$(normalize_category "${BASH_REMATCH[1]}")"
      continue
    fi
    if [[ "$line" =~ ^#[[:space:]]*===[[:space:]]*(.+)[[:space:]]*===[[:space:]]*$ ]]; then
      current_category="$(normalize_category "${BASH_REMATCH[1]}")"
      continue
    fi

    # Track simple conditional blocks used in acfs.zshrc (command -v ...; then / elif / else / fi).
    # This keeps the cheatsheet aligned with what will actually be active on the current system.
    if [[ "$line" =~ ^[[:space:]]*if[[:space:]]+command[[:space:]]+-v[[:space:]]+([[:alnum:]_.+-]+) ]]; then
      local tool="${BASH_REMATCH[1]}"
      local cond=false
      command -v "$tool" &>/dev/null && cond=true

      if_parent_active+=("$overall_active")
      if_branch_taken+=("$cond")

      if [[ "$overall_active" == "true" && "$cond" == "true" ]]; then
        overall_active=true
      else
        overall_active=false
      fi
      continue
    fi

    if [[ "${#if_parent_active[@]}" -gt 0 && "$line" =~ ^[[:space:]]*elif[[:space:]]+command[[:space:]]+-v[[:space:]]+([[:alnum:]_.+-]+) ]]; then
      local tool="${BASH_REMATCH[1]}"
      local idx=$(( ${#if_parent_active[@]} - 1 ))
      local parent_active="${if_parent_active[idx]}"
      local already_taken="${if_branch_taken[idx]}"

      if [[ "$already_taken" == "true" ]]; then
        overall_active=false
        continue
      fi

      local cond=false
      command -v "$tool" &>/dev/null && cond=true
      if_branch_taken[idx]="$cond"

      if [[ "$parent_active" == "true" && "$cond" == "true" ]]; then
        overall_active=true
      else
        overall_active=false
      fi
      continue
    fi

    if [[ "${#if_parent_active[@]}" -gt 0 && "$line" =~ ^[[:space:]]*else([[:space:]]*#.*)?$ ]]; then
      local idx=$(( ${#if_parent_active[@]} - 1 ))
      local parent_active="${if_parent_active[idx]}"
      local already_taken="${if_branch_taken[idx]}"

      if [[ "$parent_active" == "true" && "$already_taken" != "true" ]]; then
        overall_active=true
      else
        overall_active=false
      fi
      if_branch_taken[idx]=true
      continue
    fi

    if [[ "${#if_parent_active[@]}" -gt 0 && "$line" =~ ^[[:space:]]*fi([[:space:]]*#.*)?$ ]]; then
      local idx=$(( ${#if_parent_active[@]} - 1 ))
      overall_active="${if_parent_active[idx]}"
      unset 'if_parent_active[idx]'
      unset 'if_branch_taken[idx]'
      continue
    fi

    local line_active="$overall_active"
    # Handle one-line conditionals: `command -v tool ... && alias name='cmd'`
    # shellcheck disable=SC2250  # Regex pattern stored in variable for portability
    local oneliner_pattern='^[[:space:]]*command[[:space:]]+-v[[:space:]]+([[:alnum:]_.+-]+)[^#]*&&[[:space:]]*alias[[:space:]]'
    if [[ "$line" =~ $oneliner_pattern ]]; then
      local tool="${BASH_REMATCH[1]}"
      if ! command -v "$tool" &>/dev/null; then
        line_active=false
      fi
    fi
    [[ "$line_active" == "true" ]] || continue

    # Pre-process line to protect escaped quotes so basic parsing works.
    # Zsh/Bash aliases often use '\'' to embed single quotes inside single-quoted strings.
    # We replace this sequence with a placeholder to avoid splitting on the inner quotes.
    local safe_line
    safe_line="${line//\'\\\'\'/__ACFS_SQ__}"
    # Protect \" inside double quotes
    safe_line="${safe_line//\\\"/__ACFS_DQ__}"

    rest="$safe_line"
    while [[ "$rest" == *"alias "* ]]; do
      # Move to the next alias segment.
      rest="${rest#*alias }"

      local name="${rest%%=*}"
      name="${name%%[[:space:]]*}"
      [[ -n "$name" ]] || break

      local value="${rest#*=}"
      [[ -n "$value" ]] || break

      local cmd="" remainder=""
      if [[ "$value" == \'* ]]; then
        value="${value#\'}"
        if [[ "$value" == *"'"* ]]; then
          cmd="${value%%\'*}"
          remainder="${value#*\'}"
        else
          cmd="$value"
          remainder=""
        fi
      elif [[ "$value" == \"* ]]; then
        value="${value#\"}"
        if [[ "$value" == *"\""* ]]; then
          cmd="${value%%\"*}"
          remainder="${value#*\"}"
        else
          cmd="$value"
          remainder=""
        fi
      else
        cmd="${value%%[[:space:]]*}"
        remainder="${value#"$cmd"}"
      fi

      # Restore placeholders
      cmd="${cmd//__ACFS_SQ__/\'}"
      cmd="${cmd//__ACFS_DQ__/\"}"

      local category="$current_category"
      [[ -z "$category" || "$category" == "Misc" ]] && category="$(infer_category "$name" "$cmd")"

      printf '%s%s%s%s%s%s%s\n' "$category" "$CHEATSHEET_DELIM" "$name" "$CHEATSHEET_DELIM" "$cmd" "$CHEATSHEET_DELIM" "alias"

      # Continue searching for more aliases in the same line.
      rest="$remainder"
    done
  done < "$zshrc"
}

cheatsheet_collect_entries() {
  local zshrc="${1:-$ACFS_HOME/zsh/acfs.zshrc}"
  local -a entries=()
  local line

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    entries+=("$line")
  done < <(cheatsheet_parse_zshrc "$zshrc" || true)

  # De-dupe by name keeping the last definition (matches shell alias overriding behavior).
  local -A seen=()
  local -a dedup_rev=()
  local i
  for ((i=${#entries[@]}-1; i>=0; i--)); do
    IFS="$CHEATSHEET_DELIM" read -r _cat name _cmd _kind <<<"${entries[$i]}"
    if [[ -z "$name" || -n "${seen[$name]:-}" ]]; then
      continue
    fi
    seen[$name]=1
    dedup_rev+=("${entries[$i]}")
  done

  for ((i=${#dedup_rev[@]}-1; i>=0; i--)); do
    echo "${dedup_rev[$i]}"
  done
}

cheatsheet_filter_entries() {
  local category_filter="${1:-}"
  local search_filter="${2:-}"
  local zshrc="${3:-$ACFS_HOME/zsh/acfs.zshrc}"

  local line cat name cmd kind
  while IFS= read -r line; do
    IFS="$CHEATSHEET_DELIM" read -r cat name cmd kind <<<"$line"

    if [[ -n "$category_filter" ]]; then
      if [[ "${cat,,}" != "${category_filter,,}" ]]; then
        continue
      fi
    fi

    if [[ -n "$search_filter" ]]; then
      local hay="${cat} ${name} ${cmd}"
      if [[ "${hay,,}" != *"${search_filter,,}"* ]]; then
        continue
      fi
    fi

    echo "$line"
  done < <(cheatsheet_collect_entries "$zshrc")
}

cheatsheet_render_plain() {
  local category_filter="${1:-}"
  local search_filter="${2:-}"
  local zshrc="${3:-$ACFS_HOME/zsh/acfs.zshrc}"

  echo "ACFS Cheatsheet v$ACFS_VERSION"
  echo "Source: $zshrc"
  echo ""

  local current=""
  local cat name cmd kind line
  while IFS= read -r line; do
    IFS="$CHEATSHEET_DELIM" read -r cat name cmd kind <<<"$line"
    if [[ "$cat" != "$current" ]]; then
      current="$cat"
      echo "$current"
    fi
    printf '  %-8s %s\n' "$name" "$cmd"
  done < <(cheatsheet_filter_entries "$category_filter" "$search_filter" "$zshrc")
}

cheatsheet_render_gum() {
  local category_filter="${1:-}"
  local search_filter="${2:-}"
  local zshrc="${3:-$ACFS_HOME/zsh/acfs.zshrc}"

  gum style --bold --foreground "#89b4fa" "ACFS Cheatsheet v$ACFS_VERSION"
  gum style --foreground "#6c7086" "Source: $zshrc"
  echo ""

  local current=""
  local cat name cmd kind line
  while IFS= read -r line; do
    IFS="$CHEATSHEET_DELIM" read -r cat name cmd kind <<<"$line"
    if [[ "$cat" != "$current" ]]; then
      current="$cat"
      echo ""
      gum style --bold --foreground "#cba6f7" "$current"
    fi
    printf '  %-8s %s\n' "$name" "$cmd"
  done < <(cheatsheet_filter_entries "$category_filter" "$search_filter" "$zshrc")
}

cheatsheet_render_json() {
  local category_filter="${1:-}"
  local search_filter="${2:-}"
  local zshrc="${3:-$ACFS_HOME/zsh/acfs.zshrc}"

  local json_output
  json_output=$(
    local first=true
    printf '{'
    printf '"version":"%s",' "$(json_escape "$ACFS_VERSION")"
    printf '"source":"%s",' "$(json_escape "$zshrc")"
    printf '"entries":['

    local cat name cmd kind line
    while IFS= read -r line; do
      IFS="$CHEATSHEET_DELIM" read -r cat name cmd kind <<<"$line"
      if [[ "$first" == "true" ]]; then
        first=false
      else
        printf ','
      fi
      printf '{'
      printf '"category":"%s",' "$(json_escape "$cat")"
      printf '"name":"%s",' "$(json_escape "$name")"
      printf '"command":"%s",' "$(json_escape "$cmd")"
      printf '"kind":"%s"' "$(json_escape "$kind")"
      printf '}'
    done < <(cheatsheet_filter_entries "$category_filter" "$search_filter" "$zshrc")

    printf ']'
    printf '}'
  )

  # Use output formatting library if available
  if type -t acfs_format_output &>/dev/null; then
    local resolved_format
    resolved_format=$(acfs_resolve_format "$_CHEATSHEET_OUTPUT_FORMAT")
    acfs_format_output "$json_output" "$resolved_format" "$_CHEATSHEET_SHOW_STATS"
  else
    # Fallback: direct JSON output
    printf '%s\n' "$json_output"
  fi
}

main() {
  local zshrc=""
  local category_filter=""
  local search_filter=""
  local json_mode=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        print_help
        return 0
        ;;
      --json)
        json_mode=true
        shift
        ;;
      --format|-f)
        if [[ -z "${2:-}" || "$2" == -* ]]; then
          echo "Error: --format requires a value (json or toon)" >&2
          return 1
        fi
        _CHEATSHEET_OUTPUT_FORMAT="$2"
        json_mode=true
        shift 2
        ;;
      --format=*)
        _CHEATSHEET_OUTPUT_FORMAT="${1#*=}"
        if [[ -z "$_CHEATSHEET_OUTPUT_FORMAT" ]]; then
          echo "Error: --format requires a value (json or toon)" >&2
          return 1
        fi
        json_mode=true
        shift
        ;;
      --toon|-t)
        _CHEATSHEET_OUTPUT_FORMAT="toon"
        json_mode=true
        shift
        ;;
      --stats)
        _CHEATSHEET_SHOW_STATS=true
        shift
        ;;
      --category)
        if [[ -z "${2:-}" ]]; then
          echo "Error: --category requires a value" >&2
          return 1
        fi
        category_filter="$2"
        shift 2
        ;;
      --search)
        if [[ -z "${2:-}" ]]; then
          echo "Error: --search requires a value" >&2
          return 1
        fi
        search_filter="$2"
        shift 2
        ;;
      --zshrc)
        if [[ -z "${2:-}" ]]; then
          echo "Error: --zshrc requires a path" >&2
          return 1
        fi
        zshrc="$2"
        shift 2
        ;;
      *)
        # Treat positional arg as either category match or a search term.
        local q="$1"
        shift
        case "${q,,}" in
          agents|git|docker|directories|system|bun|modern\ cli)
            category_filter="$q"
            ;;
          *)
            search_filter="$q"
            ;;
        esac
        ;;
    esac
  done

  cheatsheet_prepare_context

  if [[ -z "$zshrc" ]]; then
    zshrc="$ACFS_HOME/zsh/acfs.zshrc"
  fi

  if [[ ! -f "$zshrc" ]]; then
    echo "Error: zshrc not found: $zshrc" >&2
    echo "Hint: re-run the ACFS installer, or pass --zshrc <path> / set ACFS_HOME." >&2
    return 1
  fi

  if [[ "$json_mode" == "true" ]]; then
    cheatsheet_render_json "$category_filter" "$search_filter" "$zshrc"
  elif [[ "$HAS_GUM" == "true" ]]; then
    cheatsheet_render_gum "$category_filter" "$search_filter" "$zshrc"
  else
    cheatsheet_render_plain "$category_filter" "$search_filter" "$zshrc"
  fi
}

main "$@"
