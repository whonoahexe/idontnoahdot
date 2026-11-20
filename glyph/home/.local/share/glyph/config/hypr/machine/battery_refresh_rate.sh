#!/usr/bin/env bash
# AC/battery watcher for monitors.lua's power-aware layout.
# Primary path: dbus-monitor on UPower's PropertiesChanged signal (fires
# precisely on physical AC plug/unplug). `stdbuf -oL` forces line-buffered
# output — without it, dbus-monitor's stdout is fully block-buffered once
# piped (not a tty), which can delay or swallow the trigger indefinitely.
# Fallback path: a 60s poll running alongside it, so an actual state change
# is never missed even if the dbus route hiccups on a given system/session.
# 60s is cheap (vs. the original 5s loop) since it's just a safety net, not
# the primary trigger.

LOG="$HOME/.cache/hypr-battery-watcher.log"
mkdir -p "$(dirname "$LOG")"
: > "$LOG"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"
}

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

last_state=""
apply_if_changed() {
    local source="$1"
    local state
    state=$(get_state)
    if [ "$state" != "$last_state" ]; then
        log "state change ($source): $last_state -> $state"
        hyprctl eval "hyde_power_state='$state'; hyde_apply_layout()" >/dev/null 2>>"$LOG"
        last_state="$state"
    fi
}

apply_if_changed "startup"

( while true; do
    sleep 60
    apply_if_changed "poll-fallback"
done ) &

stdbuf -oL dbus-monitor --system "type='signal',interface='org.freedesktop.DBus.Properties',path='/org/freedesktop/UPower'" 2>>"$LOG" |
while read -r line; do
    case "$line" in
        *member=PropertiesChanged*)
            apply_if_changed "dbus-event"
            ;;
    esac
done
