--- @diagnostic disable: undefined-global

hl.layer_rule({
    match = { namespace = "^(quickshell)$" },
    no_anim = true,
})

hl.window_rule({ match = { class = "^(org\\.wezfurlong\\.wezterm)$" }, tile = true })
hl.window_rule({ match = { class = "^(gnome-control-center)$" }, tile = true })
hl.window_rule({ match = { class = "^(org\\.gnome\\.Nautilus)$" }, float = false })

hl.window_rule({ match = { class = "^(org\\.gnome\\.)" }, rounding = 12 })

hl.window_rule({
    match = { class = "^(zen|app\\.zen_browser\\.zen|[Ff]irefox|org\\.mozilla\\.firefox)$" },
    opacity = "1.0 override 1.0 override",
    no_blur = true,
})

hl.window_rule({ match = { class = "^(VirtualBox Manager)$" }, workspace = "5" })
hl.window_rule({ match = { class = "^(VirtualBox Machine)$" }, workspace = "2" })

hl.window_rule({
    match = { title = "^(Picture-in-Picture)$" },
    float = true,
    pin = true,
})

hl.window_rule({
    match = { class = "^(steam)$", title = "^(notificationtoasts)" },
    no_initial_focus = true,
    pin = true,
})

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

hl.window_rule({
    match  = { class = "^(nm-connection-editor)$" },
    float  = true,
    size   = "600 500",
    center = true,
})

hl.window_rule({
    match  = { class = "^(org\\.gnome\\.Calculator)$" },
    float  = true,
    size   = "450 600",
    center = true,
})

hl.window_rule({ match = { class = "^(steam)$" }, float = true, size = "1100 700", center = true })
hl.window_rule({ match = { class = "^(zoom)$"  }, float = true, size = "1100 700", center = true })

hl.window_rule({
    match   = { title = "^(float_term)$" },
    float   = true,
    size    = "1300 850",
    center  = true,
})

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