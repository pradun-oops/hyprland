#!/usr/bin/env bash

# ==========================================================
# 🚀 Dotfiles Deployment Script
# Deploys Hyprland configuration, Quickshell widgets, terminal
# styles, theming profiles, and wallpapers from the repo to $HOME.
# ==========================================================

set -euo pipefail

# ==========================================================
# 📍 Repository Path Detection
# Resolves the absolute root path of the cloned repository.
# ==========================================================
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ==========================================================
# 📁 Directory Preparation
# Ensures core target destination directories exist.
# ==========================================================
mkdir -p "$HOME/.config/hypr"
mkdir -p "$HOME/Pictures/Wallpapers"

# ==========================================================
# 🖼️ Default Wallpapers Deployment
# Copies wallpapers to the standard Pictures directory.
# ==========================================================
echo ":: Deploying default wallpapers to ~/Pictures/Wallpapers..."
if [ -d "$REPO_DIR/assets/Wallpapers" ]; then
    cp -rn "$REPO_DIR/assets/Wallpapers/"* "$HOME/Pictures/Wallpapers/" 2>/dev/null || true
else
    echo ":: Notice: $REPO_DIR/assets/Wallpapers not found. Skipping."
fi

# ==========================================================
# 🍏 WhiteSur GTK Theme (GDM Background Utility)
# Clones the repo to Wallpapers so the GDM keybind works.
# ==========================================================
echo ":: Cloning WhiteSur GTK theme to ~/Pictures/Wallpapers..."
WHITESUR_DIR="$HOME/Pictures/Wallpapers/WhiteSur-gtk-theme"
if [ ! -d "$WHITESUR_DIR" ]; then
    git clone https://github.com/vinceliuice/WhiteSur-gtk-theme.git "$WHITESUR_DIR"
else
    echo ":: Notice: WhiteSur-gtk-theme already exists in Wallpapers. Skipping clone."
fi

# ==========================================================
# 🖥️ Dynamic Workspace Configuration (Dual Monitor Detection)
# Reads kernel DRM status to count physically connected displays.
# ==========================================================
echo ":: Checking hardware for connected monitors..."
MONITOR_COUNT=$(cat /sys/class/drm/*/status 2>/dev/null | grep -c "^connected" || echo 1)
ENTRY_FILE="$REPO_DIR/hyprland.lua"

if [ -f "$ENTRY_FILE" ]; then
    if [ "$MONITOR_COUNT" -gt 1 ]; then
        echo ":: Dual-monitor setup detected ($MONITOR_COUNT displays). Enabling configs.workspaces..."
        sed -i -E 's/^--\s*require\("configs\.workspaces"\)/require("configs.workspaces")/' "$ENTRY_FILE"
    else
        echo ":: Single monitor detected. Disabling configs.workspaces to prevent routing errors..."
        sed -i -E 's/^require\("configs\.workspaces"\)/-- require("configs.workspaces")/' "$ENTRY_FILE"
    fi
else
    echo ":: Notice: $ENTRY_FILE not found. Skipping dynamic workspace configuration."
fi

# ==========================================================
# 🔑 File Permissions (Repo-Side)
# Ensures scripts are executable before copying them over.
# ==========================================================
echo ":: Setting execution permissions on shell scripts..."
if [ -d "$REPO_DIR/scripts" ]; then
    find "$REPO_DIR/scripts" -type f -name "*.sh" -exec chmod +x {} +
fi

# ==========================================================
# 🔗 Global Configuration Deployment (~/.config/)
# Copies configurations to the home directory.
# ==========================================================
echo ":: Deploying global configurations by copying..."
GLOBAL_CONFIGS=("fastfetch" "kitty" "matugen")

for app in "${GLOBAL_CONFIGS[@]}"; do
    if [ -d "$REPO_DIR/$app" ]; then
        rm -rf "$HOME/.config/$app"
        cp -r "$REPO_DIR/$app" "$HOME/.config/"
    fi
done

# ==========================================================
# 🪟 Hyprland & Quickshell Suite Deployment (~/.config/hypr/)
# Copies the modular environment files including hypridle.conf
# ==========================================================
echo