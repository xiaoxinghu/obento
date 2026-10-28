#!/usr/bin/env bash
# shellcheck disable=SC2088 # "~/" in messages is display text
# Tests for `obento link`, `add` and `move`. Each case builds a throwaway repo
# inside a throwaway $HOME (with a space in it, to catch quoting), makes the
# kind of mess a long-lived machine collects, runs obento and checks the result.
#   test/link.sh            run all
#   test/link.sh t_move     run one
set -uo pipefail

OB="$(cd "$(dirname "$0")/.." && pwd)/shared/.local/bin/obento"
case "$(uname -s)" in Darwin) P=macos O=linux ;; *) P=linux O=macos ;; esac

# ----- helpers -----
sandbox() {
  T="$(mktemp -d)"
  export HOME="$T/my home" GIT_CONFIG_NOSYSTEM=1
  R="$HOME/code/obento"
  export OBENTO_PATH="$R"
  mkdir -p "$R" && git -C "$R" init -q
}
put() { mkdir -p "$(dirname "$R/$1")" && printf '%s\n' "${2:-$1}" >"$R/$1"; }  # put <repo path> [content]
mine() { mkdir -p "$(dirname "$HOME/$1")" && printf '%s\n' "$2" >"$HOME/$1"; } # mine <home path> <content>
ob() { "$OB" "$@" >"$T/out" 2>&1 || fail "obento $* exited non-zero: $(cat "$T/out")"; }

fail() { echo "    $*"; failed=1; }
link_to() { [[ "$(readlink "$HOME/$1")" == "$R/$2" ]] || fail "~/$1 -> '$(readlink "$HOME/$1")', want $2"; }
has() { [[ "$(cat "$HOME/$1" 2>&1)" == "$2" ]] || fail "~/$1 has '$(cat "$HOME/$1" 2>&1)', want '$2'"; }
real_dir() { [[ -d "$HOME/$1" && ! -L "$HOME/$1" ]] || fail "~/$1 is not a real dir"; }
absent() { [[ ! -e "$HOME/$1" && ! -L "$HOME/$1" ]] || fail "~/$1 should not exist"; }
no_backups() { local b; b="$(find "$HOME" -name '*.obento-bak*')"; [[ -z "$b" ]] || fail "unexpected backups: $b"; }
repo_clean() { local l; l="$(find "$R" -type l)"; [[ -z "$l" ]] || fail "links written into the repo: $l"; }
rerun_quiet() { ob link; [[ ! -s "$T/out" ]] || fail "re-run not quiet: $(cat "$T/out")"; }

# ----- fresh machine -----
t_fresh() {
  put shared/.zshenv
  put shared/.config/git/config
  put shared/.local/bin/tool
  put "$P/.config/emacs/init.el"
  put "$P/.config/emacs/.gitignore" '/var/'
  put "$P/.config/emacs/var/state"   # ignored runtime state, inside a whole dir
  put "$P/Brewfile"                  # package root, not a dotfile
  put "$O/.other"                    # the other platform
  ob link
  link_to .zshenv shared/.zshenv
  real_dir .config/git; link_to .config/git/config shared/.config/git/config
  real_dir .local/bin; link_to .local/bin/tool shared/.local/bin/tool
  link_to .config/emacs "$P/.config/emacs"
  absent Brewfile; absent .other
  rerun_quiet; no_backups; repo_clean
}

t_ignored_files_are_not_linked() {
  printf '.DS_Store\n' >"$R/.gitignore"
  put shared/.config/app/conf
  put shared/.config/app/.DS_Store
  ob link
  link_to .config/app/conf shared/.config/app/conf
  absent .config/app/.DS_Store
}

t_untracked_and_tracked_files_both_link() {
  put shared/.a; put shared/.b; git -C "$R" add shared/.a
  ob link
  link_to .a shared/.a; link_to .b shared/.b
}

t_nested_gitignore_links_outermost_dir() {
  put "$P/.config/emacs/.gitignore" '/elpa/'
  put "$P/.config/emacs/lisp/.gitignore" 'x'
  put "$P/.config/emacs/lisp/a.el"
  ob link
  link_to .config/emacs "$P/.config/emacs"
  no_backups
}

t_package_root_gitignore_is_just_a_file() {
  put shared/.gitignore 'x'
  put shared/.config/git/config
  ob link
  real_dir .config; link_to .config/git/config shared/.config/git/config
  absent shared
}

