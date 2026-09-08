#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p "$HOME/.config/hypr"
mkdir -p "$HOME/Pictures"

echo "Copying global configurations..."
cp -a "$REPO_DIR/fastfetch" "$HOME/.config/" 2>/dev/null || true
cp -a "$REPO_DIR/kitty" "$HOME/.config/" 2>/dev/null || true
cp -a "$REPO_DIR/matugen" "$HOME/.config/" 2>/dev/null || true

echo "Copying Hyprland environment..."
cp -a "$REPO_DIR/assets" "$HOME/.config/hypr/" 2>/dev/null || true
cp -a "$REPO_DIR/configs" "$HOME/.config/hypr/" 2>/dev/null || true
cp -a "$REPO_DIR/quickshell" "$HOME/.config/hypr/" 2>/dev/null || true
cp -a "$REPO_DIR/scripts" "$HOME/.config/hypr/" 2>/dev/null || true
cp -a "$REPO_DIR/hyprland.lua" "$HOME/.config/hypr/" 2>/dev/null || true

echo "Copying Wallpapers..."
cp -a "$REPO_DIR/Wallpapers" "$HOME/Pictures/" 2>/dev/null || true

echo "Making scripts executable..."
if [ -d "$HOME/.config/hypr/scripts" ]; then
    find "$HOME/.config/hypr/scripts" -type f -name "*.sh" -exec chmod +x {} +
fi

echo "Reloading Hyprland..."
if command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload
fi

echo "Setup complete!"