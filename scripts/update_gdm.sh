#!/usr/bin/env bash
set -euo pipefail

THEME_DIR="$HOME/Pictures/Wallpapers/WhiteSur-gtk-theme"
WHITESUR_SCRIPT="$THEME_DIR/tweaks.sh"

notify_ok() { notify-send -i "preferences-desktop-wallpaper" "GDM Sync" "$1"; }
notify_error() { notify-send -u critical -i dialog-error "GDM Sync Error" "$1"; }
has_cmd() { command -v "$1" >/dev/null 2>&1; }

for cmd in awww awk sed xargs notify-send sudo; do
    has_cmd "$cmd" || { notify_error "Missing command: $cmd"; exit 1; }
done

has_cmd figlet && has_cmd lolcat && figlet -f slant "GDM SYNC" | lolcat || echo "GDM SYNC"
echo "------------------------------------------------"

CURRENT_WALLPAPER="$(awww query 2>/dev/null | awk -F 'image: ' '/currently displaying: image:/ {print $2; exit}' | sed 's/:$//' | xargs)"

[[ -n "$CURRENT_WALLPAPER" && -f "$CURRENT_WALLPAPER" && -f "$WHITESUR_SCRIPT" ]] || {
    notify_error "Wallpaper or WhiteSur script invalid/not found."
    exit 1
}

echo "Applying wallpaper to GDM..."
sudo "$WHITESUR_SCRIPT" -g -b "$CURRENT_WALLPAPER"

notify_ok "Login screen updated successfully."