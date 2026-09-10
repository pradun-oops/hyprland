#!/usr/bin/env bash

# ==========================================================
# 📸 Hyprland Screenshot Utility (screenshot.sh)
# Captures active displays, selected regions, or all outputs via grim & slurp.
# Automatically copies the result to the clipboard and sends a rich preview notification.
# ==========================================================

set -euo pipefail

# ==========================================================
# 📁 Storage Destination & File Naming
# ==========================================================
SAVE_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SAVE_DIR"
FILENAME="$SAVE_DIR/Screenshot_$(date +'%Y-%m-%d_%H-%M-%S').png"

# ==========================================================
# 🎯 Screenshot Dispatcher (Active Output / Area / All)
# ==========================================================
case "$1" in
    # Capture currently focused monitor
    "active") 
        grim -o "$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')" "$FILENAME" 
        ;;

    # Interactive area selection (brief delay prevents menu artifact grab)
    "area") 
        sleep 0.2
        GEOM=$(slurp) && [ -n "$GEOM" ] && grim -g "$GEOM" "$FILENAME" || exit 0 
        ;;

    # Entire multi-monitor canvas
    "all") 
        grim "$FILENAME" 
        ;;

    *) 
        echo "Usage: $0 {active|area|all}" >&2
        exit 1 
        ;;
esac

# ==========================================================
# 📋 Clipboard Sync & Desktop Notification
# ==========================================================
if [[ -f "$FILENAME" ]]; then
    wl-copy < "$FILENAME"
    notify-send -a "Screenshot" "Screenshot Saved" "Saved to $FILENAME" -i "$FILENAME"
fi