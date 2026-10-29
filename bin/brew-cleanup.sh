#!/bin/bash
# Uninstalls what no Brewfile of this machine declares any more (an entry
# deleted from the shared Brewfile or an overlay Brewfile).
# `brew bundle install` only adds; bin/sync-brewfile.sh holds deleted entries
# back as uninstall requests until this runs.
#
# Casks are zapped (their preferences, caches and support files go too).
# brew lists what it would remove and asks first. Declining keeps it: the
# next sync then records it in the machine's own Brewfile. Without a
# terminal it only lists. Runs from run_onchange_before_02-brew-bundle.
#
# Usage: bin/brew-cleanup.sh

set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=bin/lib/brewfiles.sh
. "${SOURCE_DIR}/bin/lib/brewfiles.sh"

combined="$(mktemp)"
trap 'rm -f "$combined"' EXIT
cat "${declared_files[@]}" > "$combined"

echo "==> Checking for packages no Brewfile declares..."
if [ ! -t 0 ]; then
  /opt/homebrew/bin/brew bundle cleanup --zap --file="$combined" || true
  echo "==> No terminal: nothing uninstalled. Run bin/brew-cleanup.sh to choose."
  exit 0
fi

/opt/homebrew/bin/brew bundle cleanup --zap --file="$combined" ||
  echo "==> Declined or failed: what is still installed gets recorded in this machine's own Brewfile by the next sync-brewfile."
# Removed or kept on purpose: either way no uninstall request is left.
rm -f "$brew_removed"
