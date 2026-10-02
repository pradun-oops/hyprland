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
    
    # Customization & Utilities
    quickshell
    xdg-utils
    glib2
    procps-ng
    jq
    
    # Audio & Media
    pipewire
    wireplumber
    pulseaudio-utils
    playerctl
    pavucontrol
    ffmpeg
    
    # Hyprland Ecosystem
    grim
    hypridle
    hyprlock
    slurp
    wl-clipboard
    
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
    
    # Dev Environments
    ruby
    python3
    python3-pip
    curl
    wget
    git
    cargo
)

echo ":: Installing core desktop and development packages..."
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
# 🧊 6. Hyprglass Plugin Setup
# ==========================================================
echo ":: Setting up Hyprglass liquid glass plugin..."
hyprpm update || echo "hyprpm update failed, continuing..."
hyprpm add https://github.com/hyprnux/hyprglass || echo "hyprpm add failed, continuing..."
hyprpm enable hyprglass || echo "hyprglass enablement failed, you may need to run this manually in an active session."

# ==========================================================
# 🔤 7. Fonts Installation (FiraCode Nerd Font)
# ==========================================================
echo ":: Installing FiraCode Nerd Font..."
FONT_DIR="$HOME/.local/share/fonts/FiraCode"
if [ ! -d "$FONT_DIR" ]; then
    mkdir -p "$FONT_DIR"
    wget -qO /tmp/FiraCode.zip "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip"
    unzip -q /tmp/FiraCode.zip -d "$FONT_DIR"
    rm /tmp/FiraCode.zip
    
    echo ":: Rebuilding font cache..."
    fc-cache -fv
    echo ":: FiraCode Nerd Font successfully installed."
else
    echo ":: FiraCode Nerd Font already exists at $FONT_DIR, skipping."
fi

# ==========================================================
# ⚙️ 8. Systemd Daemons & Hardware Services
# ==========================================================
echo ":: Activating background system services..."
systemctl --user enable --now wireplumber.service
systemctl --user enable --now pipewire.service
sudo systemctl enable --now power-profiles-daemon.service

echo -e "\n✅ Setup completed successfully!"