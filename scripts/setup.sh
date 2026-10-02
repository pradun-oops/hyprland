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
# 🐚 Oh My Posh Theme & Shell Configuration
# ==========================================================
echo ":: Setting up Oh My Posh Catppuccin theme..."
OMP_DIR="$HOME/.config/oh-my-posh"
mkdir -p "$OMP_DIR"

if [ ! -f "$OMP_DIR/catppuccin.omp.json" ]; then
    echo ":: Downloading Catppuccin Oh My Posh theme..."
    curl -sL https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/catppuccin.omp.json -o "$OMP_DIR/catppuccin.omp.json"
fi

# Inject Bash Initialization
if ! grep -q "oh-my-posh init bash" "$HOME/.bashrc" 2>/dev/null; then
    echo ":: Configuring Oh My Posh for Bash..."
    echo "" >> "$HOME/.bashrc"
    echo "# Oh My Posh Initialization" >> "$HOME/.bashrc"
    echo 'eval "$(oh-my-posh init bash --config "$HOME/.config/oh-my-posh/catppuccin.omp.json")"' >> "$HOME/.bashrc"
fi

# Inject Fish Initialization
mkdir -p "$HOME/.config/fish"
if [ ! -f "$HOME/.config/fish/config.fish" ] || ! grep -q "oh-my-posh init fish" "$HOME/.config/fish/config.fish" 2>/dev/null; then
    echo ":: Configuring Oh My Posh for Fish..."
    echo "" >> "$HOME/.config/fish/config.fish"
    echo "# Oh My Posh Initialization" >> "$HOME/.config/fish/config.fish"
    echo 'oh-my-posh init fish --config "$HOME/.config/oh-my-posh/catppuccin.omp.json" | source' >> "$HOME/.config/fish/config.fish"
fi

# ==========================================================
# 🔑 File Permissions
# ==========================================================
echo ":: Setting execution permissions on shell scripts..."
if [ -d "$REPO_DIR/scripts" ]; then
    find "$REPO_DIR/scripts" -type f -name "*.sh" -exec chmod +x {} +
fi

# ==========================================================
# 🔄 Compositor Live Reload
# ==========================================================
echo ":: Reloading Hyprland configuration..."
if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    hyprctl reload
else
    echo ":: Notice: Hyprland session not detected. Skipping live reload."
fi

echo ":: Setup complete! All configurations deployed successfully."