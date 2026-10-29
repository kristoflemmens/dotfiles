#!/bin/bash
# Notifies (does not auto-fix) when any chezmoi-managed dotfile has drifted
# from what's declared in its source repo -- e.g. you edited ~/.zshrc
# directly instead of via `chezmoi edit`, or a tool rewrote a config file
# chezmoi manages.
#
# Checks this repo and every private overlay that has its own config in
# ~/.config/chezmoi-*/chezmoi.yaml.
#
# Deliberately notification-only: some files are composed from fragments a
# private overlay provides, so blindly running `chezmoi re-add` here could
# leak private overlay content into the public repo. Review manually, per file.
#
# Runs automatically via a LaunchAgent (login + every 4 hours). Logs to
# ~/.local/share/chezmoi-logs/check-dotfiles-drift.log.
#
# Usage: bin/check-dotfiles-drift.sh

set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Settings files merged by a modify_ template (VS Code, Claude Code) get
# rewritten by their app in its own key order. Same content once both sides
# are normalised by chezmoi = no drift.
merged_unchanged() { # <path relative to ~> <chezmoi args...>
  local target="${HOME}/$1"
  shift
  [ "$(chezmoi "$@" cat "$target" 2>/dev/null)" = \
    "$(chezmoi execute-template "{{ include \"${target}\" | fromJsonc | toPrettyJson \"  \" }}" 2>/dev/null)" ]
}

drift=0
report() {
  local name="$1"
  shift
  local status line path output=""
  status="$(chezmoi "$@" status --exclude=scripts 2>&1 || true)"
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    path="${line:3}"
    case "$path" in
      .claude/settings.json | "Library/Application Support/Code/User/settings.json")
        merged_unchanged "$path" "$@" && continue ;;
    esac
    output+="${line}"$'\n'
  done <<< "$status"
  if [ -n "$output" ]; then
    drift=1
    echo "==> Drift in ${name}:"
    printf '%s\n' "$output"
  fi
}

report "dotfiles" --source "$SOURCE_DIR"
for config in "${HOME}"/.config/chezmoi-*/chezmoi.yaml; do
  [ -f "$config" ] || continue
  report "$(basename "$(dirname "$config")")" --config "$config"
done

if [ "$drift" -eq 0 ]; then
  echo "==> No drift detected. All chezmoi-managed dotfiles match their source repos."
  exit 0
fi

echo "==> Review with \`chezmoi diff\` (and \`chezmoi --config <overlay config> diff\`), then either:"
echo "      chezmoi add <path>     # pull a specific live change back into the source repo"
echo "      chezmoi apply <path>   # overwrite a specific live file back to the declared state"
echo "    VS Code / Claude Code settings.json: a shared key changed in the app. Keep it by"
echo "    editing .chezmoitemplates/{vscode,claude}-settings.jsonc (or the overlay's fragment),"
echo "    never chezmoi add (that would replace the merge with a plain copy)."

if command -v osascript >/dev/null 2>&1; then
  osascript -e 'display notification "Run chezmoi diff to review." with title "Dotfiles drift detected" sound name "Funk"' >/dev/null 2>&1 || true
fi
