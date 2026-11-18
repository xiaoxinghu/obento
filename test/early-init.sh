#!/usr/bin/env bash
# A first start must create the parent of package-quickstart-file before ELPA writes it.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
HOME="$tmp" OBENTO_TEST_EMACS_DIR="$tmp/emacs" emacs -Q --batch \
  --eval '(setq user-emacs-directory (file-name-as-directory (getenv "OBENTO_TEST_EMACS_DIR")))' \
  -l "$REPO/shared/.config/emacs/early-init.el" \
  --eval '(unless (file-directory-p (file-name-directory package-quickstart-file)) (error "Missing quickstart directory"))'
echo 'ok   fresh Emacs quickstart directory'
