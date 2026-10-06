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
# 🖼️️ Default Wallpapers Deployment
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
# 🎨 GTK4 & GNOME Theming Configurations
# ==========================================================
echo ":: Configuring GTK4 and Libadwaita dark mode preferences..."
mkdir -p "$HOME/.config/gtk-4.0"
cat <<'EOF' > "$HOME/.config/gtk-4.0/settings.ini"
[Settings]
gtk-theme-name=adw-gtk3-dark
gtk-icon-theme-name=WhiteSur
gtk-application-prefer-dark-theme=1
EOF

echo ":: Applying GSettings color-scheme preference..."
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' || true

echo ":: Killing active Nautilus instances to apply theme changes..."
nautilus -q 2>/dev/null || true

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
echo ":: Note: You may need to log out and log back in for all environment variables (like ADW_DISABLE_PORTAL) to fully apply." here do one more thing ls -la
total 20
drwxr-xr-x. 1 pradun pradun   198 Sep 26 10:33 ./
drwxr-xr-x+ 1 pradun pradun  2512 Oct  2 11:05 ../
drwxr-xr-x. 1 pradun pradun   266 Oct  2 10:52 assets/
drwxr-xr-x. 1 pradun pradun   318 Sep 28 16:11 configs/
drwxr-xr-x. 1 pradun pradun    58 Sep 26 10:33 extensions/
drwxr-xr-x. 1 pradun pradun    34 Sep  5 21:54 fastfetch/
drwxr-xr-x. 1 pradun pradun   164 Oct  6 12:33 .git/
-rw-r--r--. 1 pradun pradun  2232 Sep 14 07:47 hypridle.conf
-rw-------. 1 pradun pradun  2643 Sep 30 15:35 hyprland.lua
drwxr-xr-x. 1 pradun pradun    20 Sep  5 21:54 kitty/
drwxr-xr-x. 1 pradun pradun    40 Sep  6 10:46 matugen/
drwxr-xr-x. 1 pradun pradun   504 Oct  1 12:46 quickshell/
-rw-r--r--. 1 pradun pradun 11831 Oct  6 13:58 README.md
drwxr-xr-x. 1 pradun pradun   296 Oct  2 11:56 scripts/ 