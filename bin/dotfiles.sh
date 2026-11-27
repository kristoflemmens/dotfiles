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
#   dotfiles git <git command> [args]     that git command in every repo's source
#                                         dir, a header per repo with output; on a
#                                         terminal in colour, through git's pager
#                                         (dotfiles git status -sb, git diff, git log
#                                         @{u}..). Not for interactive ones (add -p)
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

# The header above a repo's output: overlay or base, each in its own colour
# on a terminal (or when git_all forces colour).
color=
[ -t 1 ] && color=1
header() {
  local role=overlay c='35' # magenta
  if [ "$1" -eq "$base" ]; then role=base c='34'; fi # blue
  if [ -n "$color" ]; then
    printf '\033[1;%sm==> %s %s\033[0m\n' "$c" "$role" "${repos[$1]}"
  else
    printf '==> %s %s\n' "$role" "${repos[$1]}"
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
    if [ -n "$out" ]; then pending=1; header "$i"; printf '%s\n' "$out"; fi
  done
  return "$pending"
}

# Status first: a repo with nothing to apply gets no header and no pager.
diff() {
  local i
  for i in "${!repos[@]}"; do
    [ -n "$(cz "$i" status)" ] || continue
    header "$i"
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
    header "$i"
    cz "$i" git -- push
  done
}

# Output is captured to know whether a repo gets a header.
git_each() {
  local i out rc=0
  for i in "${!repos[@]}"; do
    out="$(cz "$i" git -- "$@")" || rc=1
    if [ -n "$out" ]; then header "$i"; printf '%s\n' "$out"; fi
  done
  return "$rc"
}

# Captured output isn't a terminal: colour is forced, and git's own pager
# (delta) gets all repos at once, with git's default LESS.
git_all() {
  if [ ! -t 1 ]; then git_each "$@"; return; fi
  color=1
  export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=color.ui GIT_CONFIG_VALUE_0=always
  git_each "$@" | LESS="${LESS-FRX}" sh -c "$(git var GIT_PAGER)"
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
  git) shift; [ $# -gt 0 ] || { echo "dotfiles git: no git command" >&2; exit 2; }; git_all "$@" ;;
  timestamp) shift; [ $# -gt 0 ] || { echo "dotfiles timestamp: no command" >&2; exit 2; }; timestamp "$@" ;;
  *) sed -n 's/^# \{0,1\}//; /^Usage:/,/^$/p' "${BASH_SOURCE[0]}" >&2; exit 2 ;;
esac
