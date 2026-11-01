#!/usr/bin/env bash

set -euo pipefail

THEME_DIR="$HOME/Pictures/Wallpapers/WhiteSur-gtk-theme"
WHITESUR_SCRIPT="$THEME_DIR/tweaks.sh"

notify_ok() { 
    notify-send -i "preferences-desktop-wallpaper" "GDM Sync" "$1"
}

notify_error() { 
    notify-send -u critical -i dialog-error "GDM Sync Error" "$1"
}

has_cmd() { 
    command -v "$1" >/dev/null 2>&1
}

WALL_CMD="swww"
if ! has_cmd swww && has_cmd awww; then
    WALL_CMD="awww"
fi

for cmd in "$WALL_CMD" awk sed notify-send sudo; do
    has_cmd "$cmd" || { notify_error "Missing command: $cmd"; exit 1; }
done

has_cmd figlet && has_cmd lolcat && figlet -f slant "GDM SYNC" | lolcat || echo "GDM SYNC"
echo "------------------------------------------------"

CURRENT_WALLPAPER="$("$WALL_CMD" query 2>/dev/null | awk -F 'image: ' '/currently displaying: image:/ {print $2; exit}' | sed 's/[[:space:]]*$//')"

if [[ -z "$CURRENT_WALLPAPER" || ! -f "$CURRENT_WALLPAPER" ]]; then
    notify_error "No active wallpaper found from $WALL_CMD."
    exit 1
fi

if [[ ! -f "$WHITESUR_SCRIPT" ]]; then
    notify_error "WhiteSur tweaks script not found at: $WHITESUR_SCRIPT"
    exit 1
fi

echo "Applying wallpaper to GDM: $CURRENT_WALLPAPER"
sudo "$WHITESUR_SCRIPT" -g -b "$CURRENT_WALLPAPER"

notify_ok "Login screen updated successfully."