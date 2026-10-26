# dotfiles

Personal macOS dotfiles and machine bootstrap, managed with [chezmoi](https://www.chezmoi.io/).
Public and generic: nothing employer- or client-specific lives here (see
[work overlay](#on-a-work-mac-a-second-private-overlay)).

## Profiles

`chezmoi init` asks once for a machine **profile** (`personal` or `work`) and
stores it in the generated `~/.config/chezmoi/chezmoi.yaml` (from
`.chezmoi.yaml.tmpl`). Templates use `.profile` for the few differences between
machines (extra Brewfile, `.warprc` bookmarks). Change it with
`chezmoi init --promptChoice "Machine profile=work"`.

## What's in here

- Shell: `.zshenv`, `.zprofile`, `.zshrc`, `.p10k.zsh`, `~/.config/zsh/path.zsh`
  (PATH setup shared by `.zshenv` and `.zprofile`, see comments there)
- oh-my-zsh and third-party zsh plugins via `.chezmoiexternal.toml` (refreshed
  weekly by `chezmoi apply`). Own plugins go in `dot_config/oh-my-zsh-custom/plugins/`
  (`ZSH_CUSTOM`). Plugins listed in `.zshrc` that aren't installed are skipped.
- Git: `.gitconfig`, global ignore in `~/.config/git/ignore`, commit signing via
  1Password with `~/.ssh/allowed_signers` for verification, `~/.git-template`
  with a prek/pre-commit hook
- SSH client config (1Password agent, colima + `~/.ssh/config.d/*.conf` includes)
- VS Code user settings, Ghostty, k9s, gh, colima template, `.warprc`
- `Brewfile` (shared, curated by hand) + `Brewfile.personal` (maintained by `bin/sync-brewfile.sh`); work packages live in the private overlay
- `~/.config/mise/config.toml` — runtimes (Java, Node, pnpm), **work profile only**; mise itself is installed by the work overlay's Brewfile. Personal Macs use Homebrew Node and no mise.
- `macos-defaults.tsv` — Dock, Finder, trackpad, keyboard defaults
- Scripts run by `chezmoi apply`:
  - `run_once_before_01` install Homebrew
  - `run_onchange_before_02` `brew bundle install` for `Brewfile` and `Brewfile.<profile>`
  - `run_onchange_after_01` `mise install` (work profile only)
  - `run_onchange_after_02` apply `macos-defaults.tsv`
  - `run_onchange_after_03` (re)load the LaunchAgents listed in `.chezmoidata.yaml`

## Bootstrap a new Mac

```sh
xcode-select --install
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply kristoflemmens
```

Homebrew, all CLI tools/casks, runtimes, dotfiles, oh-my-zsh and macOS defaults
are set up automatically.

### On a work Mac: a second, private overlay

Employer/client-specific config lives in a separate private repo, applied as an
independent chezmoi source **with its own config and state** after the base
bootstrap (by then 1Password, gh and SSH work, so cloning a private repo is no
chicken-and-egg problem). See that repo's README.

The overlay integrates through optional files under `~/.config/work-overlay/`
that templates here include when present, plus `~/.*.work` shell hooks:

| Overlay file | Used by |
|---|---|
| `gitconfig/includeif-work.conf` | `[include]` in `.gitconfig` |
| `ssh/allowed_signers` | appended to `~/.ssh/allowed_signers` |
| `vscode/settings.fragment.jsonc` | appended to VS Code `settings.json` |
| `warprc/entries.txt` | appended to `~/.warprc` |
| `~/.zshenv.work`, `~/.zprofile.work`, `~/.zshrc.work`, `~/.zshrc.work.plugins` | sourced by the zsh files |

Because the base templates read overlay files, apply the overlay **first** and
the base second when both changed (`dotfiles-apply` in the overlay does this).

## Day to day

```sh
chezmoi edit ~/.zshrc   # edit through chezmoi
chezmoi diff            # what would change
chezmoi apply           # apply
chezmoi update          # git pull + apply
```

## Drift detection

LaunchAgents (listed in `.chezmoidata.yaml`, optionally per profile) run at login and every 4 hours (logs in
`~/.local/share/chezmoi-logs/`, macOS notification on changes). Nothing is ever
committed automatically.

| Script | What it does |
|---|---|
| `bin/sync-brewfile.sh` | Writes Homebrew drift into **this machine's own Brewfile**: the private overlay's `Brewfile` on `profile=work`, `Brewfile.personal` on `profile=personal`. New installs are appended, uninstalled entries removed. The shared `Brewfile` is curated by hand and never written; shared entries that aren't installed are only reported. |
| `bin/sync-macos-defaults.sh` | Writes live macOS defaults back into `macos-defaults.tsv` (`--check` to only report). |
| `bin/prune-app-logs.sh` | *Personal profile only.* Deletes Reolink desktop client SDK logs older than 24h (~3 GB/day, no setting in the app). |
| `bin/check-dotfiles-drift.sh` | Reports `chezmoi status` for this repo and every overlay with a config in `~/.config/chezmoi-*/`. Never writes. |

`chezmoi update` pulls with `--autostash --rebase`, so uncommitted sync results
don't block it.

Resolving drift:

- **Homebrew:** review `chezmoi git diff` (or `chezcegeka git diff`), commit, and
  move packages you want everywhere to the shared `Brewfile` yourself.
- **macOS defaults:** review `chezmoi git diff -- macos-defaults.tsv` and commit,
  or discard and force a re-apply (below).
- **Dotfiles:** `chezmoi add <path>` to keep the live change, or
  `chezmoi apply <path>` to restore the declared one. Files composed from
  overlay fragments (VS Code settings, `.warprc`, `allowed_signers`) must be
  edited in the right repo, never with `chezmoi re-add`.

### Forcing a run_onchange script

chezmoi re-runs a `run_onchange_` script only when its rendered content's hash
changes; it never inspects the live system. After reverting a file to a
previously applied state, forget that one script's state and apply again:

```sh
chezmoi state delete --bucket=entryState --key="$HOME/02-macos-defaults.sh"
chezmoi apply
```

## Gotchas

- `.chezmoi.yaml.tmpl` contains the merge command with literal `{{ .Target }}`
  placeholders wrapped in a raw string, so they survive `chezmoi init` and are
  evaluated by chezmoi at merge time.
- `sync-macos-defaults.sh` doesn't write while chezmoi still has to run the
  macOS defaults script (after a pull or an apply with `--exclude=scripts`):
  the live values are stale then, not drift.
- Don't manage `~/.config/chezmoi/chezmoi.yaml` itself: it's generated by
  `chezmoi init` from `.chezmoi.yaml.tmpl`.
