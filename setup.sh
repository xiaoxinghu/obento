#!/usr/bin/env bash
# Set up this machine. Runs the platform bootstrap (native packages + mise),
# symlinks dotfiles into $HOME with GNU stow (shared + the matching platform
# package), then installs the cross-platform CLI tools with mise. Idempotent.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$(uname -s)" in
  Darwin) PLATFORM="macos" ;;
  Linux)  PLATFORM="linux" ;;
  *) echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac

# ----- setup platform -----
if [[ -x "$REPO/$PLATFORM/setup.sh" ]]; then
  "$REPO/$PLATFORM/setup.sh"
fi

# ----- config -----
pkgs=(shared)
[[ -d "$REPO/$PLATFORM" ]] && pkgs+=("$PLATFORM")

# Make ~/.local/bin a real dir before stow, so stow can't fold ~/.local into a
# single symlink into the repo (that would swallow ~/.local/share/obento and
# mise's ~/.local/{bin,share}). The obento command lives in shared/.local/bin.
install -d "$HOME/.local/bin"

# Same guard for pi: keep ~/.pi/agent (and its extensions/skills dirs) as real
# dirs so stow links individual entries instead of folding the whole tree into
# the repo — that would swallow auth.json, sessions/, and herdr's extension, and
# lets machine-local extensions/skills coexist with the stowed ones.
install -d "$HOME/.pi/agent/extensions" "$HOME/.pi/agent/skills"

echo "Stowing: ${pkgs[*]} -> $HOME"
stow --dir="$REPO" --target="$HOME" --restow --verbose "${pkgs[@]}"

# ----- expose repo location -----
# Persist $OBENTO_PATH so the `obento` command (and anything else) can find this
# repo regardless of cwd. Written to a machine-local, untracked zshenv that
# ~/.config/zsh/.zshenv sources. Idempotent: the OBENTO_PATH line is rewritten.
local_env="$HOME/.config/zsh/local.zshenv"
install -d "$(dirname "$local_env")"
tmp="$(mktemp)"
[[ -f "$local_env" ]] && grep -v '^export OBENTO_PATH=' "$local_env" >"$tmp" || true
printf 'export OBENTO_PATH=%q\n' "$REPO" >>"$tmp"
mv "$tmp" "$local_env"

# ----- tools -----
# Cross-platform CLI tools are declared in shared/.config/mise/config.toml,
# which stow just linked to ~/.config/mise/config.toml. Install them.
# Include the mise shims dir so mise-managed tools (gh, …) resolve below.
export PATH="$HOME/.local/bin:${XDG_DATA_HOME:-$HOME/.local/share}/mise/shims:/opt/homebrew/bin:/usr/local/bin:$PATH"
if command -v mise >/dev/null 2>&1; then
  echo "Installing tools with mise..."
  mise install -y
fi

# ----- github ssh key -----
# Give this machine its own SSH key on GitHub (per-machine, never shared). The
# first run does a one-time web/device login; re-runs skip whatever is already
# in place. Needs gh (from mise, above), so this stays after `mise install`.
if command -v gh >/dev/null 2>&1; then
  key="$HOME/.ssh/id_ed25519"
  # If gh is already authenticated, leave that session alone. Only start the
  # one-time login on a fresh machine, and only when running interactively.
  if ! gh auth status >/dev/null 2>&1; then
    if [[ -t 0 ]]; then
      gh auth login --hostname github.com --git-protocol ssh --skip-ssh-key --web -s admin:public_key || true
    else
      echo "warning: gh is not authenticated; skipping GitHub SSH key registration" >&2
    fi
  fi
  if gh auth status >/dev/null 2>&1; then
    if gh ssh-key list >/dev/null 2>&1; then
      install -d -m 700 "$HOME/.ssh"
      [[ -f "$key" ]] || ssh-keygen -t ed25519 -N '' -C "$(whoami)@$(hostname)" -f "$key"
      pub="$(awk '{print $2}' "$key.pub")"
      gh ssh-key list 2>/dev/null | grep -qF "$pub" ||
        gh ssh-key add "$key.pub" --title "$(hostname)" ||
        echo "warning: could not add SSH key to GitHub" >&2
    else
      echo "warning: gh is authenticated but cannot list SSH keys; skipping GitHub SSH key registration" >&2
    fi
  fi
fi
