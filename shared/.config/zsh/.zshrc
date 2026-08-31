# Disable Powerlevel10k instant prompt cache (it interferes with compinit)
export POWERLEVEL9K_INSTANT_PROMPT=off
unsetopt prompt_cr prompt_subst prompt_sp

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.config/zsh/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Platform-specific config (macos/ or linux/ provides ~/.config/zsh/platform.zsh).
[[ -r ${ZDOTDIR:-$HOME}/platform.zsh ]] && source ${ZDOTDIR:-$HOME}/platform.zsh

# Activate mise early so its tools (zoxide, direnv, carapace, eza, node, …) are
# on PATH for the rest of this file.
command -v mise >/dev/null && eval "$(mise activate zsh)"

fpath=(~/.config/zsh/functions $fpath)
autoload -Uz ~/.config/zsh/functions/*(N:t)

autoload -Uz compinit
compinit -C
zmodload zsh/complist
zstyle ':completion:*' menu select

# (Optional) Jump straight into the menu on first Tab
bindkey '^I' menu-select   # ^I is Tab

# ============================================================================
# Zsh plugins via antidote (cross-platform; replaces the Homebrew formulae).
# Clones antidote + plugins into XDG data dir, rebuilds a static bundle into the
# cache dir only when .zsh_plugins.txt changes, then sources it. Loads the
# powerlevel10k theme; ~/.config/zsh/.p10k.zsh below applies its config.
# ============================================================================
export ANTIDOTE_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/antidote/plugins"
antidote_src="${XDG_DATA_HOME:-$HOME/.local/share}/antidote/src"
[[ -e $antidote_src/antidote.zsh ]] ||
  git clone --depth=1 https://github.com/mattmc3/antidote.git "$antidote_src"
source "$antidote_src/antidote.zsh"

zsh_plugins_txt="${ZDOTDIR:-$HOME}/.zsh_plugins.txt"
zsh_plugins_zsh="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zsh_plugins.zsh"
if [[ ! $zsh_plugins_zsh -nt $zsh_plugins_txt ]]; then
  mkdir -p "${zsh_plugins_zsh:h}"
  antidote bundle <"$zsh_plugins_txt" >"$zsh_plugins_zsh"
fi
source "$zsh_plugins_zsh"

# Lines configured by zsh-newuser-install
HISTFILE=~/.config/zsh/.histfile
HISTSIZE=1000
SAVEHIST=1000
setopt autocd
bindkey -v
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename "${ZDOTDIR:-$HOME/.config/zsh}/.zshrc"

# ============================================================================
# ALIASES
# ============================================================================

alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'
alias lazyconfig='lazygit --git-dir=$HOME/.cfg/ --work-tree=$HOME'

# --- ls ---
alias ls="eza"
alias l="eza -lbF --git"         # list, size, type, git
alias ll="eza -lbGF --git"       # long list
alias llm="eza -lbGd --git --sort=modified"  # long list, modified date sort
alias la="eza -lbhHigmSa --time-style=long-iso --git --color-scale"  # all list
alias lx="eza -lbhHigUmuSa@ --time-style=long-iso --git --color-scale"  # all + extended list
alias lS="eza -1"                # one column, just names
alias lt="eza --tree --level=2"  # tree

# --- vim ---
alias v="nvim"
alias vv="nvim \$(fzf)"

# --- other tools ---
alias ta="tmux a"
alias s='sesh connect "$(sesh list | gum filter --limit 1 --placeholder "Pick a sesh" --prompt="⚡")"'
alias g="lazygit"
alias e="emacsclient"
alias man="batman"

# ============================================================================
# 4. Initialize completions FIRST
# ============================================================================

# 2) Arrow keys will now navigate; add vim-style hjkl too:
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'j' vi-down-line-or-history
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char

# (Optional) Accept with Ctrl-y (in menu) and execute immediately with Enter
bindkey -M menuselect '^Y' accept-search
bindkey -M menuselect '^M' .accept-line

# To customize prompt, run `p10k configure` or edit ~/.config/zsh/.p10k.zsh.
[[ ! -f ~/.config/zsh/.p10k.zsh ]] || source ~/.config/zsh/.p10k.zsh


GITSTATUS_LOG_LEVEL=DEBUG

eval "$(zoxide init zsh)"
command -v fzf >/dev/null && source <(fzf --zsh)
eval "$(direnv hook zsh)"

# --- key binds (history-substring-search; plugin loaded via antidote above) ---
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# load bun completions
if (( $+commands[bun] )); then
  [ -s ~/.bun/_bun ] || bun completions >| ~/.bun/_bun
  mkdir -p ~/.local/share/zsh/site-functions
  cp ~/.bun/_bun ~/.local/share/zsh/site-functions/_bun
  fpath+=(~/.local/share/zsh/site-functions)
fi

# autocompletion via carapace
export CARAPACE_BRIDGES='zsh,fish,bash,inshellisense' # optional
zstyle ':completion:*' format $'\e[2;37mCompleting %d\e[m'
source <(carapace _carapace)

zedz() {
  local dir
  dir="$(zoxide query -i "$@")" || return
  zed "$dir"
}

# Machine-local config (secrets, per-host tweaks). Not tracked.
[[ ! -f ~/.config/zsh/local.zsh ]] || source ~/.config/zsh/local.zsh
