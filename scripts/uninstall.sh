#!/usr/bin/env bash

# ==========================================================
# 🛑 Fedora Hyprland & Quickshell Uninstaller
# Safely removes Hyprland, Quickshell, AWWW, Matugen, 
# custom COPRs, and cleans up dotfiles.
# ==========================================================

set -u

# Define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${RED}⚠️  WARNING: This script will remove Hyprland, Quickshell, custom themes, and your configuration files.${NC}"
read -p "Are you sure you want to completely uninstall this setup? (y/N): " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo ":: Uninstallation aborted."
    exit 0
fi

echo -e "\n${YELLOW}:: 1. Removing compiled binaries & Rust packages (AWWW & Matugen)...${NC}"
sudo rm -f /usr/local/bin/awww /usr/local/bin/awww-daemon
sudo rm -f /usr/local/bin/swww /usr/local/bin/swww-daemon
cargo uninstall matugen 2>/dev/null || echo "Matugen not found in Cargo, skipping."

echo -e "\n${YELLOW}:: 2. Removing WhiteSur Icons...${NC}"
rm -rf ~/.local/share/icons/WhiteSur*
echo "WhiteSur icons removed."

echo -e "\n${YELLOW}:: 3. Removing Hyprglass Plugin...${NC}"
if command -v hyprpm >/dev/null 2>&1; then
    hyprpm remove hyprglass || echo "Hyprglass not installed or hyprpm unavailable."
fi

echo -e "\n${YELLOW}:: 4. Disabling custom COPR repositories...${NC}"
sudo dnf copr disable -y errornointernet/quickshell
sudo dnf copr disable -y lionheartp/Hyprland
sudo dnf copr disable -y solopasha/hyprland
sudo dnf copr disable -y tofik/nwg-shell

echo -e "\n${YELLOW}:: 5. Removing specific desktop packages...${NC}"
# We ONLY remove the GUI/Hyprland specific packages. 
# Core utilities (gcc, python3, pipewire, etc.) are intentionally omitted to prevent breaking Fedora.
PACKAGES_TO_REMOVE=(
    hyprland
    hyprland-devel
    hyprland-guiutils
    quickshell
    qt5ct
    qt6ct
    nwg-look
    fira-code-fonts
    grim
    hypridle
    hyprlock
    slurp
    wl-clipboard
    fastfetch
    figlet
    lolcat
)

sudo dnf remove -y "${PACKAGES_TO_REMOVE[@]}"

echo -e "\n${YELLOW}:: 6. Cleaning up unneeded dependencies...${NC}"
sudo dnf autoremove -y

echo -e "\n${YELLOW}:: 7. Removing Configuration Files...${NC}"
read -p "Do you want to delete the configuration folders (~/.config/hypr, ~/.config/quickshell)? (y/N): " conf_confirm
if [[ "$conf_confirm" =~ ^[Yy]$ ]]; then
    echo "Removing configurations..."
    rm -rf ~/.config/hypr
    rm -rf ~/.config/quickshell
    # Optional: rm -rf ~/.config/kitty 
    echo "Configs deleted."
else
    echo "Configurations kept intact."
fi

echo -e "\n${GREEN}✅ Uninstallation complete!${NC}"
echo "Note: RPMFusion repositories and core system utilities (like PipeWire, Make, GCC) were left intact as they are standard components of Fedora."