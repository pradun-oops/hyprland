# 🧊 Liquid Glass Hyprland | Fedora

> A modern Hyprland desktop focused on performance, aesthetics, and an efficient Cyber Security workflow.

![Fedora](https://img.shields.io/badge/OS-Fedora-blue?style=for-the-badge&logo=fedora)
![Hyprland](https://img.shields.io/badge/WM-Hyprland-58E1FF?style=for-the-badge&logo=hyprland)
![Wayland](https://img.shields.io/badge/Display-Wayland-8A2BE2?style=for-the-badge)
![Kitty](https://img.shields.io/badge/Terminal-Kitty-000000?style=for-the-badge&logo=kitty)
![License](https://img.shields.io/badge/License-MIT-success?style=for-the-badge)

---

## 📸 System Gallery

| | | |
|:-:|:-:|:-:|
| ![](./assets/image1.png) | ![](./assets/image2.png) | ![](./assets/image3.png) |
| ![](./assets/image4.png) | ![](./assets/image5.png) | ![](./assets/image6.png) |
| ![](./assets/image7.png) | ![](./assets/image8.png) | ![](./assets/image9.png) |
| ![](./assets/image10.png) | ![](./assets/image11.png) | ![](./assets/image12.png) |

# 💻 Hardware

| Component | Specification |
|------------|--------------|
| **Laptop** | Lenovo LOQ 15IRX9 (2024) |
| **CPU** | Intel Core i5-13450HX |
| **GPU** | NVIDIA RTX 3050 6GB |
| **RAM** | 24GB DDR5 |
| **Storage** | 512GB NVMe (Fedora) + 256GB NVMe (VM Storage) |
| **Primary Monitor** | Acer EK251Q P2 • 1920×1080 • 144Hz |
| **Secondary Monitor** | Built-in 15.6" FHD |

---

# ✨ Features

- 🧊 Liquid Glass UI with Gaussian Blur
- 🎨 Dynamic wallpaper management using **awww** and **Matugen**
- 🌈 Automatic keyboard RGB synchronization (Lenovo LegionAura)
- 🖥️ Dual-monitor optimized layout
- 🚀 Hardware accelerated Wayland rendering
- 🧩 **100% Custom-built Quickshell Widgets** (Completely self-written UI Architecture)
- ⚡ Smooth Hyprland animations
- 📂 Smart floating and tiling window rules
- 🔔 Modern notification center
- 🔍 Spotlight launcher
- 🎛️ Control Center
- 🔋 Battery & system telemetry widgets
- 📋 Clipboard history
- 🖼️ Workspace overview
- 🎯 Optimized for productivity

---

# 📦 Main Components

- Fedora
- Hyprland
- Quickshell
- Kitty
- awww
- Matugen
- Zen Browser
- VS Codium
- Nautilus
- Fastfetch

---

# 🛠 Installation

Setting up this configuration on a fresh Fedora install is completely automated.

1. **Clone the repository:**
   ```bash
   git clone https://github.com/pradun-oops/hyprland.git
   cd hyprland
   ```

2. **Run the installation script:**
   This handles all DNF package dependencies, sets up the required Copr repositories, compiles `awww` via Cargo, installs Ruby tools, and configures systemd services.
   ```bash
   ./scripts/install.sh
   ```

3. **Run the setup script:**
   This will securely mirror the entire repository into your `~/.config` directory and instantly reload Hyprland.
   ```bash
   ./scripts/setup.sh
   ```

---

# 📁 Repository Structure

```text
.
├── assets/
├── configs/
├── fastfetch/
├── kitty/
├── matugen/
├── quickshell/
├── scripts/
├── Wallpapers/
├── hyprland.lua
└── README.md
```

---

# ❤️ Credits

- Hyprland
- Fedora Project
- Quickshell
- awww
- Matugen