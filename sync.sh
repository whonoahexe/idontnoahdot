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
)

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
