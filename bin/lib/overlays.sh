# The overlay register: the one place that knows how overlays are found.
# Sourced by the bin/ scripts. An overlay is a chezmoi source with its own
# config in ~/.config/chezmoi-<name>/chezmoi.yaml; its source dir is what
# that config says (`chezmoi source-path`), wherever it lives. Sets, in the
# same order (by name):
#   overlay_names    the <name> of each config, e.g. personal
#   overlay_configs  their config files
#   overlay_sources  their source dirs
# DOTFILES_CHEZMOI is the chezmoi to call (tests point it at a stub). In a
# script chezmoi runs, that is the running chezmoi (CHEZMOI_EXECUTABLE: on a
# new Mac it need not be on PATH yet); never CHEZMOI, which chezmoi sets to 1.
# shellcheck shell=bash disable=SC2034

DOTFILES_CHEZMOI="${DOTFILES_CHEZMOI:-${CHEZMOI_EXECUTABLE:-chezmoi}}"

overlay_names=()
overlay_configs=()
overlay_sources=()
for _config in "${HOME}"/.config/chezmoi-*/chezmoi.yaml; do
  [ -f "$_config" ] || continue
  _dir="${_config%/chezmoi.yaml}"
  overlay_names+=("${_dir##*/chezmoi-}")
  overlay_configs+=("$_config")
  overlay_sources+=("$("$DOTFILES_CHEZMOI" --config "$_config" source-path)")
done
unset _config _dir
