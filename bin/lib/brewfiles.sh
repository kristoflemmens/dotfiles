# Sourced by the Brewfile scripts; expects SOURCE_DIR (this repo). Sets:
#   personal           "true" on a personal Mac
#   overlay_brewfiles  the Brewfile of every overlay source
#   declared_files     every Brewfile this machine declares: Brewfile (shared)
#                      + Brewfile.personal (personal Macs) + overlay Brewfiles
#   brew_removed       entries deleted from a Brewfile but still installed:
#                      sync-brewfile writes it, brew-cleanup.sh clears it
# shellcheck shell=bash disable=SC2034

personal="$(chezmoi --source "$SOURCE_DIR" execute-template '{{ .personal }}')"

overlay_brewfiles=()
for f in "${HOME}"/.local/share/chezmoi-*/Brewfile; do
  [ -f "$f" ] && overlay_brewfiles+=("$f")
done

declared_files=("${SOURCE_DIR}/Brewfile")
[ "$personal" = "true" ] && declared_files+=("${SOURCE_DIR}/Brewfile.personal")
declared_files+=(${overlay_brewfiles[@]+"${overlay_brewfiles[@]}"})

brew_removed="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/brewfile-removed"
