# dotfiles

Personal macOS dotfiles and machine bootstrap, managed with [chezmoi](https://www.chezmoi.io/).

## What's in here

- Shell / terminal config: `.zshrc`, `.p10k.zsh`, `.tmux.conf`, `.warprc`
- Git config: `.gitconfig` + per-context includes (`.gitconfig_personal`, `.gitconfig_cegeka_ajh`, `.gitconfig_cegeka_vutg`)
- SSH client config (`.ssh/config`) — no keys or secrets, just client settings (1Password SSH agent, colima include)
- VS Code user `settings.json`
- `Brewfile` — every Homebrew tap/formula/cask this machine needs
- `.tool-versions` — runtime versions (Java, Node), installed via [mise](https://mise.jdx.dev/)
- `run_once_*` scripts — executed automatically, exactly once, by `chezmoi apply`:
  - Install Homebrew if missing
  - `brew bundle install` from the `Brewfile`
  - `mise install` for the runtimes in `.tool-versions`
  - Apply macOS system defaults (Dock, Finder, trackpad, keyboard, screenshots)

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
