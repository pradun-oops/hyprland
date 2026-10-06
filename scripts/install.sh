#!/usr/bin/env bash

# ==========================================================
# 🚀 Fedora Post-Install & Hyprland Environment Setup
# Automates repositories, core packages, audio daemons, 
# Quickshell, Matugen, AWWW, LegionAura, and Hyprglass.
# ==========================================================

set -uo pipefail

echo ":: Starting fresh Fedora Hyprland setup..."

# ==========================================================
# 🌍 1. Configure Third-Party Repositories
# ==========================================================
echo ":: Enabling RPM Fusion repositories (for ffmpeg & media codecs)..."
sudo dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
                    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

echo ":: Setting up custom COPR repositories..."
sudo dnf copr enable -y errornointernet/quickshell
sudo dnf copr enable -y lionheartp/Hyprland
sudo dnf copr enable -y solopasha/hyprland # Added for hyprland-guiutils
sudo dnf copr enable -y tofik/nwg-shell    # Added for nwg-look

echo ":: Refreshing metadata and upgrading system..."
sudo dnf upgrade --refresh -y

# ==========================================================
# 📦 2. Define & Install Dependencies
# ==========================================================
PACKAGES=(
    # Core Hyprland
    hyprland
    hyprland-devel
    hyprland-guiutils
    
    # Build Tools (For AWWW & Hyprpm)
    cpio
    meson
    ninja-build
    libxkbcommon-devel
    wayland-devel
    scdoc
    gcc
    gcc-c++
    cmake
    make
    pkgconf-pkg-config
    lz4-devel
    
    # Customization, Theming & Utilities
    quickshell
    qt5ct
    qt6ct
    qt6-qt5compat
    nwg-look
    adw-gtk3-theme
    fira-code-fonts
    xdg-utils
    glib2
    procps-ng
    jq
    fish
    
    # Audio & Media
    pipewire
    wireplumber
    pulseaudio-utils
    xdg-desktop-portal-hyprland 
    xdg-desktop-portal-gtk
    playerctl
    pavucontrol
    ffmpeg
    
    # Hyprland Ecosystem
    grim
    hypridle
    hyprlock
    slurp
    wl-clipboard
    cliphist           # <-- Added for clipboard history
    
    # Misc & System
    brightnessctl
    libnotify
    inotify-tools
    ImageMagick
    python3-pillow
    power-profiles-daemon
    gnome-power-manager
    kitty
    fastfetch
    figlet
    lolcat
    unzip
    fontconfig

    # Bluetooth
    bluez
    blueman
    
    # Dev Environments
    ruby
    python3
    python3-pip
    curl
    wget
    git
    cargo
)

echo ":: Installing core desktop, development, and theming packages..."
# Temporarily disable exit-on-error for the bulk install to handle failures gracefully
set +e
sudo dnf install -y --allowerasing "${PACKAGES[@]}"
DNF_EXIT_CODE=$?
set -e

# ==========================================================
# 🚨 3. Installation Verification & Error Handling
# ==========================================================
if [ $DNF_EXIT_CODE -ne 0 ]; then
    echo -e "\n⚠️ WARNING: Bulk package installation encountered an error."
    echo ":: Scanning for missing packages..."
    
    MISSING_PACKAGES=()
    for pkg in "${PACKAGES[@]}"; do
        if ! dnf list installed "$pkg" &>/dev/null; then
            MISSING_PACKAGES+=("$pkg")
        fi
    done

    if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
        echo -e "\n❌ The following packages failed to install:"
        for missing in "${MISSING_PACKAGES[@]}"; do
            echo "   - $missing"
        done
        echo -e "\nPlease resolve any conflicts and install them manually using:"
        echo "sudo dnf install ${MISSING_PACKAGES[*]}"
        echo -e "Exiting setup to prevent downstream compilation errors.\n"
        exit 1
    fi
fi
echo ":: All DNF packages installed successfully."

# Ensure Cargo binaries are in the PATH for the current session
export PATH="$HOME/.cargo/bin:$PATH"

# ==========================================================
# 🎨 4. Matugen Material You Palette Generator
# ==========================================================
if ! command -v matugen >/dev/null 2>&1; then
    echo ":: Installing Matugen via Cargo..."
    cargo install matugen
fi

# ==========================================================
# 🖼️ 5. AWWW / SWWW Animated Wallpaper Daemon
# ==========================================================
if ! command -v awww >/dev/null 2>&1 && ! command -v swww >/dev/null 2>&1; then
    echo ":: Compiling and installing AWWW wallpaper daemon..."
    rm -rf /tmp/awww # Clean up any failed previous runs
    git clone https://codeberg.org/LGFae/awww.git /tmp/awww
    cd /tmp/awww
    cargo build --release
    if [ -f target/release/awww ]; then
        sudo cp target/release/awww target/release/awww-daemon /usr/local/bin/
    else
        sudo cp target/release/swww /usr/local/bin/awww
        sudo cp target/release/swww-daemon /usr/local/bin/awww-daemon
    fi
    cd -
    rm -rf /tmp/awww
fi

# ==========================================================
# 🍏 6. WhiteSur GTK Icon Theme
# ==========================================================
echo ":: Installing WhiteSur Icon Theme..."
rm -rf /tmp/WhiteSur-icon-theme
git clone https://github.com/vinceliuice/WhiteSur-icon-theme.git /tmp/WhiteSur-icon-theme
cd /tmp/WhiteSur-icon-theme
./install.sh -a
cd -
rm -rf /tmp/WhiteSur-icon-theme

# ==========================================================
# 🔤 7. NerdFontsSymbolsOnly Installation
# ==========================================================
echo ":: Installing NerdFontsSymbolsOnly..."
mkdir -p ~/.local/share/fonts
curl -fLO https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.zip
unzip -o NerdFontsSymbolsOnly.zip -d ~/.local/share/fonts/
rm NerdFontsSymbolsOnly.zip
fc-cache -fv

# ==========================================================
# 🐚 8. Shell Setup: Oh My Posh & Fish Defaults
# ==========================================================
echo ":: Installing Oh My Posh..."
curl -s https://ohmyposh.dev/install.sh | sudo bash -s

echo ":: Changing default shell to Fish..."
# Uses SUDO_USER if run with sudo, otherwise falls back to standard USER
sudo chsh -s $(which fish) "${SUDO_USER:-$USER}"

# ==========================================================
# 🧊 9. Hyprglass Plugin Setup
# ==========================================================
echo ":: Setting up Hyprglass liquid glass plugin..."
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    hyprpm update || true
    hyprpm add https://github.com/hyprnux/hyprglass || true
    hyprpm enable hyprglass || true
    echo ":: Hyprglass installation attempted."
else
    echo ":: INFO: Hyprland is not currently running (no instance signature found)."
    echo ":: INFO: Skipping Hyprglass compilation. Please run 'hyprpm add https://github.com/hyprnux/hyprglass' and 'hyprpm enable hyprglass' later inside an active Hyprland session."
fi

# ==========================================================
# ⚙️ 10. Systemd Daemons & Hardware Services
# ==========================================================
echo ":: Activating background system services..."
systemctl --user enable --now wireplumber.service
systemctl --user enable --now pipewire.service
sudo systemctl enable --now power-profiles-daemon.service

echo -e "\n✅ Installation phase completed successfully!"

# ==========================================================
# 🚀 11. Execute Setup Script
# ==========================================================
if [ -f "./setup.sh" ]; then
    echo ":: Executing setup.sh..."
    bash ./setup.sh
else
    echo ":: setup.sh not found in the current directory. Skipping."
fi