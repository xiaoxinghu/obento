# -*- mode: shell-script -*-
# Environment variables sourced by all zsh instances (login, interactive,
# scripts). Bootstrapped from ~/.zshenv.

# TERM fallback for Ghostty over SSH. Ghostty advertises TERM=xterm-ghostty,
# which ssh forwards to the remote. Most servers (and pre-6.5 ncurses distros
# like current Ubuntu) lack that terminfo entry; without it zsh's line editor
# emits the wrong key sequences (one keypress echoes as several) and prompt
# styling breaks. If the entry is missing on this machine, fall back to a
# widely-known TERM so the shell stays usable. Auto-disables once the
# xterm-ghostty terminfo entry is installed (e.g. via Ghostty's ssh-terminfo).
if [[ $TERM == xterm-ghostty ]] && ! infocmp xterm-ghostty &>/dev/null; then
  export TERM=xterm-256color
fi

# PATH — Homebrew (Apple Silicon / Intel)
if [[ -d "/opt/homebrew/bin" ]]; then
    export PATH="/opt/homebrew/bin:$PATH"
elif [[ -d "/usr/local/bin" ]]; then
    export PATH="/usr/local/bin:$PATH"
fi

# Local user binaries
export PATH="$HOME/.local/bin:$PATH"

# Bun
export PATH="$HOME/.bun/bin:$PATH"

# mise shims — make mise-managed tools (rg, node, nvim, …) available to
# non-interactive shells and GUI apps (e.g. Emacs via exec-path-from-shell)
# that don't run `mise activate`. Interactive shells still prefer the real
# tool dirs that `mise activate` prepends in .zshrc.
export PATH="${XDG_DATA_HOME:-$HOME/.local/share}/mise/shims:$PATH"

# Rust / Cargo
[[ -d "$HOME/.cargo" ]] && . "$HOME/.cargo/env"

# Machine-local env (e.g. OBENTO_PATH, written by setup.sh). Not tracked.
[[ -f "${ZDOTDIR:-$HOME/.config/zsh}/local.zshenv" ]] && source "${ZDOTDIR:-$HOME/.config/zsh}/local.zshenv"
