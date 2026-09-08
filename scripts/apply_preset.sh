#!/usr/bin/env bash

set -euo pipefail

STATE_FILE="/tmp/rgb_power_state"
PRESET_FILE="/tmp/rgb_current_preset"
WATCHER_PID_FILE="/tmp/rgb_watcher.pid"
CONFIG_FILE="$HOME/.config/hypr/configs/colors.lua"
BRIGHTNESS=2

usage() {
    echo "Usage: $0 {0-9}"
    echo
    echo "0  = Adaptive DMS theme color"
    echo "1  = Matrix Green"
    echo "2  = Cyber Blue"
    echo "3  = Hacker Red"
    echo "4  = Neon Cyan/Magenta"
    echo "5  = RGB Classic"
    echo "6  = Sunset Fire"
    echo "7  = Ocean Wave"
    echo "8  = Breathing Green"
    echo "9  = Rainbow Hue"  
}

get_theme_color() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "ffffff"
        return
    fi

    # Robust regex to extract the 6 hex characters from the Lua file
    HEX_COLOR="$(grep -m 1 'active_border' "$CONFIG_FILE" | grep -oE '[0-9a-fA-F]{6}' | head -n 1 || true)"

    if [[ "$HEX_COLOR" =~ ^[0-9a-fA-F]{6}$ ]]; then
        echo "$HEX_COLOR"
    else
        echo "ffffff" # Fallback if parsing fails
    fi
}

apply_static() {
    legionaura static "$@" --brightness "$BRIGHTNESS"
}

apply_effect() {
    legionaura "$@" --brightness "$BRIGHTNESS"
}

stop_watcher() {
    if [ -f "$WATCHER_PID_FILE" ]; then
        WPID=$(cat "$WATCHER_PID_FILE")
        if [ -n "$WPID" ] && kill -0 "$WPID" 2>/dev/null; then
            kill "$WPID" 2>/dev/null || true
        fi
        rm -f "$WATCHER_PID_FILE"
    fi
}

# --- BACKGROUND DAEMON LOGIC ---
watch_colors() {
    echo $$ > "$WATCHER_PID_FILE"
    LAST_COLOR="$(get_theme_color)"
    
    while true; do
        # Use inotifywait for instant, 0-CPU event monitoring if installed, otherwise fallback to 2s polling
        if command -v inotifywait >/dev/null 2>&1; then
            inotifywait -qq -e modify,close_write "$CONFIG_FILE" 2>/dev/null || sleep 2
        else
            sleep 2
        fi
        
        # Verify backlight is still ON and still set to mode 0
        STATE="$(cat "$STATE_FILE" 2>/dev/null || echo 0)"
        PRESET="$(cat "$PRESET_FILE" 2>/dev/null || echo 0)"
        if [ "$STATE" != "1" ] || [ "$PRESET" != "0" ]; then
            exit 0
        fi
        
        NEW_COLOR="$(get_theme_color)"
        if [ "$NEW_COLOR" != "$LAST_COLOR" ]; then
            LAST_COLOR="$NEW_COLOR"
            apply_static "$NEW_COLOR" "$NEW_COLOR" "$NEW_COLOR" "$NEW_COLOR"
        fi
    done
}

# If the script is called by itself to run the watcher, route it to the daemon function
if [ "${1:-}" == "--watch" ]; then
    watch_colors
    exit 0
fi

# --- NORMAL SCRIPT EXECUTION ---
command -v legionaura >/dev/null 2>&1 || { echo "Error: legionaura not found"; exit 1; }

STATE="$(cat "$STATE_FILE" 2>/dev/null || echo 0)"
if [ "$STATE" != "1" ]; then
    exit 0
fi

PRESET="${1:-0}"
echo "$PRESET" > "$PRESET_FILE"

# Always kill old watcher when a new preset is manually applied
stop_watcher

case "$PRESET" in
    0)
        THEME_COLOR="$(get_theme_color)"
        apply_static "$THEME_COLOR" "$THEME_COLOR" "$THEME_COLOR" "$THEME_COLOR"
        
        # Spawn the real-time background watcher completely detached
        nohup "$0" --watch >/dev/null 2>&1 &
        ;;

    1) apply_static 00ff44 00cc33 00ff88 00aa22 ;;
    2) apply_static 0077ff 00ccff 0044ff 00ffff ;;
    3) apply_static ff0033 cc0000 ff4444 990000 ;;
    4) apply_static 00ffff ff00ff 00aaff ff44cc ;;
    5) apply_static ff0000 00ff00 0000ff ffff00 ;;
    6) apply_static ff2200 ff6600 ffaa00 ffff00 ;;
    7) apply_effect wave ltr --speed 2 ;;
    8) apply_effect breath 00ff88 --speed 2 ;;
    9) apply_effect hue --speed 2 ;;   

    *)
        usage
        exit 1
        ;;
esac