#!/usr/bin/env bash
# Fresh Arch install -> the whole rice, in one command (run as your user, not root):
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/whonoahexe/idontnoahdot/master/bootstrap.sh)
#
# Safe to re-run: every step skips what is already done.
set -euo pipefail

DOTS_REPO="https://github.com/whonoahexe/idontnoahdot.git"
DOTS="$HOME/Projects/idontnoahdot"
END4_REPO="https://github.com/end-4/dots-hyprland.git"
END4="$HOME/Projects/dots-hyprland"
END4_COMMIT="2f0c8bf42b803f4d597572f2a014d4e78d7d9f26"   # the end-4 version these dots were built on
STRATA_REPO="https://github.com/lgse/strata.git"
STRATA="$HOME/.local/src/strata"
HARDWARE_MODEL="FA506QM"   # ASUS TUF A15; NVIDIA/ASUS packages and tweaks only apply on this model

step() { printf '\n\033[1;35m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!! %s\033[0m\n' "$*"; }

if [ "$EUID" -eq 0 ]; then echo "Run this as your normal user, not root." >&2; exit 1; fi
command -v pacman >/dev/null || { echo "This script is for Arch Linux." >&2; exit 1; }

step "Asking for sudo once (kept alive for the whole run)"
sudo -v
while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &

step "Updating the system and installing git/base-devel"
sudo pacman -Syu --needed --noconfirm git base-devel rsync jq

if ! command -v yay >/dev/null; then
  step "Installing yay"
  tmp="$(mktemp -d)"
  git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
  (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
  rm -rf "$tmp"
fi

step "Getting the dots"
if [ -d "$DOTS/.git" ]; then
  git -C "$DOTS" pull --ff-only
else
  git clone "$DOTS_REPO" "$DOTS"
fi

step "Installing end-4's illogical-impulse (Hyprland, quickshell, matugen, fonts...)"
[ -d "$END4/.git" ] || git clone "$END4_REPO" "$END4"
git -C "$END4" fetch -q origin
git -C "$END4" checkout -q -f "$END4_COMMIT"
# The same local tweak used on the original install (yay without --sudoloop)
git -C "$END4" apply "$DOTS/end4/install-deps.patch" 2>/dev/null || true
(cd "$END4" && ./setup install --force --skip-sysupdate)

is_hardware=false
grep -q "$HARDWARE_MODEL" /sys/class/dmi/id/product_name 2>/dev/null && is_hardware=true

install_pkgs() {
  local list="$1"
  [ -s "$list" ] || return 0
  mapfile -t pkgs < "$list"
  if ! yay -S --needed --noconfirm "${pkgs[@]}"; then
    warn "Bulk install from $(basename "$list") failed; retrying one by one"
    for p in "${pkgs[@]}"; do
      yay -S --needed --noconfirm "$p" || warn "could not install $p"
    done
  fi
}

step "Installing my packages"
# Drivers first, so Steam's lib32 Vulkan dependency resolves to NVIDIA under --noconfirm
if $is_hardware; then
  install_pkgs "$DOTS/packages/hardware.txt"
else
  warn "Not a $HARDWARE_MODEL: skipping NVIDIA/ASUS packages (packages/hardware.txt)"
fi
install_pkgs "$DOTS/packages/pacman.txt"
install_pkgs "$DOTS/packages/aur.txt"

step "Installing system tweaks into /etc"
install_tree() {
  local root="$1"
  [ -d "$root" ] || return 0
  (cd "$root" && find etc -type f) | while read -r f; do
    sed "s#/home/noah#$HOME#g" "$root/$f" | sudo install -D -m 644 /dev/stdin "/$f"
    echo "installed /$f"
  done
}
install_tree "$DOTS/system/common"
$is_hardware && install_tree "$DOTS/system/hardware"
sudo systemctl daemon-reload
while read -r unit; do
  if systemctl list-unit-files "$unit" --no-legend | grep -q .; then
    sudo systemctl enable "$unit" || warn "could not enable $unit"
  fi
done < "$DOTS/system/services.txt"
if $is_hardware && command -v asusctl >/dev/null; then
  asusctl battery limit 90 || warn "asusctl battery limit failed (asusd starts after reboot)"
fi

step "Applying the dots"
"$DOTS/install.sh"

# Glyph: a second, separate rice (glyph/). end4 stays the active one; rice-switch glyph to try it
step "Installing the Glyph rice next to end4"
"$DOTS/glyph/install.sh" || warn "Glyph install failed; re-run $DOTS/glyph/install.sh"

if [ ! -x "$HOME/.local/bin/strata" ]; then
  step "Building Strata (file manager) with my patches"
  sudo pacman -S --needed --noconfirm bubblewrap ffmpeg ffmpegthumbnailer fontconfig gstreamer \
    gst-libav gst-plugins-base gst-plugins-good gtk4 gtksourceview5 gvfs poppler-glib rustup
  rustup toolchain list | grep -q . || rustup default stable
  [ -d "$STRATA/.git" ] || git clone "$STRATA_REPO" "$STRATA"
  git -C "$STRATA" fetch -q --tags origin
  tag="$(git -C "$STRATA" tag -l 'v*' --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -1)"
  git -C "$STRATA" checkout -q -B local/ssh-hosts "$tag"
  git -C "$STRATA" am -q "$DOTS"/strata/*.patch
  "$HOME/.local/bin/strata-patched-update" --force || warn "Strata build failed; run strata-patched-update --force later"
fi

if ! command -v claude >/dev/null && [ ! -x "$HOME/.local/bin/claude" ]; then
  step "Installing Claude Code"
  curl -fsSL https://claude.ai/install.sh | bash || warn "Claude Code install failed"
fi

step "Done"
echo "Reboot, pick Hyprland (not the UWSM entry) at the login screen, and you're home."
