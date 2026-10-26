#!/bin/bash
# Compares the CURRENT macOS defaults with macos-defaults.tsv and reports
# drift (e.g. changes made via System Settings). It never touches the system.
#
# By default it is read-only, so the scheduled run never dirties the source
# repo (which would block `chezmoi update`). Pass --write to accept the live
# values into macos-defaults.tsv, then review and commit:
#
#   bin/sync-macos-defaults.sh --write
#   chezmoi git diff -- macos-defaults.tsv
#   chezmoi git add -A && chezmoi git -- commit -m "..."
#
# To revert the system instead, see the README (force re-apply of the
# run_onchange script).
#
# Runs automatically (without --write) via a LaunchAgent at login and every
# 4 hours; logs go to ~/.local/share/chezmoi-logs/sync-macos-defaults.log.
#
# Usage: bin/sync-macos-defaults.sh [--write]

set -eufo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULTS_FILE="${SCRIPT_DIR}/macos-defaults.tsv"
write=0
[ "${1:-}" = "--write" ] && write=1

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
elif [ "$changed" -eq 1 ]; then
  echo
  echo "==> Run with --write to accept these values into macos-defaults.tsv."
  if command -v osascript >/dev/null 2>&1; then
    osascript -e 'display notification "Run ~/.local/share/chezmoi/bin/sync-macos-defaults.sh to review." with title "macOS defaults drift detected" sound name "Funk"' >/dev/null 2>&1 || true
  fi
else
  echo "==> No drift detected. macos-defaults.tsv already matches the system."
fi
