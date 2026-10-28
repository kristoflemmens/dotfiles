# dotfiles

Personal macOS dotfiles and machine bootstrap, managed with [chezmoi](https://www.chezmoi.io/).
Public and generic: nothing employer- or client-specific lives here. Work
config comes from a private overlay repo (see
[Overlays](#overlays-eg-a-work-mac)).

## Personal or not

`chezmoi init` asks once whether this is a **personal Mac** and stores the
answer in the generated `~/.config/chezmoi/chezmoi.yaml` (from
`.chezmoi.yaml.tmpl`). It only switches personal extras on: `Brewfile.personal`,
the Reolink log-pruning agent and a few VS Code preferences. Change it with `chezmoi init --promptBool "Personal Mac=false"`.

## What's in here

- Shell: zsh without a framework. `.zshenv`, `.zprofile`, `.zshrc`,
  `~/.config/zsh/path.zsh` (PATH setup shared by `.zshenv` and `.zprofile`, see
  comments there). Prompt: Starship (`~/.config/starship.toml`, Tokyo Night
  preset plus kube context, command duration and herdr pane). `z` (zoxide)
  for jumping between directories.
- zsh plugins via antidote, listed in `~/.config/zsh/plugins.txt` (oh-my-zsh
  alias sets for git, kubectl, brew and eza without the framework,
  autosuggestions, syntax highlighting); an overlay adds
  `~/.config/dotfiles-overlay/zsh/plugins.txt`. `antidote update` updates the
  clones. Completions: zsh's own plus what Homebrew packages install.
- Git: `.gitconfig` (delta side-by-side as pager, Tokyo Night theme from `~/.config/bat/themes`), global ignore in `~/.config/git/ignore`, commit signing via
  1Password with `~/.ssh/allowed_signers` for verification, `~/.git-template`
  with a prek/pre-commit hook
- SSH client config (1Password agent, colima + `~/.ssh/config.d/*.conf` includes)
- VS Code user settings, Ghostty, k9s, gh, colima template
- `Brewfile` (shared, curated by hand) + `Brewfile.personal` (personal Macs, maintained by `bin/sync-brewfile.sh`)
- `macos-defaults.tsv` — Dock, Finder, trackpad, keyboard defaults
- Scripts run by `chezmoi apply`:
  - `run_once_before_01` install Homebrew
  - `run_onchange_before_02` `brew bundle install` for `Brewfile` (+ `Brewfile.personal` on personal Macs), then `bin/brew-cleanup.sh` offers to uninstall what no Brewfile declares any more
  - `run_onchange_after_02` apply `macos-defaults.tsv`
  - `run_onchange_after_03` (re)load the LaunchAgents listed in `.chezmoidata.yaml`

## Bootstrap a new Mac

```sh
xcode-select --install
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply kristoflemmens
```

Homebrew, all CLI tools/casks, dotfiles, shell plugins and macOS defaults
are set up automatically.

### Overlays (e.g. a work Mac)

Machine-specific config that doesn't belong in a public repo (a work identity,
employer tools, client settings) lives in a separate private repo, applied as
an independent chezmoi source **with its own config and state** after the base
bootstrap (by then 1Password, gh and SSH work, so cloning a private repo is no
chicken-and-egg problem). See that repo's README.

This repo never refers to a specific overlay. It reads these optional files
when they exist, all under `~/.config/dotfiles-overlay/`:

| Overlay file | Used by |
|---|---|
| `gitconfig` | `[include]` in `.gitconfig` (e.g. includeIf identities) |
| `allowed_signers` | appended to `~/.ssh/allowed_signers` |
| `vscode-settings.jsonc` | appended to VS Code `settings.json` |
| `zsh/zshenv.zsh`, `zsh/zprofile.zsh`, `zsh/zshrc.zsh` | sourced by the zsh files |
| `zsh/plugins.txt` | extra antidote bundles, appended to `~/.config/zsh/plugins.txt` |
| `~/.local/share/chezmoi-*/Brewfile` | declared packages for `bin/sync-brewfile.sh` |

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

LaunchAgents (listed in `.chezmoidata.yaml`; `personal: true` limits one to personal Macs) run at login and every 4 hours (logs in
`~/.local/share/chezmoi-logs/`, macOS notification on changes). Nothing is ever
committed automatically.

| Script | What it does |
|---|---|
| `bin/sync-brewfile.sh` | Writes Homebrew drift into **this machine's own Brewfile**: `Brewfile.personal` on a personal Mac, otherwise the overlay's `Brewfile` (or only reports, without either). New installs are appended, uninstalled entries removed. An entry you delete from a Brewfile is held back as an uninstall request (not re-added) until `chezmoi apply` uninstalls it or you decline. The shared `Brewfile` is curated by hand and never written; shared entries that aren't installed are only reported. |
| `bin/brew-cleanup.sh` | Uninstalls what no Brewfile of this machine declares (shared + personal + overlays) after brew asks; run by `run_onchange_before_02`, or by hand. Without a terminal it only lists. |
| `bin/sync-macos-defaults.sh` | Writes live macOS defaults back into `macos-defaults.tsv` (`--check` to only report). |
| `bin/prune-app-logs.sh` | *Personal Macs only.* Deletes Reolink desktop client SDK logs older than 24h (~3 GB/day, no setting in the app). |
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
  overlay fragments (VS Code settings, `allowed_signers`) must be
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
