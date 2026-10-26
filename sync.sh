#!/usr/bin/env bash
# Pulls the live configs from $HOME into this repo (the reverse of install.sh).
# Run it, review `git diff`, then commit. Personal values (weather city) are
# redacted, and the end4-pC shell is stored as a patch on top of pctrade's fork.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

# Paths relative to $HOME. Directories are mirrored (files deleted at home are
# deleted here too); files are copied as-is.
PATHS=(
  .bashrc .bash_profile .gitconfig .gtkrc-2.0
  .config/hypr
  .config/matugen
  .config/illogical-impulse/config.json
  .config/illogical-impulse/presets
  .config/fish .config/kitty .config/foot .config/ghostty .config/starship.toml
  .config/zshrc.d
  .config/gtk-3.0 .config/gtk-4.0 .config/gtkrc .config/gtkrc-2.0
  .config/Kvantum .config/kde-material-you-colors/config.conf .config/darklyrc
  .config/fontconfig .config/xsettingsd .config/QtProject.conf .config/Trolltech.conf
  .config/fuzzel .config/wlogout .config/cava .config/mpv .config/yazi
  .config/mimeapps.list .config/xdg-desktop-portal
  .config/xkb .config/MangoHud .config/brave-flags.conf
  .config/strata/settings.toml .config/strata/actions
  .config/systemd/user/audio-watchdog.service .config/systemd/user/audio-watchdog.timer
  .config/systemd/user/mouse-rgb.service .config/systemd/user/linux-wallpaperengine.service
  .config/systemd/user/strata-patched-update.service .config/systemd/user/strata-patched-update.timer
  .local/bin/audio-watchdog .local/bin/suspend-unless-docked .local/bin/gamemode-hook.sh
  .local/bin/mouse-rgb-watch .local/bin/claude-usage .local/bin/strata-patched-update
  .local/bin/gh .local/bin/git-credential-gh-account
  .local/share/applications/io.github.lgse.Strata.desktop
  .local/share/dbus-1/services/io.github.lgse.Strata.FileManager1.service
  .local/share/icons/hicolor/scalable/apps/io.github.lgse.Strata.svg
  .local/state/quickshell/user/generated/colors.json
  .local/state/quickshell/user/generated/color.txt
  .local/state/quickshell/user/generated/material_colors.scss
  .local/state/quickshell/user/generated/terminal
  .local/state/quickshell/user/generated/wallpaper
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
)
HARDWARE_FILES=(
  /etc/modprobe.d/mt7921e.conf
  /etc/systemd/system/nvidia-persistenced-boost.service
)

# Packages: everything installed explicitly, minus the base system (comes from
# the Arch install), end-4's own meta packages (its installer handles them),
# Plasma leftovers, and linux-wallpaper-engine-ux (built locally, not on the AUR).
# Drivers/laptop tools go to hardware.txt.
PKG_SKIP='^(base|base-devel|linux|linux-firmware|linux-headers|amd-ucode|intel-ucode|efibootmgr|sudo|nano|man-db|yay|yay-bin|plasma-meta|linux-wallpaper-engine-ux|illogical-impulse-.*)$'
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
    rsync -a --delete "${EXCLUDES[@]}" "$src/" "$p/"
  else
    cp -a "$src" "$p"
  fi
done

rm -rf system && mkdir -p system/common system/hardware
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

# Redact personal values from the shell config and presets
for f in .config/illogical-impulse/config.json .config/illogical-impulse/presets/*.json; do
  [ -f "$f" ] || continue
  jq '(.bar.weather.city? // empty) |= ""' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done

# end4-pC: the fork's upstream commit + our local changes as one patch
QS="$HOME/.config/quickshell/end4-pC"
if [ -d "$QS/.git" ]; then
  mkdir -p quickshell
  base="$(git -C "$QS" merge-base HEAD origin/main)"
  git -C "$QS" diff --binary "$base" > quickshell/end4-pC.patch
  printf 'repo=%s\nbase=%s\n' "$(git -C "$QS" remote get-url origin)" "$base" > quickshell/end4-pC.base
  untracked="$(git -C "$QS" ls-files --others --exclude-standard)"
  [ -n "$untracked" ] && printf 'warning: untracked files in end4-pC are not in the patch:\n%s\n' "$untracked"
fi

echo
git status --short
