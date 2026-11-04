# Sourced by the Brewfile scripts; expects SOURCE_DIR (this repo). Sets:
#   BREW               the brew to call (scripts run without the shell's PATH;
#                      tests point it at a stub)
#   overlay_brewfiles  the Brewfile of every overlay that has one
#   declared_files     every Brewfile this machine declares, in install order:
#                      Brewfile (shared) first, then the overlay Brewfiles
#   own_brewfile       this machine's own Brewfile (its overlay's), where
#                      sync-brewfile writes; empty without an overlay
#   brew_removed       entries deleted from a Brewfile but still installed:
#                      sync-brewfile writes it, brew-cleanup.sh clears it
# shellcheck shell=bash disable=SC2034

# shellcheck source=bin/lib/overlays.sh
. "${SOURCE_DIR}/bin/lib/overlays.sh"

BREW="${BREW:-/opt/homebrew/bin/brew}"

overlay_brewfiles=()
for _src in ${overlay_sources[@]+"${overlay_sources[@]}"}; do
  [ -f "$_src/Brewfile" ] && overlay_brewfiles+=("$_src/Brewfile")
done
unset _src

declared_files=("${SOURCE_DIR}/Brewfile" ${overlay_brewfiles[@]+"${overlay_brewfiles[@]}"})

own_brewfile="${overlay_brewfiles[0]:-}"

brew_removed="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/brewfile-removed"
