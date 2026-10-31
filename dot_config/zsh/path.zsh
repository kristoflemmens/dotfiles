# PATH setup, sourced from both ~/.zshenv (every shell, including scripts and
# non-login shells) and ~/.zprofile (login shells). The second pass is needed
# because macOS' /etc/zprofile runs path_helper, which moves the system dirs
# in front of everything .zshenv added. `typeset -U` keeps the first
# occurrence, so re-prepending restores our order.
#
# Static equivalent of `brew shellenv`: no subprocesses, because .zshenv runs
# for every zsh invocation. Tool dirs that only some machines have carry
# (N): they're added only when they exist, so no per-machine config is
# needed. Go installs into ~/.local/bin (GOBIN in Go's own env file).

typeset -U PATH path

if [[ $OSTYPE == darwin* ]]; then
  export HOMEBREW_PREFIX=/opt/homebrew
  export HOMEBREW_CELLAR=/opt/homebrew/Cellar
  export HOMEBREW_REPOSITORY=/opt/homebrew
else
  export HOMEBREW_PREFIX=/home/linuxbrew/.linuxbrew
  export HOMEBREW_CELLAR=/home/linuxbrew/.linuxbrew/Cellar
  export HOMEBREW_REPOSITORY=/home/linuxbrew/.linuxbrew/Homebrew
fi

path=(
  "$HOME/.local/bin"
  "${KREW_ROOT:-$HOME/.krew}"/bin(N)
  "${CARGO_HOME:-$HOME/.cargo}"/bin(N)
  "$HOMEBREW_PREFIX/opt/rustup/bin"(N)   # cargo/rustc proxies (rustup is keg-only)
  "$HOMEBREW_PREFIX/bin"
  "$HOMEBREW_PREFIX/sbin"
  $path
  "$HOME/Library/Application Support/JetBrains/Toolbox"/scripts(N)
)

[[ -z ${MANPATH-} ]] || export MANPATH=":${MANPATH#:}"
[[ :${INFOPATH-}: == *:$HOMEBREW_PREFIX/share/info:* ]] ||
  export INFOPATH="$HOMEBREW_PREFIX/share/info:${INFOPATH:-}"
