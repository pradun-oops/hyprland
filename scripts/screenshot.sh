#!/usr/bin/env bash

set -euo pipefail

SAVE_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SAVE_DIR"
FILENAME="$SAVE_DIR/Screenshot_$(date +'%Y-%m-%d_%H-%M-%S').png"

TARGET="${1:-}"

case "$TARGET" in
    "active")
        ACTIVE_MONITOR=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
        grim -o "$ACTIVE_MONITOR" "$FILENAME"
        ;;
    "area")
        sleep 0.2
        if ! GEOM=$(slurp 2>/dev/null) || [[ -z "$GEOM" ]]; then
            exit 0
        fi
        grim -g "$GEOM" "$FILENAME"
        ;;
    "all")
        grim "$FILENAME"
        ;;
    *)
        echo "Usage: $0 {active|area|all}" >&2
        exit 1
        ;;
esac

if [[ -f "$FILENAME" ]]; then
    wl-copy --type image/png < "$FILENAME"
    notify-send -a "Screenshot" "Screenshot Saved" "Saved to $FILENAME" -i "$FILENAME"
fi