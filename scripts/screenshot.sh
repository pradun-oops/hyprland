#!/usr/bin/env bash

# Screenshot save directory
SAVE_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SAVE_DIR"

FILENAME="$SAVE_DIR/Screenshot_$(date +'%Y-%m-%d_%H-%M-%S').png"

case "$1" in
    "active")
        # Active/Focused monitor only
        MONITOR=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name')
        grim -o "$MONITOR" "$FILENAME"
        ;;
    "area")
        # Selected region
        # The sleep command prevents the Wayland grab lock issue with the compositor
        sleep 0.2 
        GEOM=$(slurp)
        [ -z "$GEOM" ] && exit 0
        grim -g "$GEOM" "$FILENAME"
        ;;
    "all")
        # Entire desktop (both monitors)
        grim "$FILENAME"
        ;;
    *)
        echo "Usage: $0 {active|area|all}"
        exit 1
        ;;
esac

if [ -f "$FILENAME" ]; then
    wl-copy < "$FILENAME"
    notify-send -a "Screenshot" "Screenshot Saved" "Saved to $FILENAME" -i "$FILENAME"
fi