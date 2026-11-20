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

@test "starship.toml gets the overlay's fragment appended, still valid TOML" {
  grep -q '^FIXTURE_SUBSCRIPTION = "fixture"' "$HOME/.config/starship.toml"
  if command -v starship >/dev/null; then
    run env STARSHIP_CONFIG="$HOME/.config/starship.toml" starship print-config azure
    [[ $output == *'disabled = false'* ]]
  fi
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
  grep -q 'agent_panel_sort = "fixture"' "$HOME/.config/herdr/config.toml"
  grep -q 'status_indicators = "symbols"' "$HOME/.config/herdr/config.toml"
}

@test "herdr integrations script reruns when herdr or an agent changes" {
  command -v herdr >/dev/null || skip "herdr not installed"
  run script herdr-integrations
  [[ $output == *'# herdr: '* ]]
  [[ $output == *'# claude: '* && $output == *'# opencode: '* ]]
}

@test "1Password settings: no file before the app's first start, merged after, left alone when it holds (macOS)" {
  [[ $OSTYPE == darwin* ]] || skip "1Password settings are macOS-only"
  local f="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/Library/Application Support/1Password/Data/settings/settings.json"
  [[ ! -e "$HOME/Library/Group Containers" ]]
  mkdir -p "$(dirname "$f")"
  printf '{\n  "version": 1,\n  "security.autolock.minutes": 5,\n  "app.state": "kept"\n}\n' > "$f"
  cm apply --force "$f"
  grep -q '"security.autolock.minutes": 60' "$f"
  grep -q '"app.state": "kept"' "$f"
  grep -q '"fixture.onepassword": true' "$f"
  # the app writes the same values back in its own order: no drift, no rewrite
  jq --indent 4 . "$f" > "$f.app" && mv "$f.app" "$f"
  cp "$f" "$f.before"
  cm apply --force "$f"
  cmp "$f" "$f.before"
}
