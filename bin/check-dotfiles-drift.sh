#!/bin/bash
# Notifies (does not auto-fix) when any chezmoi-managed dotfile has drifted
# from what's declared in its source repo -- e.g. you edited ~/.zshrc
# directly instead of via `chezmoi edit`, or a tool rewrote a config file
# chezmoi manages.
#
# Checks this repo and every private overlay (bin/lib/overlays.sh).
#
# Deliberately notification-only: some files are composed from fragments a
# private overlay provides, so blindly running `chezmoi re-add` here could
# leak private overlay content into the public repo. Review manually, per file.
#
# Runs automatically via a LaunchAgent (login + every 4 hours). Logs to
# ~/.local/state/dotfiles/logs/check-dotfiles-drift.log.
#
# Usage: bin/check-dotfiles-drift.sh

set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=bin/lib/overlays.sh
. "${SOURCE_DIR}/bin/lib/overlays.sh"

# A merged file (a modify_ template: VS Code, Claude Code, APM, OpenLogi)
# gets rewritten by its app in its own key order. Same content once both
# sides are normalised in the file's format = no drift.
merged_unchanged() { # <path relative to ~> <chezmoi args...>
  local target="${HOME}/$1" from to
  shift
  case "$("$DOTFILES_CHEZMOI" "$@" source-path "$target" 2>/dev/null)" in
    */modify_*) ;;
    *) return 1 ;;
  esac
  case "$target" in
    *.json) from=fromJsonc to='toPrettyJson "  "' ;;
    *.yml | *.yaml) from=fromYaml to=toYaml ;;
    *.toml) from=fromToml to=toToml ;;
    *) return 1 ;;
  esac
  [ "$("$DOTFILES_CHEZMOI" "$@" cat "$target" 2>/dev/null)" = \
    "$("$DOTFILES_CHEZMOI" "$@" execute-template "{{ include \"${target}\" | ${from} | ${to} }}" 2>/dev/null)" ]
}

drift=0
report() {
  local name="$1"
  shift
  local status line path output=""
  status="$("$DOTFILES_CHEZMOI" "$@" status --exclude=scripts 2>&1 || true)"
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    path="${line:3}"
    merged_unchanged "$path" "$@" && continue
    output+="${line}"$'\n'
  done <<< "$status"
  if [ -n "$output" ]; then
    drift=1
    echo "==> Drift in ${name}:"
    printf '%s\n' "$output"
  fi
}

report "dotfiles" --source "$SOURCE_DIR"
for i in ${overlay_names[@]+"${!overlay_names[@]}"}; do
  report "chezmoi-${overlay_names[$i]}" --config "${overlay_configs[$i]}"
done

if [ "$drift" -eq 0 ]; then
  echo "==> No drift detected. All chezmoi-managed dotfiles match their source repos."
  exit 0
fi

echo "==> Review with \`chezmoi diff\` (and \`chez<overlay> diff\`), then either:"
echo "      chezmoi add <path>     # pull a specific live change back into the source repo"
echo "      chezmoi apply <path>   # overwrite a specific live file back to the declared state"
echo "    A merged file (modify_ template): a shared key changed in the app. Keep it by"
echo "    editing its .chezmoitemplates file (or the overlay's fragment), never"
echo "    chezmoi add (that would replace the merge with a plain copy)."

if command -v osascript >/dev/null 2>&1; then
  osascript -e 'display notification "Run chezmoi diff to review." with title "Dotfiles drift detected" sound name "Funk"' >/dev/null 2>&1 || true
fi
