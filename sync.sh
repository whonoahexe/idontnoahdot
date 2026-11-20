#!/usr/bin/env bash
# Pulls the live configs from $HOME into this repo (the reverse of install.sh).
# The repo root is the machine and its apps (packages, /etc tweaks, helper scripts,
# app configs); glyph/ is the rice (see the Glyph section at the end and glyph/README.md).
# Run it, review `git diff`, then commit. The end4 setup this repo used to hold is
# kept at the end4-final tag.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

# Paths relative to $HOME. Directories are mirrored (files deleted at home are
# deleted here too); files are copied as-is.
PATHS=(
  .bashrc .bash_profile .gitconfig
  .config/ghostty .config/fontconfig .config/mpv
  .config/mimeapps.list .config/xdg-desktop-portal
  .config/MangoHud .config/brave-flags.conf
  .config/strata/settings.toml .config/strata/actions
  .config/systemd/user/audio-watchdog.service .config/systemd/user/audio-watchdog.timer
  .config/systemd/user/mouse-rgb.service
  .config/systemd/user/strata-patched-update.service .config/systemd/user/strata-patched-update.timer
  .local/bin/audio-watchdog .local/bin/gamemode-hook.sh
  .local/bin/mouse-rgb-watch .local/bin/strata-patched-update
  .local/bin/gh .local/bin/git-credential-gh-account
  .local/share/applications/io.github.lgse.Strata.desktop
  .local/share/dbus-1/services/io.github.lgse.Strata.FileManager1.service
  .local/share/icons/hicolor/scalable/apps/io.github.lgse.Strata.svg
  Pictures/Wallpapers/city-night-street
)

# System files under /etc (installed by bootstrap.sh with sudo). The hardware
# ones only go on the same laptop model (see HARDWARE_MODEL in bootstrap.sh).
SYSTEM_FILES=(
  /etc/gamemode.ini
  /etc/sysctl.d/99-gaming.conf /etc/sysctl.d/99-zram.conf
  /etc/systemd/zram-generator.conf
  /etc/systemd/logind.conf.d/no-auto-sleep.conf
  /etc/modprobe.d/v4l2loopback.conf
  /etc/bluetooth/main.conf
)
HARDWARE_FILES=(
  /etc/modprobe.d/mt7921e.conf
  /etc/systemd/system/nvidia-persistenced-boost.service
  /usr/local/bin/reboot-to-windows
)

# Packages: everything installed explicitly, minus the base system (comes from
# the Arch install), Plasma/end4 leftovers, linux-wallpaper-engine-ux (built
# locally, not on the AUR) and quickshell-git (extra's quickshell is new enough
# now). Glyph's own packages are hand-kept in packages/glyph.txt.
# Drivers/laptop tools go to hardware.txt.
PKG_SKIP='^(base|base-devel|linux|linux-firmware|linux-headers|amd-ucode|intel-ucode|efibootmgr|sudo|nano|man-db|yay|yay-bin|plasma-meta|linux-wallpaper-engine-ux|illogical-impulse-.*|quickshell-git)$'
PKG_HARDWARE='^(nvidia-.*|lib32-nvidia-utils|cuda|libva-nvidia-driver|asusctl|rog-control-center|v4l2loopback-dkms)$'

EXCLUDES=(--exclude '*.bak*' --exclude '*.old' --exclude '__pycache__' --exclude 'mpvpaper_thumbnails')

for p in "${PATHS[@]}"; do
  src="$HOME/$p"
  if [ ! -e "$src" ]; then
    echo "skip (missing at home): $p"
    continue
  fi
  mkdir -p "$(dirname "$p")"
  if [ -d "$src" ]; then
    # -L: copy what links point to
    rsync -aL --delete "${EXCLUDES[@]}" "$src/" "$p/"
  else
    cp -aL "$src" "$p"
  fi
done

