#!/usr/bin/env bash

# ==============================================================================
# 🔄 THEME WATCHER & RGB AUTO-SYNCHRONIZER
# ==============================================================================
# Monitors colors.lua for palette changes (including atomic file replacements)
# and immediately synchronizes the Lenovo keyboard backlight in real time.
# ==============================================================================

set -euo pipefail

CONFIG_DIR="$HOME/.config/hypr/configs"
CONFIG_FILE="$CONFIG_DIR/colors.lua"
PRESET_SCRIPT="$HOME/.config/hypr/scripts/apply_preset.sh"
STATE_FILE="/tmp/rgb_power_state"

# Ensure initial state defaults to ON (1) if uninitialized
if [ ! -f "$STATE_FILE" ]; then
    echo 1 > "$STATE_FILE"
fi

# Function to safely trigger the RGB preset update
sync_rgb() {
    local state
    state="$(cat "$STATE_FILE" 2>/dev/null | tr -d '[:space:]' || echo 0)"
    if [ "$state" = "1" ] && [ -x "$PRESET_SCRIPT" ]; then
        "$PRESET_SCRIPT" 0 >/dev/null 2>&1 || true
    fi
}

# Run once at startup to sync current palette
sync_rgb

# ==============================================================================
# 📡 EVENT MONITORING ENGINE
# ==============================================================================
# Strategy A: Use inotifywait on the directory (catches atomic renames instantly)
if command -v inotifywait >/dev/null 2>&1; then
    inotifywait -m -q -e close_write,moved_to --format "%f" "$CONFIG_DIR" | while read -r filename; do
        if [ "$filename" = "colors.lua" ]; then
            sleep 0.05 # Allow disk write buffer to flush
            sync_rgb
        fi
    done
else
    # Strategy B: Coreutils hash polling fallback (Zero dependencies, 1s interval)
    LAST_HASH=""
    while true; do
        if [ -f "$CONFIG_FILE" ]; then
            CURRENT_HASH="$(md5sum "$CONFIG_FILE" 2>/dev/null | awk '{print $1}')"
            if [ -n "$CURRENT_HASH" ] && [ "$CURRENT_HASH" != "$LAST_HASH" ]; then
                LAST_HASH="$CURRENT_HASH"
                sync_rgb
            fi
        fi
        sleep 1
    done
fi