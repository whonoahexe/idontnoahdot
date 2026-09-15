#!/usr/bin/env bash
# Restores these dotfiles into $HOME. Existing files/dirs are backed up
# with a .bak-<timestamp> suffix rather than overwritten silently.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"

copy_with_backup() {
  local src="$1" dst="$2"
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mv "$dst" "$dst.bak-$STAMP"
    echo "backed up existing $dst -> $dst.bak-$STAMP"
  fi
  mkdir -p "$(dirname "$dst")"
  cp -r "$src" "$dst"
  echo "restored $dst"
}

for src in "$REPO_DIR"/.config/*; do
  name="$(basename "$src")"
  copy_with_backup "$src" "$HOME/.config/$name"
done

for name in .bashrc .bash_profile .gitconfig .gtkrc-2.0; do
  copy_with_backup "$REPO_DIR/$name" "$HOME/$name"
done

echo
echo "Done. Boot splash (plymouth/) is not installed automatically — see README.md."
