#!/bin/bash
# Claude Code reads skills from ~/.claude/skills/, not from the shared
# ~/.agents/skills/. Link every skill there (a directory with a SKILL.md)
# into ~/.claude/skills/<name> and remove links into ~/.agents/skills/ whose
# target is gone or holds no SKILL.md. Real directories (synced/, which
# Claude itself manages) and links elsewhere are left alone.
set -euo pipefail
src="$HOME/.agents/skills"
dst="$HOME/.claude/skills"
mkdir -p "$dst"

if [ -d "$src" ]; then
  for dir in "$src"/*/; do
    [ -f "$dir/SKILL.md" ] || continue
    name=$(basename "$dir")
    if [ -e "$dst/$name" ] && [ ! -L "$dst/$name" ]; then
      echo "link-claude-skills: $dst/$name exists and isn't a link, skipped" >&2
      continue
    fi
    ln -sfn "$src/$name" "$dst/$name"
  done
fi

for link in "$dst"/*; do
  [ -L "$link" ] || continue
  case "$(readlink "$link")" in
    "$src"/*) [ -f "$link/SKILL.md" ] || rm "$link" ;;
  esac
done
