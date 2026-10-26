#!/bin/bash
# Reports drift between the Homebrew packages declared for this machine and
# what is actually installed. Read-only: it never touches the system or the
# source repo, so `chezmoi update` never trips over a dirty working tree and
# two machines with different package sets don't overwrite each other's
# Brewfile.
#
# Declared = Brewfile (shared) + Brewfile.<profile> (if present) + the
# Brewfile of every private overlay source (~/.local/share/chezmoi-*/Brewfile).
#
# To resolve drift, edit the right Brewfile by hand (shared, per-profile or
# overlay), commit, `chezmoi apply`. Packages that are declared but missing are
# installed by that apply; packages to drop must be uninstalled with
# `brew uninstall` (brew bundle never removes anything).
#
# Runs automatically via a LaunchAgent (login + every 4 hours). Logs to
# ~/.local/share/chezmoi-logs/sync-brewfile.log.
#
# Usage: bin/sync-brewfile.sh

set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
profile="$(chezmoi --source "$SOURCE_DIR" execute-template '{{ .profile }}' 2>/dev/null || true)"

declared_files=("${SOURCE_DIR}/Brewfile")
[ -n "$profile" ] && [ -f "${SOURCE_DIR}/Brewfile.${profile}" ] && declared_files+=("${SOURCE_DIR}/Brewfile.${profile}")
for f in "${HOME}"/.local/share/chezmoi-*/Brewfile; do
  [ -f "$f" ] && declared_files+=("$f")
done

# Normalise Brewfile lines to `type "name"` so options/comments don't matter.
entries() {
  grep -hoE '^(tap|brew|cask|vscode|krew) "[^"]+"' "$@" | sort -u
}

tmp_live="$(mktemp)"
tmp_declared="$(mktemp)"
trap 'rm -f "$tmp_live" "$tmp_declared"' EXIT

brew bundle dump --force --file=- | entries /dev/stdin > "$tmp_live"
entries "${declared_files[@]}" > "$tmp_declared"

undeclared="$(comm -23 "$tmp_live" "$tmp_declared")"
missing="$(comm -13 "$tmp_live" "$tmp_declared")"

if [ -z "$undeclared" ] && [ -z "$missing" ]; then
  echo "==> No drift detected (profile: ${profile:-unknown})."
  exit 0
fi

echo "==> Homebrew drift detected (profile: ${profile:-unknown})"
echo "    Declared in: ${declared_files[*]}"
if [ -n "$undeclared" ]; then
  echo
  echo "Installed but not declared (add to a Brewfile, or brew uninstall):"
  # shellcheck disable=SC2001
  sed 's/^/  /' <<< "$undeclared"
fi
if [ -n "$missing" ]; then
  echo
  echo "Declared but not installed (chezmoi apply installs them, or remove from the Brewfile):"
  # shellcheck disable=SC2001
  sed 's/^/  /' <<< "$missing"
fi

if command -v osascript >/dev/null 2>&1; then
  osascript -e 'display notification "Run ~/.local/share/chezmoi/bin/sync-brewfile.sh to review." with title "Brewfile drift detected" sound name "Funk"' >/dev/null 2>&1 || true
fi
