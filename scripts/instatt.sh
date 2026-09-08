#!/usr/bin/env bash

set -euo pipefail

sudo dnf upgrade --refresh -y

sudo dnf install -y --allowerasing \
    hyprland \
    hyprpaper \
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

sudo dnf copr enable -y errornointernet/quickshell
sudo dnf install -y quickshell

if ! command -v matugen >/dev/null 2>&1; then
    cargo install matugen
fi

if ! command -v awww >/dev/null 2>&1; then
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

if ! command -v legionaura >/dev/null 2>&1; then
    pip3 install --user legionaura --break-system-packages
fi

systemctl --user enable --now wireplumber.service
systemctl --user enable --now pipewire.service
sudo systemctl enable --now power-profiles-daemon.service