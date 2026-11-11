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
#   dotfiles diff                         chezmoi diff of every repo with something
#                                         to apply
#   dotfiles push                         git push every repo with unpushed commits;
#                                         names repos with uncommitted changes
#   dotfiles timestamp <command> [args]   run a command, every output line (stdout
#                                         and stderr) prefixed with the local time;
#                                         exits with its status (LaunchAgents' logs)

set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "$(readlink "${BASH_SOURCE[0]}" || echo "${BASH_SOURCE[0]}")")/.." && pwd)"
# shellcheck source=bin/lib/overlays.sh
. "${SOURCE_DIR}/bin/lib/overlays.sh"

# Every repo in apply order: the overlays, then the base (the last index).
repos=(${overlay_names[@]+"${overlay_names[@]}"} dotfiles)
base=$((${#repos[@]} - 1))

# chezmoi on repo $1 (an index in repos): an overlay through its config.
cz() {
  local i=$1
  shift
  if [ "$i" -lt "$base" ]; then
    "$DOTFILES_CHEZMOI" --config "${overlay_configs[$i]}" "$@"
  else
    "$DOTFILES_CHEZMOI" "$@"
  fi
}

apply() {
  local i
  for ((i = 0; i < base; i++)); do cz "$i" apply; done
  cz "$base" apply "$@"
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
  local i
  for i in "${!repos[@]}"; do cz "$i" git pull -- --rebase; done
  pull_nvim
  apply "$@"
}

status() {
  local i out pending=0
  for i in "${!repos[@]}"; do
    out="$(cz "$i" status)"
    if [ -n "$out" ]; then pending=1; printf '==> %s\n%s\n' "${repos[$i]}" "$out"; fi
  done
  return "$pending"
}

# Status first: a repo with nothing to apply gets no header and no pager.
diff() {
  local i
  for i in "${!repos[@]}"; do
    [ -n "$(cz "$i" status)" ] || continue
    printf '==> %s\n' "${repos[$i]}"
    cz "$i" diff
  done
}

# Without an upstream (a new branch) rev-list fails: git push then says why.
push() {
  local i ahead
  for i in "${!repos[@]}"; do
    if [ -n "$(cz "$i" git -- status --porcelain)" ]; then
      echo "dotfiles push: ${repos[$i]} has uncommitted changes, not pushed" >&2
    fi
    ahead="$(cz "$i" git -- rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo '?')"
    [ "$ahead" != 0 ] || continue
    printf '==> %s\n' "${repos[$i]}"
    cz "$i" git -- push
  done
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
  status | diff | push) "$1" ;;
  timestamp) shift; [ $# -gt 0 ] || { echo "dotfiles timestamp: no command" >&2; exit 2; }; timestamp "$@" ;;
  *) sed -n 's/^# \{0,1\}//; /^Usage:/,/^$/p' "${BASH_SOURCE[0]}" >&2; exit 2 ;;
esac
