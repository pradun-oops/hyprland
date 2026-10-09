#!/usr/bin/env bash

set -euo pipefail

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    REPO_DIR="$(git rev-parse --show-toplevel)"
else
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
    cp -a "$REPO_DIR/assets/Wallpapers/"* "$HOME/Pictures/Wallpapers/" 2>/dev/null || true
fi

echo ":: Setting default wallpaper..."
DEFAULT_WALLPAPER="$HOME/Pictures/Wallpapers/wallpapers.jpg"
if [ -f "$DEFAULT_WALLPAPER" ]; then
    echo ":: Applying $DEFAULT_WALLPAPER..."
    
    mkdir -p "$HOME/.config/qt5ct/colors" "$HOME/.config/qt6ct/colors" "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0" "$HOME/.config/hypr/configs"
    
    if command -v matugen >/dev/null 2>&1; then
        matugen image "$DEFAULT_WALLPAPER" -m dark --source-color-index 0
        cp -a "$HOME/.config/qt5ct/colors/." "$HOME/.config/qt6ct/colors/" 2>/dev/null || true
    fi
    
    if command -v awww >/dev/null 2>&1; then
        if awww -h 2>&1 | grep -q -- '--transition-type'; then
             awww img "$DEFAULT_WALLPAPER" --transition-type fade --transition-pos 0.5,0.5 --transition-duration 0.5 2>/dev/null || \
             awww -i "$DEFAULT_WALLPAPER" --transition-type fade 2>/dev/null || \
             awww "$DEFAULT_WALLPAPER" --transition-type fade
        elif awww -h 2>&1 | grep -q -- '-i'; then
             awww -i "$DEFAULT_WALLPAPER"
        elif awww -h 2>&1 | grep -q 'load'; then
             awww load "$DEFAULT_WALLPAPER"
        else
             awww img "$DEFAULT_WALLPAPER" --transition-type fade 2>/dev/null || awww "$DEFAULT_WALLPAPER" 2>/dev/null
        fi
    fi
    
    hyprctl reload 2>/dev/null || true
else
    echo "   [!] Warning: $DEFAULT_WALLPAPER not found."
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
        cp -a "$REPO_DIR/$app/"* "$HOME/.config/$app/" 2>/dev/null || true
    else
        echo "   [!] Warning: $app not found in $REPO_DIR"
    fi
done

echo ":: Deploying Hyprland modular environment..."
mkdir -p "$HOME/.config/hypr"

HYPR_COMPONENTS=("configs" "extensions" "quickshell" "scripts" "hypridle.conf" "hyprland.lua")

if [ "$REPO_DIR" != "$HOME/.config/hypr" ]; then
    for component in "${HYPR_COMPONENTS[@]}"; do
        if [ -d "$REPO_DIR/$component" ]; then
            mkdir -p "$HOME/.config/hypr/$component"
            cp -a "$REPO_DIR/$component/"* "$HOME/.config/hypr/$component/" 2>/dev/null || true
        elif [ -f "$REPO_DIR/$component" ]; then
            cp -a "$REPO_DIR/$component" "$HOME/.config/hypr/" 2>/dev/null || true
        else
            echo "   [!] Warning: $component not found in $REPO_DIR"
        fi
    done
else
    echo "   [i] Repository is already in ~/.config/hypr. Skipping copy."
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
touch "$BASH_RC"
BASH_OMP_LINE='eval "$(oh-my-posh init bash --config "$HOME/.config/oh-my-posh/catppuccin.omp.json")"'
if ! grep -q "oh-my-posh init bash" "$BASH_RC" 2>/dev/null; then
    echo "$BASH_OMP_LINE" >> "$BASH_RC"
else
    sed -i 's@.*oh-my-posh init bash.*@'"$BASH_OMP_LINE"'@' "$BASH_RC"
fi

FISH_DIR="$HOME/.config/fish"
FISH_RC="$FISH_DIR/config.fish"
mkdir -p "$FISH_DIR"
touch "$FISH_RC"
FISH_OMP_LINE='oh-my-posh init fish --config "$HOME/.config/oh-my-posh/catppuccin.omp.json" | source'
if ! grep -q "oh-my-posh init fish" "$FISH_RC" 2>/dev/null; then
    echo "$FISH_OMP_LINE" >> "$FISH_RC"
else
    sed -i 's@.*oh-my-posh init fish.*@'"$FISH_OMP_LINE"'@' "$FISH_RC"
fi

echo ":: Setup completed successfully!"