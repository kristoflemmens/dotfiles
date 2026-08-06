#!/bin/bash
# Pulls the CURRENT Homebrew state (taps, formulae, casks, vscode extensions,
# krew plugins) back into Brewfile, so drift (e.g. `brew install X` or
# `brew uninstall Y` run ad hoc, outside chezmoi) shows up as a normal git
# diff in the dotfiles repo. It does NOT install/uninstall anything, and it
# does NOT commit anything automatically -- you decide what to do with the
# diff:
#
#   chezmoi git diff -- Brewfile          # review what changed (works from anywhere)
#   chezmoi git add -A
#   chezmoi git -- commit -m "..."        # accept drift as the new desired state
#   chezmoi git checkout -- Brewfile && chezmoi apply   # revert the system instead
#
# IMPORTANT: this machine may also have a private work overlay repo with its
# own Brewfile (employer/client-specific taps & packages). Anything declared
# there is EXCLUDED from what gets written here, so work-specific packages
# never leak into this public Brewfile just because they're installed on
# this machine. If you install something ad hoc that actually belongs in the
# work overlay, move it there yourself after reviewing the diff.
#
# Runs automatically via a LaunchAgent (see
# Library/LaunchAgents/com.kristoflemmens.dotfiles.sync-brewfile.plist), so
# you don't have to remember to run this yourself. When drift is found, it
# sends a macOS notification. Logs go to ~/.local/share/chezmoi-logs/ for
# debugging the scheduled runs.
#
# Usage: bin/sync-brewfile.sh   (run from anywhere; finds the repo itself)

set -euo pipefail
# NOTE: intentionally NOT `-f` (noglob) here, unlike the other scripts in
# this repo -- this script relies on globbing to find private overlay
# Brewfiles (PRIVATE_BREWFILES=(...*.../Brewfile)).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BREWFILE="${SCRIPT_DIR}/Brewfile"

# Any private work overlay repos next to this one. Their Brewfiles' entries
# are excluded from what we write here.
PRIVATE_BREWFILES=("${HOME}"/.local/share/chezmoi-*/Brewfile)

if [ ! -f "$BREWFILE" ]; then
  echo "Could not find Brewfile next to this script (looked in ${SCRIPT_DIR})" >&2
  exit 1
fi

tmp_live="$(mktemp)"
tmp_exclude="$(mktemp)"
tmp_filtered="$(mktemp)"
trap 'rm -f "$tmp_live" "$tmp_exclude" "$tmp_filtered"' EXIT

brew bundle dump --describe --force --file="$tmp_live"

# Collect tap/brew/cask/vscode/krew names declared in any private overlay
# Brewfile, so they get excluded from the public one below.
: > "$tmp_exclude"
for f in "${PRIVATE_BREWFILES[@]}"; do
  [ -f "$f" ] || continue
  grep -oE '^(tap|brew|cask|vscode|krew) "[^"]+"' "$f" \
    | sed -E 's/^(tap|brew|cask|vscode|krew) "([^"]+)"/\2/' >> "$tmp_exclude"
done

# Filter the live dump: drop any tap/brew/cask/vscode/krew entry (and its
# preceding '#' description comment, which `--describe` adds) whose name is
# excluded above.
awk -v exclude_file="$tmp_exclude" '
  BEGIN {
    while ((getline name < exclude_file) > 0) excluded[name] = 1
  }
  /^#/ { pending = pending $0 "\n"; next }
  /^(tap|brew|cask|vscode|krew) "/ {
    name = $0
    sub(/^(tap|brew|cask|vscode|krew) "/, "", name)
    sub(/".*/, "", name)
    if (name in excluded) { pending = ""; next }
    printf "%s", pending
    pending = ""
    print
    next
  }
  { printf "%s", pending; pending = ""; print }
' "$tmp_live" > "$tmp_filtered"

if diff -q "$BREWFILE" "$tmp_filtered" >/dev/null 2>&1; then
  echo "==> No drift detected. Brewfile already matches installed packages (excluding private overlay packages)."
  exit 0
fi

echo "==> Drift detected in Homebrew packages:"
diff -u "$BREWFILE" "$tmp_filtered" | grep -E '^[+-](tap|brew|cask|vscode|krew) "' || true

mv "$tmp_filtered" "$BREWFILE"

echo
echo "==> Brewfile updated to reflect actually-installed packages."
echo "    Review with: chezmoi git diff -- Brewfile"

if command -v osascript >/dev/null 2>&1; then
  osascript -e 'display notification "Run `chezmoi git diff -- Brewfile` to review." with title "Brewfile drift detected" sound name "Funk"' >/dev/null 2>&1 || true
fi
