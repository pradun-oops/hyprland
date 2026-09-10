#!/usr/bin/env bash

# ==========================================================
# ⌨️ LegionAura RGB Keyboard Preset Controller
# Manages 4-zone RGB keyboard profiles, reactive dynamic theme
# syncing, and animated light effects via legionaura.
# ==========================================================

set -euo pipefail

# ==========================================================
# 📁 Runtime State & Configuration Paths
# ==========================================================
STATE_FILE="/tmp/rgb_power_state"              # Backlight power switch (1=ON, 0=OFF)
PRESET_FILE="/tmp/rgb_current_preset"          # Currently active profile index (0-9)
WATCHER_PID_FILE="/tmp/rgb_watcher.pid"        # PID tracker for background theme watcher
CONFIG_FILE="$HOME/.config/hypr/configs/colors.lua" # Source palette for dynamic sync
BRIGHTNESS=2                                   # Global hardware backlight brightness level

# ==========================================================
# 📖 Help & Usage Cheatsheet
# ==========================================================
usage() {
    echo "Usage: $0 {0-9}"
    echo
    echo "0  = Adaptive DMS theme color (auto-synced to colors.lua)"
    echo "1  = Matrix Green"
    echo "2  = Cyber Blue"
    echo "3  = Hacker Red"
    echo "4  = Neon Cyan/Magenta"
    echo "5  = RGB Classic"
    echo "6  = Sunset Fire"
    echo "7  = Ocean Wave (Animated LTR)"
    echo "8  = Breathing Green (Animated)"
    echo "9  = Rainbow Hue (Animated Cycle)"  
}

# ==========================================================
# 🎨 Palette Extraction Helper
# Parses the primary active border hex code from colors.lua
# ==========================================================
get_theme_color() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "ffffff"
        return
    fi

    # Robust regex to extract 6 hex characters matching active_border
    HEX_COLOR="$(grep -m 1 'active_border' "$CONFIG_FILE" | grep -oE '[0-9a-fA-F]{6}' | head -n 1 || true)"

    if [[ "$HEX_COLOR" =~ ^[0-9a-fA-F]{6}$ ]]; then
        echo "$HEX_COLOR"
    else
        echo "ffffff" # Fallback white if extraction fails
    fi
}

# ==========================================================
# 💡 LegionAura Command Dispatchers
# ==========================================================
-- Apply static 4-zone colors
apply_static() {
    legionaura static "$@" --brightness "$BRIGHTNESS"
}

-- Apply dynamic hardware effects
apply_effect() {
    legionaura "$@" --brightness "$BRIGHTNESS"
}

-- Clean up active file-watching daemon
stop_watcher() {
    if [ -f "$WATCHER_PID_FILE" ]; then
        WPID=$(cat "$WATCHER_PID_FILE")
        if [ -n "$WPID" ] && kill -0 "$WPID" 2>/dev/null; then
            kill "$WPID" 2>/dev/null || true
        fi
        rm -f "$WATCHER_PID_FILE"
    fi
}

# ==========================================================
# 🔄 Dynamic Theme Auto-Sync Daemon
# Monitors colors.lua in real time; instantly updates keyboard zones
# ==========================================================
watch_colors() {
    echo $$ > "$WATCHER_PID_FILE"
    LAST_COLOR="$(get_theme_color)"
    
    while true; do
        # Use inotifywait for instant, 0-CPU event monitoring if installed, fallback to 2s polling
        if command -v inotifywait >/dev/null 2>&1; then
            inotifywait -qq -e modify,close_write "$CONFIG_FILE" 2>/dev/null || sleep 2
        else
            sleep 2
        fi
        
        # Verify keyboard power is still ON and still set to dynamic mode (Preset 0)
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

# Daemon branch entry point
if [ "${1:-}" == "--watch" ]; then
    watch_colors
    exit 0
fi

# ==========================================================
# 🚀 Main Preset Execution Logic
# ==========================================================

# Guard: Ensure the legionaura binary is installed and reachable in PATH
command -v legionaura >/dev/null 2>&1 || { echo "Error: legionaura not found"; exit 1; }

# Guard: Abort early if the keyboard backlight is currently turned off
STATE="$(cat "$STATE_FILE" 2>/dev/null || echo 0)"
if [ "$STATE" != "1" ]; then
    exit 0
fi

PRESET="${1:-0}"
echo "$PRESET" > "$PRESET_FILE"

# Terminate existing color watcher before switching profiles
stop_watcher

case "$PRESET" in
    0)
        # Dynamic theme sync mode
        THEME_COLOR="$(get_theme_color)"
        apply_static "$THEME_COLOR" "$THEME_COLOR" "$THEME_COLOR" "$THEME_COLOR"
        
        # Spawn detached background watcher
        nohup "$0" --watch >/dev/null 2>&1 &
        ;;

    # Static 4-zone profiles: Zone1 Zone2 Zone3 Zone4
    1) apply_static 00ff44 00cc33 00ff88 00aa22 ;; # Matrix Green
    2) apply_static 0077ff 00ccff 0044ff 00ffff ;; # Cyber Blue
    3) apply_static ff0033 cc0000 ff4444 990000 ;; # Hacker Red
    4) apply_static 00ffff ff00ff 00aaff ff44cc ;; # Neon Cyan / Magenta
    5) apply_static ff0000 00ff00 0000ff ffff00 ;; # RGB Classic
    6) apply_static ff2200 ff6600 ffaa00 ffff00 ;; # Sunset Fire

    # Animated hardware profiles
    7) apply_effect wave ltr --speed 2 ;;           # Ocean Wave
    8) apply_effect breath 00ff88 --speed 2 ;;      # Breathing Green
    9) apply_effect hue --speed 2 ;;                # Rainbow Hue Loop   

    *)
        usage
        exit 1
        ;;
esac