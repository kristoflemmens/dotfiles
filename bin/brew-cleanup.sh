#!/bin/bash
# Uninstalls what no Brewfile of this machine declares any more (an entry
# deleted from the shared Brewfile or an overlay Brewfile).
# `brew bundle install` only adds; bin/sync-brewfile.sh holds deleted entries
# back as uninstall requests until this runs.
#
# Casks are zapped (their preferences, caches and support files go too).
# brew lists what it would remove and asks first. Declining keeps it: the
# next sync then records it in the machine's own Brewfile. Without a
# terminal it only lists. Runs from bin/brew-bundle.sh, after the installs,
# and from run_onchange_after_10-brew-cleanup when sync-brewfile recorded
# new uninstall requests after the last brew bundle run.
#
# Usage: bin/brew-cleanup.sh

set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=bin/lib/brewfiles.sh
. "${SOURCE_DIR}/bin/lib/brewfiles.sh"

combined="$(mktemp)"
trap 'rm -f "$combined"' EXIT
cat "${declared_files[@]}" > "$combined"

# brew bundle cleanup leaves an extension type (krew, npm, vscode, ...) alone
# while no Brewfile lists one, so deleting the last entry of a type would
# never be uninstalled. For a type with an uninstall request, a placeholder
# entry makes the type count as declared.
if [ -s "$brew_removed" ]; then
  grep -oE '^[a-z_]+' "$brew_removed" | sort -u | while read -r type; do
    case $type in tap | brew | cask) continue ;; esac
    grep -qE "^${type} \"" "$combined" || echo "${type} \"dotfiles-cleanup-placeholder\"" >> "$combined"
  done
fi

echo "==> Checking for packages no Brewfile declares..."
if [ ! -t 0 ]; then
  "$BREW" bundle cleanup --zap --file="$combined" || true
  echo "==> No terminal: nothing uninstalled. Run bin/brew-cleanup.sh to choose."
  exit 0
fi

"$BREW" bundle cleanup --zap --file="$combined" ||
  echo "==> Declined or failed: what is still installed gets recorded in this machine's own Brewfile by the next sync-brewfile."
# Removed or kept on purpose: either way no uninstall request is left.
rm -f "$brew_removed"
