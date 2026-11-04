#!/usr/bin/env bats
# bin/check-dotfiles-drift.sh against a fixture source applied with the real
# chezmoi into a throwaway HOME: a plain file and two merged files (modify_
# templates, JSON and YAML) that set one shared key over what the app wrote.

load helpers

setup() {
  command -v chezmoi >/dev/null || skip "chezmoi not installed"
  common_setup
  unset DOTFILES_CHEZMOI
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/bin/bash\n' > "$BATS_TEST_TMPDIR/bin/osascript"
  chmod +x "$BATS_TEST_TMPDIR/bin/osascript"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"

  echo plain > "$src/dot_plain"
  cat > "$src/modify_settings.json" <<'T'
{{- /* chezmoi:modify-template */ -}}
{{- $s := dict -}}
{{- if .chezmoi.stdin }}{{ $s = .chezmoi.stdin | fromJsonc }}{{ end -}}
{{- $_ := set $s "shared" 1 -}}
{{ toPrettyJson "  " $s }}
T
  cat > "$src/modify_apm.yml" <<'T'
{{- /* chezmoi:modify-template */ -}}
{{- $s := dict -}}
{{- if .chezmoi.stdin }}{{ $s = .chezmoi.stdin | fromYaml }}{{ end -}}
{{- $_ := set $s "shared" 1 -}}
{{ toYaml $s }}
T
  printf '{"app": 1}\n' > "$HOME/settings.json"
  printf 'app: 1\n' > "$HOME/apm.yml"
  chezmoi --source "$src" apply --no-pager --exclude=scripts
}

drift() { run "$src/bin/check-dotfiles-drift.sh"; }

@test "freshly applied: no drift" {
  drift
  [ "$status" -eq 0 ]
  [[ $output == *'No drift'* ]]
}

@test "a merged file the app rewrote in its own key order is no drift" {
  printf '{\n\t"shared": 1,\n\t"app": 1\n}\n' > "$HOME/settings.json"
  printf 'shared: 1\napp: 1\n' > "$HOME/apm.yml"
  drift
  [[ $output == *'No drift'* ]]
}

@test "a key the app added to a merged file is no drift" {
  printf '{"app": 1, "shared": 1, "theme": "dark"}\n' > "$HOME/settings.json"
  drift
  [[ $output == *'No drift'* ]]
}

@test "a shared key changed in a merged file is drift" {
  printf '{"app": 1, "shared": 5}\n' > "$HOME/settings.json"
  drift
  [[ $output == *'Drift in dotfiles'*'settings.json'* ]]
  [[ $output != *'apm.yml'* ]]
}

@test "an edited plain file is drift" {
  echo edited > "$HOME/.plain"
  drift
  [[ $output == *'Drift in dotfiles'*'.plain'* ]]
}
