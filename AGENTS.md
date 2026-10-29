# AGENTS.md

chezmoi source for Kristof's macOS dotfiles. Public repo: anything machine-,
employer- or client-specific belongs in a private overlay repo
(`kristoflemmens/dotfiles-personal` and `kristoflemmens/dotfiles-cegeka`, each
with its own AGENTS.md). README.md describes
layout, bootstrap and the drift agents; read it before structural changes.

## Model

- A Mac is this repo plus one overlay (personal or work). No flags or
  profiles here: an overlay reaches this repo solely through the generic
  files under `~/.config/dotfiles-overlay/` that templates include when
  present, its `Brewfile`, and its own `com.kristoflemmens.dotfiles.*`
  LaunchAgents (loaded by `run_onchange_after_03`).
- Overlays are separate chezmoi sources with their own config and state
  (`~/.config/chezmoi-<name>/`). Apply the overlay first, then this repo
  (`dotfiles-apply`): templates here read files the overlay installs.

## Ownership

- `Brewfile` (shared) is curated by hand by the user: edit it only when asked,
  or when a shared config file needs a package to work (say so). Ad-hoc
  installs are recorded automatically by `bin/sync-brewfile.sh` into the
  overlay's `Brewfile`.
  Deleting an entry is how the user uninstalls: sync holds it back and
  `bin/brew-cleanup.sh` (on `chezmoi apply`) removes it.
- Settings files apps also write themselves are merged, not owned: VS Code
  and Claude Code `settings.json` come from `modify_` templates that lay
  `.chezmoitemplates/{vscode,claude}-settings.jsonc` and then the overlay's
  fragment over the live file. Change a shared setting in the
  `.chezmoitemplates` file; what the app writes stays and isn't drift. A key
  removed from the source stays in the live file until deleted there.
- `allowed_signers.tmpl` is composed with the overlay's fragment: edit the
  `.tmpl`; `chezmoi add`/`re-add` would flatten it.
- chezmoi's own files are YAML (the user prefers it over TOML), e.g.
  `.chezmoiexternals/*.yaml`. Tool config stays in the tool's own format
  (Starship and mise TOML): converting it would break `chezmoi edit`/`add`/
  `re-add` and tools that write their own config (`mise use`).

## Template gotchas

- Everything in `.chezmoiexternals/` is parsed as a template, even without
  `.tmpl`; so is `.chezmoi.yaml.tmpl`. Write comments there without `{{`.
- Missing map keys are errors: read optional keys with `get . "key"`.
- `include`/`glob` resolve against the source/destination; CI renders into an
  empty destination with `--no-pager` (delta isn't installed there).

## Verifying a change

Done means all of these hold:
1. Templates render without an overlay: `chezmoi apply --no-pager --dry-run
   --exclude=externals --destination <empty dir>` in a throwaway `HOME` (see
   `.github/workflows/ci.yml`).
2. `shellcheck bin/*.sh` is clean; `bin/` scripts run under macOS
   `/bin/bash` 3.2, so expand possibly-empty arrays as `${a[@]+"${a[@]}"}`.
   A change to the Brewfile sync logic comes with a case in `tests/` (bats,
   stubbed brew), and `bats tests/` passes.
   CI job names are required checks in the `main` ruleset: renaming a job
   means updating the ruleset.
3. On the machine: `chezmoi diff` shows only the intended change, then
   `chezmoi apply` and `chezmoi status` is empty.
4. CI on the pushed commit is green.

## Operating on the user's Mac

- `chezmoi apply <dir>` applies everything under that directory. To leave one
  file alone, pass file paths, never a parent directory.
- Restart the Dock with `launchctl kickstart -k gui/$(id -u)/com.apple.Dock.agent`:
  after a plain `killall Dock` it can stay down (no Dock, no Mission Control,
  no trackpad swipes).
- Removals go to `~/.Trash` (moved, not deleted); the user empties it.
- Commits are signed through 1Password. When signing fails non-interactively
  (`1Password: failed to fill whole buffer`), leave the changes staged and ask
  the user to run the commit with a `!` prefix.

## Decisions already made

The user settled these; build on them:
- Theme: Tokyo Night in Ghostty, VS Code (Catppuccin icons) and claude-statusbar
  (colour overrides in `~/.claude/claude-statusbar.json`; `cs` has no themes).
- git and `chezmoi diff` page through delta, side-by-side.
- Shell: no oh-my-zsh, no Powerlevel10k. Starship prompt (tokyo-night preset
  + kube, duration, herdr), plugins via antidote (`~/.config/zsh/plugins.txt`,
  overlays append their own list), only the oh-my-zsh alias sets for
  git/kubectl/brew/eza, zoxide as `cd` instead of wd bookmarks (`wd` aliases `cd`),
  fzf key bindings and completion (no option-as-alt in Ghostty, so no alt-c).
- Personal Mac: Node from Homebrew, no mise, no Java. Runtimes for work live
  in the work overlay.
- Docker: `colima` docker context; `DOCKER_HOST` is set only by the work overlay
  (Testcontainers needs it).
- SSH `WarnWeakCrypto no` applies only to RFC 1918 hosts.
- LaunchAgents only report or write into the machine's own files. One that
  only some Macs need lives in that Mac's overlay.
- Font: FiraCode Nerd Font Mono (Ghostty, VS Code); its cask is in the shared
  Brewfile because those configs name it.
- GNU tools only for typed commands (oh-my-zsh's gnu-utils hashes them); no
  gnubin in PATH, so scripts keep the macOS versions. Scripts that need GNU
  call it explicitly (`gsed`).
- XDG selectively, never by setting the XDG variables globally (that moves
  zoxide/k9s/helm data out of ~/Library). Go uses its own env file (GOBIN
  ~/.local/bin, GOPATH ~/.local/share/go); Rust RUSTUP_HOME/CARGO_HOME under
  ~/.local/share (old ~/.rustup/~/.cargo win where they exist); zsh, less and
  Python history in ~/.local/state. `.ssh`, `.docker`, `.kube`, `.gradle`,
  `.m2`, `.colima`, `.claude` stay put.
- PATH entries for tools not every Mac has carry the `(N)` qualifier in
  `path.zsh` (added only when the dir exists) instead of a per-machine
  template.
- Rust on the personal Mac via rustup (projects pin toolchains in
  `rust-toolchain.toml`); no default toolchain.
- bat pages `cat`, `--help` (the global alias buffers output first: `claude`
  touches the terminal while exiting) and man pages.
- Plugin settings (zstyles) are local files listed in `plugins.txt` right
  before their plugin (`eza.zsh`).
- A modern replacement takes over the classic name only where the typed
  habit keeps working: `cat`=bat, `top`=btop, `df`=duf (drops `-h`), `dig`=doggo
  (real dig for `+options` doggo lacks). fd, ripgrep, dust and tldr keep their
  own names.
