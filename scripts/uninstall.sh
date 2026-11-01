#!/usr/bin/env bash

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TARGET_USER="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

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
rm -rf "$USER_HOME/.local/share/icons/WhiteSur"*
rm -f "$USER_HOME/.local/share/fonts/SymbolsNerdFont"*
fc-cache -fv >/dev/null 2>&1 || true

echo -e "\n${YELLOW}:: 3. Removing Hyprglass Plugin...${NC}"
if command -v hyprpm >/dev/null 2>&1; then
    hyprpm remove hyprglass 2>/dev/null || true
fi

echo -e "\n${YELLOW}:: 4. Reverting Shell Configuration to Bash...${NC}"
BASH_BIN="$(command -v bash)"
if [ "$SHELL" != "$BASH_BIN" ]; then
    sudo chsh -s "$BASH_BIN" "$TARGET_USER" || true
fi

if [ -f "$USER_HOME/.bashrc" ]; then
    sed -i '/oh-my-posh/d' "$USER_HOME/.bashrc"
fi

if [ -f "$USER_HOME/.config/fish/config.fish" ]; then
    sed -i '/oh-my-posh/d' "$USER_HOME/.config/fish/config.fish"
    sed -i '/\.cargo\/bin/d' "$USER_HOME/.config/fish/config.fish"
fi

echo -e "\n${YELLOW}:: 5. Removing desktop environment packages and tools...${NC}"
PACKAGES_TO_REMOVE=(
    hyprland
    hyprland-devel
    hyprland-guiutils
    hyprsunset
    hypridle
    hyprlock
    quickshell
    qt5ct
    qt6ct
    qt6-qt5compat
    nwg-look
    adw-gtk3-theme
    fira-code-nerd-fonts
    xdg-desktop-portal-hyprland
    playerctl
    pavucontrol
    grim
    slurp
    wf-recorder
    wl-clipboard
    cliphist
    brightnessctl
    inotify-tools
    kitty
    fastfetch
    figlet
    lolcat
    fish
    eza
    preload
)

sudo dnf remove -y "${PACKAGES_TO_REMOVE[@]}" || true

echo -e "\n${YELLOW}:: 6. Disabling custom repositories (COPR)...${NC}"
sudo dnf copr disable -y errornointernet/quickshell || true
sudo dnf copr disable -y lionheartp/Hyprland || true
sudo dnf copr disable -y tofik/nwg-shell || true
sudo dnf copr disable -y aquacash5/nerd-fonts || true
sudo dnf copr disable -y atim/preload || true

echo -e "\n${YELLOW}:: 7. Reverting Polkit rules and desktop entry overrides...${NC}"
sudo rm -f /etc/polkit-1/rules.d/10-udisks2.rules

HIDDEN_DESKTOP_APPS=(
    "qt5ct.desktop"
    "qt6ct.desktop"
    "nwg-look.desktop"
    "legionaura.desktop"
    "uuctl.desktop"
    "org.pulseaudio.pavucontrol.desktop"
    "bluetooth-sendto.desktop"
    "blueman-adapters.desktop"
    "org.gnome.Logs.desktop"
    "org.gnome.PowerStats.desktop"
    "gtk3-demo.desktop"
    "gtk3-icon-browser.desktop"
    "gtk3-widget-factory.desktop"
    "geoclue-demo-agent.desktop"
    "breezestyleconfig.desktop"
    "kcm_breezedecoration.desktop"
    "org.kde.knewstuff-dialog.desktop"
    "org.kde.knewstuff-dialog6.desktop"
    "ibus-setup-chewing.desktop"
    "ibus-setup-hangul.desktop"
    "ibus-setup-libpinyin.desktop"
    "ibus-setup-anthy.desktop"
    "ibus-setup-m17n.desktop"
    "ibus-setup-tb.desktop"
    "ibus-setup-typing-booster.desktop"
)

for app in "${HIDDEN_DESKTOP_APPS[@]}"; do
    target="/usr/share/applications/$app"
    if [ -f "$target" ]; then
        sudo sed -i '/^NoDisplay=true/d' "$target"
    fi
done

sudo update-desktop-database /usr/share/applications 2>/dev/null || true

echo -e "\n${YELLOW}:: 8. Cleaning up unneeded dependencies (PLEASE REVIEW CAREFULLY)...${NC}"
sudo dnf autoremove

echo -e "\n${YELLOW}:: 9. Removing Configuration Files (~/.config)...${NC}"
rm -rf "$USER_HOME/.config/hypr"
rm -rf "$USER_HOME/.config/kitty"
rm -rf "$USER_HOME/.config/fastfetch"
rm -rf "$USER_HOME/.config/matugen"
rm -rf "$USER_HOME/.config/oh-my-posh"
rm -rf "$USER_HOME/.config/quickshell"
rm -rf "$USER_HOME/.config/fish"
rm -rf "$USER_HOME/Pictures/Wallpapers/WhiteSur-gtk-theme"
rm -f /tmp/rgb_power_state

dconf reset -f /org/gnome/

echo -e "\n${GREEN}✅ Uninstallation complete!${NC}"
echo ":: Note: Critical system tools and GNOME power management tools were kept to prevent breaking Fedora."
echo ":: Please reboot your system to fully apply shell changes and cleanly return to GNOME."