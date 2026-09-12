#!/usr/bin/env bash

# ==============================================================================
# Script Name: Legion RGB Control Utility
# Description: Manages keyboard backlight presets via 'legionaura', featuring 
#              dynamic theme synchronization with Hyprland/DMS color configs.
# ==============================================================================

set -euo pipefail

# --- Configuration & Environment Paths ---
STATE_FILE="/tmp/rgb_power_state"          # Tracks global RGB power toggle state
CONFIG_FILE="$HOME/.config/hypr/dms/colors.lua" # Path to active DMS theme configuration
BRIGHTNESS=2                               # Default keyboard backlight intensity (0-3)

# --- Usage & Help Menu ---
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

# --- Dynamic Color Extraction ---
get_theme_color() {
    # Fallback to pure white if the DMS color config is missing
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "ffffff"
        return
    fi

    # Parse the active window border HEX color directly from the Lua table
    HEX_COLOR="$(
        grep -m 1 'active_border' "$CONFIG_FILE" \
            | sed -n 's/.*rgb(\([0-9a-fA-F]\{6\}\)).*/\1/p' \
            | tr -d '[:space:]'
    )"

    # Validate hex format; fallback to white if parsing fails
    if [[ "$HEX_COLOR" =~ ^[0-9a-fA-F]{6}$ ]]; then
        echo "$HEX_COLOR"
    else
        echo "ffffff"
    fi
}

# --- Helper Wrappers for Legion Aura ---
apply_static() {
    legionaura static "$@" --brightness "$BRIGHTNESS"
}

apply_effect() {
    legionaura "$@" --brightness "$BRIGHTNESS"
}

# --- Dependency Verification ---
command -v legionaura >/dev/null 2>&1 || {
    echo "Error: legionaura not found"
    exit 1
}

# --- Power State Guard ---
# Exit silently if the global RGB power toggle is disabled (state != 1)
STATE="$(cat "$STATE_FILE" 2>/dev/null || echo 0)"

if [ "$STATE" != "1" ]; then
    exit 0
fi

# --- Preset Execution Engine ---
PRESET="${1:-}"

case "$PRESET" in
    0) # Dynamic Theme: Matches active Hyprland/DMS accent color
        THEME_COLOR="$(get_theme_color)"
        apply_static "$THEME_COLOR" "$THEME_COLOR" "$THEME_COLOR" "$THEME_COLOR"
        ;;

    1) # Matrix Green
        apply_static 00ff44 00cc33 00ff88 00aa22
        ;;

    2) # Cyber Blue
        apply_static 0077ff 00ccff 0044ff 00ffff
        ;;

    3) # Hacker Red
        apply_static ff0033 cc0000 ff4444 990000
        ;;

    4) # Neon Cyan/Magenta
        apply_static 00ffff ff00ff 00aaff ff44cc
        ;;

    5) # RGB Classic
        apply_static ff0000 00ff00 0000ff ffff00
        ;;

    6) # Sunset Fire
        apply_static ff2200 ff6600 ffaa00 ffff00
        ;;

    7) # Ocean Wave (Dynamic Effect)
        apply_effect wave ltr --speed 2
        ;;

    8) # Breathing Green (Dynamic Effect)
        apply_effect breath 00ff88 --speed 2
        ;;

    9) # Rainbow Hue Cycling (Dynamic Effect)
        apply_effect hue --speed 2
        ;;   

    *) # Invalid option: Display help menu and exit
        usage
        exit 1
        ;;
esac