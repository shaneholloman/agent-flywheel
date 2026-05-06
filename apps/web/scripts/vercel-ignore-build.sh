#!/bin/bash
# Vercel Ignored Build Step
# https://vercel.com/docs/project-configuration/vercel-json#ignorecommand
#
# Exit 0 = SKIP build (no relevant changes)
# Exit 1 = PROCEED with build (relevant changes detected)
#
# This script reduces Vercel credit consumption by skipping builds
# when only non-web files change (e.g., installer scripts, bash libs).

set -euo pipefail

echo "🔍 Checking if web app files changed..."

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT" || exit 1

# Get the commit range (VERCEL_GIT_PREVIOUS_SHA may be empty on first deploy)
PREV_SHA="${VERCEL_GIT_PREVIOUS_SHA:-HEAD~1}"
CURR_SHA="${VERCEL_GIT_COMMIT_SHA:-HEAD}"

echo "   Previous: $PREV_SHA"
echo "   Current:  $CURR_SHA"

# If we can't determine the git diff (shallow clones / missing SHAs), fail open
# and proceed with the build to avoid stale deployments.
CHANGED_FILES="$(git diff --name-only "$PREV_SHA" "$CURR_SHA" 2>/dev/null || true)"
if [[ -z "$CHANGED_FILES" ]]; then
  if ! git rev-parse --verify "$PREV_SHA^{commit}" >/dev/null 2>&1 || \
    ! git rev-parse --verify "$CURR_SHA^{commit}" >/dev/null 2>&1; then
    echo "⚠️  Unable to determine changes (missing commit range); proceeding with build"
    exit 1
  fi
fi

# Paths that should trigger a rebuild. The script always evaluates paths from
# the repository root because Vercel may run ignore commands from apps/web.
TRIGGER_PATHS=(
    "apps/web/"
    "package.json"
    "bun.lock"
    "vercel.json"
    ".vercelignore"
)

path_matches_trigger() {
  local changed_file="$1"
  local trigger="$2"

  if [[ "$trigger" == */ ]]; then
    [[ "$changed_file" == "$trigger"* ]]
  else
    [[ "$changed_file" == "$trigger" ]]
  fi
}

# Check if any trigger paths have changes
matched_trigger=""
if [[ -n "$CHANGED_FILES" ]]; then
  while IFS= read -r changed_file; do
    for trigger in "${TRIGGER_PATHS[@]}"; do
      if path_matches_trigger "$changed_file" "$trigger"; then
        matched_trigger="$trigger"
        break 2
      fi
    done
  done <<< "$CHANGED_FILES"
fi

if [[ -n "$matched_trigger" ]]; then
  echo "✅ Changes detected in: $matched_trigger"
  echo "   → Proceeding with build"
  exit 1  # Build
fi

echo "⏭️  No web app changes detected"
echo "   → Skipping build to save Vercel credits"
echo ""
echo "   Changed files:"
if [[ -n "$CHANGED_FILES" ]]; then
  printf '%s\n' "$CHANGED_FILES" | awk 'NR <= 20'
else
  echo "   (none)"
fi

exit 0  # Skip build
