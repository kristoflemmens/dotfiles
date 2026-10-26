#!/bin/bash
# Keeps this machine's own Brewfile in sync with what is actually installed,
# so an ad-hoc `brew install X` / `brew uninstall Y` ends up in chezmoi
# instead of silently drifting.
#
# Declared = Brewfile (shared) + Brewfile.<profile> + the Brewfile of every
# private overlay source (~/.local/share/chezmoi-*/Brewfile).
#
# Writes go to exactly one file, the machine's own:
#   profile=work      -> the private overlay's Brewfile
#   profile=personal  -> Brewfile.personal
# - installed but declared nowhere   -> appended to the machine's own file
# - in the machine's own file but no longer installed -> removed from it
# The shared Brewfile is curated by hand and never written: shared entries
# that aren't installed are only reported (`chezmoi apply` installs them).
#
# Nothing is committed. Review with `chezmoi git diff` (or `chezcegeka git
# diff` for the overlay) and commit, or move entries to the shared Brewfile.
#
# Runs automatically via a LaunchAgent (login + every 4 hours). Logs to
# ~/.local/share/chezmoi-logs/sync-brewfile.log.
#
# Usage: bin/sync-brewfile.sh

set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
profile="$(chezmoi --source "$SOURCE_DIR" execute-template '{{ .profile }}')"

overlay_brewfiles=()
for f in "${HOME}"/.local/share/chezmoi-*/Brewfile; do
  [ -f "$f" ] && overlay_brewfiles+=("$f")
done

if [ "$profile" = "work" ] && [ "${#overlay_brewfiles[@]}" -gt 0 ]; then
  target="${overlay_brewfiles[0]}"
else
  target="${SOURCE_DIR}/Brewfile.${profile}"
  [ -f "$target" ] || printf '# Packages for profile=%s, maintained by bin/sync-brewfile.sh.\n' "$profile" > "$target"
fi

declared_files=("${SOURCE_DIR}/Brewfile")
[ -f "${SOURCE_DIR}/Brewfile.${profile}" ] && declared_files+=("${SOURCE_DIR}/Brewfile.${profile}")
declared_files+=(${overlay_brewfiles[@]+"${overlay_brewfiles[@]}"})

# Normalise Brewfile lines to `type "name"` so options/comments don't matter.
keys() {
  grep -hoE '^[a-z_]+ "[^"]+"' "$@" | sort -u || true
}

tmp_dump="$(mktemp)"
tmp_live="$(mktemp)"
tmp_declared="$(mktemp)"
tmp_add="$(mktemp)"
tmp_remove="$(mktemp)"
tmp_target="$(mktemp)"
trap 'rm -f "$tmp_dump" "$tmp_live" "$tmp_declared" "$tmp_add" "$tmp_remove" "$tmp_target"' EXIT

brew bundle dump --force --file="$tmp_dump"
keys "$tmp_dump" > "$tmp_live"
keys "${declared_files[@]}" > "$tmp_declared"

comm -23 "$tmp_live" "$tmp_declared" > "$tmp_add"
comm -12 <(comm -13 "$tmp_live" "$tmp_declared") <(keys "$target") > "$tmp_remove"
shared_missing="$(comm -13 "$tmp_live" <(keys "${SOURCE_DIR}/Brewfile"))"

# Rewrite the target: drop removed entries (with the description comment
# brew puts above them), then append new entries as `brew bundle dump`
# wrote them (options and description included).
awk -v remove_file="$tmp_remove" -v add_file="$tmp_add" -v dump_file="$tmp_dump" '
  function key(line) { match(line, /^[a-z_]+ "[^"]+"/); return substr(line, RSTART, RLENGTH) }
  BEGIN {
    while ((getline k < remove_file) > 0) remove[k] = 1
    while ((getline k < add_file) > 0) add[k] = 1
  }
  FILENAME != dump_file {
    if (/^# /) { pending = pending $0 "\n"; next }
    if (/^[a-z_]+ "/ && (key($0) in remove)) { pending = ""; next }
    printf "%s", pending; pending = ""; print
    next
  }
  /^# / { comment = $0; next }
  /^[a-z_]+ "/ && (key($0) in add) {
    if (comment != "") added = added comment "\n"
    added = added $0 "\n"
  }
  { comment = "" }
  END { printf "%s", pending; printf "%s", added }
' "$target" "$tmp_dump" > "$tmp_target"

changed=0
if ! cmp -s "$target" "$tmp_target"; then
  changed=1
  cp "$tmp_target" "$target"
fi

echo "==> profile: ${profile}, writing to: ${target}"
if [ -s "$tmp_add" ]; then
  echo "Added (installed but declared nowhere):"
  sed 's/^/  /' "$tmp_add"
fi
if [ -s "$tmp_remove" ]; then
  echo "Removed (no longer installed):"
  sed 's/^/  /' "$tmp_remove"
fi
if [ -n "$shared_missing" ]; then
  echo "In the shared Brewfile but not installed here (chezmoi apply installs them):"
  # shellcheck disable=SC2001
  sed 's/^/  /' <<< "$shared_missing"
fi

if [ "$changed" -eq 0 ]; then
  echo "==> ${target##*/} is up to date."
  exit 0
fi

echo "==> Updated ${target}. Review and commit it."
if command -v osascript >/dev/null 2>&1; then
  osascript -e 'display notification "Review the Brewfile changes in your dotfiles repo." with title "Brewfile updated" sound name "Funk"' >/dev/null 2>&1 || true
fi