t_two_packages_share_a_dir() {
  put shared/.config/tmux/tmux.conf
  put "$P/.config/tmux/platform.conf"
  ob link
  real_dir .config/tmux
  link_to .config/tmux/tmux.conf shared/.config/tmux/tmux.conf
  link_to .config/tmux/platform.conf "$P/.config/tmux/platform.conf"
}

t_spaces_in_names() {
  put "shared/.config/my app/conf file"
  ob link
  link_to ".config/my app/conf file" "shared/.config/my app/conf file"
  rerun_quiet
}

# ----- migrating from stow -----
t_stow_relative_links_are_repointed() {
  put shared/.zshenv; put shared/.config/git/config
  ln -s code/obento/shared/.zshenv "$HOME/.zshenv"
  mkdir -p "$HOME/.config/git"; ln -s ../../code/obento/shared/.config/git/config "$HOME/.config/git/config"
  ob link
  link_to .zshenv shared/.zshenv; link_to .config/git/config shared/.config/git/config
  no_backups; rerun_quiet
}

t_stow_folded_dirs_are_split() {
  put shared/.local/bin/tool
  put shared/.config/lazygit/config.yml
  put "$P/.config/emacs/.gitignore" '/var/'
  mkdir -p "$HOME/.config"
  ln -s code/obento/shared/.local "$HOME/.local"
  ln -s ../code/obento/shared/.config/lazygit "$HOME/.config/lazygit"
  ln -s ../code/obento/"$P"/.config/emacs "$HOME/.config/emacs"
  ob link
  real_dir .local; real_dir .local/bin; link_to .local/bin/tool shared/.local/bin/tool
  real_dir .config/lazygit; link_to .config/lazygit/config.yml shared/.config/lazygit/config.yml
  link_to .config/emacs "$P/.config/emacs"
  no_backups; repo_clean; rerun_quiet
}

t_stow_folded_config_with_two_packages() {
  put shared/.config/git/config
  put "$P/.config/aerospace/aerospace.toml"
  ln -s code/obento/shared/.config "$HOME/.config"
  ob link
  real_dir .config
  link_to .config/git/config shared/.config/git/config
  link_to .config/aerospace/aerospace.toml "$P/.config/aerospace/aerospace.toml"
  no_backups; repo_clean
}

t_link_from_old_repo_location_is_repointed() {
  put shared/.zshenv
  ln -s /old/place/obento/shared/.zshenv "$HOME/.zshenv"
  ob link
  link_to .zshenv shared/.zshenv
  no_backups
}

# ----- things in the way: moved aside, never lost -----
t_real_file_is_moved_aside() {
  put shared/.zshenv
  mine .zshenv 'my zshenv'
  ob link
  link_to .zshenv shared/.zshenv
  has .zshenv.obento-bak 'my zshenv'
  rerun_quiet
}

t_backups_never_overwrite_backups() {
  put shared/.zshenv
  mine .zshenv first; ob link
  rm "$HOME/.zshenv"; mine .zshenv second; ob link
  has .zshenv.obento-bak first
  has .zshenv.obento-bak1 second
}

t_real_dir_where_whole_dir_goes() {
  put "$P/.hammerspoon/init.lua"
  put "$P/.hammerspoon/.gitignore" '/Spoons/'
  mine .hammerspoon/init.lua 'old config'
  ob link
  link_to .hammerspoon "$P/.hammerspoon"
  has .hammerspoon.obento-bak/init.lua 'old config'
}

t_old_links_in_a_dir_becoming_whole_are_cleared() {
  put "$P/.hs/init.lua"
  put "$P/.hs/.gitignore" '/Spoons/'
  mkdir -p "$HOME/.hs"; ln -s ../code/obento/"$P"/.hs/init.lua "$HOME/.hs/init.lua"  # stow, no state
  ob link
  link_to .hs "$P/.hs"
  no_backups
}

t_empty_dirs_in_the_way_are_just_removed() {
  put "$P/.hammerspoon/.gitignore" '/Spoons/'
  mkdir -p "$HOME/.hammerspoon/a/b"
  ob link
  link_to .hammerspoon "$P/.hammerspoon"
  no_backups
}

t_file_where_a_dir_should_be() {
  put shared/.config/git/config
  mine .config 'not a dir'
  ob link
  link_to .config/git/config shared/.config/git/config
  has .config.obento-bak 'not a dir'
}

