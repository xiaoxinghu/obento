#!/usr/bin/env bash
# Bootstrap platform-bound packages on Linux.
# Detects the distro package manager, installs platform packages, then
# bootstraps mise itself. Cross-platform CLI tools come from mise
# (shared/.config/mise/config.toml) and
# the zsh plugins/prompt are handled by antidote from .zshrc. Idempotent.
set -euo pipefail

# Run a command as root when we aren't already.
run() { if [[ $EUID -eq 0 ]]; then "$@"; else sudo "$@"; fi; }

# Echo the first supported package manager found on PATH.
detect_pm() {
  for pm in apt-get dnf pacman zypper apk; do
    command -v "$pm" >/dev/null 2>&1 && { echo "$pm"; return; }
  done
  echo "No supported package manager found" >&2
  exit 1
}

# ----- system packages -----
install_system() {
  case "$(detect_pm)" in
    apt-get) run apt-get update -y
             run apt-get install -y zsh git tmux pass gnupg curl ca-certificates build-essential ;;
    dnf)     run dnf install -y zsh git tmux pass gnupg2 curl ca-certificates gcc make ;;
    pacman)  run pacman -Syu --needed --noconfirm zsh git tmux pass gnupg curl base-devel ;;
    zypper)  run zypper install -y zsh git tmux pass gpg2 curl gcc make ;;
    apk)     run apk add zsh git tmux pass gnupg curl ca-certificates build-base ;;
  esac
}

# ----- mise -----
install_mise() {
  command -v mise >/dev/null 2>&1 && return
  echo "Installing mise..."
  curl -fsSL https://mise.run | sh
}

# ----- claude code -----
install_claude_code() {
  case "$(detect_pm)" in
    apt-get)
      run install -d -m 0755 /etc/apt/keyrings
      curl -fsSL https://downloads.claude.ai/keys/claude-code.asc |
        run tee /etc/apt/keyrings/claude-code.asc >/dev/null
      printf '%s\n' 'deb [signed-by=/etc/apt/keyrings/claude-code.asc] https://downloads.claude.ai/claude-code/apt/stable stable main' |
        run tee /etc/apt/sources.list.d/claude-code.list >/dev/null
      run apt-get update -y
      run apt-get install -y claude-code
      ;;
    dnf)
      cat <<'EOF' | run tee /etc/yum.repos.d/claude-code.repo >/dev/null
[claude-code]
name=Claude Code
baseurl=https://downloads.claude.ai/claude-code/rpm/stable
enabled=1
gpgcheck=1
gpgkey=https://downloads.claude.ai/keys/claude-code.asc
EOF
      run dnf install -y claude-code
      ;;
    apk)
      curl -fsSL https://downloads.claude.ai/keys/claude-code.rsa.pub |
        run tee /etc/apk/keys/claude-code.rsa.pub >/dev/null
      run sed -i '\|downloads.claude.ai/claude-code/apk/|d' /etc/apk/repositories
      printf '%s\n' 'https://downloads.claude.ai/claude-code/apk/stable' |
        run tee -a /etc/apk/repositories >/dev/null
      run apk update
      run apk add claude-code
      ;;
    *) echo "Claude Code package repo is only published for apt, dnf, and apk; skipping" ;;
  esac
}

install_system
install_claude_code
install_mise
