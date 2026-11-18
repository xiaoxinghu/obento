#!/usr/bin/env bash
# Set up the Omarchy-bound parts: the packages in omarchy/packages, zsh as the
# login shell, and Omarchy's seeded Neovim config moved out of the way. mise
# ships with Omarchy; cross-platform CLI tools come from it
# (shared/.config/mise/config.toml). Run as your normal user. Idempotent.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ----- packages -----
# omarchy-pkg-add installs what is missing and never upgrades the system:
# Omarchy stops a direct `pacman -Syu`, upgrades go through `omarchy update`.
# shellcheck disable=SC2046 # one word per package name
omarchy-pkg-add $(grep -o '^[^#[:space:]]\+' "$HERE/packages")

# ----- default shell -----
# Omarchy's login shell is bash; its desktop session takes its environment
# from uwsm, not from the shell, so zsh can take over.
zsh_bin="$(command -v zsh)"
if [[ "$(getent passwd "$(id -un)" | cut -d: -f7)" != "$zsh_bin" ]]; then
  sudo chsh -s "$zsh_bin" "$(id -un)"
fi
# The user manager can survive logout, and uwsm never imports SHELL. Update
# both activation environments so newly started terminals see the new shell.
# Existing terminal processes still need to be quit, or use `exec zsh -l`.
if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
  dbus-update-activation-environment --systemd "SHELL=$zsh_bin"
fi

# ----- neovim -----
# Omarchy seeds a whole Neovim config. obento links its own files one by one
# into that dir, which would leave the two mixed, so the seeded one goes aside
# first. Once init.lua is obento's link there is nothing left to move.
nvim="$HOME/.config/nvim"
if [[ -d "$nvim" && ! -L "$nvim" && ! -L "$nvim/init.lua" ]]; then
  n=""
  while [[ -e "$nvim.obento-bak$n" ]]; do n=$((n + 1)); done
  mv "$nvim" "$nvim.obento-bak$n"
  echo "moved aside: $nvim.obento-bak$n"
fi
