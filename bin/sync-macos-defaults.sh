#!/bin/bash
# Pulls the CURRENT macOS defaults values back into macos-defaults.tsv, so
# drift (e.g. a change made via System Settings) shows up as a normal git
# diff instead of being lost. It never touches the system and never commits:
#
#   chezmoi git diff -- macos-defaults.tsv            # review
#   chezmoi git add -A && chezmoi git -- commit -m "..."   # accept
#   chezmoi git checkout -- macos-defaults.tsv        # discard (see README to re-apply)
#
# Runs automatically via a LaunchAgent at login and every 4 hours; logs go to
# ~/.local/share/chezmoi-logs/sync-macos-defaults.log.
#
# Usage: bin/sync-macos-defaults.sh [--check]   (--check: report only, don't write)

set -eufo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULTS_FILE="${SCRIPT_DIR}/macos-defaults.tsv"
write=1
[ "${1:-}" = "--check" ] && write=0

if [ ! -f "$DEFAULTS_FILE" ]; then
  echo "Could not find macos-defaults.tsv next to this script (looked in ${SCRIPT_DIR})" >&2
  exit 1
fi

tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

changed=0

while IFS= read -r line; do
  # pass through comments and blank lines untouched
  case "$line" in
    ''|'#'*)
      echo "$line" >> "$tmp_file"
      continue
      ;;
  esac

  IFS='|' read -r flag domain key type value <<< "$line"

  # shellcheck disable=SC2086
  current="$(defaults $flag read "$domain" "$key" 2>/dev/null || true)"

  if [ -z "$current" ]; then
    # key doesn't exist on this system (never set / app not installed) -- leave declared value untouched
    echo "$line" >> "$tmp_file"
    continue
  fi

  case "$type" in
    bool)
      # defaults read returns 0/1 for bools
      case "$current" in
        1) current="true" ;;
        0) current="false" ;;
      esac
      ;;
  esac

  if [ "$current" != "$value" ]; then
    echo "==> drift detected: ${domain} ${key} = '${value}' (declared) -> '${current}' (actual)"
    changed=1
  fi

  echo "${flag}|${domain}|${key}|${type}|${current}" >> "$tmp_file"
done < "$DEFAULTS_FILE"

if [ "$changed" -eq 1 ] && [ "$write" -eq 1 ]; then
  mv "$tmp_file" "$DEFAULTS_FILE"
  trap - EXIT
  echo
  echo "==> macos-defaults.tsv updated to reflect actual system state."
  echo "    Review with: chezmoi git diff -- macos-defaults.tsv"
  if command -v osascript >/dev/null 2>&1; then
    osascript -e 'display notification "Review with: chezmoi git diff -- macos-defaults.tsv" with title "macOS defaults drift detected" sound name "Funk"' >/dev/null 2>&1 || true
  fi
elif [ "$changed" -eq 1 ]; then
  echo
  echo "==> --check: macos-defaults.tsv left unchanged."
else
  echo "==> No drift detected. macos-defaults.tsv already matches the system."
fi
