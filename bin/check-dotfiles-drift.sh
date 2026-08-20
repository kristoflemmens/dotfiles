#!/bin/bash
# Notifies (does not auto-fix) when any chezmoi-managed dotfile has drifted
# from what's declared in the source repo -- e.g. you edited ~/.zshrc
# directly instead of via `chezmoi edit`, or a tool rewrote a config file
# chezmoi manages.
#
# Deliberately notification-only, unlike sync-macos-defaults.sh /
# sync-brewfile.sh: those safely auto-write drift into a dedicated data file
# they own outright. Plain dotfiles here can't be blindly auto-synced the
# same way, because some files might be intentionally managed by a private
# work overlay repo instead of this public repo. Blindly pulling live state
# back into this source with `chezmoi re-add` could leak private overlay
# content into the public repo. So: review manually, per file.
#
# Runs automatically via a LaunchAgent (login + every 4 hours). Logs to
# ~/.local/share/chezmoi-logs/check-dotfiles-drift.log.
#
# Usage: bin/check-dotfiles-drift.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

status_output="$(chezmoi --source "$SCRIPT_DIR" status 2>&1 || true)"

if [ -z "$status_output" ]; then
  echo "==> No drift detected. All chezmoi-managed dotfiles match the source repo."
  exit 0
fi

echo "==> Dotfiles drift detected:"
echo "$status_output"
echo
echo "==> Review with: chezmoi diff"
echo "    Then either:"
echo "      chezmoi add <path>     # pull a specific live change back into the source repo"
echo "      chezmoi apply <path>   # overwrite a specific live file back to the declared state"
echo
echo "    Note: if a private work overlay is used on this machine, check whether"
echo "    a drifted file is intentionally owned there before re-adding it here."
echo "    See the README for ownership boundaries."

if command -v osascript >/dev/null 2>&1; then
  osascript -e 'display notification "Run `chezmoi diff` in your dotfiles repo to review." with title "Dotfiles drift detected" sound name "Funk"' >/dev/null 2>&1 || true
fi
