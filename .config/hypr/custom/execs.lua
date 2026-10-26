hl.on("hyprland.start", function ()
    -- Start the linux-wallpaperengine backend via its systemd --user unit
    -- (Restart=on-failure recovers it from the Wayland frame-callback segfault;
    -- the UX Electron app's own launch-on-login/restore-last-wallpaper is
    -- disabled to avoid a second, competing renderer instance -- open the UX
    -- app manually if you want to pick a different wallpaper)
    -- Disabled 2026-10-27: the scene now plays as a video wallpaper through the shell
    -- (~/Videos/Wallpapers/city-night-street.mp4). Uncomment to go back.
    -- hl.exec_cmd("systemctl --user start linux-wallpaperengine.service")

    -- AC/battery watcher: keeps monitor refresh rate + power-profiles-daemon
    -- profile in sync with power source (see monitors.lua for the full
    -- state matrix)
    hl.exec_cmd("$HOME/.config/hypr/custom/scripts/battery_refresh_rate.sh")

    -- Razer DeathAdder V2 lighting: OpenRGB's color isn't stored on the mouse,
    -- so re-apply the violet (623CEA) at every login. Targets the mouse by
    -- name so the laptop's ASUS keyboard backlight is left alone (a saved
    -- OpenRGB profile would also overwrite that)
    hl.exec_cmd("openrgb --noautoconnect --device 'Razer Deathadder V2' --mode static --color 623CEA")
end)
