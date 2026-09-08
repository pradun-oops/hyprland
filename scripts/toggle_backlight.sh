#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$HOME/.config/hypr/scripts"
STATE_FILE="/tmp/rgb_power_state"
PRESET_FILE="/tmp/rgb_current_preset"
WATCHER_PID_FILE="/tmp/rgb_watcher.pid"
BRIGHTNESS=2

command -v legionaura >/dev/null 2>&1 || {
    echo "Error: legionaura not found"
    exit 1
}

if [ ! -f "$STATE_FILE" ]; then
    echo 0 > "$STATE_FILE"
fi

STATE="$(cat "$STATE_FILE" 2>/dev/null || echo 0)"

if [ "$STATE" = "0" ]; then
    # TURN ON
    echo 1 > "$STATE_FILE"
    
    # Restore the last active preset (defaults to 0 / Adaptive)
    CURRENT_PRESET="$(cat "$PRESET_FILE" 2>/dev/null || echo 0)"

    if [ -x "$SCRIPT_DIR/apply_preset.sh" ]; then
        "$SCRIPT_DIR/apply_preset.sh" "$CURRENT_PRESET"
    elif [ -f "$SCRIPT_DIR/apply_preset.sh" ]; then
        bash "$SCRIPT_DIR/apply_preset.sh" "$CURRENT_PRESET"
    else
        legionaura static ffffff --brightness "$BRIGHTNESS"
    fi
else
    # TURN OFF
    echo 0 > "$STATE_FILE"
    
    # Kill the background color watcher if it's running
    if [ -f "$WATCHER_PID_FILE" ]; then
        kill "$(cat "$WATCHER_PID_FILE")" 2>/dev/null || true
        rm -f "$WATCHER_PID_FILE"
    fi
    
    legionaura off
fi