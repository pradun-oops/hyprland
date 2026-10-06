if hl.plugin.hyprglass then
    local hg = hl.plugin.hyprglass

    hg.preset("liquid", {
        glass_opacity        = 1.0, 
        blur_strength        = 1.5, 
        blur_iterations      = 0.0,   
        refraction_strength  = 1.0, 
        chromatic_aberration = 0.0, 
        fresnel_strength     = 0.0, 
        specular_strength    = 0.0, 
        edge_thickness       = 0.01,
        tint_color           = 0x11112222, 
        lens_distortion      = 0.0,

        dark = {
            brightness        = 1.5,
            contrast          = 1,
            saturation        = 1,
            vibrancy          = 1,
            vibrancy_darkness = 0.0,
            adaptive_dim      = 0.0,
            adaptive_boost    = 0.0,
        },

        light = {
            brightness        = 1.5,
            contrast          = 1,
            saturation        = 1,
            vibrancy          = 1,
            vibrancy_darkness = 0.0,
            adaptive_dim      = 0.0,
            adaptive_boost    = 0.0,
        },
    })

    hg.config({
        default_theme  = "dark",
        default_preset = "liquid",
        layers         = { enabled = true },
    })

    local liquid_layers = {
        "qs-brightness-osd",
        "qs-volume-osd",
        "qs-bar",
        "qs-dock",
        "qs-desktop-dashboard",
        "qs-desktop-clock",
        "qs-notifications",
        "notification-center",
        "qs-notification-center",
        "qs-spotlight",
        "spotlight",
        "qs-keybinds",
        "keybinds",
        "qs-drawer",
        "qs-overview",
        "qs-network-center",
        "qs-control-center",
        "qs-bluetooth-center",
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
        "qs-digital-wellbeing",       
    }

    for _, layer in ipairs(liquid_layers) do
        hg.layer(layer, { preset = "liquid", mask_threshold = 0.01 })
    end

    hg.layer("quickshell", { preset = "liquid", mask_threshold = 0.3 })
    hg.layer("debug-panel", { exclude = true })
end