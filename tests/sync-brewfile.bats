#!/usr/bin/env bats
# bin/sync-brewfile.sh against fixture Brewfiles. brew, chezmoi and osascript
# are stubs: `brew bundle dump` writes $BATS_TEST_TMPDIR/live (what is
# "installed"), chezmoi answers the personal flag from $PERSONAL.

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
  printf '#!/bin/bash\necho "$PERSONAL"\n' > "$BATS_TEST_TMPDIR/stubs/chezmoi"
  printf '#!/bin/bash\n' > "$BATS_TEST_TMPDIR/stubs/osascript"
  chmod +x "$BATS_TEST_TMPDIR"/stubs/*
  export PATH="$BATS_TEST_TMPDIR/stubs:$PATH"

  export PERSONAL=true
  printf 'brew "git"\n' > "$src/Brewfile"
  : > "$src/Brewfile.personal"
}

installed() { printf '%s\n' "$@" > "$BATS_TEST_TMPDIR/live"; }
sync() { run "$src/bin/sync-brewfile.sh"; [ "$status" -eq 0 ]; }
pending() { cat "$HOME/.local/state/dotfiles/brewfile-removed"; }

@test "an ad-hoc install is appended to Brewfile.personal with its description" {
  installed 'brew "git"' '# Friendly cat' 'brew "bat"'
  sync
  [ "$(cat "$src/Brewfile.personal")" = $'# Friendly cat\nbrew "bat"' ]
  [ "$(cat "$src/Brewfile")" = 'brew "git"' ]
}

@test "an uninstalled entry leaves Brewfile.personal together with its comment" {
  printf '# Friendly cat\nbrew "bat"\n# Search\nbrew "ripgrep"\n' > "$src/Brewfile.personal"
  installed 'brew "git"' 'brew "ripgrep"'
  sync
  [ "$(cat "$src/Brewfile.personal")" = $'# Search\nbrew "ripgrep"' ]
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
  [ ! -s "$src/Brewfile.personal" ]
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
  printf 'brew "jq"\n' > "$src/Brewfile.personal"
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
  [ "$(cat "$src/Brewfile.personal")" = 'brew "jq"' ]
}

@test "on a work Mac the overlay Brewfile is written" {
  export PERSONAL=false
  mkdir -p "$HOME/.local/share/chezmoi-work"
  : > "$HOME/.local/share/chezmoi-work/Brewfile"
  printf 'brew "mise"\n' > "$src/Brewfile.personal"   # not this machine's
  installed 'brew "git"' 'brew "bat"'
  sync
  [ "$(cat "$HOME/.local/share/chezmoi-work/Brewfile")" = 'brew "bat"' ]
  [ "$(cat "$src/Brewfile.personal")" = 'brew "mise"' ]
}

@test "without a personal flag or overlay, drift is only reported" {
  export PERSONAL=false
  installed 'brew "git"' 'brew "bat"'
  sync
  [[ $output == *'reporting only'*'brew "bat"'* ]]
  [ ! -s "$src/Brewfile.personal" ]
}
