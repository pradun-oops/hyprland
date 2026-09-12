#!/usr/bin/env bash

# ==========================================================
# 🚀 Fedora Post-Install & Hyprland Environment Setup
# Automates packages, audio daemons, Quickshell COPR,
# dynamic theming tools (Matugen), wallpaper engines, and RGB drivers.
# ==========================================================

set -euo pipefail

# ==========================================================
# 🔄 System Updates
# Refreshes metadata cache and brings core system packages up to date.
# ==========================================================
echo ":: Refreshing repositories and upgrading system packages..."
sudo dnf upgrade --refresh -y

# ==========================================================
# 📦 Core Hyprland Desktop & Utility Dependencies
# Installs compositor, audio framework, screenshot tools, 
# build essentials, and runtime helpers.
# ==========================================================
echo ":: Installing core desktop and development packages..."
sudo dnf install -y --allowerasing \
    hyprland \
    xdg-utils \
    glib2 \
    procps-ng \
    jq \
    pipewire \
    wireplumber \
    pulseaudio-utils \
    playerctl \
    pavucontrol \
    grim \
    hypridle \
    hyprlock \
    brightnessctl \
    slurp \
    wl-clipboard \
    libnotify \
    inotify-tools \
    ImageMagick \
    ffmpeg \
    python3-pillow \
    power-profiles-daemon \
    gnome-power-manager \
    kitty \
    figlet \
    ruby \
    python3 \
    python3-pip \
    curl \
    wget \
    git \
    cargo \
    gcc \
    gcc-c++ \
    make \
    lolcat

# ==========================================================
# 🐚 Quickshell Installation (COPR Repository)
# Enables third-party repository and installs the custom shell engine.
# ==========================================================
echo ":: Setting up Quickshell repository..."
sudo dnf copr enable -y errornointernet/quickshell
sudo dnf install -y quickshell

# ==========================================================
# 🎨 Matugen Material You Palette Generator
# Builds and installs Matugen CLI for real-time dynamic color extraction.
# ==========================================================
if ! command -v matugen >/dev/null 2>&1; then
    echo ":: Installing Matugen via Cargo..."
    cargo install matugen
fi

# ==========================================================
# 🖼️ AWWW / SWWW Animated Wallpaper Daemon
# Clones, compiles from source via Cargo, and installs binaries globally.
# ==========================================================
if ! command -v awww >/dev/null 2>&1; then
    echo ":: Compiling and installing AWWW wallpaper daemon..."
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
# ⌨️ LegionAura RGB Controller
# Installs Python tool for 4-zone Lenovo keyboard backlight control.
# ==========================================================
if ! command -v legionaura >/dev/null 2>&1; then
    echo ":: Installing LegionAura Python package..."
    pip3 install --user legionaura --break-system-packages
fi

# ==========================================================
# ⚙️ Systemd Daemons & Hardware Service Activation
# Enables PipeWire audio engine and power management profiles.
# ==========================================================
echo ":: Activating background system services..."
systemctl --user enable --now wireplumber.service
systemctl --user enable --now pipewire.service
sudo systemctl enable --now power-profiles-daemon.service

echo ":: Setup completed successfully!"