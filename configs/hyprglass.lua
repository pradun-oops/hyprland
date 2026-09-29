--- @diagnostic disable: undefined-global

-- ============================================================================
-- 🧊 HYPRGLASS PLUGIN CONFIGURATION
-- ============================================================================
if hl.plugin.hyprglass then
    local hg = hl.plugin.hyprglass

    -- Preset modeled after the liquid UI showcase
    hg.preset("liquid", {
        glass_opacity        = 1, 
        blur_strength        = 1.5, 
        blur_iterations      = 1,   
        
        refraction_strength  = 2, 
        chromatic_aberration = 1, 
        fresnel_strength     = 2, 
        specular_strength    = 1, 
        edge_thickness       = 0.01,
        
        tint_color           = 0x11112222, 
        lens_distortion      = 0.01,

        dark = {
            brightness        = 2,
            contrast          = 1,
            saturation        = 1,
            vibrancy          = 1,
            vibrancy_darkness = 0.1,
            adaptive_dim      = 0.2,
            adaptive_boost    = 0.00001,
        },

        light = {
            brightness        = 1.0,
            contrast          = 1.0,
            saturation        = 1.0,
            vibrancy          = 0.1,
            vibrancy_darkness = 0.0,
            adaptive_dim      = 0.3,
            adaptive_boost    = 0.2,
        },
    })

    hg.config({
        default_theme  = "dark",
        default_preset = "liquid",
        layers         = { enabled = true },
    })

    -- ========================================================================
    -- 🪟 UI LAYER ASSIGNMENTS (BATCH PROCESSING)
    -- ========================================================================
    
    local liquid_layers = {
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
        "qs-rgbcontrol",       
        
    }

    -- Apply the liquid preset to all namespaces in the array above
    for _, layer in ipairs(liquid_layers) do
        hg.layer(layer, { preset = "liquid", mask_threshold = 0.01 })
    end

    -- Fallbacks & Exclusions
    hg.layer("quickshell", { preset = "liquid", mask_threshold = 0.3 })
    hg.layer("debug-panel", { exclude = true })
end