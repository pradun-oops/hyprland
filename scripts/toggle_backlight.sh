#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$HOME/.config/hypr/scripts"
STATE_FILE="/tmp/rgb_power_state"
BRIGHTNESS=2

if ! command -v legionaura >/dev/null 2>&1; then
    echo "Error: legionaura not found." >&2
    exit 1
fi

if [[ ! -f "$STATE_FILE" ]]; then
    echo "0" > "$STATE_FILE"
fi

STATE=$(tr -d '[:space:]' < "$STATE_FILE" 2>/dev/null || echo "0")

if [[ "$STATE" == "0" ]]; then
    echo "1" > "$STATE_FILE"

    if [[ -x "$SCRIPT_DIR/apply_preset.sh" ]]; then
        "$SCRIPT_DIR/apply_preset.sh" 0
    elif [[ -f "$SCRIPT_DIR/apply_preset.sh" ]]; then
        bash "$SCRIPT_DIR/apply_preset.sh" 0
    else
        legionaura static ffffff ffffff ffffff ffffff --brightness "$BRIGHTNESS"
    fi
else
    legionaura off
    echo "0" > "$STATE_FILE"
fi