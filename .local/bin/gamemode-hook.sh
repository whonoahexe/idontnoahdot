#!/usr/bin/env bash
# Called by gamemoded ([custom] start/end in /etc/gamemode.ini).
# start: begin nvidia-smi logging
# end:   stop logging
LOGDIR=$HOME/mangohud-logs
PIDFILE=/tmp/gamemode-nvidia-log.pid
case "$1" in
  start)
    mkdir -p "$LOGDIR"
    nvidia-smi --query-gpu=timestamp,utilization.gpu,clocks.gr,clocks.mem,power.draw,temperature.gpu,memory.used,pstate,clocks_event_reasons.hw_thermal_slowdown,clocks_event_reasons.sw_power_cap \
      --format=csv -lms 500 > "$LOGDIR/gpu_$(date +%Y-%m-%d_%H-%M-%S).csv" 2>/dev/null &
    echo $! > "$PIDFILE"
    notify-send "GameMode started" "GPU logging on"
    ;;
  end)
    [[ -f $PIDFILE ]] && { kill "$(cat "$PIDFILE")" 2>/dev/null; rm -f "$PIDFILE"; }
    notify-send "GameMode ended" "GPU logging off"
    ;;
esac
