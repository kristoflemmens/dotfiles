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
- `Brewfile` (shared) + `Brewfile.<profile>`
- `~/.config/mise/config.toml` — global runtimes (Java, Node, pnpm)
- `macos-defaults.tsv` — Dock, Finder, trackpad, keyboard defaults
- Scripts run by `chezmoi apply`:
  - `run_once_before_01` install Homebrew
  - `run_onchange_before_02` `brew bundle install` for `Brewfile` and `Brewfile.<profile>`
  - `run_onchange_after_01` `mise install`
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

Three LaunchAgents run at login and every 4 hours and **only report** drift
(macOS notification + log in `~/.local/share/chezmoi-logs/`). None of them
write into this repo, so the working tree stays clean and `chezmoi update`
always works, and machines with different profiles never overwrite each
other's state.

| Script | Checks |
|---|---|
| `bin/check-dotfiles-drift.sh` | `chezmoi status` for this repo and every overlay with a config in `~/.config/chezmoi-*/` |
| `bin/sync-brewfile.sh` | installed Homebrew packages vs. `Brewfile` + `Brewfile.<profile>` + overlay Brewfiles |
| `bin/sync-macos-defaults.sh` | live macOS defaults vs. `macos-defaults.tsv` (`--write` accepts the live values into the file) |

Resolving drift:

- **Dotfiles:** `chezmoi add <path>` to keep the live change, or
  `chezmoi apply <path>` to restore the declared one. Files composed from
  overlay fragments (VS Code settings, `.warprc`, `allowed_signers`) must be
  edited in the right repo, never with `chezmoi re-add`.
- **Homebrew:** add the package to the right Brewfile (shared, profile or
  overlay) and commit, or `brew uninstall` it. `brew bundle install` never
  removes packages.
- **macOS defaults:** `bin/sync-macos-defaults.sh --write`, review and commit;
  or revert the system (below).

### Forcing a run_onchange script

chezmoi re-runs a `run_onchange_` script only when its rendered content's hash
changes; it never inspects the live system. After reverting a file to a
previously applied state, force a re-run with:

```sh
chezmoi state delete-bucket --bucket=scriptState
chezmoi apply
```

## Gotchas

- `.chezmoi.yaml.tmpl` contains the merge command with literal `{{ .Target }}`
  placeholders wrapped in a raw string, so they survive `chezmoi init` and are
  evaluated by chezmoi at merge time.
- Don't manage `~/.config/chezmoi/chezmoi.yaml` itself: it's generated by
  `chezmoi init` from `.chezmoi.yaml.tmpl`.
