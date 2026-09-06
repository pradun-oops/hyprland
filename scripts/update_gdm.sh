#!/usr/bin/env bash

set -euo pipefail

THEME_DIR="$HOME/Pictures/Wallpapers/WhiteSur-gtk-theme"
WHITESUR_SCRIPT="$THEME_DIR/tweaks.sh"
NOTIFY_ICON="preferences-desktop-wallpaper"

notify_ok() {
    notify-send -i "$NOTIFY_ICON" "GDM Sync" "$1"
}

notify_error() {
    notify-send -u critical -i dialog-error "GDM Sync Error" "$1"
}

print_line() {
    echo "------------------------------------------------"
}

has_cmd() {
    command -v "$1" >/dev/null 2>&1
}

# Added matugen to the dependency check
for cmd in awww awk sed xargs notify-send sudo matugen; do
    if ! has_cmd "$cmd"; then
        notify_error "Missing command: $cmd"
        echo "Missing command: $cmd"
        exit 1
    fi
done

clear

if has_cmd figlet && has_cmd lolcat; then
    figlet -f slant "GDM SYNC" | lolcat
    print_line | lolcat
else
    echo "GDM SYNC"
    print_line
fi

echo "Checking current wallpaper..."

CURRENT_WALLPAPER="$(
    awww query 2>/dev/null \
        | awk -F 'image: ' '/currently displaying: image:/ {print $2; exit}' \
        | sed 's/:$//' \
        | xargs
)"

if [ -z "$CURRENT_WALLPAPER" ]; then
    notify_error "Could not detect current wallpaper from awww."
    echo "ERROR: Could not detect current wallpaper from awww."
    exit 1
fi

if [ ! -f "$CURRENT_WALLPAPER" ]; then
    notify_error "Wallpaper file not found."
    echo "ERROR: Image not found at: $CURRENT_WALLPAPER"
    exit 1
fi

if [ ! -d "$THEME_DIR" ]; then
    notify_error "WhiteSur theme directory not found."
    echo "ERROR: Directory not found: $THEME_DIR"
    exit 1
fi

if [ ! -f "$WHITESUR_SCRIPT" ]; then
    notify_error "WhiteSur tweaks.sh not found."
    echo "ERROR: Script not found: $WHITESUR_SCRIPT"
    exit 1
fi

echo "Found wallpaper:"
echo "$CURRENT_WALLPAPER"
print_line

# ------------------------------------------------------------
# MATUGEN: ADAPT COLORS
# ------------------------------------------------------------
echo "Adapting system colors with Matugen..."

mkdir -p "$HOME/.config/qt5ct/colors"
mkdir -p "$HOME/.config/qt6ct/colors"
mkdir -p "$HOME/.config/gtk-3.0"
mkdir -p "$HOME/.config/gtk-4.0"
mkdir -p "$HOME/.config/hypr/configs"

matugen image "$CURRENT_WALLPAPER" --source-color-index 0

# Sync Qt5 colors to Qt6 automatically
cp -a "$HOME/.config/qt5ct/colors/." "$HOME/.config/qt6ct/colors/" 2>/dev/null || true

echo "Theme files updated successfully."
print_line
# ------------------------------------------------------------
# GDM: APPLY WALLPAPER
# ------------------------------------------------------------
echo "Applying wallpaper to GDM..."
echo "Sudo password may be required."
print_line

cd "$THEME_DIR"

sudo ./tweaks.sh -g -b "$CURRENT_WALLPAPER"

print_line
echo "DONE! Colors generated and Login screen updated."

notify_ok "Theme colors generated and GDM updated successfully."

sleep 2