-- Auto-switch monitors + power profile based on monitor topology and power
-- source. Reacts live to hotplug via Hyprland's monitor events, and to
-- AC/battery transitions via an external dbus-driven watcher
-- (custom/scripts/battery_refresh_rate.sh) that calls back through
-- `hyde_apply_layout()` below. Both trigger sources funnel into the same
-- idempotent function so there's no race between "monitor changed" and
-- "power changed" happening independently.
--
-- State matrix:
--   AC,      no external -> eDP-1 @ preferred (native max res/refresh), performance
--   AC,      external     -> eDP-1 disabled, external @ auto max res/refresh, performance
--   battery, no external -> eDP-1 @ 1920x1080@60,                      power-saver
--   battery, external     -> eDP-1 disabled, external @ auto max res/refresh, power-saver
-- Power profile tracks power source only; external-monitor presence
-- doesn't affect it.

local INTERNAL = "eDP-1"
local EXTERNAL = "DP-1"

-- Updated externally via `hyprctl eval "hyde_power_state='battery'; hyde_apply_layout()"`
-- by the watcher script. Defaults to "ac" until the watcher's first check runs.
_G.hyde_power_state = _G.hyde_power_state or "ac"

local function external_connected()
    for _, m in ipairs(hl.get_monitors()) do
        -- "FALLBACK" is Hyprland's synthetic placeholder output when no real
        -- monitor is enabled — it must not count as an external monitor.
        if m.name ~= INTERNAL and m.name ~= "FALLBACK" then
            return true
        end
    end
    return false
end

local function get_monitor(name)
    for _, m in ipairs(hl.get_monitors()) do
        if m.name == name then
            return m
        end
    end
    return nil
end

-- Picks the mode with the largest resolution; among ties, the highest
-- refresh rate. `available_modes` entries are tables:
-- {width, height, refresh_rate, preferred}.
local function best_mode(available_modes)
    local best, best_area, best_refresh = nil, -1, -1
    for _, entry in ipairs(available_modes or {}) do
        local area = entry.width * entry.height
        if area > best_area or (area == best_area and entry.refresh_rate > best_refresh) then
            best, best_area, best_refresh = entry, area, entry.refresh_rate
        end
    end
    if not best then
        return "preferred"
    end
    return string.format("%dx%d@%.2f", best.width, best.height, best.refresh_rate)
end

local function set_power_profile(profile)
    hl.exec_cmd("powerprofilesctl set " .. profile)
end

local function apply_layout()
    set_power_profile(_G.hyde_power_state == "battery" and "power-saver" or "performance")

    if external_connected() then
        local ext = get_monitor(EXTERNAL)
        local mode = ext and best_mode(ext.available_modes) or "preferred"
        hl.monitor({
            output = INTERNAL,
            disabled = true,
        })
        hl.monitor({
            output = EXTERNAL,
            disabled = false,
            mode = mode,
            position = "0x0",
            scale = 1,
        })
    else
        hl.monitor({
            output = INTERNAL,
            disabled = false,
            bitdepth = 8,
            mode = _G.hyde_power_state == "battery" and "1920x1080@60" or "preferred",
            position = "auto",
            scale = 1,
        })
    end
end

_G.hyde_apply_layout = apply_layout

apply_layout()

hl.on("monitor.added", apply_layout)
hl.on("monitor.removed", apply_layout)
