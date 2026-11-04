# Dotfiles

The language of this repo and the private overlays that sit on top of it on
each Mac.

## Language

**Base**:
This public repo: everything every machine shares.
_Avoid_: main repo, shared repo, dotfiles (for this repo alone)

**Overlay**:
A private chezmoi source with its own config and state, applied on top of
the base on one Mac (personal or work).
_Avoid_: profile, flavour, private repo

**Overlay register**:
The list of overlays on a machine, known by their configs; the one place
anything asks "which overlays are there?".
_Avoid_: overlay discovery, overlay glob

**Fragment**:
A file an overlay installs under `~/.config/dotfiles-overlay/` that a base
template includes when present.
_Avoid_: hook file, snippet, overlay config

**Merged file**:
A settings file an app also writes itself, laid over by the base and the
overlay's fragment instead of owned.
_Avoid_: managed settings, owned file

**Own Brewfile**:
The Brewfile of this machine's overlay, where ad-hoc installs are recorded.
_Avoid_: personal Brewfile, local Brewfile

**Shared Brewfile**:
The base's Brewfile, curated by hand.
_Avoid_: main Brewfile, common Brewfile
