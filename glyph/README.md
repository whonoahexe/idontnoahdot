# Glyph

My second rice: [Glyph](https://github.com/Nebelung-cloud/glyph-rice), a Nothing OS–style Hyprland + Quickshell setup (black, white dots, one red), with my changes on top, and the apps themed to match it. It lives next to the end4 rice at the repo root; `rice-switch` flips between them.

Everything Glyph-only is in this folder. Nothing here is needed by end4.

## What's here

- `glyph.base` + `patches/` — Glyph is [Nebelung-cloud/glyph-rice](https://github.com/Nebelung-cloud/glyph-rice) at the tag in `glyph.base`, plus my commits as `git format-patch` files, applied with `git am` onto branch `noah-local` in `~/.local/share/glyph`. `tags` records which patch the `ljs-easing` and `fast-anim` tags sit on (`glyph-easing` reverts/cherry-picks them). What the patches add:
  - **Super+P panel** for Cloudflare WARP + Proton VPN (free) instead of Clash Verge; the Quick-settings VPN tile drives WARP
  - **Wallpapers**: the picker reads one folder down; a wallpaper folder's `scene/Scene.qml` plays as a live wallpaper (colour look, only on the home screen and on AC); options in the picker for **HOME** default / clear (bare widgets and bar, like the picker), **MOTION** still / live, **WINDOWS** solid / glass (unfocused windows 90% opaque + 5% dim, frosted by the blur)
  - home widgets **by the clock or against the right edge** (Prefs → Home → place)
  - bar margins match Hyprland's real gaps; clipboard image preview toggles dots ↔ original (Ctrl+O)
  - GTK4 rules for Apostrophe's editor; faster animations; threaded render loop (smooth at 160 Hz); Brave / Strata apps, keybinds, power-menu entry back to end4
- `home/` — mirrors `$HOME`; files Glyph's repo doesn't carry:
  - `.local/share/glyph/config/hypr/user.lua` — machine overrides (gitignored by Glyph): NVIDIA env, monitor layout shared with end4, VRR, mouse colour, animation speeds, kitty see-through when unfocused
  - `.local/state/rice/glyph.json` + `.config/demonshot/rules.json` — Glyph's settings (wallpaper, looks, widgets, gaps, idle…)
  - `.local/bin/glyph-easing` — switch the ljs.lol easing on/off
  - Apps themed to match: `.config/spicetify/Themes/glyph` (Spotify, on the Text theme) + `Extensions/glyph-move.js` (right-click → Move to top/bottom in playlists), `.local/share/brave-glyph-theme` (Brave), `.config/apostrophe/glyph.css` (Apostrophe's preview)
- `system/etc/pacman.d/hooks/` — keep those themes through updates: `spicetify.hook` re-applies Spicetify after Spotify / spicetify-cli updates, `apostrophe-glyph.hook` re-links the Apostrophe style
- `brave/nightTab-glyph.json` — Night Tab settings with the Glyph look (import by hand)

The Obsidian theme isn't here: it lives in the vault itself (`.obsidian/themes/Glyph`), which syncs on its own.

## Install

`../bootstrap.sh` does this on a fresh machine. On an existing one:

```sh
./install.sh      # clone + patches, home/ files (existing ones backed up), hooks (sudo), rice-switch init
rice-switch glyph --logout
```

It does not run Glyph's own upstream `install.sh` (that links straight into `~/.config`, which `rice-switch` manages); Glyph's packages are in `../packages`. Then by hand: start Spotify and log in once and run `spicetify backup apply`; in Brave load `~/.local/share/brave-glyph-theme` unpacked (Developer mode, once per profile); import `brave/nightTab-glyph.json` in Night Tab.

## Updating

`../sync.sh` refreshes this folder: patches from `~/.local/share/glyph` (`noah-local` since the base tag; uncommitted changes there are reported, not included), the `home/` files, and the hooks from `/etc`. Commit Glyph changes in `~/.local/share/glyph` as `noah: …` first.
