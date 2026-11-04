#!/usr/bin/env bats
# Renders this repo with the real chezmoi into a throwaway HOME that holds an
# overlay: the fragments in tests/fixtures/dotfiles-overlay/ and an overlay
# config whose source has a Brewfile and an own skill. Every template branch
# that reads an overlay runs here; without an overlay (CI's render job) none
# of them does. VS Code and the macOS scripts only on macOS.

setup() {
  command -v chezmoi >/dev/null || skip "chezmoi not installed"
  repo="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.config"
  cp -R "$BATS_TEST_DIRNAME/fixtures/dotfiles-overlay" "$HOME/.config/"

  osrc="$BATS_TEST_TMPDIR/overlay-src"
  mkdir -p "$HOME/.config/chezmoi-fixture" "$osrc/dot_agents/skills/fixture-own"
  printf 'sourceDir: "%s"\n' "$osrc" > "$HOME/.config/chezmoi-fixture/chezmoi.yaml"
  printf 'brew "fixture-formula"\n' > "$osrc/Brewfile"

  cm() { chezmoi --source "$repo" --no-pager "$@"; }
  cm init
  cm apply --force --exclude=scripts,externals
}

script() { # rendered run_ script, by name pattern
  local f
  f=$(ls "$repo"/run_*"$1"*.tmpl)
  chezmoi --source "$repo" execute-template < "$f"
}

@test "gitconfig includes the overlay's gitconfig" {
  grep -qF 'path = ~/.config/dotfiles-overlay/gitconfig' "$HOME/.gitconfig"
}

@test "allowed_signers gets the overlay's signers appended" {
  grep -q '^kristof@klconsultancy.be ' "$HOME/.ssh/allowed_signers"
  grep -q '^fixture@example.com ' "$HOME/.ssh/allowed_signers"
}

@test "Claude Code settings: shared keys plus the overlay fragment" {
  grep -q '"fixtureClaude": true' "$HOME/.claude/settings.json"
}

@test "VS Code settings: the JSONC fragment, comment and all, is merged" {
  [[ $OSTYPE == darwin* ]] || skip "VS Code settings are macOS-only"
  grep -q '"fixture.vscode": true' "$HOME/Library/Application Support/Code/User/settings.json"
}

@test "APM manifest: the overlay's skills follow the shared ones" {
  grep -q 'fixture/skills/fixture-skill#v1.0.0' "$HOME/.apm/apm.yml"
}

@test "agent-skills script tracks the overlay list and the overlay's own skills" {
  run script agent-skills
  [[ $output == *'overlay apm-deps.yaml hash: '[0-9a-f]* ]]
  [[ $output == *'chezmoi-fixture skills: fixture-own'* ]]
}

@test "brew script reruns on the overlay's Brewfile (macOS)" {
  [[ $OSTYPE == darwin* ]] || skip "macOS script"
  run script 02-brew-bundle.sh
  [[ $output == *"$osrc/Brewfile hash: "* ]]
}

@test "Docker config script merges the overlay's credHelpers (macOS)" {
  [[ $OSTYPE == darwin* ]] || skip "macOS script"
  run script docker-config
  [[ $output == *'"fixture.example.com": "fixture"'* ]]
  [[ $output == *'"currentContext": "colima"'* ]]
}

@test "herdr config: shared preferences over what herdr wrote itself (macOS)" {
  [[ $OSTYPE == darwin* ]] || skip "herdr config is macOS-only"
  grep -q 'name = "tokyo-night"' "$HOME/.config/herdr/config.toml"
  printf '[keys]\nprefix = "ctrl+a"\n[theme]\nname = "dracula"\n' > "$HOME/.config/herdr/config.toml"
  cm apply --force "$HOME/.config/herdr/config.toml"
  grep -q 'prefix = "ctrl+a"' "$HOME/.config/herdr/config.toml"
  grep -q 'name = "tokyo-night"' "$HOME/.config/herdr/config.toml"
}
