#!/usr/bin/env bash

set -euo pipefail

QS_DIR="$HOME/.config/hypr/quickshell/circle_search"
IMAGE_PATH="/tmp/circle_screen.png"

for cmd in hyprctl jq grim quickshell notify-send; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        notify-send -u critical -i dialog-error "Circle Search Error" "Missing command: $cmd"
        exit 1
    fi
done

if [[ ! -d "$QS_DIR" ]]; then
    notify-send -u critical -i dialog-error "Circle Search Error" "Directory not found: $QS_DIR"
    exit 1
fi

if pgrep -u "$USER" -f "quickshell.*$QS_DIR" >/dev/null 2>&1; then
    exit 0
fi

ACTIVE_MONITOR="$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .name')"

if [[ -z "$ACTIVE_MONITOR" || "$ACTIVE_MONITOR" == "null" ]]; then
    notify-send -u critical -i dialog-error "Circle Search Error" "Could not determine active monitor."
    exit 1
fi

rm -f "$IMAGE_PATH"

if grim -o "$ACTIVE_MONITOR" "$IMAGE_PATH"; then
    quickshell -c "$QS_DIR" >/dev/null 2>&1 &
else
    notify-send -u critical -i dialog-error "Circle Search Error" "Failed to capture screen on $ACTIVE_MONITOR."
    exit 1
fi