#!/usr/bin/env bash

# ==========================================================
# 🖼️ GDM Lockscreen Wallpaper Sync Utility (update_gdm.sh)
# Synchronizes the active dynamic wallpaper (queried from awww)
# with the GNOME Display Manager (GDM) using WhiteSur theme tweaks.
# ==========================================================

set -euo pipefail

# ==========================================================
# 📁 Paths & Script Definitions
# ==========================================================
THEME_DIR="$HOME/Pictures/Wallpapers/WhiteSur-gtk-theme"
WHITESUR_SCRIPT="$THEME_DIR/tweaks.sh"

# ==========================================================
# 📢 Desktop Notification Dispatchers
# ==========================================================
notify_ok() { 
    notify-send -i "preferences-desktop-wallpaper" "GDM Sync" "$1"
}

notify_error() { 
    notify-send -u critical -i dialog-error "GDM Sync Error" "$1"
}

# ==========================================================
# 🔍 Dependency & Command Verification
# ==========================================================
has_cmd() { 
    command -v "$1" >/dev/null 2>&1
}

# Ensure all essential CLI tools exist in PATH
for cmd in awww awk sed xargs notify-send sudo; do
    has_cmd "$cmd" || { notify_error "Missing command: $cmd"; exit 1; }
done

# ==========================================================
# 🎨 Terminal Banner Display
# ==========================================================
has_cmd figlet && has_cmd lolcat && figlet -f slant "GDM SYNC" | lolcat || echo "GDM SYNC"
echo "------------------------------------------------"

# ==========================================================
# 🖼️ Active Wallpaper Query
# Extracts the currently rendered wallpaper path from awww daemon
# ==========================================================
CURRENT_WALLPAPER="$(awww query 2>/dev/null | awk -F 'image: ' '/currently displaying: image:/ {print $2; exit}' | sed 's/:$//' | xargs)"

# Guard: Validate both wallpaper path and WhiteSur script existence
[[ -n "$CURRENT_WALLPAPER" && -f "$CURRENT_WALLPAPER" && -f "$WHITESUR_SCRIPT" ]] || {
    notify_error "Wallpaper or WhiteSur script invalid/not found."
    exit 1
}

# ==========================================================
# 🚀 Apply Wallpaper to GDM Login Screen
# ==========================================================
echo "Applying wallpaper to GDM..."
sudo "$WHITESUR_SCRIPT" -g -b "$CURRENT_WALLPAPER"

notify_ok "Login screen updated successfully."