#!/usr/bin/env bash

# ==========================================================
# 🚀 Dotfiles Deployment & Symlink Sync Script
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
    # Copying (cp -rn) instead of moving (mv) so your git repo stays clean
    # -r = recursive, -n = no clobber (won't overwrite if you already added your own)
    cp -rn "$REPO_DIR/assets/Wallpapers/"* "$HOME/Pictures/Wallpapers/" 2>/dev/null || true
else
    echo ":: Notice: $REPO_DIR/assets/Wallpapers not found. Skipping."
fi

# ==========================================================
# 🔗 Global Configuration Deployment (~/.config/)
# Uses symlinks so live edits reflect directly in the git repo.
# ==========================================================
echo ":: Deploying global configurations via symlinks..."
GLOBAL_CONFIGS=("fastfetch" "kitty" "matugen")

for app in "${GLOBAL_CONFIGS[@]}"; do
    if [ -d "$REPO_DIR/$app" ]; then
        ln -sfn "$REPO_DIR/$app" "$HOME/.config/$app"
    fi
done

# ==========================================================
# 🪟 Hyprland & Quickshell Suite Deployment (~/.config/hypr/)
# ==========================================================
echo ":: Deploying Hyprland modular environment via symlinks..."
HYPR_CONFIGS=("assets" "configs" "quickshell" "scripts" "hyprland.lua")

for item in "${HYPR_CONFIGS[@]}"; do
    if [ -e "$REPO_DIR/$item" ]; then
        ln -sfn "$REPO_DIR/$item" "$HOME/.config/hypr/$item"
    fi
done

# ==========================================================
# 🔑 File Permissions
# ==========================================================
echo ":: Setting execution permissions on shell scripts..."
# Apply permissions directly to the repo files since we are symlinking them
if [ -d "$REPO_DIR/scripts" ]; then
    find "$REPO_DIR/scripts" -type f -name "*.sh" -exec chmod +x {} +
fi

# ==========================================================
# 🔄 Compositor Live Reload
# ==========================================================
echo ":: Reloading Hyprland configuration..."
# Check both if hyprctl exists AND if a Hyprland session is actually active
if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    hyprctl reload
else
    echo ":: Notice: Hyprland session not detected. Skipping live reload."
fi

echo ":: Setup complete! All configurations deployed successfully."