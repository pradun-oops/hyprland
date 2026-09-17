--- @diagnostic disable: undefined-global

-- ============================================================================
-- 🪟 LAYER SURFACE RULES & BACKDROP EFFECTS
-- ============================================================================
-- Manages rendering behaviors, animations, and background blur sampling 
-- across all custom Quickshell UI components and layer shell surfaces.
-- ============================================================================

-- ============================================================================
-- 🚫 LAYER ANIMATION OVERRIDES
-- ============================================================================
-- Disables default compositor transitions on base shell surfaces to prevent 
-- flickering and let Quickshell handle smooth internal motion transitions.
hl.layer_rule({
    name    = "quickshell-no-anim",
    match   = { namespace = "^(quickshell)$" },
    no_anim = true,
})


-- ============================================================================
-- 🛠️ LAYER BLUR HELPER FUNCTION
-- ============================================================================
-- Dynamically batch-applies backdrop blur, xray, and alpha threshold settings 
-- across groups of matching layer-shell namespaces to eliminate code duplication.
-- ============================================================================
local function apply_blur(namespaces, alpha_threshold)
    for _, ns in ipairs(namespaces) do
        hl.layer_rule({
            name         = ns .. "-blur",
            match        = { namespace = "^(" .. ns .. ")$" },
            blur         = true,
            xray         = false,
            ignore_alpha = alpha_threshold, -- Transparent cut-off threshold for sampling blur
        })
    end
end


-- ============================================================================
-- 🧊 STANDARD FROSTED SURFACES (Alpha Threshold: 0.01)
-- ============================================================================
-- Core widgets, OSDs, status bars, notification centers, and control panels.
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

    -- Launchers, Spotlights & Cheatsheets
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
    "qs-analog-clock",
}, 0.01)


-- ============================================================================
-- ⚡ SESSION & POWER SURFACES (Alpha Threshold: 0.02)
-- ============================================================================
-- Elevated blur threshold tailored specifically for deep translucent power menus.
apply_blur({
    "qs-power-menu",
}, 0.02)