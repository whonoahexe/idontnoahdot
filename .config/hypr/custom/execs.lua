hl.on("hyprland.start", function ()
    -- Restore Linux Wallpaper Engine (previously autostarted via Plasma/XDG autostart;
    -- Hyprland doesn't reliably trigger graphical-session.target for the xdg-autostart
    -- systemd generator, so launch it directly instead)
    hl.exec_cmd("/usr/lib/electron39/electron /usr/lib/linux-wallpaper-engine-ux/app.asar")

    -- AC/battery watcher: keeps monitor refresh rate + power-profiles-daemon
    -- profile in sync with power source (see monitors.lua for the full
    -- state matrix)
    hl.exec_cmd("$HOME/.config/hypr/custom/scripts/battery_refresh_rate.sh")
end)
