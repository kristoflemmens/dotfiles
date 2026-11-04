#!/bin/bash
# Installs every Brewfile this machine declares: the shared Brewfile first
# (overlay Brewfiles may rely on what it installs), then each overlay's. Then
# bin/brew-cleanup.sh offers to uninstall what no Brewfile declares any more.
#
# Overlays have no brew script of their own: their Brewfile is all they
# provide. A Brewfile that fails stops the run before the cleanup, so a
# half-installed machine is never offered uninstalls.
#
# Runs from run_onchange_before_02-brew-bundle, which reruns when any of these
# Brewfiles changes.
#
# Usage: bin/brew-bundle.sh

set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=bin/lib/brewfiles.sh
. "${SOURCE_DIR}/bin/lib/brewfiles.sh"

tilde="~"
for f in "${declared_files[@]}"; do
  echo "==> Installing packages from ${f/#"$HOME"/$tilde}..."
  "$BREW" bundle install --file="$f"
done

"${SOURCE_DIR}/bin/brew-cleanup.sh"
