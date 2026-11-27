#!/usr/bin/env bats
# bin/dotfiles.sh and the overlay register (bin/lib/overlays.sh) it uses,
# against a chezmoi stub (tests/helpers.bash).

load helpers

setup() {
  common_setup
  log="$BATS_TEST_TMPDIR/chezmoi.log"
  : > "$log"
}

@test "apply: every overlay, then the base, which gets the arguments" {
  overlay personal
  overlay work
  run "$src/bin/dotfiles.sh" apply --verbose
  [ "$status" -eq 0 ]
  [ "$(cat "$log")" = $'personal apply\nwork apply\nbase apply --verbose' ]
}

@test "apply: a failing overlay stops before the base" {
  overlay personal
  touch "$BATS_TEST_TMPDIR/fail-personal"
  run "$src/bin/dotfiles.sh" apply
  [ "$status" -ne 0 ]
  [ "$(cat "$log")" = 'personal apply' ]
}

@test "apply without an overlay is a plain chezmoi apply" {
  run "$src/bin/dotfiles.sh" apply
  [ "$status" -eq 0 ]
  [ "$(cat "$log")" = 'base apply' ]
}

@test "update: pulls every repo with rebase, then applies" {
  overlay personal
  run "$src/bin/dotfiles.sh" update
  [ "$status" -eq 0 ]
  [ "$(cat "$log")" = $'personal git pull -- --rebase\nbase git pull -- --rebase\npersonal apply\nbase apply' ]
}

@test "update: leaves a Neovim config with local changes alone" {
  git init -q "$HOME/.config/nvim"
  touch "$HOME/.config/nvim/wip.lua"
  run "$src/bin/dotfiles.sh" update
  [ "$status" -eq 0 ]
  [[ $output == *'local changes, not pulled'* ]]
}

@test "status: empty everywhere exits 0 and prints nothing" {
  overlay personal
  run "$src/bin/dotfiles.sh" status
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "status: names the repo with something to apply and exits 1" {
  overlay personal
  overlay work
  echo ' M .zshrc' > "$BATS_TEST_TMPDIR/status-work"
  run "$src/bin/dotfiles.sh" status
  [ "$status" -eq 1 ]
  [ "$output" = $'==> overlay work\n M .zshrc' ]
}

@test "status: the base's header says base, an overlay's says overlay" {
  overlay work
  echo ' M .zshrc' > "$BATS_TEST_TMPDIR/status-work"
  echo ' M .gitconfig' > "$BATS_TEST_TMPDIR/status-base"
  run "$src/bin/dotfiles.sh" status
  [ "$output" = $'==> overlay work\n M .zshrc\n==> base dotfiles\n M .gitconfig' ]
}

@test "git: runs in every repo, a header only for repos with output" {
  overlay personal
  overlay work
  echo '## main...origin/main [ahead 1]' > "$BATS_TEST_TMPDIR/git-work-status"
  run "$src/bin/dotfiles.sh" git status -sb
  [ "$status" -eq 0 ]
  [ "$output" = $'==> overlay work\n## main...origin/main [ahead 1]' ]
  [ "$(cat "$log")" = $'personal git -- status -sb\nwork git -- status -sb\nbase git -- status -sb' ]
}

@test "git: a failing repo doesn't stop the others, the exit status says so" {
  overlay personal
  touch "$BATS_TEST_TMPDIR/fail-personal"
  run "$src/bin/dotfiles.sh" git diff
  [ "$status" -eq 1 ]
  [ "$(cat "$log")" = $'personal git -- diff\nbase git -- diff' ]
}

@test "git without a git command is an error" {
  run "$src/bin/dotfiles.sh" git
  [ "$status" -eq 2 ]
}

@test "an unknown command prints the usage" {
  run "$src/bin/dotfiles.sh" frobnicate
  [ "$status" -eq 2 ]
  [[ $output == *'dotfiles apply'*'dotfiles status'* ]]
}

@test "works when called through the ~/.local/bin symlink" {
  mkdir -p "$HOME/.local/bin"
  ln -s "$src/bin/dotfiles.sh" "$HOME/.local/bin/dotfiles"
  run "$HOME/.local/bin/dotfiles" apply
  [ "$status" -eq 0 ]
  [ "$(cat "$log")" = 'base apply' ]
}

@test "the register takes the source dir from the config, wherever it is" {
  overlay personal
  run bash -c ". '$src/bin/lib/overlays.sh'; echo \"\${overlay_names[*]}|\${overlay_sources[*]}\""
  [ "$output" = "personal|$BATS_TEST_TMPDIR/sources/personal" ]
}

@test "inside a chezmoi script: CHEZMOI=1 is ignored, CHEZMOI_EXECUTABLE is used" {
  overlay personal
  unset DOTFILES_CHEZMOI
  run env CHEZMOI=1 CHEZMOI_EXECUTABLE="$BATS_TEST_TMPDIR/stubs/chezmoi" "$src/bin/dotfiles.sh" apply
  [ "$status" -eq 0 ]
  [ "$(cat "$log")" = $'personal apply\nbase apply' ]
}

@test "timestamp: prefixes every stdout and stderr line, keeps the exit status" {
  run "$src/bin/dotfiles.sh" timestamp bash -c 'echo out; echo err >&2; printf last; exit 3'
  [ "$status" -eq 3 ]
  [ "${#lines[@]}" -eq 3 ]
  for line in "${lines[@]}"; do
    [[ $line =~ ^\[[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}\]\  ]]
  done
  [[ ${lines[0]} == *'] out' && ${lines[1]} == *'] err' && ${lines[2]} == *'] last' ]]
}

@test "timestamp without a command is a usage error" {
  run "$src/bin/dotfiles.sh" timestamp
  [ "$status" -eq 2 ]
}

@test "diff: only repos with something to apply, each under a header" {
  overlay personal
  overlay work
  echo ' M .zshrc' > "$BATS_TEST_TMPDIR/status-work"
  run "$src/bin/dotfiles.sh" diff
  [ "$status" -eq 0 ]
  [ "$output" = '==> overlay work' ]
  [ "$(grep diff "$log")" = 'work diff' ]
}

@test "push: only repos with unpushed commits" {
  overlay personal
  echo 2 > "$BATS_TEST_TMPDIR/git-personal-rev-list"
  run "$src/bin/dotfiles.sh" push
  [ "$status" -eq 0 ]
  [ "$output" = '==> overlay personal' ]
  [ "$(grep -- '-- push' "$log")" = 'personal git -- push' ]
}

@test "push: names a repo with uncommitted changes, still pushes its commits" {
  echo ' M Brewfile' > "$BATS_TEST_TMPDIR/git-base-status"
  echo 1 > "$BATS_TEST_TMPDIR/git-base-rev-list"
  run "$src/bin/dotfiles.sh" push
  [ "$status" -eq 0 ]
  [[ $output == *'dotfiles has uncommitted changes'* ]]
  [ "$(grep -- '-- push' "$log")" = 'base git -- push' ]
}

@test "push: a failing push stops before the next repo" {
  overlay personal
  echo 1 > "$BATS_TEST_TMPDIR/git-personal-rev-list"
  echo 1 > "$BATS_TEST_TMPDIR/git-base-rev-list"
  touch "$BATS_TEST_TMPDIR/fail-personal"
  run "$src/bin/dotfiles.sh" push
  [ "$status" -ne 0 ]
  ! grep -q 'base git -- push' "$log"
}
