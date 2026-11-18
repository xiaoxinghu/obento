#!/usr/bin/env bash
# Bootstrap an Omarchy machine, and keep it correct on re-runs.
#
# Self-contained: safe to pipe straight from a permalink into bash.
#
# Usage (as your normal user, on a machine installed from the Omarchy ISO):
#   curl -fsSL https://raw.githubusercontent.com/xiaoxinghu/obento/main/omarchy/bootstrap.sh | bash
#
# The ISO has already made the user and installed git, so, like the macOS
# bootstrap, this just:
#   1. clones this obento repo into $OBENTO_PATH (or updates it),
#   2. runs setup.sh.
# Idempotent: re-run any time to converge the machine to the desired state.
set -euo pipefail

# Overridable via environment.
REPO_URL="${REPO_URL:-https://github.com/xiaoxinghu/obento.git}"

if [[ $EUID -eq 0 ]]; then
  echo "Don't run as root on Omarchy; run as your normal user." >&2
  exit 1
fi
if [[ ! -d /usr/share/omarchy ]]; then
  echo "This machine is not Omarchy; use linux/bootstrap.sh." >&2
  exit 1
fi

# ----- clone -----
# Where the repo lives: $OBENTO_PATH if set, else where setup.sh recorded it on
# an earlier run, else ~/.obento, tied to no layout. Move it later with `obento move`.
[[ -n "${OBENTO_PATH:-}" ]] || OBENTO_PATH="$(sed -n 's/^export OBENTO_PATH=//p' "$HOME/.config/zsh/local.zshenv" 2>/dev/null || true)"
DEST="${OBENTO_PATH:-$HOME/.obento}"
if [[ -d "$DEST/.git" ]]; then
  echo "Repo already at $DEST, updating..."
  git -C "$DEST" pull --ff-only
else
  echo "Cloning $REPO_URL -> $DEST"
  mkdir -p "$(dirname "$DEST")"
  git clone "$REPO_URL" "$DEST"
fi

# ----- setup -----
# setup.sh installs packages (sudo asks for your password), links dotfiles and
# registers this machine's SSH key on GitHub. Give it the terminal as stdin
# (this script's own stdin is the curl pipe), so its interactive steps can ask.
echo "Running setup.sh..."
cd "$DEST"
if [[ -r /dev/tty ]]; then ./setup.sh </dev/tty; else ./setup.sh; fi

echo "Done. Log out and back in for zsh to be your login shell."
