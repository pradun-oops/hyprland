#!/usr/bin/env bash

# ==============================================================================
# Script Name: Legion RGB Power Toggle Utility
# Description: Toggles the keyboard backlight power state globally. Flips between 
#              active (restoring the default preset 0) and off.
# ==============================================================================

set -euo pipefail

# --- Configuration & Environment Paths ---
SCRIPT_DIR="$HOME/.config/hypr/scripts" # Directory containing preset management scripts
STATE_FILE="/tmp/rgb_power_state"          # Tracks global RGB power toggle state (0 = Off, 1 = On)
BRIGHTNESS=2                               # Default keyboard backlight intensity for fallbacks

# --- Dependency Verification ---
command -v legionaura >/dev/null 2>&1 || {
    echo "Error: legionaura not found"
    exit 1
}

# --- Initialize State File ---
# Create the state tracking file with a default 'off' state (0) if it doesn't exist
if [ ! -f "$STATE_FILE" ]; then
    echo 0 > "$STATE_FILE"
fi

# Read current power state safely
STATE="$(cat "$STATE_FILE" 2>/dev/null || echo 0)"

# --- Toggle Logic ---
if [ "$STATE" = "0" ]; then
    # Currently OFF: Turn ON and apply default theme preset (0)
    echo 1 > "$STATE_FILE"

    # Execute preset script if executable, fallback to direct execution or plain white
    if [ -x "$SCRIPT_DIR/apply_preset.sh" ]; then
        "$SCRIPT_DIR/apply_preset.sh" 0
    elif [ -f "$SCRIPT_DIR/apply_preset.sh" ]; then
        bash "$SCRIPT_DIR/apply_preset.sh" 0
    else
        legionaura static ffffff --brightness "$BRIGHTNESS"
    fi
else
    # Currently ON: Turn OFF completely and update state to 0
    legionaura off
    echo 0 > "$STATE_FILE"
fi