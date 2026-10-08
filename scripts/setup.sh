#!/usr/bin/env bash

set -euo pipefail

# 1. Accurately determine the repository root, even if run from inside the scripts/ folder
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    REPO_DIR="$(git rev-parse --show-toplevel)"
else
    # Fallback just in case git is not initialized
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ "$(basename "$SCRIPT_DIR")" == "scripts" ]]; then
        REPO_DIR="$(dirname "$SCRIPT_DIR")"
    else
        REPO_DIR="$SCRIPT_DIR"
    fi
fi

mkdir -p "$HOME/.config"
mkdir -p "$HOME/Pictures/Wallpapers"

echo ":: Deploying default wallpapers to ~/Pictures/Wallpapers..."
if [ -d "$REPO_DIR/assets/Wallpapers" ]; then
    # Use -a to preserve attributes, overwrite cleanly without failing if it exists
    cp -a "$REPO_DIR/assets/Wallpapers/"* "$HOME/Pictures/Wallpapers/" 2>/dev/null || true
fi

echo ":: Deploying WhiteSur GTK theme to ~/Pictures/Wallpapers..."
WHITESUR_DIR="$HOME/Pictures/Wallpapers/WhiteSur-gtk-theme"
if [ ! -d "$WHITESUR_DIR" ]; then
    git clone https://github.com/vinceliuice/WhiteSur-gtk-theme.git "$WHITESUR_DIR"
else
    echo "   [i] WhiteSur GTK theme already exists. Pulling latest updates..."
    git -C "$WHITESUR_DIR" pull --quiet
fi

echo ":: Deploying global configurations (fastfetch, kitty, matugen)..."
GLOBAL_CONFIGS=("fastfetch" "kitty" "matugen")

for app in "${GLOBAL_CONFIGS[@]}"; do
    if [ -d "$REPO_DIR/$app" ]; then
        mkdir -p "$HOME/.config/$app"
        # Safely overlay files without wiping the entire directory first
        cp -a "$REPO_DIR/$app/"* "$HOME/.config/$app/" 2>/dev/null || true
    else
        echo "   [!] Warning: $app not found in $REPO_DIR"
    fi
done

echo ":: Deploying Hyprland modular environment..."
mkdir -p "$HOME/.config/hypr"

# Explicitly define which folders/files belong inside ~/.config/hypr/
HYPR_COMPONENTS=("configs" "extensions" "quickshell" "scripts" "hypridle.conf" "hyprland.lua")

for component in "${HYPR_COMPONENTS[@]}"; do
    if [ -e "$REPO_DIR/$component" ]; then
        cp -a "$REPO_DIR/$component" "$HOME/.config/hypr/"
    else
        echo "   [!] Warning: $component not found in $REPO_DIR"
    fi
done

echo ":: Checking hardware for connected monitors..."
# This will correctly detect your dual monitor setup (Laptop + Acer EK251Q P2)
MONITOR_COUNT=$(cat /sys/class/drm/*/status 2>/dev/null | grep -c "^connected" || echo 1)
ENTRY_FILE="$HOME/.config/hypr/hyprland.lua"

if [ -f "$ENTRY_FILE" ]; then
    if [ "$MONITOR_COUNT" -gt 1 ]; then
        echo ":: Dual-monitor setup detected ($MONITOR_COUNT displays). Enabling configs.workspaces..."
        sed -i -E 's/^--\s*require\("configs\.workspaces"\)/require("configs.workspaces")/' "$ENTRY_FILE"
    else
        echo ":: Single monitor detected. Disabling configs.workspaces to prevent routing errors..."
        sed -i -E 's/^require\("configs\.workspaces"\)/-- require("configs.workspaces")/' "$ENTRY_FILE"
    fi
fi

echo ":: Downloading and configuring Oh My Posh Catppuccin theme..."
OMP_DIR="$HOME/.config/oh-my-posh"
mkdir -p "$OMP_DIR"
curl -fsSL "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/catppuccin.omp.json" -o "$OMP_DIR/catppuccin.omp.json"

# Configure Bash
BASH_RC="$HOME/.bashrc"
touch "$BASH_RC"
BASH_OMP_LINE='eval "$(oh-my-posh init bash --config "$HOME/.config/oh-my-posh/catppuccin.omp.json")"'
if ! grep -q "oh-my-posh init bash" "$BASH_RC" 2>/dev/null; then
    echo "$BASH_OMP_LINE" >> "$BASH_RC"
else
    sed -i 's|.*oh-my-posh init bash.*|'"$BASH_OMP_LINE"'|' "$BASH_RC"
fi

# Configure Fish
FISH_DIR="$HOME/.config/fish"
FISH_RC="$FISH_DIR/config.fish"
mkdir -p "$FISH_DIR"
touch "$FISH_RC"
FISH_OMP_LINE='oh-my-posh init fish --config "$HOME/.config/oh-my-posh/catppuccin.omp.json" | source'
if ! grep -q "oh-my-posh init fish" "$FISH_RC" 2>/dev/null; then
    echo "$FISH_OMP_LINE" >> "$FISH_RC"
else
    sed -i 's|.*oh-my-posh init fish.*|'"$FISH_OMP_LINE"'|' "$FISH_RC"
fi

echo ":: Setup completed successfully!"