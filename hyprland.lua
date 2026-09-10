-- ==========================================================
-- 🚀 Hyprland Master Entrypoint (init.lua)
-- Modular configuration loader organized by subsystem lifecycle:
-- Environment -> Hardware/Display -> Compositor Core -> Shell & Bindings.
-- ==========================================================

-- ==========================================================
-- 🌐 System Session & Environment Variables
-- Must load first to set Wayland backends, GPU flags, and themes.
-- ==========================================================
require("configs.envs")
require("configs.cursor")

-- ==========================================================
-- 🖥️ Hardware Displays & Input Devices
-- Output resolutions, refresh rates, monitor layouts, and keyboards/mice.
-- ==========================================================
require("configs.outputs")
require("configs.input")

-- ==========================================================
-- ⚙️ Compositor Behavior, Layouts & Theming
-- Core aesthetics, gaps, window borders, blur, and color schemes.
-- ==========================================================
require("configs.general")
require("configs.colors")
require("configs.animations")
require("configs.misc")

-- ==========================================================
-- 🪟 Windows, Layers & Workspace Routing
-- Explicit tiling rules, float assignments, and screen pinning.
-- ==========================================================
require("configs.workspaces")
require("configs.windowrules")
require("configs.layerrules")

-- ==========================================================
-- ⌨️ Keybindings & Session Autostart
-- Hotkeys for applications/widgets and background daemon startup.
-- ==========================================================
require("configs.binds")
require("configs.autostart")