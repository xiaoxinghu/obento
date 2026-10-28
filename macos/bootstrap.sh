#!/usr/bin/env bash
# Bootstrap a macOS machine from scratch, and keep it correct on re-runs.
#
# Self-contained: safe to pipe straight from a permalink into bash.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/xiaoxinghu/obento/main/macos/bootstrap.sh | bash
#
# Unlike the Linux bootstrap there's no user-creation/root ceremony: on macOS
# you're already your own user, and Homebrew (invoked by setup.sh) refuses to
# run as root. So this just:
#   1. ensures git exists (via the Xcode Command Line Tools),
#   2. clones this obento repo into $OBENTO_PATH (or updates it),
#   3. runs setup.sh.
# Idempotent: re-run any time to converge the machine to the desired state.
set -euo pipefail

# Overridable via environment.
REPO_URL="${REPO_URL:-https://github.com/xiaoxinghu/obento.git}"

if [[ $EUID -eq 0 ]]; then
  echo "Don't run as root on macOS; run as your normal user." >&2
  exit 1
fi

# ----- prereqs -----
# git ships with the Xcode Command Line Tools. On a fresh Mac they're absent
# (and /usr/bin/git is just a stub that pops the installer), so gate on the
# tools themselves. Trigger the GUI installer and ask for a re-run once done.
if ! xcode-select -p >/dev/null 2>&1; then
  echo "Installing Xcode Command Line Tools (needed for git)..."
  xcode-select --install || true
  echo "Finish the Command Line Tools install, then re-run this script." >&2
  exit 1
fi

# ----- clone -----
# Where the repo lives: $OBENTO_PATH if set, else where setup.sh recorded it on
# an earlier run, else the ws code layout. Move it later with `obento move`.
[[ -n "${OBENTO_PATH:-}" ]] || OBENTO_PATH="$(sed -n 's/^export OBENTO_PATH=//p' "$HOME/.config/zsh/local.zshenv" 2>/dev/null || true)"
DEST="${OBENTO_PATH:-$HOME/code/github.com/xiaoxinghu/obento}"
if [[ -d "$DEST/.git" ]]; then
  echo "Repo already at $DEST, updating..."
  git -C "$DEST" pull --ff-only
else
  echo "Cloning $REPO_URL -> $DEST"
  mkdir -p "$(dirname "$DEST")"
  git clone "$REPO_URL" "$DEST"
fi

# ----- setup -----
# setup.sh installs Homebrew + packages, stows dotfiles, and registers this
# machine's SSH key on GitHub. It may prompt for your password (sudo) and for
# GitHub auth; that's fine since you're running interactively.
echo "Running setup.sh..."
cd "$DEST" && ./setup.sh

echo "Done."
