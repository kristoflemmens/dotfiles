# dotfiles

Personal macOS dotfiles and machine bootstrap, managed with [chezmoi](https://www.chezmoi.io/).
Public and generic: nothing machine-, employer- or client-specific lives
here. That comes from a private overlay repo per Mac, personal or work (see
[Overlays](#overlays)).

## What's in here

- Shell: zsh without a framework. `.zshenv`, `.zprofile`, `.zshrc`,
  `~/.config/zsh/path.zsh` (PATH setup shared by `.zshenv` and `.zprofile`, see
  comments there). Prompt: Starship (`~/.config/starship.toml`, Tokyo Night
  preset plus kube context, command duration and herdr pane). `cd` jumps
  through zoxide (`cd homelab`; `cdi` picks with fzf, `wd` is an alias). fzf: ctrl-r searches history,
  ctrl-t inserts a file, `**<tab>` completes paths, processes and hosts.
- Replacements under the classic name: `cat` (bat), `top` (btop), `df` (duf),
  `dig` (doggo; `+trace` and other dig-only options run the real dig). Under
  their own name: `fd`, `rg`, `dust` (du), `tldr` (short examples per command).
- zsh plugins via antidote, listed in `~/.config/zsh/plugins.txt` (oh-my-zsh
  alias sets for git, kubectl, brew and eza without the framework,
  autosuggestions, syntax highlighting); an overlay adds
  `~/.config/dotfiles-overlay/zsh/plugins.txt`. `antidote update` updates the
  clones. Completions: zsh's own plus what Homebrew packages install.
- Git: `.gitconfig` (delta side-by-side as pager, Tokyo Night theme from `~/.config/bat/themes`), global ignore in `~/.config/git/ignore`, commit signing via
  1Password with `~/.ssh/allowed_signers` for verification, `~/.git-template`
  with a prek/pre-commit hook
- SSH client config (1Password agent, colima + `~/.ssh/config.d/*.conf` includes)
- lazygit (`~/.config/lazygit`, also on macOS): diffs through delta (settings from `.gitconfig`), and `e` from
  lazygit.nvim opens the file in the surrounding Neovim (`nvim-remote`)
- VS Code user settings, Ghostty, k9s, gh, colima template, OpenLogi (app
  settings and per-model mouse settings, merged into its config.toml), herdr
  (preferences merged into its config.toml)
- Rectangle: `RectangleConfig.json` (an export from Rectangle's settings),
  staged for Rectangle's own import by `run_onchange_after_05`
- Neovim: `~/.config/nvim` is cloned from the kickstart.nvim fork when missing
  (`.chezmoiexternals/nvim.yaml`) and never pulled; commit and push in the fork
- Agent skills, shared by every agent in `~/.agents/skills/` (see
  [Agent skills](#agent-skills))
- `Brewfile` (shared, curated by hand); each overlay adds its own, maintained by `bin/sync-brewfile.sh`
- `macos-defaults.tsv` — Dock, Finder, trackpad, keyboard defaults
- Scripts run by `chezmoi apply`:
  - `run_once_before_01` install Homebrew
  - `run_onchange_before_02` `bin/brew-bundle.sh`: `brew bundle install` for the shared `Brewfile`, then for each overlay's, then `bin/brew-cleanup.sh` offers to uninstall what no Brewfile declares any more. Overlays have no brew script of their own
  - `run_onchange_after_02` apply `macos-defaults.tsv`
  - `run_onchange_after_03` (re)load the LaunchAgents listed in `.chezmoidata.yaml`
  - `run_onchange_after_05` put `RectangleConfig.json` where Rectangle imports it
    on its next launch (after asking); re-export over the file to change it
  - `run_onchange_after_06` agent skills: `apm install --global`, then links every skill in `~/.agents/skills/` into `~/.claude/skills/`; runs when a skill list or the own skills of any source change
  - `run_onchange_after_08` sets the Docker CLI keys (colima context, buildx alias and plugin dir) plus the overlay's `credHelpers` in `~/.docker/config.json`, leaving the rest to Docker
  - `run_onchange_after_09` lets herdr install its integration (`herdr integration install`) for each coding agent the machine has (claude, opencode); herdr owns those hook/plugin files, so chezmoi doesn't keep them

## Agent skills

Every skill lives once in `~/.agents/skills/<name>/`, the location the agents
share. Claude Code only reads `~/.claude/skills/`, so `bin/link-claude-skills.sh`
(run by `run_onchange_after_06`) links each skill there (`~/.claude/skills/synced/`, which Claude itself
manages, is left alone).

- **Own skills:** in a chezmoi source under `dot_agents/skills/<name>/`, here
  for every Mac, in an overlay for one Mac.
- **Third-party skills:** installed by [APM](https://microsoft.github.io/apm/)
  at user scope (`~/.apm/apm.yml`, target `agent-skills`). The list for every
  Mac is `.chezmoitemplates/apm-deps.yaml`; an overlay adds its own in
  `~/.config/dotfiles-overlay/apm-deps.yaml`. `dot_apm/modify_apm.yml` owns
  the dependencies and targets in the manifest and leaves the rest to APM.
  Pin each entry (`owner/repo/skills/name#v1.0.0` or `#<sha>`). To add a skill,
  add it to a list and apply; an `apm install -g <pkg>` shows up as drift
  until it's in a list. A removed entry is uninstalled on the next apply.
  `apm outdated` / `apm update` find newer versions; bump the pin in the list.

## Bootstrap a new Mac

```sh
xcode-select --install
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply kristoflemmens
```

Homebrew, all CLI tools/casks, dotfiles, shell plugins and macOS defaults
are set up automatically.

## Bootstrap a Linux server

On Debian, as a user with passwordless sudo and zsh as login shell:

```sh
sudo apt-get install -y zsh build-essential procps curl file git
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin init --apply kristoflemmens
```

This installs Homebrew in `/home/linuxbrew`, the tools from `Brewfile.linux` and
the shell, git and editor config. Everything macOS-only is skipped (see
`.chezmoiignore`), and commits aren't signed. There is no overlay and no drift
detection: `chezmoi update` by hand.

### Overlays

Machine-specific config that doesn't belong in a public repo (personal
packages and hosts, a work identity, employer tools, client settings) lives in
a separate private repo per Mac, applied as
an independent chezmoi source **with its own config and state** after the base
bootstrap (by then 1Password, gh and SSH work, so cloning a private repo is no
chicken-and-egg problem). See that repo's README.

An overlay is found by its config, `~/.config/chezmoi-<name>/chezmoi.yaml`
(written by `chezmoi --config <that file> init`); its source dir is whatever
that config's `sourceDir` says. `bin/lib/overlays.sh` is the one place that
lists them (`dotfiles`, the Brewfile scripts and the drift check use it), and
`.zshrc` defines `chez<name>` for each: chezmoi with that overlay's own config
and state.

This repo never refers to a specific overlay. It reads these optional files
when they exist, all under `~/.config/dotfiles-overlay/`:

| Overlay file                                          | Used by                                                                                  |
| ----------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `gitconfig`                                           | `[include]` in `.gitconfig` (e.g. includeIf identities)                                  |
| `allowed_signers`                                     | appended to `~/.ssh/allowed_signers`                                                     |
| `vscode-settings.jsonc`                               | VS Code `settings.json`: a JSONC object merged over the shared ones                      |
| `claude-settings.jsonc`                               | `~/.claude/settings.json`: a JSONC object merged over the shared ones                    |
| `herdr-settings.toml`                                 | `~/.config/herdr/config.toml`: TOML tables merged over the shared ones                   |
| `zsh/zshenv.zsh`, `zsh/zprofile.zsh`, `zsh/zshrc.zsh` | sourced by the zsh files                                                                 |
| `zsh/plugins.txt`                                     | extra antidote bundles, appended to `~/.config/zsh/plugins.txt`                          |
| `apm-deps.yaml`                                       | extra third-party skills (`apm:` list), appended to the dependencies in `~/.apm/apm.yml` |
| `docker-config.json`                                  | a JSON object (its `credHelpers`) merged into `~/.docker/config.json` by `run_onchange_after_08` |
| `Brewfile` (in the overlay's source dir)               | installed by `bin/brew-bundle.sh` after the shared one; ad-hoc installs land here        |

Adding an overlay `<name>` to a Mac, after the base bootstrap, with 1Password's
SSH agent on (overlays are private and clone over SSH):

```sh
chezmoi --config ~/.config/chezmoi-<name>/chezmoi.yaml \
  --source ~/.local/share/chezmoi-<name> \
  init --apply git@github.com:<owner>/<repo>.git
exec zsh          # chez<name> now exists
dotfiles apply    # the base picks up the fragments and installs the overlay's Brewfile
dotfiles apply    # once more: overlay scripts that need a tool from that Brewfile
```

An overlay's own README lists only what it contains and what to do by hand
(sign-ins); everything about how it plugs in is here.

Because the base templates read overlay files, apply the overlay **first** and
the base second when both changed: `dotfiles apply` does this for every
overlay, `dotfiles update` pulls them all first (and fast-forwards the
Neovim config), `dotfiles status` shows what is left to apply in each.
`dotfiles-apply` and `dotfiles-update` are aliases for the first two.

## Day to day

```sh
chezmoi edit ~/.zshrc   # edit through chezmoi
chezmoi diff            # what would change
chezmoi apply           # apply
chezmoi update          # git pull + apply (base only)
dotfiles update         # every overlay and the base: pull, then apply
dotfiles status         # anything left to apply, per repo
```

## Drift detection

LaunchAgents (listed in `.chezmoidata.yaml`, plus any `com.kristoflemmens.dotfiles.*` agent an overlay installs) run at login and every 4 hours (logs in
`~/.local/state/dotfiles/logs/`, every line timestamped by `dotfiles timestamp`; macOS notification on changes). Nothing is ever
committed automatically.

| Script                        | What it does                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `bin/sync-brewfile.sh`        | Writes Homebrew drift into **this machine's own Brewfile**: the overlay's `Brewfile` (or only reports, without an overlay). New installs are appended, uninstalled entries removed. An entry you delete from a Brewfile is held back as an uninstall request (not re-added) until `chezmoi apply` uninstalls it or you decline. The shared `Brewfile` is curated by hand and never written; shared entries that aren't installed are only reported. |
| `bin/brew-cleanup.sh`         | Uninstalls what no Brewfile of this machine declares (shared + overlays) after brew asks; run by `bin/brew-bundle.sh`, or by hand. Without a terminal it only lists.                                                                                                                                                                                                                                                                            |
| `bin/sync-macos-defaults.sh`  | Writes live macOS defaults back into `macos-defaults.tsv` (`--check` to only report).                                                                                                                                                                                                                                                                                                                                                               |
| `bin/check-dotfiles-drift.sh` | Reports `chezmoi status` for this repo and every overlay (`bin/lib/overlays.sh`). Never writes.                                                                                                                                                                                                                                                                                                                                                            |

`tests/` holds bats tests (`bats tests/`, all in a throwaway HOME): the `bin/` scripts, with brew, chezmoi and defaults stubbed (`tests/helpers.bash`), the drift check with the real chezmoi, and `overlay-render.bats`, which renders this repo with the overlay fixture in `tests/fixtures/dotfiles-overlay/` so every template branch that reads an overlay runs.

`chezmoi update` pulls with `--autostash --rebase`, so uncommitted sync results
don't block it.

Resolving drift:

- **Homebrew:** review `chezmoi git diff` (or `chez<overlay> git diff`), commit, and
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
