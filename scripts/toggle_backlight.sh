#!/usr/bin/env bash

# ==========================================================
# 💡 LegionAura RGB Backlight Power Toggle (toggle_backlight.sh)
# Manages keyboard backlight ON/OFF state transitions, restoring the
# last active lighting preset on power-up and stopping daemons on shutdown.
# ==========================================================

set -euo pipefail

# ==========================================================
# 📁 Paths & Hardware State Configurations
# ==========================================================
SCRIPT_DIR="$HOME/.config/hypr/scripts"
STATE_FILE="/tmp/rgb_power_state"              # Hardware power state (1=ON, 0=OFF)
PRESET_FILE="/tmp/rgb_current_preset"          # Cached profile index (0-9)
WATCHER_PID_FILE="/tmp/rgb_watcher.pid"        # Dynamic color sync daemon PID
BRIGHTNESS=2                                   # Default fallback hardware brightness

# ==========================================================
# 🔍 Dependency Verification
# ==========================================================
command -v legionaura >/dev/null 2>&1 || {
    echo "Error: legionaura not found" >&2
    exit 1
}

# Ensure the state file exists with a default power state (0 = OFF)
if [ ! -f "$STATE_FILE" ]; then
    echo 0 > "$STATE_FILE"
fi

STATE="$(cat "$STATE_FILE" 2>/dev/null || echo 0)"

# ==========================================================
# ⚡ Power State Toggle Logic
# ==========================================================
if [ "$STATE" = "0" ]; then
    # ------------------------------------------------------
    # 🟢 Action: Turn Backlight ON
    # ------------------------------------------------------
    echo 1 > "$STATE_FILE"
    
    # Retrieve the last active profile (defaults to Preset 0 / Adaptive Theme Sync)
    CURRENT_PRESET="$(cat "$PRESET_FILE" 2>/dev/null || echo 0)"

    # Restore the preset using the dispatcher script, with static white fallback
    if [ -x "$SCRIPT_DIR/apply_preset.sh" ]; then
        "$SCRIPT_DIR/apply_preset.sh" "$CURRENT_PRESET"
    elif [ -f "$SCRIPT_DIR/apply_preset.sh" ]; then
        bash "$SCRIPT_DIR/apply_preset.sh" "$CURRENT_PRESET"
    else
        legionaura static ffffff --brightness "$BRIGHTNESS"
    fi
else
    # ------------------------------------------------------
    # 🔴 Action: Turn Backlight OFF
    # ------------------------------------------------------
    echo 0 > "$STATE_FILE"
    
    # Terminate background theme auto-sync daemon to free resources
    if [ -f "$WATCHER_PID_FILE" ]; then
        kill "$(cat "$WATCHER_PID_FILE")" 2>/dev/null || true
        rm -f "$WATCHER_PID_FILE"
    fi
    
    # Send hardware turn-off command
    legionaura off
fi