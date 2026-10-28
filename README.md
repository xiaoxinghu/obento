# Obento 🍱 (お弁当)

> A neatly packed box of dotfiles and tools that sets up a Linux/macOS box *just the way I like it* — one command, everything in its place.

Like a bento, it's opinionated and pre-portioned: run the bootstrap and your machine comes out prepped and ready to eat. 🥢

## Setup

macOS (run as your normal user):

```sh
curl -fsSL https://raw.githubusercontent.com/xiaoxinghu/obento/main/macos/bootstrap.sh | bash
```

Linux (run from a root shell):

```sh
curl -fsSL https://raw.githubusercontent.com/xiaoxinghu/obento/main/linux/bootstrap.sh | bash
```

The repo goes to `~/code/github.com/xiaoxinghu/obento`. To put it elsewhere, set
`OBENTO_PATH`, e.g. `curl ... | OBENTO_PATH=~/dotfiles bash`. Re-runs find it
where it is.

## Usage

After setup, the `obento` command is on your `PATH` (and `$OBENTO_PATH` points
at this repo):

```sh
obento update            # git pull + re-run setup.sh (aborts on conflicts)
obento add <path>        # move a config into the current platform and stow it
obento move <dest>       # move this repo and repoint every link (under $HOME)
```

Example:

```sh
obento add ~/.config/seth/seth.toml
```
