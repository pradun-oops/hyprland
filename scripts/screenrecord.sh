#!/usr/bin/env bash

# ==========================================================
# 🎥 Hyprland Screen Recording Utility (screenrecord.sh)
# Records full displays or selected screen areas via wf-recorder,
# with automated desktop notifications and toggle-to-stop control.
# ==========================================================

set -euo pipefail

# ==========================================================
# 📁 Storage Destination & File Naming
# ==========================================================
SAVE_DIR="$HOME/Videos/Screencasts"
TIMESTAMP="$(date +'%Y-%m-%d_%H-%M-%S')"
FILENAME="$SAVE_DIR/$TIMESTAMP.mp4"

# ==========================================================
# 🔔 Notification Icons & Audio Configuration
# ==========================================================
ICON_START="media-record"
ICON_STOP="media-playback-stop"
ICON_ERROR="dialog-error"

RECORD_AUDIO=false # Set to true if configuring audio capture

# ==========================================================
# 📢 Notification Dispatchers
# ==========================================================
notify_start() {
    notify-send -u low -i "$ICON_START" "Screen Record" "$1"
}

notify_stop() {
    notify-send -u low -i "$ICON_STOP" "Screen Record" "$1"
}

notify_error() {
    notify-send -u critical -i "$ICON_ERROR" "Screen Record Error" "$1"
}

# ==========================================================
# 🔍 Dependency & Environment Verification
# ==========================================================
has_cmd() {
    command -v "$1" >/dev/null 2>&1
}

usage() {
    notify_error "Usage: screenrecord.sh full | area"
    echo "Usage: $0 full | area"
}

# Ensure essential tools are installed and present in PATH
for cmd in wf-recorder notify-send hyprctl jq; do
    if ! has_cmd "$cmd"; then
        echo "Missing command: $cmd"
        notify_error "Missing command: $cmd"
        exit 1
    fi
done

# Slurp is required specifically for interactive region captures
if [ "${1:-}" = "area" ] && ! has_cmd slurp; then
    echo "Missing command: slurp"
    notify_error "Missing command: slurp"
    exit 1
fi

# Ensure the output directory exists
mkdir -p "$SAVE_DIR"

# ==========================================================
# ⏹️ Toggle Stop Logic
# If wf-recorder is already running, send SIGINT to cleanly save the file.
# ==========================================================
if pgrep -x wf-recorder >/dev/null 2>&1; then
    pkill -INT wf-recorder
    notify_stop "Recording saved in Videos/Screencasts."
    exit 0
fi

# ==========================================================
# 🚀 Recording Dispatcher (Full Screen vs. Selected Area)
# ==========================================================
AUDIO_ARGS=()

MODE="${1:-}"

case "$MODE" in
    # Interactive rectangular area capture
    area)
        GEOM="$(slurp || true)"

        # Guard: Check if the user aborted the region selection
        if [ -z "$GEOM" ]; then
            notify_error "Area selection cancelled."
            exit 1
        fi

        wf-recorder -g "$GEOM" "${AUDIO_ARGS[@]}" -f "$FILENAME" &
        notify_start "Area recording started."
        ;;

    # Full display capture (anchored to currently focused monitor)
    full)
        ACTIVE_MONITOR="$(
            hyprctl monitors -j \
                | jq -r '.[] | select(.focused == true) | .name' \
                | xargs
        )"

        if [ -z "$ACTIVE_MONITOR" ] || [ "$ACTIVE_MONITOR" = "null" ]; then
            notify_error "Could not detect focused monitor."
            exit 1
        fi

        wf-recorder -o "$ACTIVE_MONITOR" "${AUDIO_ARGS[@]}" -f "$FILENAME" &
        notify_start "Recording started on $ACTIVE_MONITOR."
        ;;

    *)
        usage
        exit 1
        ;;
esac