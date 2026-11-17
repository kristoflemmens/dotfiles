#!/bin/bash
set -eufo pipefail
# Homebrew's zsh becomes the login shell; apt's zsh only bootstraps the server.

brew_zsh=/home/linuxbrew/.linuxbrew/bin/zsh
user=$(id -un)

[ -x "$brew_zsh" ] || exit 0
grep -qxF "$brew_zsh" /etc/shells || echo "$brew_zsh" | sudo tee -a /etc/shells >/dev/null
if [ "$(getent passwd "$user" | cut -d: -f7)" != "$brew_zsh" ]; then
  echo "==> Setting the login shell to $brew_zsh..."
  sudo chsh -s "$brew_zsh" "$user"
fi
