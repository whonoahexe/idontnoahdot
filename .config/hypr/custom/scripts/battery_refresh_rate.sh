#!/usr/bin/env bash
# Event-driven AC/battery watcher for monitors.lua's power-aware layout.
# Listens for UPower's PropertiesChanged signal (fires precisely on physical
# AC plug/unplug, not on noisy per-battery percentage ticks) and re-applies
# the full monitor+power-profile state via `hyde_apply_layout()` whenever
# the power source actually changes. No polling.

get_state() {
    local supply
    supply=$(upower -e | grep -m1 'BAT')
    [ -z "$supply" ] && { echo "ac"; return; }
    if upower -i "$supply" | grep -q "state:.*discharging"; then
        echo "battery"
    else
        echo "ac"
    fi
}

apply() {
    hyprctl eval "hyde_power_state='$1'; hyde_apply_layout()" >/dev/null
}

last_state=$(get_state)
apply "$last_state"

dbus-monitor --system "type='signal',interface='org.freedesktop.DBus.Properties',path='/org/freedesktop/UPower'" 2>/dev/null |
while read -r line; do
    case "$line" in
        *member=PropertiesChanged*)
            state=$(get_state)
            if [ "$state" != "$last_state" ]; then
                apply "$state"
                last_state="$state"
            fi
            ;;
    esac
done
