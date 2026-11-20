#!/usr/bin/env bash
# Installs the Glyph rice (bootstrap.sh runs it after the root install.sh).
# Safe to re-run: what is already there is left alone or backed up first.
#
#   1. Glyph itself: Nebelung-cloud/glyph-rice at the tag in glyph.base, our commits
#      applied on branch noah-local (git am), and the tags glyph-easing uses
#   2. Glyph's own links into ~/.config (its upstream `install.sh --links`; anything in
#      the way goes to ~/.dots-backup-<date>)
#   3. home/ -> $HOME, file by file, existing different files backed up as .bak-<stamp>
#      (user.lua + machine/, Glyph's settings, and the Spotify/Brave/Apostrophe themes that match it)
#   4. system/ -> /etc (pacman hooks that keep the Spotify and Apostrophe themes
#      through updates), then the Apostrophe hook once
#   5. GTK look (gsettings)
#
# Glyph's packages and services are installed by ../bootstrap.sh (packages/glyph.txt),
# so only the --links part of its upstream installer is used.
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

# 2. Glyph's links: hypr, its shell, kitty, fish, starship, gtk.css, fonts...
"$GLYPH/install.sh" --links

# 3. files in $HOME
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

# 4. pacman hooks (sudo), then link the Apostrophe preview style once without reinstalling
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

# 5. GTK look: Glyph's links set dark mode + adw-gtk3-dark; the rest is mine
#    (icons "Rice" are built by the shell on first start)
if command -v gsettings >/dev/null; then
  gi=org.gnome.desktop.interface
  gsettings set $gi gtk-theme adw-gtk3-dark || true
  gsettings set $gi color-scheme prefer-dark || true
  gsettings set $gi icon-theme Rice || true
  gsettings set $gi cursor-theme Bibata-Modern-Classic || true
  gsettings set $gi cursor-size 23 || true
  gsettings set $gi font-name "Google Sans Flex 12" || true
fi

cat <<EOF

Glyph is installed. Still by hand:
  - Spotify:  start it and log in once, then: spicetify backup apply
  - Brave:    brave://extensions -> Developer mode -> Load unpacked -> ~/.local/share/brave-glyph-theme
              (once per profile)
  - Night Tab: settings -> Data -> Import -> $HERE/brave/nightTab-glyph.json
EOF
