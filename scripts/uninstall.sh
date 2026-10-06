#!/usr/bin/env bash

set -u

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}⚠️  WARNING: This script will remove Hyprland, Quickshell, custom themes, and your configuration files.${NC}"
read -p "Are you sure you want to completely uninstall this setup? (y/N): " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo ":: Uninstallation aborted."
    exit 0
fi

echo -e "\n${YELLOW}:: 1. Removing compiled binaries & Rust packages (AWWW, Matugen, Oh My Posh)...${NC}"
sudo rm -f /usr/local/bin/awww /usr/local/bin/awww-daemon
sudo rm -f /usr/local/bin/swww /usr/local/bin/swww-daemon
sudo rm -f /usr/local/bin/oh-my-posh 2>/dev/null
cargo uninstall matugen 2>/dev/null || echo "Matugen not found in Cargo, skipping."

echo -e "\n${YELLOW}:: 2. Removing WhiteSur Icons & Custom Fonts...${NC}"
rm -rf ~/.local/share/icons/WhiteSur*
rm -f ~/.local/share/fonts/NerdFontsSymbolsOnly*
fc-cache -fv
echo "Icons and fonts removed."

echo -e "\n${YELLOW}:: 3. Removing Hyprglass Plugin...${NC}"
if command -v hyprpm >/dev/null 2>&1; then
    hyprpm remove hyprglass || echo "Hyprglass not installed or hyprpm unavailable."
fi

echo -e "\n${YELLOW}:: 4. Disabling custom COPR repositories...${NC}"
sudo dnf copr disable -y errornointernet/quickshell
sudo dnf copr disable -y lionheartp/Hyprland
sudo dnf copr disable -y solopasha/hyprland
sudo dnf copr disable -y tofik/nwg-shell

echo -e "\n${YELLOW}:: 5. Reverting Shell Configuration to Bash...${NC}"
echo "Changing default shell back to Bash..."
sudo chsh -s $(which bash) "${SUDO_USER:-$USER}" || echo "Failed to change shell. You may need to run 'chsh -s /bin/bash' manually."

echo "Cleaning Oh My Posh initialization from .bashrc and config.fish..."
sed -i '/oh-my-posh/d' "$HOME/.bashrc" 2>/dev/null || true
sed -i '/Oh My Posh Initialization/d' "$HOME/.bashrc" 2>/dev/null || true
if [ -f "$HOME/.config/fish/config.fish" ]; then
    sed -i '/oh-my-posh/d' "$HOME/.config/fish/config.fish" 2>/dev/null || true
    sed -i '/Oh My Posh Initialization/d' "$HOME/.config/fish/config.fish" 2>/dev/null || true
fi

echo -e "\n${YELLOW}:: 6. Removing specific desktop packages...${NC}"
PACKAGES_TO_REMOVE=(
    hyprland
    hyprland-devel
    hyprland-guiutils
    xdg-desktop-portal-hyprland
    quickshell
    qt5ct
    qt6ct
    qt6-qt5compat
    nwg-look
    adw-gtk3-theme
    fira-code-fonts
    grim
    hypridle
    hyprlock
    slurp
    wl-clipboard
    cliphist
    blueman
    fastfetch
    figlet
    lolcat
    fish
)

sudo dnf remove -y "${PACKAGES_TO_REMOVE[@]}"

echo -e "\n${YELLOW}:: 7. Cleaning up unneeded dependencies...${NC}"
sudo dnf autoremove -y

echo -e "\n${YELLOW}:: 8. Removing Configuration Files...${NC}"
read -p "Do you want to delete the configuration folders (~/.config/hypr, ~/.config/quickshell, etc)? (y/N): " conf_confirm
if [[ "$conf_confirm" =~ ^[Yy]$ ]]; then
    echo "Removing configurations..."
    rm -rf ~/.config/hypr
    rm -rf ~/.config/quickshell
    rm -rf ~/.config/oh-my-posh
    rm -rf ~/.config/fastfetch
    rm -rf ~/.config/matugen
    rm -rf ~/.config/gtk-4.0/settings.ini
    
    rm -rf ~/Pictures/Wallpapers/WhiteSur-gtk-theme
    
    echo "Configs deleted."
else
    echo "Configurations kept intact."
fi

echo -e "\n${GREEN}✅ Uninstallation complete!${NC}"
echo "Note: RPMFusion repositories and core system utilities (like PipeWire, BlueZ, GCC) were left intact as they are standard components of Fedora."
echo "Please log out and log back in (or reboot) to fully apply the shell changes and return to your default desktop environment."