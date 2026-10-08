#!/bin/bash

QS_DIR="$HOME/.config/hypr/quickshell/circle_search"
IMAGE_PATH="/tmp/circle_screen.png"

if pgrep -f "quickshell -c $QS_DIR" > /dev/null; then
    exit 0
fi

ACTIVE_MONITOR=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')

if [ -z "$ACTIVE_MONITOR" ]; then
    notify-send "Circle Search Error" "Could not determine active monitor."
    exit 1
fi

rm -f "$IMAGE_PATH"

if grim -o "$ACTIVE_MONITOR" "$IMAGE_PATH"; then
    quickshell -c "$QS_DIR/" >/dev/null 2>&1 & disown
else
    notify-send "Circle Search Error" "Failed to capture the screen."
    exit 1
fi