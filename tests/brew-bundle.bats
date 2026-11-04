#!/usr/bin/env bats
# bin/brew-bundle.sh (and the bin/brew-cleanup.sh it ends with) against
# fixture Brewfiles. The brew stub logs each call as `<command> <file
# contents>`, so a test sees which Brewfile was installed in which order.

setup() {
  src="$BATS_TEST_TMPDIR/src"
  export HOME="$BATS_TEST_TMPDIR/home"
  unset XDG_STATE_HOME
  mkdir -p "$src" "$HOME" "$BATS_TEST_TMPDIR/stubs"
  cp -R "$BATS_TEST_DIRNAME/../bin" "$src/"
  log="$BATS_TEST_TMPDIR/brew.log"

  cat > "$BATS_TEST_TMPDIR/stubs/brew" <<'STUB'
#!/bin/bash
for a; do case $a in --file=*) file=${a#--file=};; esac; done
echo "$2 $(tr '\n' ' ' < "$file")" >> "$BATS_TEST_TMPDIR/brew.log"
grep -q 'brew "broken"' "$file" && exit 1
exit 0
STUB
  chmod +x "$BATS_TEST_TMPDIR/stubs/brew"
  export BREW="$BATS_TEST_TMPDIR/stubs/brew"

  printf 'brew "git"\n' > "$src/Brewfile"
}

overlay() { # name entry
  mkdir -p "$HOME/.local/share/chezmoi-$1"
  printf '%s\n' "$2" > "$HOME/.local/share/chezmoi-$1/Brewfile"
}

@test "installs the shared Brewfile, then each overlay's, then cleans up over all of them" {
  overlay personal 'brew "bat"'
  overlay work 'brew "jq"'
  run "$src/bin/brew-bundle.sh"
  [ "$status" -eq 0 ]
  [ "$(cat "$log")" = 'install brew "git" 
install brew "bat" 
install brew "jq" 
cleanup brew "git" brew "bat" brew "jq" ' ]
}

@test "without an overlay only the shared Brewfile is installed" {
  run "$src/bin/brew-bundle.sh"
  [ "$status" -eq 0 ]
  [ "$(cat "$log")" = 'install brew "git" 
cleanup brew "git" ' ]
}

@test "a failing Brewfile stops the run before the cleanup" {
  overlay personal 'brew "broken"'
  overlay work 'brew "jq"'
  run "$src/bin/brew-bundle.sh"
  [ "$status" -ne 0 ]
  [ "$(cat "$log")" = 'install brew "git" 
install brew "broken" ' ]
}

@test "a source dir without a Brewfile (chezmoi-logs) is no overlay" {
  mkdir -p "$HOME/.local/share/chezmoi-logs"
  run "$src/bin/brew-bundle.sh"
  [ "$status" -eq 0 ]
  [ "$(grep -c '^install' "$log")" -eq 1 ]
}
