# idontnoahdot

Personal dotfiles for my [illogical-impulse](https://github.com/end-4/dots-hyprland) Hyprland rice, curated for easy restore on a fresh install. Colors throughout (Hyprland, GTK, Qt/Kvantum, terminal, lock screen, boot splash) are generated dynamically from the current wallpaper via [matugen](https://github.com/InioX/matugen) (Material You).

## Two rices, kept apart

| | Where | What |
|---|---|---|
| **end4** (default) | repo root | my [illogical-impulse](https://github.com/end-4/dots-hyprland) rice: everything listed below |
| **Glyph** | [`glyph/`](glyph/) | a Nothing OS–style rice on [Nebelung-cloud/glyph-rice](https://github.com/Nebelung-cloud/glyph-rice) with my changes as patches, plus the Spotify / Brave / Apostrophe themes made to match it. Self-contained: its own [README](glyph/README.md) and `install.sh` |
| shared | repo root | packages, `/etc` tweaks, helper scripts (`reboot-to-windows` serves both rices' power menus), wallpapers, and `rice-switch` (`.local/bin`), which flips between the two (`rice-switch glyph` / `rice-switch end4`, then log out and in) |

Nothing Glyph-only lives at the root, and `glyph/` holds nothing of end4's.

## What's here (end4 + shared)

- `.config/hypr` — Hyprland, hypridle, hyprlock
- `.config/matugen` — matugen config + templates that regenerate colors across every app below when the wallpaper changes
- `.config/illogical-impulse/config.json` + `presets/` — shell appearance/bar/lock settings (weather city redacted)
- `quickshell/` — the shell itself: [pctrade/end4-pC](https://github.com/pctrade/end4-pC) pinned to the commit in `end4-pC.base`, with my changes in `end4-pC.patch` (extra quick toggles: Movie mode, Animated wallpaper, a fixed Cloudflare WARP; notification/lock/media fixes; GPU tab in the resources overlay; Restart to Windows; animated wallpaper scenes that pause on battery and behind windows)
- Terminal/shell: `kitty`, `foot`, `ghostty`, `fish`, `zshrc.d`, `starship.toml`, `.bashrc`, `.bash_profile`
- Theming: `gtk-3.0`, `gtk-4.0`, `Kvantum`, `kde-material-you-colors`, `darklyrc`, `fontconfig`, `xsettingsd`, `.gtkrc-2.0`
- Misc: `fuzzel` (launcher), `wlogout`, `cava`, `mpv`, `mimeapps.list`, `QtProject.conf`, `Trolltech.conf`, `xdg-desktop-portal`
- `.local/bin` + `.config/systemd/user` — helper scripts and their user units: `audio-watchdog` (restarts a hung PipeWire), `suspend-unless-docked`, `gamemode-hook.sh`, `mouse-rgb-watch` (re-applies the mouse color on replug), `strata-patched-update`, and the `gh` / `git-credential-gh-account` wrappers for per-folder GitHub accounts
- `Pictures/Wallpapers` (current wallpaper + its animated scene) and `.local/state/quickshell/user/generated` (its generated colors, so the first login already looks right)
- `MangoHud`, `brave-flags.conf`, `strata` (file manager settings + custom actions)
- `plymouth/illogical-impulse` — custom boot splash theme matched to the matugen palette (not part of upstream dots-hyprland, built separately)

Not included on purpose: anything with credentials/session state (SSH, GPG, browser profiles, `gh`/`npm`/`tailscale` config, KDE wallet, Strata's SSH hosts, etc.), work tooling, video wallpapers, and KDE Plasma session leftovers unrelated to the Hyprland setup.

## Updating this repo

```sh
./sync.sh      # copies the live configs from $HOME in, redacts, regenerates the end4-pC patch and glyph/
git diff       # review, then commit and push
```

The list of what gets synced is `PATHS` at the top of `sync.sh` (`SYSTEM_FILES` / `HARDWARE_FILES` for `system/`). `/etc/sudoers.d` can't be read without root, so its files are kept in `system/` as written rather than re-read. Private values that must never land in the repo are rewritten using find/replace rules in `~/.config/idontnoahdot/scrub.sed`, which is deliberately not in the repo.

## Fresh install: one command

On a fresh Arch install (with a user that has sudo and a network connection), run as that user:

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/whonoahexe/idontnoahdot/master/bootstrap.sh)
```

Enter your password once, then reboot when it says done and pick Hyprland (not the UWSM entry) at the login screen. `bootstrap.sh` is safe to re-run; it skips what's already done. In order, it:

1. updates the system and installs `git`, `base-devel` and `yay`
2. clones this repo to `~/Projects/idontnoahdot`
3. installs end-4's [illogical-impulse](https://github.com/end-4/dots-hyprland) at the pinned commit these dots were built on (`./setup install --force`), into `~/Projects/dots-hyprland`
4. installs my packages from `packages/` (`hardware.txt`, the NVIDIA + ASUS bits, only on the same laptop model, an ASUS TUF A15 FA506QM)
5. installs the system tweaks from `system/` (gamemode, zram + sysctl, no auto-sleep on lid close, v4l2loopback; on the same model: Wi-Fi ASPM fix, NVIDIA power limit, and `/usr/local/bin/reboot-to-windows` + its sudo rule for the power menus' Restart to Windows) and enables the services in `system/services.txt`
6. runs `install.sh` (below)
7. runs `glyph/install.sh`: Glyph next to end4, end4 stays active ([details](glyph/README.md))
8. builds [Strata](https://github.com/lgse/strata) from the latest release with my patches in `strata/`
9. installs Claude Code

### Just the dotfiles

If the system is already set up, `./install.sh` alone copies everything into place under `$HOME` file by file, backing up any existing file it would change with a `.bak-<timestamp>` suffix first. It also clones end4-pC into `~/.config/quickshell/end4-pC` and applies the patch (skipped if that folder exists), and enables the user units. Hyprland is already pointed at it via `hl.env("qsConfig", "end4-pC")` in `.config/hypr/custom/variables.lua`.

### Boot splash

Not automated (it edits the initramfs and bootloader).
```sh
cd plymouth
sudo pacman -S --needed plymouth
sudo cp -r illogical-impulse /usr/share/plymouth/themes/
sudo plymouth-set-default-theme illogical-impulse
# Add the `plymouth` hook to HOOKS= in /etc/mkinitcpio.conf (after sd-vconsole, before block),
# then: sudo mkinitcpio -P
# Add "quiet splash" to the kernel options line in /boot/loader/entries/*.conf
```
