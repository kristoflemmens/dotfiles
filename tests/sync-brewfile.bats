#!/usr/bin/env bats
# bin/sync-brewfile.sh against fixture Brewfiles. brew and osascript are
# stubs: `brew bundle dump` writes $BATS_TEST_TMPDIR/live (what is
# "installed"). The machine's own Brewfile is an overlay's ($own).

setup() {
  src="$BATS_TEST_TMPDIR/src"
  export HOME="$BATS_TEST_TMPDIR/home"
  unset XDG_STATE_HOME
  mkdir -p "$src" "$HOME" "$BATS_TEST_TMPDIR/stubs"
  cp -R "$BATS_TEST_DIRNAME/../bin" "$src/"

  cat > "$BATS_TEST_TMPDIR/stubs/brew" <<'STUB'
#!/bin/bash
for a; do case $a in --file=*) cp "$BATS_TEST_TMPDIR/live" "${a#--file=}";; esac; done
STUB
  printf '#!/bin/bash\n' > "$BATS_TEST_TMPDIR/stubs/osascript"
  chmod +x "$BATS_TEST_TMPDIR"/stubs/*
  export PATH="$BATS_TEST_TMPDIR/stubs:$PATH"

  printf 'brew "git"\n' > "$src/Brewfile"
  own="$HOME/.local/share/chezmoi-personal/Brewfile"
  mkdir -p "${own%/*}"
  : > "$own"
}

installed() { printf '%s\n' "$@" > "$BATS_TEST_TMPDIR/live"; }
sync() { run "$src/bin/sync-brewfile.sh"; [ "$status" -eq 0 ]; }
pending() { cat "$HOME/.local/state/dotfiles/brewfile-removed"; }

@test "an ad-hoc install is appended to the overlay Brewfile with its description" {
  installed 'brew "git"' '# Friendly cat' 'brew "bat"'
  sync
  [ "$(cat "$own")" = $'# Friendly cat\nbrew "bat"' ]
  [ "$(cat "$src/Brewfile")" = 'brew "git"' ]
}

@test "an uninstalled entry leaves the overlay Brewfile together with its comment" {
  printf '# Friendly cat\nbrew "bat"\n# Search\nbrew "ripgrep"\n' > "$own"
  installed 'brew "git"' 'brew "ripgrep"'
  sync
  [ "$(cat "$own")" = $'# Search\nbrew "ripgrep"' ]
}

@test "the shared Brewfile is only reported, never written" {
  printf 'brew "git"\nbrew "jq"\n' > "$src/Brewfile"
  installed 'brew "git"'
  sync
  [[ $output == *'not installed here'*'brew "jq"'* ]]
  [ "$(cat "$src/Brewfile")" = $'brew "git"\nbrew "jq"' ]
}

@test "an entry deleted from a Brewfile is held back as an uninstall request" {
  printf 'brew "git"\nbrew "jq"\n' > "$src/Brewfile"
  installed 'brew "git"' 'brew "jq"'
  sync
  printf 'brew "git"\n' > "$src/Brewfile"
  sync
  [ ! -s "$own" ]
  [ "$(pending)" = 'brew "jq"' ]
  # Still pending on the next run, until it is uninstalled.
  sync
  [ "$(pending)" = 'brew "jq"' ]
  installed 'brew "git"'
  sync
  [ ! -s "$HOME/.local/state/dotfiles/brewfile-removed" ]
}

@test "declaring an entry again cancels its uninstall request" {
  printf 'brew "git"\nbrew "jq"\n' > "$src/Brewfile"
  installed 'brew "git"' 'brew "jq"'
  sync
  printf 'brew "git"\n' > "$src/Brewfile"
  sync
  printf 'brew "jq"\n' > "$own"
  sync
  [ ! -s "$HOME/.local/state/dotfiles/brewfile-removed" ]
}

@test "after brew-cleanup clears the requests, a kept package is recorded" {
  printf 'brew "git"\nbrew "jq"\n' > "$src/Brewfile"
  installed 'brew "git"' 'brew "jq"'
  sync
  printf 'brew "git"\n' > "$src/Brewfile"
  sync
  rm "$HOME/.local/state/dotfiles/brewfile-removed"   # what brew-cleanup.sh does
  sync
  [ "$(cat "$own")" = 'brew "jq"' ]
}

@test "without an overlay, drift is only reported" {
  rm -r "$HOME/.local/share/chezmoi-personal"
  installed 'brew "git"' 'brew "bat"'
  sync
  [[ $output == *'reporting only'*'brew "bat"'* ]]
  [ ! -e "$own" ]
}
