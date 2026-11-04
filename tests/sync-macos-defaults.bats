#!/usr/bin/env bats
# bin/sync-macos-defaults.sh against a fixture macos-defaults.tsv. The
# defaults stub reads $BATS_TEST_TMPDIR/defaults/<domain>.<key>; chezmoi is
# the helpers stub (`status` prints $BATS_TEST_TMPDIR/status-base).

load helpers

setup() {
  common_setup
  mkdir -p "$BATS_TEST_TMPDIR/defaults"
  cat > "$BATS_TEST_TMPDIR/stubs/defaults" <<'STUB'
#!/bin/bash
[ "$1" = read ] || exit 1
cat "$BATS_TEST_TMPDIR/defaults/$2.$3" 2>/dev/null || exit 1
STUB
  printf '#!/bin/bash\n' > "$BATS_TEST_TMPDIR/stubs/osascript"
  chmod +x "$BATS_TEST_TMPDIR"/stubs/*
  export PATH="$BATS_TEST_TMPDIR/stubs:$PATH"
  printf '# comment\n\n|com.apple.dock|autohide|bool|true\n|com.apple.dock|tilesize|int|48\n|com.apple.dock|missing|int|1\n' > "$src/macos-defaults.tsv"
  live dock autohide 1
  live dock tilesize 48
}

live() { echo "$3" > "$BATS_TEST_TMPDIR/defaults/com.apple.$1.$2"; }
tsv() { cat "$src/macos-defaults.tsv"; }
sync() { run "$src/bin/sync-macos-defaults.sh" "$@"; [ "$status" -eq 0 ]; }

@test "a bool read back as 1 matches a declared true; a missing key stays as declared" {
  before=$(tsv)
  sync
  [[ $output == *'No drift'* ]]
  [ "$(tsv)" = "$before" ]
}

@test "a changed value is written back, comments kept" {
  live dock tilesize 64
  sync
  [[ $output == *"tilesize = '48' (declared) -> '64' (actual)"* ]]
  grep -q '^|com.apple.dock|tilesize|int|64$' "$src/macos-defaults.tsv"
  grep -q '^# comment$' "$src/macos-defaults.tsv"
}

@test "--check only reports" {
  live dock tilesize 64
  sync --check
  grep -q '^|com.apple.dock|tilesize|int|48$' "$src/macos-defaults.tsv"
}

@test "declared values not applied yet are not overwritten by the stale live ones" {
  live dock tilesize 64
  echo ' R 02-macos-defaults.sh' > "$BATS_TEST_TMPDIR/status-base"
  sync
  [[ $output == *"aren't applied yet; reporting only"* ]]
  grep -q '^|com.apple.dock|tilesize|int|48$' "$src/macos-defaults.tsv"
}
