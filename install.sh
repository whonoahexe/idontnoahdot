#!/usr/bin/env bash
# Restores the shared dotfiles (apps, helper scripts, user units; not the rice,
# that's glyph/install.sh) into $HOME, file by file. A file that already exists
# and differs is backed up with a .bak-<timestamp> suffix first; anything else
# in the target folders is left alone.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
cd "$REPO_DIR"

copy_with_backup() {
  local src="$1" dst="$2"
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    cmp -s "$src" "$dst" && return
    mv "$dst" "$dst.bak-$STAMP"
    echo "backed up existing $dst -> $dst.bak-$STAMP"
  fi
  mkdir -p "$(dirname "$dst")"
  cp -a "$src" "$dst"
  echo "restored $dst"
}

git ls-files .config .local Pictures .bashrc .bash_profile .gitconfig | while read -r f; do
  copy_with_backup "$f" "$HOME/$f"
done

systemctl --user daemon-reload
systemctl --user enable --now audio-watchdog.timer mouse-rgb.service strata-patched-update.timer || true