# Files kept only in the repo across the wipe below: /etc/sudoers.d is root-only, so it
# can't be re-read here, and the NVIDIA early-load / modeset drop-ins were written for the
# fresh install (this machine has them in its hand-edited /etc/mkinitcpio.conf instead)
REPO_ONLY=(system/*/etc/sudoers.d system/hardware/etc/mkinitcpio.conf.d system/hardware/etc/modprobe.d/nvidia.conf)
keep="$(mktemp -d)"; cp -a --parents "${REPO_ONLY[@]}" "$keep" 2>/dev/null || true
rm -rf system && mkdir -p system/common system/hardware
cp -a "$keep/system" . 2>/dev/null || true; rm -rf "$keep"
for f in "${SYSTEM_FILES[@]}"; do [ -f "$f" ] && install -D -m 644 "$f" "system/common$f"; done
for f in "${HARDWARE_FILES[@]}"; do [ -f "$f" ] && install -D -m 644 "$f" "system/hardware$f"; done
systemctl list-unit-files --state=enabled --no-legend --type=service,socket \
  | awk '{print $1}' | grep -vE '^(getty@|autovt@|dbus-org\.)' > system/services.txt

mkdir -p packages
{ pacman -Qqen; pacman -Qqem; } | grep -vE "$PKG_SKIP" > packages/.all
grep -E "$PKG_HARDWARE" packages/.all > packages/hardware.txt || true
pacman -Qqen | grep -vE "$PKG_SKIP|$PKG_HARDWARE" > packages/pacman.txt || true
pacman -Qqem | grep -vE "$PKG_SKIP|$PKG_HARDWARE" > packages/aur.txt || true
rm packages/.all

# Strata: local patches on top of the upstream release tag. The commits carry
# private values (work identity, a real host in a test fixture), so they are
# rewritten with the find/replace rules in SCRUB, which is kept out of the repo
# so the values themselves are never published. No SCRUB, no patch refresh.
STRATA="$HOME/.local/src/strata"
SCRUB="$HOME/.config/idontnoahdot/scrub.sed"
if [ -d "$STRATA/.git" ] && [ ! -f "$SCRUB" ]; then
  echo "warning: $SCRUB missing; leaving strata/ patches as they are"
elif [ -d "$STRATA/.git" ]; then
  rm -rf strata && mkdir -p strata
  tag="$(git -C "$STRATA" describe --tags --abbrev=0 --match 'v*' local/ssh-hosts)"
  git -C "$STRATA" format-patch -q -o "$REPO_DIR/strata" "$tag..local/ssh-hosts"
  sed -i -f "$SCRUB" strata/*.patch
fi

# ---- Glyph: everything rice goes to glyph/, nothing to the root ----
# Glyph itself: Nebelung-cloud/glyph-rice at its upstream tag + our commits as patches
# (git am keeps them as commits, and the tags glyph-easing needs are recorded by number).
# home/ mirrors $HOME: files Glyph's repo doesn't carry (user.lua and machine/ are gitignored there),
# its settings, and the apps themed to match it. system/ = its pacman hooks.
GLYPH="$HOME/.local/share/glyph"
if [ -d "$GLYPH/.git" ]; then
  # system/ is not wiped: a hook kept here but not yet installed in /etc must not get lost
  rm -rf glyph/patches glyph/home && mkdir -p glyph/patches glyph/home
  gbase="$(git -C "$GLYPH" describe --tags --abbrev=0 --match 'v*' main)"
  # -N: no "[PATCH n/m]", so adding a commit doesn't rewrite every older patch
  git -C "$GLYPH" format-patch -q -N -o "$REPO_DIR/glyph/patches" "$gbase..noah-local"
  printf 'repo=%s\nbase=%s\nbranch=noah-local\n' "$(git -C "$GLYPH" remote get-url origin)" "$gbase" > glyph/glyph.base
  # "<tag> <n>": the tag sits on the n-th patch (glyph-easing reverts/cherry-picks ljs-easing)
  for t in $(git -C "$GLYPH" tag -l --no-merged "$gbase" --merged noah-local); do
    echo "$t $(git -C "$GLYPH" rev-list --count "$gbase..$t")"
  done > glyph/tags
  [ -z "$(git -C "$GLYPH" status --porcelain)" ] || echo "warning: uncommitted changes in $GLYPH are not in glyph/patches"
  GLYPH_HOME=(
    .local/share/glyph/config/hypr/user.lua
    .local/share/glyph/config/hypr/machine
    .config/gtk-3.0/bookmarks
    .local/state/rice/glyph.json
    .config/demonshot/rules.json
    .local/bin/glyph-easing
    .config/spicetify/Themes/glyph .config/spicetify/Extensions/glyph-move.js
    .local/share/brave-glyph-theme
    .config/apostrophe/glyph.css
    .config/strata/themes/glyph.toml
  )
  for p in "${GLYPH_HOME[@]}"; do
    [ -e "$HOME/$p" ] || { echo "skip (missing at home): $p"; continue; }
    mkdir -p "glyph/home/$(dirname "$p")"
    # Brave writes a binary "Cached Theme.pak" into an unpacked theme
    if [ -d "$HOME/$p" ]; then rsync -aL --delete "${EXCLUDES[@]}" --exclude 'Cached Theme.pak' "$HOME/$p/" "glyph/home/$p/"
    else cp -aL "$HOME/$p" "glyph/home/$p"; fi
  done
  for f in /etc/pacman.d/hooks/spicetify.hook /etc/pacman.d/hooks/apostrophe-glyph.hook; do
    [ -f "$f" ] && install -D -m 644 "$f" "glyph/system$f"
  done
fi

echo
git status --short
