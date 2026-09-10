-- ==========================================================
-- 🪟 Layer Surface Rules & Backdrop Effects
-- Manages rendering behaviors, animations, and background 
-- blur sampling for Quickshell UI components.
-- ==========================================================

-- ==========================================================
-- 🚫 Animation Overrides
-- Disables default compositor transitions on base shell surfaces
-- to prevent flickering and let Quickshell handle internal motions.
-- ==========================================================
hl.layer_rule({
    name    = "quickshell-no-anim",
    match   = { namespace = "^(quickshell)$" },
    no_anim = true,
})

-- ==========================================================
-- 🛠️ Layer Blur Helper
-- Batch applies backdrop blur and alpha thresholds across
-- groups of matching layer-shell namespaces.
-- ==========================================================
local function apply_blur(namespaces, alpha)
    for _, ns in ipairs(namespaces) do
        hl.layer_rule({
            name         = ns .. "-blur",
            match        = { namespace = "^(" .. ns .. ")$" },
            blur         = true,
            xray         = false,
            ignore_alpha = alpha, -- Transparent cut-off threshold for sampling blur
        })
    end
end

-- ==========================================================
-- 🧊 Standard Frosted Surfaces (Alpha Threshold: 0.01)
-- Core widgets, dialogs, status overlays, and system HUDs.
-- ==========================================================
apply_blur({
    -- On-Screen Displays (OSD)
    "qs-brightness-osd",
    "qs-volume-osd",

    -- Shell Bars, Docks & Desktop Elements
    "qs-bar",
    "qs-dock",
    "qs-desktop-dashboard",
    "qs-desktop-clock",

    -- Notifications & Center Panels
    "qs-notifications",
    "notification-center",
    "qs-notification-center",

    -- Launchers & Cheatsheets
    "qs-spotlight",
    "spotlight",
    "qs-keybinds",
    "keybinds",
    "qs-drawer",
    "qs-overview",

    -- Quick Setting Dialogs & Management Centers
    "qs-network-center",
    "qs-control-center",
    "qs-bluetooth-center",

    -- Standalone Utility Widgets
    "qs-calendar",
    "qs-sysmon",
    "qs-weather",
    "qs-config",
    "qs-wallselect",
    "qs-calculator",
    "qs-filemanager",
    "qs-clipboard",
}, 0.01)

-- ==========================================================
-- ⚡ Session & Power Surfaces (Alpha Threshold: 0.02)
-- Elevated blur threshold for deep translucent power menus.
-- ==========================================================
apply_blur({ "qs-power-menu" }, 0.02)