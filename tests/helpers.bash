# Shared bats setup: a throwaway HOME, a copy of bin/ as the base source, and
# a chezmoi stub. The stub answers `source-path` from the config's sourceDir
# and logs every other call to $BATS_TEST_TMPDIR/chezmoi.log as
# `<config name or base> <args>`; `status` prints $BATS_TEST_TMPDIR/status-<name>.

common_setup() {
  src="$BATS_TEST_TMPDIR/src"
  export HOME="$BATS_TEST_TMPDIR/home"
  unset XDG_STATE_HOME
  mkdir -p "$src" "$HOME" "$BATS_TEST_TMPDIR/stubs"
  cp -R "$BATS_TEST_DIRNAME/../bin" "$src/"

  cat > "$BATS_TEST_TMPDIR/stubs/chezmoi" <<'STUB'
#!/bin/bash
name=base
while :; do
  case "${1:-}" in
    --config) name=${2%/chezmoi.yaml}; name=${name##*/chezmoi-}; config=$2; shift 2 ;;
    --source) shift 2 ;;
    *) break ;;
  esac
done
case "${1:-}" in
  source-path) sed -n 's/^sourceDir: "\(.*\)"$/\1/p' "$config" ;;
  status) cat "$BATS_TEST_TMPDIR/status-$name" 2>/dev/null; echo "$name $*" >> "$BATS_TEST_TMPDIR/chezmoi.log" ;;
  *) echo "$name $*" >> "$BATS_TEST_TMPDIR/chezmoi.log"
     [ -e "$BATS_TEST_TMPDIR/fail-$name" ] && exit 1 ;;
esac
exit 0
STUB
  chmod +x "$BATS_TEST_TMPDIR/stubs/chezmoi"
  export DOTFILES_CHEZMOI="$BATS_TEST_TMPDIR/stubs/chezmoi"
}

# An overlay as chezmoi init leaves it: a config naming its source dir.
# Sources live outside ~/.local/share on purpose: only the config counts.
overlay() { # name [Brewfile entry]
  local source="$BATS_TEST_TMPDIR/sources/$1"
  mkdir -p "$HOME/.config/chezmoi-$1" "$source"
  printf 'sourceDir: "%s"\n' "$source" > "$HOME/.config/chezmoi-$1/chezmoi.yaml"
  [ -z "${2:-}" ] || printf '%s\n' "$2" > "$source/Brewfile"
}
