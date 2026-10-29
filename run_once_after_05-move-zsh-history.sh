#!/bin/bash
set -euo pipefail
# One-time move of the zsh history to ~/.local/state/zsh/history (HISTFILE in
# ~/.zshrc). Shells that were already open keep writing the old file until
# they exit; if it reappears, append it again and move it to the Trash.

old="$HOME/.zsh_history"
new="$HOME/.local/state/zsh/history"

[[ -f $old ]] || exit 0
mkdir -p "${new%/*}"
cat "$old" >> "$new"
chmod 600 "$new"
mv "$old" "$HOME/.Trash/zsh_history-$(date +%Y%m%d%H%M%S)"
