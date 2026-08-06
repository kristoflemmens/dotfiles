#!/bin/bash
# Pulls the CURRENT macOS defaults values back into macos-defaults.tsv,
# so drift (e.g. changes made via System Settings) shows up as a normal
# git diff in the dotfiles repo, viewable from anywhere with `chezmoi git
# diff`. It does NOT touch the system, and it does NOT commit anything
# automatically -- you decide what to do with the diff:
#
#   chezmoi git diff -- macos-defaults.tsv          # review what changed
#   chezmoi git add -A
#   chezmoi git -- commit -m "..."                  # accept drift as the new desired state
#   chezmoi git checkout -- macos-defaults.tsv && chezmoi apply   # revert the system instead
#
# Runs automatically via a LaunchAgent (see
# Library/LaunchAgents/com.kristoflemmens.dotfiles.sync-macos-defaults.plist),
# so you don't have to remember to run this yourself. When drift is found,
# it sends a macOS notification. Logs go to ~/.local/share/chezmoi-logs/
# for debugging the scheduled runs.
#
# Usage: bin/sync-macos-defaults.sh   (run from anywhere; finds the repo itself)

set -eufo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULTS_FILE="${SCRIPT_DIR}/macos-defaults.tsv"

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

mv "$tmp_file" "$DEFAULTS_FILE"
trap - EXIT

if [ "$changed" -eq 1 ]; then
  echo
  echo "==> macos-defaults.tsv updated to reflect actual system state."
  echo "    Review with: chezmoi git diff -- macos-defaults.tsv"
  if command -v osascript >/dev/null 2>&1; then
    osascript -e 'display notification "Run `chezmoi git diff -- macos-defaults.tsv` to review." with title "macOS defaults drift detected" sound name "Funk"' >/dev/null 2>&1 || true
  fi
else
  echo "==> No drift detected. macos-defaults.tsv already matches the system."
fi
