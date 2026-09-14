#!/usr/bin/env bash

# ==============================================================================
# Script Name: Legion RGB Control Utility
# Description: Manages keyboard backlight presets via 'legionaura', featuring 
#              real-time dynamic theme synchronization with configs/colors.lua.
# ==============================================================================

set -euo pipefail

# --- Configuration & Environment Paths ---
STATE_FILE="/tmp/rgb_power_state"                     # Tracks global RGB power toggle state
CONFIG_FILE="$HOME/.config/hypr/configs/colors.lua"   # Path to active Lua theme configuration
BRIGHTNESS=2                                          # Default keyboard backlight intensity (0-3)

# --- Usage & Help Menu ---
usage() {
    echo "Usage: $0 {0-9}"
    echo "0  = Real-time adaptive theme color"
    echo "1  = Matrix Green"
    # ... (other options omitted for brevity in help menu)
}

# --- Dynamic Color Extraction ---
get_theme_color() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "ffffff"
        return
    fi

    # Extract the 6-character hex string specifically from the active_border rgb() value
    HEX_COLOR="$(grep -m 1 'active_border' "$CONFIG_FILE" | sed -E 's/.*rgb\(([0-9a-fA-F]{6})\).*/\1/')"

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
    echo "Error: legionaura not found" >&2
    exit 1
}

# ==============================================================================
# 🛡️ POWER STATE GUARD (FIXED FOR REAL-TIME BOOT)
# ==============================================================================
# If the state file doesn't exist (like on a fresh boot), create it and default to ON (1)
if [ ! -f "$STATE_FILE" ]; then
    echo 1 > "$STATE_FILE"
fi

# Read state and strip any accidental whitespace
STATE="$(cat "$STATE_FILE" 2>/dev/null | tr -d '[:space:]')"

# Exit silently if the user manually toggled the keyboard OFF
if [ "$STATE" != "1" ]; then
    exit 0
fi

# ==============================================================================
# 🚀 PRESET EXECUTION ENGINE
# ==============================================================================
PRESET="${1:-0}"

case "$PRESET" in
    0) # Real-Time Dynamic Theme
        THEME_COLOR="$(get_theme_color)"
        apply_static "$THEME_COLOR" "$THEME_COLOR" "$THEME_COLOR" "$THEME_COLOR"
        ;;
    1) apply_static 00ff44 00cc33 00ff88 00aa22 ;; # Matrix Green
    2) apply_static 0077ff 00ccff 0044ff 00ffff ;; # Cyber Blue
    3) apply_static ff0033 cc0000 ff4444 990000 ;; # Hacker Red
    4) apply_static 00ffff ff00ff 00aaff ff44cc ;; # Neon Cyan/Magenta
    5) apply_static ff0000 00ff00 0000ff ffff00 ;; # RGB Classic
    6) apply_static ff2200 ff6600 ffaa00 ffff00 ;; # Sunset Fire
    7) apply_effect wave ltr --speed 2 ;;          # Ocean Wave
    8) apply_effect breath 00ff88 --speed 2 ;;     # Breathing Green
    9) apply_effect hue --speed 2 ;;               # Rainbow Hue
    *) usage; exit 1 ;;
esac