#!/usr/bin/env bash
# Bootstrap a Linux machine from scratch, and keep it correct on re-runs.
#
# Self-contained: safe to pipe straight from a permalink into bash. It reads
# interactive input from /dev/tty (not stdin), so `curl ... | bash` works.
#
# Usage (from a root shell):
#   curl -fsSL https://raw.githubusercontent.com/xiaoxinghu/obento/main/linux/bootstrap.sh | bash
# With sudo:
#   curl -fsSL <url> | sudo bash
# Non-interactive (provide the user up front, keeps env with -E):
#   curl -fsSL <url> | USERNAME=alice sudo -E bash
#
# It:
#   1. installs the bare minimum to proceed (git + sudo),
#   2. creates the requested user (in the sudo/wheel group) if missing,
#      copying root's authorized_keys and setting a password,
#   3. clones this obento repo into $OBENTO_PATH (or updates it),
#   4. runs setup.sh as that user,
#   5. sets zsh as that user's login shell.
# Idempotent: re-run any time to converge the machine to the desired state.
set -euo pipefail

# Overridable via environment.
REPO_URL="${REPO_URL:-https://github.com/xiaoxinghu/obento.git}"
USERNAME="${USERNAME:-}"
export DEBIAN_FRONTEND=noninteractive

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root (e.g. pipe into 'sudo bash')." >&2
  exit 1
fi

# Read a line from the controlling terminal even when this script arrives on
# stdin (curl ... | bash). Assigns into the named variable.
prompt() {
  local __var="$1" __msg="$2" __val=""
  [[ -r /dev/tty ]] || { echo "No terminal for input; set $__var via environment." >&2; exit 1; }
  read -rp "$__msg" __val < /dev/tty
  printf -v "$__var" '%s' "$__val"
}

# Echo the first supported package manager found on PATH.
detect_pm() {
  for pm in apt-get dnf pacman zypper apk; do
    command -v "$pm" >/dev/null 2>&1 && { echo "$pm"; return; }
  done
  echo "No supported package manager found" >&2
  exit 1
}

# The group that grants sudo differs by distro (Debian: sudo, RHEL/Arch: wheel).
sudo_group() {
  if   getent group sudo  >/dev/null; then echo sudo
  elif getent group wheel >/dev/null; then echo wheel
  else echo sudo; fi
}

# Install just enough to clone the repo and grant sudo.
install_prereqs() {
  case "$(detect_pm)" in
    apt-get) apt-get update -y && apt-get install -y git sudo ca-certificates ;;
    dnf)     dnf install -y git sudo ca-certificates ;;
    pacman)  pacman -Sy --needed --noconfirm git sudo ;;
    zypper)  zypper install -y git sudo ca-certificates ;;
    apk)     apk add git sudo ca-certificates ;;
  esac
}

# ----- user -----
[[ -n "$USERNAME" ]] || prompt USERNAME "Username to create/use: "
[[ -n "$USERNAME" ]] || { echo "Username cannot be empty" >&2; exit 1; }

install_prereqs

if id "$USERNAME" >/dev/null 2>&1; then
  echo "User '$USERNAME' already exists, skipping creation."
else
  echo "Creating user '$USERNAME'..."
  useradd -m -s /bin/bash "$USERNAME"
  usermod -aG "$(sudo_group)" "$USERNAME"

  NEW_HOME="$(getent passwd "$USERNAME" | cut -d: -f6)"

  # Carry over root's authorized_keys so SSH login keeps working.
  if [[ -f /root/.ssh/authorized_keys ]]; then
    echo "Copying root's authorized_keys to '$USERNAME'..."
    install -d -m 700 -o "$USERNAME" -g "$USERNAME" "$NEW_HOME/.ssh"
    install -m 600 -o "$USERNAME" -g "$USERNAME" \
      /root/.ssh/authorized_keys "$NEW_HOME/.ssh/authorized_keys"
  fi

  # Password is optional (key-based login already works); set it if we have a tty.
  if [[ -r /dev/tty ]]; then
    echo "Set a password for '$USERNAME':"
    passwd "$USERNAME" < /dev/tty
  else
    echo "No terminal; skipping password. Set one later: sudo passwd $USERNAME" >&2
  fi
fi

# ----- clone -----
USER_HOME="$(getent passwd "$USERNAME" | cut -d: -f6)"
# Where the repo lives: $OBENTO_PATH if set, else where setup.sh recorded it on
# an earlier run, else the ws code layout. Move it later with `obento move`.
[[ -n "${OBENTO_PATH:-}" ]] || OBENTO_PATH="$(sed -n 's/^export OBENTO_PATH=//p' "$USER_HOME/.config/zsh/local.zshenv" 2>/dev/null || true)"
DEST="${OBENTO_PATH:-$USER_HOME/code/github.com/xiaoxinghu/obento}"

if [[ -d "$DEST/.git" ]]; then
  echo "Repo already at $DEST, updating..."
  sudo -u "$USERNAME" git -C "$DEST" pull --ff-only
else
  echo "Cloning $REPO_URL -> $DEST"
  sudo -u "$USERNAME" mkdir -p "$(dirname "$DEST")"
  sudo -u "$USERNAME" git clone "$REPO_URL" "$DEST"
fi

# ----- setup -----
# setup.sh runs as $USERNAME and needs sudo (system packages). We're root and
# just created this user, so grant passwordless sudo for the duration of setup,
# then revoke it. Keeps the piped bootstrap non-interactive without weakening
# sudo permanently; a user running setup.sh standalone still gets prompted.
echo "Running setup.sh as '$USERNAME'..."
sudoers="/etc/sudoers.d/99-obento-setup"
printf '%s ALL=(ALL) NOPASSWD:ALL\n' "$USERNAME" >"$sudoers"
chmod 0440 "$sudoers"
trap 'rm -f "$sudoers"' EXIT
# Give setup.sh the terminal as stdin (bootstrap's own stdin is the curl pipe),
# so interactive steps inside it (e.g. `gh auth login --web`) can prompt you.
if [[ -r /dev/tty ]]; then
  sudo -u "$USERNAME" bash -c "cd '$DEST' && ./setup.sh" </dev/tty
else
  sudo -u "$USERNAME" bash -c "cd '$DEST' && ./setup.sh"
fi
rm -f "$sudoers"
trap - EXIT

# ----- default shell -----
# setup.sh (via linux/setup.sh) has now installed zsh; make it the login shell.
# We're still root here, so chsh needs no password. Idempotent.
ZSH_BIN="$(command -v zsh || true)"
if [[ -n "$ZSH_BIN" ]]; then
  grep -qxF "$ZSH_BIN" /etc/shells 2>/dev/null || echo "$ZSH_BIN" >> /etc/shells
  chsh -s "$ZSH_BIN" "$USERNAME"
fi

echo "Done. Log in as '$USERNAME' to start using the machine."
