#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$HOME/.config"
mkdir -p "$HOME/Pictures/Wallpapers"

echo ":: Deploying default wallpapers to ~/Pictures/Wallpapers..."
if [ -d "$REPO_DIR/assets/Wallpapers" ]; then
    cp -rn "$REPO_DIR/assets/Wallpapers/"* "$HOME/Pictures/Wallpapers/" 2>/dev/null || true
fi

echo ":: Cloning WhiteSur GTK theme to ~/Pictures/Wallpapers..."
WHITESUR_DIR="$HOME/Pictures/Wallpapers/WhiteSur-gtk-theme"
if [ ! -d "$WHITESUR_DIR" ]; then
    git clone https://github.com/vinceliuice/WhiteSur-gtk-theme.git "$WHITESUR_DIR"
fi

echo ":: Deploying global configurations (fastfetch, kitty, matugen)..."
GLOBAL_CONFIGS=("fastfetch" "kitty" "matugen")

for app in "${GLOBAL_CONFIGS[@]}"; do
    if [ -d "$REPO_DIR/$app" ]; then
        rm -rf "$HOME/.config/$app"
        cp -a "$REPO_DIR/$app" "$HOME/.config/"
    fi
done

echo ":: Deploying Hyprland modular environment..."
rm -rf "$HOME/.config/hypr"
mkdir -p "$HOME/.config/hypr"

if [ -d "$REPO_DIR/hypr" ]; then
    cp -a "$REPO_DIR/hypr/"* "$HOME/.config/hypr/" 2>/dev/null || true
else
    find "$REPO_DIR" -mindepth 1 -maxdepth 1 ! -name '.git' ! -name 'fastfetch' ! -name 'kitty' ! -name 'matugen' ! -name 'setup.sh' ! -name 'install.sh' ! -name 'assets' -exec cp -a {} "$HOME/.config/hypr/" \;
fi

echo ":: Checking hardware for connected monitors..."
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

BASH_RC="$HOME/.bashrc"
BASH_OMP_LINE='eval "$(oh-my-posh init bash --config "$HOME/.config/oh-my-posh/catppuccin.omp.json")"'
if [ -f "$BASH_RC" ]; then
    if ! grep -q "oh-my-posh init bash" "$BASH_RC" 2>/dev/null; then
        echo "$BASH_OMP_LINE" >> "$BASH_RC"
    else
        sed -i 's|.*oh-my-posh init bash.*|'"$BASH_OMP_LINE"'|' "$BASH_RC"
    fi
fi

FISH_RC="$HOME/.config/fish/config.fish"
FISH_OMP_LINE='oh-my-posh init fish --config "$HOME/.config/oh-my-posh/catppuccin.omp.json" | source'
if [ -f "$FISH_RC" ]; then
    if ! grep -q "oh-my-posh init fish" "$FISH_RC" 2>/dev/null; then
        echo "$FISH_OMP_LINE" >> "$FISH_RC"
    else
        sed -i 's|.*oh-my-posh init fish.*|'"$FISH_OMP_LINE"'|' "$FISH_RC"
    fi
fi

echo ":: Setup completed successfully!"