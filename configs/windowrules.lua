--- @diagnostic disable: undefined-global

-- ============================================================================
-- 🪟 WINDOW & LAYER RULES CONFIGURATION
-- ============================================================================
-- Manages window placement, workspace routing, floating dialogs,
-- surface opacity overrides, and layer shell behaviors.
-- ============================================================================

-- ============================================================================
-- 🚫 LAYER SHELL ANIMATIONS
-- ============================================================================
-- Suppresses default shell animations for instant UI rendering on layer surfaces.
hl.layer_rule({
    match = { namespace = "^(quickshell)$" },
    no_anim = true,
})


-- ============================================================================
-- 🧱 EXPLICIT TILING ENFORCEMENTS
-- ============================================================================
-- Forces core terminals, system settings, and file managers to tile properly.
hl.window_rule({ match = { class = "^(org\\.wezfurlong\\.wezterm)$" }, tile = true })
hl.window_rule({ match = { class = "^(gnome-control-center)$" }, tile = true })
hl.window_rule({ match = { class = "^(org\\.gnome\\.Nautilus)$" }, float = false })


-- ============================================================================
-- 🎨 AESTHETIC & THEMING OVERRIDES
-- ============================================================================
-- Uniform border rounding for GNOME core applications
hl.window_rule({ match = { class = "^(org\\.gnome\\.)" }, rounding = 12 })

-- Zen Browser: Enforce 100% solid opacity and disable compositor blur
hl.window_rule({
    match = { class = "^(zen|app\\.zen_browser\\.zen)$" },
    opacity = "1.0 override 1.0 override",
    no_blur = true,
})


-- ============================================================================
-- 📌 WORKSPACE ROUTING
-- ============================================================================
-- Automatically routes VM manager and active guest windows to designated workspaces.
hl.window_rule({ match = { class = "^(VirtualBox Manager)$" }, workspace = "5" })
hl.window_rule({ match = { class = "^(VirtualBox Machine)$" }, workspace = "2" })


-- ============================================================================
-- 📺 MEDIA & OVERLAY WINDOWS
-- ============================================================================
-- Picture-in-Picture float and pin behavior
hl.window_rule({
    match = { title = "^(Picture-in-Picture)$" },
    float = true,
    pin = true,
})

-- Steam notification toasts: Pin without stealing input focus
hl.window_rule({
    match = { class = "^(steam)$", title = "^(notificationtoasts)" },
    no_initial_focus = true,
    pin = true,
})


-- ============================================================================
-- 🔒 SYSTEM MODALS & DIALOG POPUPS
-- ============================================================================
-- Auto-centers file pickers, authentication prompts, and system dialogs.
hl.window_rule({
    match = { title = "^(File Upload|Open File|Save File|Select File|Choose File).*" },
    float = true, size = "900 600", center = true,
})

hl.window_rule({
    match = { title = "^(Authentication Required|Password Required|Unlock Keyring).*" },
    float = true, size = "500 300", center = true,
})

hl.window_rule({
    match = { title = "^(Confirm|Confirmation|Warning|Error).*" },
    float = true, size = "600 350", center = true,
})

hl.window_rule({
    match = { class = "^(xdg-desktop-portal.*)$" },
    float = true, center = true,
})


-- ============================================================================
-- 🪟 STANDARD FLOATING UTILITY WINDOWS (900x600)
-- ============================================================================
-- Bluetooth, theming, audio mixers, and control panels.
local standard_utilities = {
    "blueman-manager", "blueman-adapters", "blueman-services",
    "nwg-look", "qt5ct", "qt6ct", "org\\.gnome\\.tweaks",
    "com\\.mattjakeman\\.ExtensionManager", "waypaper",
    "org\\.pulseaudio\\.pavucontrol", "org\\.gnome\\.PowerStats",
    "gnome-calculator", "galculator"
}

for _, class_pattern in ipairs(standard_utilities) do
    hl.window_rule({
        match  = { class = "^(" .. class_pattern .. ")$" },
        float  = true,
        size   = "900 600",
        center = true,
    })
end

-- Network connection editor (custom size)
hl.window_rule({
    match  = { class = "^(nm-connection-editor)$" },
    float  = true,
    size   = "600 500",
    center = true,
})

-- GNOME Calculator (compact vertical size)
hl.window_rule({
    match  = { class = "^(org\\.gnome\\.Calculator)$" },
    float  = true,
    size   = "450 600",
    center = true,
})


-- ============================================================================
-- 🚀 LARGE FLOATING WINDOWS & APPS (1100x700 & 1300x850)
-- ============================================================================
-- Client applications and heavy toolsets
hl.window_rule({ match = { class = "^(steam)$" }, float = true, size = "1100 700", center = true })
hl.window_rule({ match = { class = "^(zoom)$"  }, float = true, size = "1100 700", center = true })

-- Dropdown / scratchpad floating terminal with semi-transparency
hl.window_rule({
    match   = { title = "^(float_term)$" },
    float   = true,
    size    = "1300 850",
    center  = true,
    opacity = "0.85 0.90",
})

-- Large GNOME productivity and utility apps
local large_utilities = {
    "org\\.gnome\\.TextEditor",
    "org\\.gnome\\.Software",
    "org\\.gnome\\.baobab",
}

for _, class_pattern in ipairs(large_utilities) do
    hl.window_rule({
        match  = { class = "^(" .. class_pattern .. ")$" },
        float  = true,
        size   = "1300 850",
        center = true,
    })
end