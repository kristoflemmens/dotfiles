# PATH setup, sourced from both ~/.zshenv (every shell, including scripts and
# non-login shells) and ~/.zprofile (login shells). The second pass is needed
# because macOS' /etc/zprofile runs path_helper, which moves the system dirs
# in front of everything .zshenv added. `typeset -U` keeps the first
# occurrence, so re-prepending restores our order.
#
# Static equivalent of `brew shellenv` and `go env GOPATH`: no subprocesses,
# because .zshenv runs for every zsh invocation.

typeset -U PATH path

export HOMEBREW_PREFIX=/opt/homebrew
export HOMEBREW_CELLAR=/opt/homebrew/Cellar
export HOMEBREW_REPOSITORY=/opt/homebrew
export GOPATH="${GOPATH:-$HOME/go}"

path=(
  "$HOME/.local/bin"
  "${KREW_ROOT:-$HOME/.krew}/bin"
  "$GOPATH/bin"
  "$HOMEBREW_PREFIX/bin"
  "$HOMEBREW_PREFIX/sbin"
  $path
  "$HOME/Library/Application Support/JetBrains/Toolbox/scripts"
)

[[ -z ${MANPATH-} ]] || export MANPATH=":${MANPATH#:}"
[[ :${INFOPATH-}: == *:$HOMEBREW_PREFIX/share/info:* ]] ||
  export INFOPATH="$HOMEBREW_PREFIX/share/info:${INFOPATH:-}"
