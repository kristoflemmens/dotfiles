# Settings for oh-my-zsh's zoxide plugin; listed in plugins.txt right before
# it. zoxide takes over `cd` (and adds `cdi`, the fzf picker): real paths
# work as always, anything else jumps to the best match zoxide remembers.
ZOXIDE_CMD_OVERRIDE=cd

# Never remember temp dirs (Claude Code and other tools cd into them). Setting
# this replaces zoxide's default of $HOME, so that stays in the list. A glob
# * also matches /, so these cover every level below; macOS has each location
# under two names (/tmp and /private/tmp), and zoxide stores the one cd used.
export _ZO_EXCLUDE_DIRS="$HOME:/tmp:/tmp/*:/private/tmp:/private/tmp/*:/var/folders/*:/private/var/folders/*"
