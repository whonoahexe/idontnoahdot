#!/usr/bin/env bash
# Installs the Glyph rice next to end4 (bootstrap.sh runs it after the root install.sh).
# Safe to re-run: what is already there is left alone or backed up first.
#
#   1. Glyph itself: Nebelung-cloud/glyph-rice at the tag in glyph.base, our commits
#      applied on branch noah-local (git am), and the tags glyph-easing uses
#   2. home/ -> $HOME, file by file, existing different files backed up as .bak-<stamp>
#      (user.lua, Glyph's settings, and the Spotify/Brave/Apostrophe themes that match it)
#   3. system/ -> /etc (pacman hooks that keep the Spotify and Apostrophe themes
#      through updates), then the Apostrophe hook once
#   4. rice-switch init: Glyph's links into ~/.local/share/rices/glyph (end4 stays active)
#
# Glyph's own upstream install.sh is not used: it links straight into ~/.config, which
# rice-switch manages. Its packages are in ../packages like everything else.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GLYPH="$HOME/.local/share/glyph"
STAMP="$(date +%Y%m%d-%H%M%S)"
. "$HERE/glyph.base"

# 1. the shell
if [ -d "$GLYPH/.git" ]; then
  echo "skipped Glyph clone: $GLYPH already exists (git am $HERE/patches/*.patch there by hand if needed)"
else
  git clone -q "$repo" "$GLYPH"
  git -C "$GLYPH" checkout -q -B "$branch" "$base"
  git -C "$GLYPH" -c user.name="$(git config user.name || echo noah)" -c user.email="$(git config user.email || echo noah@localhost)" \
    am -q --committer-date-is-author-date "$HERE"/patches/*.patch
  # tags by patch number: "<tag> <n>" = the n-th commit after the base
  while read -r tag n; do
    [ -n "$tag" ] && git -C "$GLYPH" tag -f "$tag" "$(git -C "$GLYPH" rev-list --reverse "$base..$branch" | sed -n "${n}p")" >/dev/null
  done < "$HERE/tags"
  echo "installed Glyph at $base + $(ls "$HERE"/patches/*.patch | wc -l) commits on $branch"
fi

# 2. files in $HOME
cd "$HERE/home"
find . \( -type f -o -type l \) -print0 | while IFS= read -r -d '' f; do
  dst="$HOME/${f#./}"
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && ! cmp -s "$f" "$dst"; then
    mv "$dst" "$dst.bak-$STAMP"
    echo "backed up existing $dst -> $dst.bak-$STAMP"
  fi
  [ -e "$dst" ] || { cp -a "$f" "$dst"; echo "restored $dst"; }
done

# 3. pacman hooks (sudo), then link the Apostrophe preview style once without reinstalling
#    Apostrophe (a reinstall is a partial upgrade when the system has pending updates)
cd "$HERE/system"
find etc -type f | while read -r f; do
  sed "s#/home/noah#$HOME#g" "$f" | sudo install -D -m 644 /dev/stdin "/$f"
  echo "installed /$f"
done
d=/usr/share/apostrophe/media/css/web
if [ -d "$d" ]; then
  sudo ln -sfn "$HOME/.config/apostrophe/glyph.css" "$d/glyph.css"
  grep -q "glyph.css" "$d/adwaita.css" || sudo sed -i '1a @import url("glyph.css");' "$d/adwaita.css"
  echo "linked the Glyph style into Apostrophe"
fi

# Spotify: point Spicetify at the glyph theme and the Move-to-top extension. Applying needs
# Spotify started and logged in once, so that part is left to you (see below)
if command -v spicetify >/dev/null; then
  spicetify -q config current_theme glyph color_scheme Glyph inject_theme_js 1 || true
  # "config extensions X" appends: only once
  grep -q 'glyph-move.js' "$(spicetify -c)" || spicetify -q config extensions glyph-move.js || true
fi

# 4. Glyph's side of rice-switch (links only; the active rice doesn't change)
if [ -x "$HOME/.local/bin/rice-switch" ]; then   # restored by the root install.sh
  "$HOME/.local/bin/rice-switch" init
else
  echo "rice-switch not found in ~/.local/bin: run the root install.sh, then rice-switch init"
fi

cat <<EOF

Glyph is installed next to end4. Still by hand:
  - switch:   rice-switch glyph --logout   (and rice-switch end4 to go back)
  - Spotify:  start it and log in once, then: spicetify backup apply
  - Brave:    brave://extensions -> Developer mode -> Load unpacked -> ~/.local/share/brave-glyph-theme
              (once per profile)
  - Night Tab: settings -> Data -> Import -> $HERE/brave/nightTab-glyph.json
EOF
