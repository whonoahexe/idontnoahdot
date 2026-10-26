#!/usr/bin/env bash
# Restores these dotfiles into $HOME, file by file. A file that already exists
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

git ls-files .config .local Pictures .bashrc .bash_profile .gitconfig .gtkrc-2.0 | while read -r f; do
  copy_with_backup "$f" "$HOME/$f"
done

# end4-pC shell: pctrade's fork at the pinned commit + our patch on top
QS="$HOME/.config/quickshell/end4-pC"
. quickshell/end4-pC.base
if [ -e "$QS" ]; then
  echo "skipped end4-pC: $QS already exists (apply quickshell/end4-pC.patch by hand if needed)"
else
  git clone "$repo" "$QS"
  git -C "$QS" checkout -q -b local "$base"
  git -C "$QS" apply "$REPO_DIR/quickshell/end4-pC.patch"
  echo "installed end4-pC at $base with local changes (uncommitted in $QS)"
fi

systemctl --user daemon-reload
systemctl --user enable --now audio-watchdog.timer mouse-rgb.service strata-patched-update.timer || true

echo
echo "Done. Boot splash (plymouth/) is not installed automatically — see README.md."
