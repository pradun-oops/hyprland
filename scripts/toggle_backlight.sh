#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$HOME/.config/hypr/scripts"
STATE_FILE="/tmp/rgb_power_state"
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
    echo 1 > "$STATE_FILE"

    if [ -x "$SCRIPT_DIR/apply_preset.sh" ]; then
        "$SCRIPT_DIR/apply_preset.sh" 0
    elif [ -f "$SCRIPT_DIR/apply_preset.sh" ]; then
        bash "$SCRIPT_DIR/apply_preset.sh" 0
    else
        legionaura static ffffff --brightness "$BRIGHTNESS"
    fi
else
    legionaura off
    echo 0 > "$STATE_FILE"
fi