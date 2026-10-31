#!/bin/bash
set -eufo pipefail

# Non-interactive: a server is bootstrapped without a terminal. The installer
# needs passwordless sudo to create /home/linuxbrew.
if [ ! -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  echo "==> Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
