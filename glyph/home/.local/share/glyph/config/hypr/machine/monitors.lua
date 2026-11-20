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
-- "external" here means the docked ultrawide on DP-1 only. Any other output
-- (e.g. HDMI to a TV/projector) extends the desktop to the right of eDP-1.
-- Power profile tracks power source only; external-monitor presence
-- doesn't affect it.

local INTERNAL = "eDP-1"
local EXTERNAL = "DP-1"

-- Updated externally via `hyprctl eval "hyde_power_state='battery'; hyde_apply_layout()"`
-- by the watcher script. Defaults to "ac" until the watcher's first check runs.
_G.hyde_power_state = _G.hyde_power_state or "ac"

local function get_monitor(name)
    for _, m in ipairs(hl.get_monitors()) do
        if m.name == name then
            return m
        end
    end
    return nil
end

local function external_connected()
    return get_monitor(EXTERNAL) ~= nil
end

-- Movie mode: while this file exists, the external monitor is capped at
-- 144 Hz (an exact multiple of 24 fps film, so no 3:2-style judder).
-- Toggled from the sidebar (MovieModeToggle.qml), which creates/removes the
-- file and then calls `hyde_apply_layout()`.
local MOVIE_MODE_FILE = os.getenv("HOME") .. "/.local/state/hypr/movie-mode"
local MOVIE_MODE_MAX_REFRESH = 144.5

-- Picks the mode with the largest resolution; among ties, the highest
-- refresh rate (at most `max_refresh` when given). `available_modes`
-- entries are tables: {width, height, refresh_rate, preferred}.
local function best_mode(available_modes, max_refresh)
    local best, best_area, best_refresh = nil, -1, -1
    for _, entry in ipairs(available_modes or {}) do
        local area = entry.width * entry.height
        if max_refresh and entry.refresh_rate > max_refresh then
            -- skip modes above the cap
        elseif area > best_area or (area == best_area and entry.refresh_rate > best_refresh) then
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
        local max_refresh = is_file_exists(MOVIE_MODE_FILE) and MOVIE_MODE_MAX_REFRESH or nil
        local mode = ext and best_mode(ext.available_modes, max_refresh) or "preferred"
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

hl.monitor({
    output = "eDP-1",
    bitdepth = 8,
})
