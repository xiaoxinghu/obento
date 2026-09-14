# -*- mode: shell-script -*-
# Login shell configuration

export BUN_INSTALL="$HOME/.bun"

# Drop straight into a multiplexer on SSH login. Runs here (login shell, before
# .zshrc) so it takes over ahead of p10k's instant prompt. Guards: interactive
# shell only (never scp/rsync/`ssh host cmd`), only over SSH (harmless on local
# terminals, incl. macOS), and not already inside a multiplexer (no nesting:
# tmux sets $TMUX, herdr sets $HERDR_ENV). On clean detach we `exit` so the SSH
# connection closes; if it can't start we fall through to a normal shell instead
# of locking you out.
if [[ -o interactive && -n "$SSH_CONNECTION" && -z "$TMUX" && -z "$HERDR_ENV" ]]; then
  # Linux: herdr, the agent-aware multiplexer (herdr.dev). It launches or
  # attaches to the persistent session, like `tmux new-session -A`.
  if [[ "$OSTYPE" == linux* ]] && command -v herdr &>/dev/null; then
    herdr && exit
  # Other platforms (and the herdr-missing fallback): tmux. `-A` attaches to
  # `main` if it exists, else creates it.
  elif command -v tmux &>/dev/null; then
    tmux new-session -A -s main && exit
  fi
fi