t_foreign_link_at_target_is_moved_aside() {
  put shared/.zshenv
  mkdir -p "$T/elsewhere" && echo theirs >"$T/elsewhere/zshenv"
  ln -s "$T/elsewhere/zshenv" "$HOME/.zshenv"
  ob link
  link_to .zshenv shared/.zshenv
  has .zshenv.obento-bak theirs
}

t_dangling_links_in_the_way() {
  put shared/.zshenv; put shared/.config/git/config
  ln -s /nowhere "$HOME/.zshenv"
  ln -s /nowhere "$HOME/.config"
  ob link
  link_to .zshenv shared/.zshenv
  link_to .config/git/config shared/.config/git/config
  [[ "$(readlink "$HOME/.config.obento-bak")" == /nowhere ]] || fail "dangling ~/.config not kept as backup"
}

t_foreign_dir_link_as_parent_is_followed() {
  put shared/.config/git/config
  mkdir -p "$T/dropbox"; ln -s "$T/dropbox" "$HOME/.config"
  ob link
  [[ "$(readlink "$HOME/.config")" == "$T/dropbox" ]] || fail "~/.config link was changed"
  [[ "$(readlink "$T/dropbox/git/config")" == "$R/shared/.config/git/config" ]] || fail "not linked inside the followed dir"
  no_backups
}

t_runtime_files_next_to_linked_file_stay() {
  put shared/.config/herdr/config.toml
  mine .config/herdr/session.json '{}'
  ob link
  link_to .config/herdr/config.toml shared/.config/herdr/config.toml
  has .config/herdr/session.json '{}'
  [[ ! -e "$R/shared/.config/herdr/session.json" ]] || fail "runtime file got into the repo"
}

# ----- repo changes over time -----
t_file_removed_from_repo_is_unlinked() {
  put shared/.a; put shared/.b; git -C "$R" add shared
  ob link
  rm "$R/shared/.a"   # deleted, not yet committed
  ob link
  absent .a; link_to .b shared/.b
}

t_stale_path_now_holding_my_file_is_kept() {
  put shared/.a
  ob link
  rm "$HOME/.a" "$R/shared/.a"; mine .a 'my own'
  ob link
  has .a 'my own'
}

t_file_moved_between_packages() {
  put shared/.x
  ob link
  mkdir -p "$R/$P" && mv "$R/shared/.x" "$R/$P/.x"
  ob link
  link_to .x "$P/.x"
  no_backups; rerun_quiet
}

t_whole_dir_to_files_and_back() {
  put "$P/.hs/init.lua"
  put "$P/.hs/.gitignore" '/Spoons/'
  ob link
  link_to .hs "$P/.hs"
  rm "$R/$P/.hs/.gitignore"; ob link
  real_dir .hs; link_to .hs/init.lua "$P/.hs/init.lua"
  put "$P/.hs/.gitignore" '/Spoons/'; ob link
  link_to .hs "$P/.hs"
  no_backups; repo_clean
}

# ----- add / move -----
t_add_file() {
  mine .config/new.toml 'a=1'
  ob add "$HOME/.config/new.toml"
  link_to .config/new.toml "$P/.config/new.toml"
  has .config/new.toml 'a=1'
}

t_add_dir_links_its_files() {
  mine .app/conf 'c'
  ob add "$HOME/.app"
  real_dir .app; link_to .app/conf "$P/.app/conf"
}

t_move() {
  put shared/.zshenv
  put "$P/.hs/.gitignore" '/Spoons/'
  mkdir -p "$HOME/.config/zsh"
  ob link
  ob move "$HOME/src/obento"
  R="$HOME/src/obento"
  link_to .zshenv shared/.zshenv; link_to .hs "$P/.hs"
  [[ ! -e "$HOME/code/obento" ]] || fail "old repo path still there"
  grep -q "OBENTO_PATH=.*src/obento" "$HOME/.config/zsh/local.zshenv" || fail "OBENTO_PATH not updated"
  OBENTO_PATH="$R" rerun_quiet
}

# ----- runner -----
tests="${*:-$(declare -F | awk '$3 ~ /^t_/ {print $3}')}"
total=0 bad=0
for t in $tests; do
  total=$((total + 1))
  if (failed=0; sandbox; "$t"; rm -rf "$T"; exit "$failed"); then echo "ok   $t"; else echo "FAIL $t"; bad=$((bad + 1)); fi
done
echo "$((total - bad))/$total passed"
[[ $bad -eq 0 ]]
