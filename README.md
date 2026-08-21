# dotfiles

Personal macOS dotfiles and machine bootstrap, managed with [chezmoi](https://www.chezmoi.io/).

## What's in here

- Shell / terminal config: `.zshrc`, `.p10k.zsh`, `.tmux.conf`, `.warprc`
- Git config: `.gitconfig` + a `.gitconfig_personal` include (employer/client-specific
  includes are added by a private work overlay, see below)
- SSH client config (`.ssh/config`) — no keys or secrets, just client settings (1Password SSH agent, colima include)
- VS Code user `settings.json`
- `Brewfile` — every Homebrew tap/formula/cask this machine needs
- `.tool-versions` — runtime versions (Java, Node), installed via [mise](https://mise.jdx.dev/)
- `run_once_*` / `run_onchange_*` scripts — executed automatically by `chezmoi apply`:
  - Install Homebrew if missing (`run_once_` — a true one-time bootstrap step)
  - `brew bundle install` from the `Brewfile` (`run_onchange_` — re-runs whenever
    the Brewfile changes, so adding/removing a package and running
    `chezmoi apply` actually reconciles the machine)
  - `mise install` for the runtimes in `.tool-versions` (`run_onchange_`, same idea)
  - Apply macOS system defaults — Dock, Finder, trackpad, keyboard, screenshots
    (`run_onchange_` — edit the script, commit, `chezmoi apply`, and the new
    defaults get applied; this is how macOS settings are "tracked" here)

Note: `run_onchange_` only re-applies when the *declared* state (this repo)
changes. It does not detect drift if you change a setting manually via System
Settings afterwards — there's no continuous enforcement, only "declare once,
re-apply when you edit the declaration". For always-on drift correction you'd
need something like nix-darwin, which was a deliberate trade-off (see repo history/PR discussion).

### Tracking macOS defaults & detecting drift

`macos-defaults.tsv` is the single source of truth for macOS system defaults
(Dock, Finder, trackpad, keyboard). Both the apply script
(`run_onchange_after_02-macos-defaults.sh.tmpl`) and the drift-sync helper
(`bin/sync-macos-defaults.sh`) read/write this one file.

- **Declare a new desired value:** edit `macos-defaults.tsv`, `chezmoi apply`.
- **Detect drift** (e.g. after changing something via System Settings): this
  happens **automatically** — a LaunchAgent
  (`Library/LaunchAgents/com.kristoflemmens.dotfiles.sync-macos-defaults.plist`)
  runs `bin/sync-macos-defaults.sh` at login and every 4 hours, so you don't
  have to remember to run it yourself. It reads the *live* system state and
  overwrites `macos-defaults.tsv` with it — nothing is applied to the system
  and nothing is auto-committed. If it finds drift, you'll get a macOS
  notification; run `chezmoi git diff -- macos-defaults.tsv` (works from
  anywhere, no need to `cd` into the repo) to see exactly what changed, then either:
  - `chezmoi git add -A` then `chezmoi git -- commit -m "..."` to **accept** the drift as the new desired state, or
  - `chezmoi git checkout -- macos-defaults.tsv` to discard it and re-apply the old
    declared value (see caveat below).
  - Run it manually any time with `~/.local/share/chezmoi/bin/sync-macos-defaults.sh`,
    or force an immediate run with
    `launchctl kickstart -k gui/$(id -u)/com.kristoflemmens.dotfiles.sync-macos-defaults`.
  - Logs: `~/.local/share/chezmoi-logs/sync-macos-defaults.log`.

**Important caveat:** `chezmoi apply` only re-runs a script when its rendered
content's hash differs from the hash it last recorded as applied. If you
revert `macos-defaults.tsv` to a value that was already applied *before* the
drift happened, the hash will match a value chezmoi has already seen, so
`chezmoi apply` (even with `--force`) will think there is nothing to do —
even though the live system still has the drifted value. Chezmoi never
inspects the actual system state, only the hash of what it last wrote.
To force a real re-apply in that situation:

```sh
chezmoi state delete --bucket=entryState --key="$HOME/02-macos-defaults.sh"
chezmoi apply --force
```

## Bootstrap a new Mac

```sh
xcode-select --install

# install chezmoi and apply this repo in one go
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply kristoflemmens
```

That's it. Homebrew, all CLI tools/casks, Java/Node via mise, dotfiles, and macOS
defaults are set up automatically. This repo is intentionally generic and
public: it contains nothing employer- or client-specific, so it works
unmodified on a personal Mac too.

### On a work Mac: a second, private overlay

Employer/client-specific config (work git identity, employer-specific CLI
tools, a client project's VS Code settings) lives in a **separate, private**
overlay repo, applied as its own independent chezmoi source, on top of this
one:

```sh
chezmoi --source ~/.local/share/chezmoi-work \
  --config ~/.config/chezmoi/chezmoi-work.toml \
  init --apply <private-overlay-repo-url>
```

Run this *after* the base bootstrap above — by then Homebrew, 1Password and
`gh` are already installed, so authenticating to the private repo (via the
1Password SSH agent or `gh auth login`) is no longer a chicken-and-egg
problem. See that repo's README for details, including an important
ordering caveat around VS Code settings.


Notes:
- A private Homebrew tap is used for some employer-specific CLI tools. It
  requires SSH access to the tap's host to be configured first, otherwise
  `brew bundle install` will fail on that one tap (everything else will
  still install fine — rerun `brew bundle install` afterwards once access
  works).
- Company-managed software (VPN client, MDM/Company Portal, Defender, printing, etc.)
  is intentionally NOT included here — that's provisioned by corporate IT/MDM.
- Secrets, SSH keys, kube/azure/docker credentials, etc. are deliberately NOT
  tracked here. Re-authenticate to those tools after bootstrapping.

## Day to day usage

On work machines where the private overlay creates
`~/.config/work-overlay/vscode/managed-by-work`, this repo intentionally
ignores `Library/Application Support/Code/User/settings.json` so the private
repo can own it end-to-end via the "externally modified file" symlink pattern.

```sh
# edit a tracked dotfile through chezmoi (keeps source + target in sync)
chezmoi edit ~/.zshrc

# see what would change
chezmoi diff

# apply local edits
chezmoi apply

# pull latest from git and apply
chezmoi update
```

Gotcha: `~/.config/chezmoi/chezmoi.yaml` contains literal `{{ ... }}` in the
`merge.args` command. Those placeholders are meant for chezmoi *at merge runtime*
and must stay literal text in the config file. So add/manage this file as a
normal file (`dot_config/chezmoi/chezmoi.yaml`), **not** as a template
(`--template` / `.tmpl`), otherwise chezmoi will try to evaluate `.Target` /
`.Source` while applying the file and fail.

### Tracking installed Homebrew packages & detecting drift

Same idea as the macOS defaults above: `Brewfile` is the single source of
truth for taps/formulae/casks/VS Code extensions. The apply script
(`run_onchange_before_02-brew-bundle.sh.tmpl`) pushes it to the system
(`brew bundle install`). `bin/sync-brewfile.sh` does the reverse: it runs
`brew bundle dump` and writes the result back into `Brewfile`, so ad-hoc
`brew install`/`brew uninstall` shows up as a normal diff instead of
silently drifting from what's declared.

- Runs **automatically** via a LaunchAgent (at login + every 4 hours), same
  as the macOS-defaults sync. Logs: `~/.local/share/chezmoi-logs/sync-brewfile.log`.
- Run it manually any time with `~/.local/share/chezmoi/bin/sync-brewfile.sh`.
- Nothing is installed/uninstalled and nothing is auto-committed — review
  with `chezmoi git diff -- Brewfile` (works from anywhere), then
  `chezmoi git add -A` + `chezmoi git -- commit -m "..."` to accept, or
  `chezmoi git checkout -- Brewfile && chezmoi apply` to revert the system instead.
- If a private work overlay repo is also applied on this machine, its own
  Brewfile's entries are automatically excluded here, so work-specific
  packages never leak into this public Brewfile just because they're
  installed on the same machine. If you install something ad hoc that
  actually belongs in the work overlay, move it there yourself after
  reviewing the diff (this happened during development of this feature —
  see git history).
- Same `chezmoi state delete --bucket=entryState --key=...` caveat as the
  macOS defaults applies here too, if you ever need to force a real re-apply
  after reverting `Brewfile` to a previously-seen value.

### Detecting drift in everything else (plain dotfiles)

`.zshrc`, `.tool-versions`, k9s/gh/ssh config, etc. don't have
a dedicated sync script like the two above — they're plain files chezmoi
manages directly, so `chezmoi status`/`chezmoi diff` already shows drift
between the live file and what's declared here. The problem was that nobody
was actually running that check regularly. `bin/check-dotfiles-drift.sh`
closes that gap: it runs `chezmoi status` and sends a macOS notification if
anything differs, via the same LaunchAgent pattern (login + every 4 hours,
logs in `~/.local/share/chezmoi-logs/check-dotfiles-drift.log`).

This one is **notification-only**, unlike the two above: it never writes
anything back automatically. `chezmoi re-add` (which would pull all live
changes back into the source repo) is deliberately not used here, because
some files may be intentionally managed by the private work overlay instead of
this public repo (for example VS Code settings) — blindly re-adding live state
here could leak private overlay content into the public repo. When notified,
review with
`chezmoi diff` and handle drift file-by-file: `chezmoi add <path>` to pull a
real edit back into the source, or `chezmoi apply <path>` to overwrite the
live file back to the declared state.
