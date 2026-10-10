#!/usr/bin/env bash

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}⚠️  WARNING: This script will completely uninstall Hyprland, Quickshell, custom themes, fonts, configuration files, and revert shells.${NC}"
read -p "Are you sure you want to completely wipe this setup? (y/N): " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo ":: Uninstallation aborted."
    exit 0
fi

echo -e "\n${YELLOW}:: 1. Removing compiled binaries & Rust packages (AWWW, Matugen, Oh My Posh)...${NC}"
sudo rm -f /usr/local/bin/awww /usr/local/bin/awww-daemon /usr/local/bin/swww /usr/local/bin/swww-daemon
sudo rm -f /usr/local/bin/oh-my-posh
if command -v cargo >/dev/null 2>&1; then
    cargo uninstall matugen 2>/dev/null || true
fi

echo -e "\n${YELLOW}:: 2. Removing Themes, Icons & Custom Fonts...${NC}"
sudo rm -rf /usr/share/icons/WhiteSur*
rm -rf ~/.local/share/icons/WhiteSur*
rm -f ~/.local/share/fonts/SymbolsNerdFont*
fc-cache -fv

echo -e "\n${YELLOW}:: 3. Removing Hyprglass Plugin...${NC}"
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprpm >/dev/null 2>&1; then
    hyprpm remove hyprglass || true
fi

echo -e "\n${YELLOW}:: 4. Reverting Shell Configuration to Bash...${NC}"
if [ "$SHELL" != "$(command -v bash)" ]; then
    sudo chsh -s $(command -v bash) "${SUDO_USER:-$USER}" || true
fi

if [ -f "$HOME/.bashrc" ]; then
    sed -i '/oh-my-posh/d' "$HOME/.bashrc"
fi

if [ -f "$HOME/.config/fish/config.fish" ]; then
    sed -i '/oh-my-posh/d' "$HOME/.config/fish/config.fish"
    sed -i '/\.cargo\/bin/d' "$HOME/.config/fish/config.fish"
fi

echo -e "\n${YELLOW}:: 5. Removing desktop environment packages and tools...${NC}"
PACKAGES_TO_REMOVE=(
    hyprland
    hyprland-devel
    hyprland-guiutils
    meson
    ninja-build
    libxkbcommon-devel
    wayland-devel
    scdoc
    lz4-devel
    quickshell
    qt5ct
    qt6ct
    qt6-qt5compat
    nwg-look
    adw-gtk3-theme
    fira-code-fonts
    xdg-desktop-portal-hyprland
    playerctl
    pavucontrol
    grim
    hypridle
    hyprlock
    slurp
    wl-clipboard
    cliphist
    brightnessctl
    inotify-tools
    kitty
    fastfetch
    figlet
    lolcat
    fish
)

sudo dnf remove -y "${PACKAGES_TO_REMOVE[@]}" || true

echo -e "\n${YELLOW}:: 6. Disabling custom repositories (COPR)...${NC}"
sudo dnf copr disable -y errornointernet/quickshell || true
sudo dnf copr disable -y lionheartp/Hyprland || true
sudo dnf copr disable -y solopasha/hyprland || true
sudo dnf copr disable -y tofik/nwg-shell || true


echo -e "\n${YELLOW}:: 7. Cleaning up unneeded dependencies (PLEASE REVIEW CAREFULLY)...${NC}"
sudo dnf autoremove 

echo -e "\n${YELLOW}:: 8. Removing Configuration Files (~/.config)...${NC}"
rm -rf "$HOME/.config/hypr"
rm -rf "$HOME/.config/kitty"
rm -rf "$HOME/.config/fastfetch"
rm -rf "$HOME/.config/matugen"
rm -rf "$HOME/.config/oh-my-posh"
rm -rf "$HOME/.config/quickshell"
rm -rf "$HOME/Pictures/Wallpapers/WhiteSur-gtk-theme"

dconf reset -f /org/gnome/

echo -e "\n${GREEN}✅ Uninstallation complete!${NC}"
echo ":: Note: Critical system tools and GNOME power management tools were kept to prevent breaking Fedora."
echo ":: Please reboot your system to fully apply shell changes and cleanly return to GNOME."