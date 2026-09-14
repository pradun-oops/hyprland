--- @diagnostic disable: undefined-global

-- ============================================================================
-- 🚀 HYPRLAND MASTER ENTRYPOINT (init.lua)
-- ============================================================================
-- Modular configuration loader organized by subsystem execution order:
--   1. Environment & Cursors  (Wayland backends, GPU flags, theme variables)
--   2. Hardware & Inputs       (Displays, refresh rates, keyboards, touchpads)
--   3. Core & Aesthetics       (Compositor settings, colors, animations, misc)
--   4. Rules & Routing         (Workspaces, window rules, layer shell blur)
--   5. Interactivity & Startup (Keybindings, hotkeys, background daemons)
-- ============================================================================


-- ============================================================================
-- 🌐 1. SYSTEM ENVIRONMENT & CURSORS
-- ============================================================================
-- Must load first to configure Wayland backends, NVIDIA variables, and cursors.
require("configs.envs")
require("configs.cursor")


-- ============================================================================
-- 🖥️ 2. HARDWARE DISPLAYS & INPUT DEVICES
-- ============================================================================
-- Defines output resolutions, refresh rates, monitor layouts, and input ergonomics.
require("configs.outputs")
require("configs.input")


-- ============================================================================
-- ⚙️ 3. COMPOSITOR BEHAVIOR, LAYOUTS & THEMING
-- ============================================================================
-- Core aesthetics, gaps, window borders, dynamic colors, animations, and misc flags.
require("configs.general")
require("configs.colors")
require("configs.animations")
require("configs.misc")


-- ============================================================================
-- 🪟 4. WINDOWS, LAYERS & WORKSPACE ROUTING
-- ============================================================================
-- Multi-display workspace bindings, explicit tiling rules, and layer shell blur effects.
require("configs.workspaces")
require("configs.windowrules")
require("configs.layerrules")


-- ============================================================================
-- ⌨️ 5. KEYBINDINGS & SESSION AUTOSTART
-- ============================================================================
-- Hotkeys for applications, scripts, Quickshell dialogs, and background daemon init.
require("configs.binds")
require("configs.autostart")