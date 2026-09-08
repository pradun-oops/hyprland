#!/usr/bin/env bash
set -euo pipefail

SAVE_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SAVE_DIR"
FILENAME="$SAVE_DIR/Screenshot_$(date +'%Y-%m-%d_%H-%M-%S').png"

case "$1" in
    "active") grim -o "$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')" "$FILENAME" ;;
    "area") sleep 0.2; GEOM=$(slurp) && [ -n "$GEOM" ] && grim -g "$GEOM" "$FILENAME" || exit 0 ;;
    "all") grim "$FILENAME" ;;
    *) echo "Usage: $0 {active|area|all}" >&2; exit 1 ;;
esac

[[ -f "$FILENAME" ]] && wl-copy < "$FILENAME" && notify-send -a "Screenshot" "Screenshot Saved" "Saved to $FILENAME" -i "$FILENAME"