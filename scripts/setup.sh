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
mkdir -p "$HOME/.config/hypr/extensions"

# ==========================================================
# 📦 Global Configuration Deployment (~/.config/)
# Syncs standalone terminal, fetch tools, and palette configs.
# ==========================================================
echo ":: Deploying global configurations..."
cp -a "$REPO_DIR/fastfetch" "$HOME/.config/" 2>/dev/null || true
cp -a "$REPO_DIR/kitty"     "$HOME/.config/" 2>/dev/null || true
cp -a "$REPO_DIR/matugen"   "$HOME/.config/" 2>/dev/null || true

# ==========================================================
# 🪟 Hyprland & Quickshell Suite Deployment (~/.config/hypr/)
# Deploys Lua configs, assets, Quickshell components, and helper scripts.
# ==========================================================
echo ":: Deploying Hyprland modular environment..."
cp -a "$REPO_DIR/assets"       "$HOME/.config/hypr/" 2>/dev/null || true
cp -a "$REPO_DIR/configs"      "$HOME/.config/hypr/" 2>/dev/null || true
cp -a "$REPO_DIR/quickshell"   "$HOME/.config/hypr/" 2>/dev/null || true
cp -a "$REPO_DIR/scripts"      "$HOME/.config/hypr/" 2>/dev/null || true
cp -a "$REPO_DIR/hyprland.lua" "$HOME/.config/hypr/" 2>/dev/null || true

# ==========================================================
# 🧩 VSCodium Extension Deployment
# Copies the pre-packaged .vsix extension into the config folder
# and installs it directly into VSCodium.
# ==========================================================
echo ":: Installing custom VSCodium theme sync extension..."
if [ -d "$REPO_DIR/extensions" ]; then
    cp -a "$REPO_DIR/extensions/." "$HOME/.config/hypr/extensions/" 2>/dev/null || true
fi

if [ -f "$HOME/.config/hypr/extensions/matugen-theme-sync-0.0.1.vsix" ]; then
    codium --install-extension "$HOME/.config/hypr/extensions/matugen-theme-sync-0.0.1.vsix" --force
else
    echo ":: Warning: Pre-packaged VSIX file not found in extensions directory."
fi

# ==========================================================
# 🔑 File Permissions
# Grants executable privileges (+x) to all deployed bash scripts.
# ==========================================================
echo ":: Setting execution permissions on shell scripts..."
if [ -d "$HOME/.config/hypr/scripts" ]; then
    find "$HOME/.config/hypr/scripts" -type f -name "*.sh" -exec chmod +x {} +
fi

# ==========================================================
# 🔄 Compositor Live Reload
# Signals Hyprland to apply updated Lua configs if session is active.
# ==========================================================
echo ":: Reloading Hyprland configuration..."
if command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload
fi

echo ":: Setup complete! All configurations deployed successfully."