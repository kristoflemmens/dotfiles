#!/usr/bin/env bats
# bin/link-claude-skills.sh in a throwaway HOME.

load helpers

setup() {
  common_setup
  agents="$HOME/.agents/skills"
  claude="$HOME/.claude/skills"
  mkdir -p "$agents" "$claude"
}

skill() { mkdir -p "$agents/$1"; echo "# $1" > "$agents/$1/SKILL.md"; }
link() { run "$src/bin/link-claude-skills.sh"; [ "$status" -eq 0 ]; }

@test "links every skill directory that holds a SKILL.md" {
  skill tdd
  mkdir -p "$agents/not-a-skill"
  link
  [ "$(readlink "$claude/tdd")" = "$agents/tdd" ]
  [ ! -e "$claude/not-a-skill" ]
}

@test "removes a link whose skill is gone, keeps other links and real dirs" {
  skill tdd
  link
  rm -r "$agents/tdd"
  mkdir -p "$claude/synced" "$BATS_TEST_TMPDIR/elsewhere"
  ln -s "$BATS_TEST_TMPDIR/elsewhere" "$claude/mine"
  link
  [ ! -L "$claude/tdd" ]
  [ -d "$claude/synced" ]
  [ -L "$claude/mine" ]
}

@test "a real directory with the skill's name is left alone, with a warning" {
  skill tdd
  mkdir -p "$claude/tdd"
  link
  [ ! -L "$claude/tdd" ]
  [[ $output == *'isn'"'"'t a link, skipped'* ]]
}

@test "follows a skill that is itself a symlink (an overlay's own skill)" {
  mkdir -p "$BATS_TEST_TMPDIR/repo/ajh-intake"
  echo '# x' > "$BATS_TEST_TMPDIR/repo/ajh-intake/SKILL.md"
  ln -s "$BATS_TEST_TMPDIR/repo/ajh-intake" "$agents/ajh-intake"
  link
  [ -f "$claude/ajh-intake/SKILL.md" ]
}
