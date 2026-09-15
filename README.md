# idontnoahdot

Personal dotfiles for my [illogical-impulse](https://github.com/end-4/dots-hyprland) Hyprland rice, curated for easy restore on a fresh install. Colors throughout (Hyprland, GTK, Qt/Kvantum, terminal, lock screen, boot splash) are generated dynamically from the current wallpaper via [matugen](https://github.com/InioX/matugen) (Material You).

## What's here

- `.config/hypr` — Hyprland, hypridle, hyprlock
- `.config/matugen` — matugen config + templates that regenerate colors across every app below when the wallpaper changes
- `.config/illogical-impulse/config.json` — ii-shell appearance/bar/lock settings (weather city redacted)
- Terminal/shell: `kitty`, `foot`, `ghostty`, `fish`, `zshrc.d`, `starship.toml`, `.bashrc`, `.bash_profile`
- Theming: `gtk-3.0`, `gtk-4.0`, `Kvantum`, `kde-material-you-colors`, `darklyrc`, `fontconfig`, `xsettingsd`, `.gtkrc-2.0`
- Misc: `fuzzel` (launcher), `wlogout`, `cava`, `mpv`, `yazi`, `mimeapps.list`, `QtProject.conf`, `Trolltech.conf`, `xdg-desktop-portal`
- `plymouth/illogical-impulse` — custom boot splash theme matched to the matugen palette (not part of upstream dots-hyprland, built separately)

Not included on purpose: anything with credentials/session state (SSH, GPG, browser profiles, `gh`/`npm`/`tailscale` config, KDE wallet, etc.), the vendored `quickshell` app source (comes from the `illogical-impulse-quickshell-git` package, not authored here), and KDE Plasma session leftovers unrelated to the Hyprland setup.

## Prerequisites

This assumes the [illogical-impulse dots-hyprland](https://github.com/end-4/dots-hyprland) install has already been run (it provides Hyprland, quickshell, matugen, and the `illogical-impulse-*` packages these configs depend on).

## Restoring on a fresh install

```sh
git clone https://github.com/whonoahexe/idontnoahdot.git
cd idontnoahdot
./install.sh
```

`install.sh` copies everything into place under `$HOME`, backing up any existing file/dir it would overwrite with a `.bak-<timestamp>` suffix first. It does not touch anything boot-related.

To also restore the boot splash (needs sudo, so it's separate and not run automatically):

```sh
cd plymouth
sudo pacman -S --needed plymouth
sudo cp -r illogical-impulse /usr/share/plymouth/themes/
sudo plymouth-set-default-theme illogical-impulse
# Add the `plymouth` hook to HOOKS= in /etc/mkinitcpio.conf (after sd-vconsole, before block),
# then: sudo mkinitcpio -P
# Add "quiet splash" to the kernel options line in /boot/loader/entries/*.conf
```
