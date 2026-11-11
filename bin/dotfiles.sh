#!/bin/bash
# Runs chezmoi over this machine's dotfiles: every overlay (bin/lib/overlays.sh)
# first, then this repo, whose templates include files the overlays install.
# On PATH as ~/.local/bin/dotfiles.
#
# Usage:
#   dotfiles apply [chezmoi apply args]   overlays, then the base (args go to the base)
#   dotfiles update [chezmoi apply args]  git pull every repo (rebase), fast-forward
#                                         the Neovim config, then apply
#   dotfiles status                       chezmoi status per repo; exit 1 when any
#                                         has something to apply
#   dotfiles timestamp <command> [args]   run a command, every output line (stdout
#                                         and stderr) prefixed with the local time;
#                                         exits with its status (LaunchAgents' logs)

set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "$(readlink "${BASH_SOURCE[0]}" || echo "${BASH_SOURCE[0]}")")/.." && pwd)"
# shellcheck source=bin/lib/overlays.sh
. "${SOURCE_DIR}/bin/lib/overlays.sh"

apply() {
  local config
  for config in ${overlay_configs[@]+"${overlay_configs[@]}"}; do
    "$DOTFILES_CHEZMOI" --config "$config" apply
  done
  "$DOTFILES_CHEZMOI" apply "$@"
}

# The kickstart.nvim fork is a working copy chezmoi never pulls
# (.chezmoiexternals/nvim.yaml): fast-forward it only when that can't lose
# work, else say why and leave it.
pull_nvim() {
  local nvim="${HOME}/.config/nvim"
  [ -d "$nvim/.git" ] || return 0
  if [ -n "$(git -C "$nvim" status --porcelain)" ]; then
    echo "dotfiles update: ~/.config/nvim has local changes, not pulled" >&2
  elif ! git -C "$nvim" pull --ff-only --quiet; then
    echo "dotfiles update: ~/.config/nvim can't fast-forward, not pulled" >&2
  fi
}

update() {
  local config
  for config in ${overlay_configs[@]+"${overlay_configs[@]}"}; do
    "$DOTFILES_CHEZMOI" --config "$config" git pull -- --rebase
  done
  "$DOTFILES_CHEZMOI" git pull -- --rebase
  pull_nvim
  apply "$@"
}

status() {
  local i out pending=0
  for i in ${overlay_names[@]+"${!overlay_names[@]}"}; do
    out="$("$DOTFILES_CHEZMOI" --config "${overlay_configs[$i]}" status)"
    if [ -n "$out" ]; then pending=1; printf '==> %s\n%s\n' "${overlay_names[$i]}" "$out"; fi
  done
  out="$("$DOTFILES_CHEZMOI" status)"
  if [ -n "$out" ]; then pending=1; printf '==> dotfiles\n%s\n' "$out"; fi
  return "$pending"
}

# Bash 3.2 has no printf %(...)T, macOS awk no strftime: one date per line is
# fine for the few lines an agent writes.
timestamp() {
  local line
  "$@" 2>&1 | while IFS= read -r line || [ -n "$line" ]; do
    printf '[%s] %s\n' "$(date '+%F %T')" "$line"
  done
}

case "${1:-}" in
  apply | update) cmd=$1; shift; "$cmd" "$@" ;;
  status) status ;;
  timestamp) shift; [ $# -gt 0 ] || { echo "dotfiles timestamp: no command" >&2; exit 2; }; timestamp "$@" ;;
  *) sed -n 's/^# \{0,1\}//; /^Usage:/,/^$/p' "${BASH_SOURCE[0]}" >&2; exit 2 ;;
esac
