# dotfiles

Personal macOS dotfiles and machine bootstrap, managed with [chezmoi](https://www.chezmoi.io/).

## What's in here

- Shell / terminal config: `.zshrc`, `.p10k.zsh`, `.tmux.conf`, `.warprc`
- Git config: `.gitconfig` + per-context includes (`.gitconfig_personal`, `.gitconfig_cegeka_ajh`, `.gitconfig_cegeka_vutg`)
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
- **Detect drift** (e.g. after changing something via System Settings):
  run `bin/sync-macos-defaults.sh`. It reads the *live* system state and
  overwrites `macos-defaults.tsv` with it — nothing is applied to the system
  and nothing is auto-committed. Run `git diff macos-defaults.tsv` to see
  exactly what changed, then either:
  - `git add -A && git commit` to **accept** the drift as the new desired state, or
  - `git checkout -- macos-defaults.tsv` to discard it and re-apply the old
    declared value (see caveat below).

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
defaults are set up automatically.

Notes:
- The `ajh/tap` Homebrew tap is a private work tap hosted on Bitbucket. It requires
  SSH access to Bitbucket to be configured first, otherwise `brew bundle install`
  will fail on that one tap (everything else will still install fine — rerun
  `brew bundle install` afterwards once Bitbucket SSH access works).
- Company-managed software (VPN client, MDM/Company Portal, Defender, printing, etc.)
  is intentionally NOT included here — that's provisioned by corporate IT/MDM.
- Secrets, SSH keys, kube/azure/docker credentials, etc. are deliberately NOT
  tracked here. Re-authenticate to those tools after bootstrapping.

## Day to day usage

```sh
# edit a tracked dotfile through chezmoi (keeps source + target in sync)
chezmoi edit ~/.zshrc

# see what would change
chezmoi diff

# apply local edits
chezmoi apply

# pull latest from git and apply
chezmoi update

# after installing/removing a brew package, refresh the Brewfile
chezmoi cd
brew bundle dump --force --file=Brewfile
git add Brewfile && git commit -m "Update Brewfile" && git push
```
