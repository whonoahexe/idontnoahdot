-- This machine: ASUS TUF A15 (NVIDIA dGPU + AMD iGPU), LG ultrawide on DP-1.
-- Gitignored by Glyph, so `git pull` never touches it. The monitor layout and the
-- AC/battery watcher are shared with the end4 setup and loaded from its copy
-- (~/.local/share/rices/end4), so there is one version of them for both rices.

local home = os.getenv("HOME")
local end4hypr = home .. "/.local/share/rices/end4/.config/hypr"

-- ~/.local/bin is not on the systemd user PATH, so apps Hyprland starts couldn't see it
hl.env("PATH", home .. "/.local/bin:" .. (os.getenv("PATH") or ""))

-- Render on the NVIDIA dGPU (card1) rather than the AMD iGPU that drives the laptop
-- panel: the ultrawide on DP-1 hangs off the NVIDIA card
hl.env("AQ_DRM_DEVICES", "/dev/dri/card1:/dev/dri/card2")
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")

-- monitors.lua (from end4) uses this helper from end4's hyprland/lib
if not is_file_exists then
    function is_file_exists(name)
        local f = io.open(name, "r")
        if f ~= nil then
            io.close(f)
            return true
        end
        return false
    end
end

-- Laptop panel off while the ultrawide is docked, 60 Hz on battery, Movie mode cap.
-- Glyph's Rules.monitor() calls hyde_apply_layout() after itself (local patch)
dofile(end4hypr .. "/monitors.lua")

-- Unfocused windows see-through like end4: the shell sets the opacity and dim (wallpaper picker → windows: solid / glass).
-- Glyph tags kitty opaque with the games and creative apps; let the terminal go see-through when unfocused too
hl.window_rule({ match = { class = "kitty" }, opaque = false })

-- Variable refresh rate only for fullscreen apps (games); LG ultrawide does 48-160 Hz
hl.config({ misc = { vrr = 2 } })

-- No tearing for Steam games: VRR already gives low latency in fullscreen
hl.window_rule({ match = { class = "^(steam_app).*" }, immediate = false })

hl.on("hyprland.start", function()
    -- Keeps the monitor refresh rate and power profile in sync with AC/battery
    hl.exec_cmd(end4hypr .. "/custom/scripts/battery_refresh_rate.sh")
    -- The mouse doesn't store its colour, so set the violet at every login
    hl.exec_cmd("openrgb --noautoconnect --device 'Razer Deathadder V2' --mode static --color 623CEA")
end)

-- Faster animations (Glyph's own curves and styles, shorter durations; speed is in
-- tenths of a second). To revert, delete this whole block.
-- Windows: was 0.5 s in Glyph
hl.animation({ leaf = "windowsIn",        enabled = true, speed = 2.5, bezier = "emphasizedDecel", style = "popin 80%" })
hl.animation({ leaf = "windowsOut",       enabled = true, speed = 1.5, bezier = "emphasizedDecel", style = "popin 90%" })
hl.animation({ leaf = "windowsMove",      enabled = true, speed = 2.5, bezier = "standard",        style = "slide" })
hl.animation({ leaf = "fadeIn",           enabled = true, speed = 2,   bezier = "emphasizedDecel" })
hl.animation({ leaf = "fadeOut",          enabled = true, speed = 1.5, bezier = "emphasizedDecel" })
-- Shell panels (layer surfaces): were 0.5 s in / 0.4 s out
hl.animation({ leaf = "layersIn",         enabled = true, speed = 2.5, bezier = "emphasizedDecel", style = "slide" })
hl.animation({ leaf = "layersOut",        enabled = true, speed = 2,   bezier = "emphasizedAccel", style = "slide" })
hl.animation({ leaf = "fadeLayers",       enabled = true, speed = 2.5, bezier = "standard" })
-- Workspaces: were 0.5 s / 0.4 s
hl.animation({ leaf = "workspaces",       enabled = true, speed = 3,   bezier = "standard",          style = "slidevert" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2.5, bezier = "specialWorkSwitch", style = "slidefadevert 15%" })
-- Fades and borders: were 0.6 s
hl.animation({ leaf = "fade",             enabled = true, speed = 3,   bezier = "standard" })
hl.animation({ leaf = "fadeDim",          enabled = true, speed = 3,   bezier = "standard" })
hl.animation({ leaf = "border",           enabled = true, speed = 3,   bezier = "standard" })
