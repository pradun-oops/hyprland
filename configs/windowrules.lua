hl.window_rule({ match = { class = "^(org\\.wezfurlong\\.wezterm)$" }, tile = true })
hl.window_rule({ match = { class = "^(gnome-control-center)$" }, tile = true })
hl.window_rule({ match = { class = "^(pavucontrol)$" }, tile = true })
hl.window_rule({ match = { class = "^(org\\.gnome\\.)" }, rounding = 12 })
hl.window_rule({ match = { class = "^(VirtualBox Manager)$" }, workspace = "5" })
hl.window_rule({ match = { class = "^(VirtualBox Machine)$" }, workspace = "2" })
hl.layer_rule({ match = { namespace = "^(quickshell)$" }, no_anim = true })
hl.layer_rule({ match = { namespace = "^dms:.*" }, no_anim = true })
hl.window_rule({ match = { class = "^(org\\.gnome\\.Nautilus)$" }, float = false })


hl.window_rule({ 
    match = { class = "^(zen)$" }, 
    opacity = "1.0 1.0"
})

hl.window_rule({ 
    match = { class = "^(app\\.zen_browser\\.zen)$" }, 
    opacity = "1.0 1.0"
})

hl.window_rule({ 
    match = { class = "^(gnome-calculator)$" }, 
    float = true, size = "900 600", center = true 
})

hl.window_rule({ 
    match = { class = "^(galculator)$" }, 
    float = true, size = "900 600", center = true 
})

hl.window_rule({ 
    match = { class = "^(blueman-manager)$" }, 
    float = true, size = "900 600", center = true 
})

hl.window_rule({ 
    match = { class = "^(blueman-adapters)$" }, 
    float = true, size = "900 600", center = true 
})

hl.window_rule({ 
    match = { class = "^(blueman-services)$" }, 
    float = true, size = "900 600", center = true 
})

hl.window_rule({ 
    match = { class = "^(org\\.gnome\\.Calculator)$" }, 
    float = true, size = "450 600", center = true 
})


hl.window_rule({ 
    match = { class = "^(xdg-desktop-portal.*)$" }, 
    float = true, center = true 
})

hl.window_rule({ 
    match = { class = "^(steam)$" }, 
    float = true, size = "1100 700", center = true 
})

hl.window_rule({ 
    match = { class = "^(zoom)$" }, 
    float = true, size = "1100 700", center = true 
})

hl.window_rule({
    match = { class = "^(steam)$", title = "^(notificationtoasts)" },
    no_initial_focus = true,
    pin = true,
})

hl.window_rule({
    match = { class = "^(firefox)$", title = "^(Picture-in-Picture)$" },
    float = true,
})

hl.window_rule({ 
    match = { title = "^(Picture-in-Picture)$" }, 
    float = true, pin = true 
})

hl.window_rule({ 
    match = { class = "^(nm-connection-editor)$" }, 
    float = true, size = "600 500", center = true 
})

hl.window_rule({ 
    match = { title = "^(File Upload|Open File|Save File|Select File|Choose File).*" }, 
    float = true, size = "900 600", center = true 
})

hl.window_rule({ 
    match = { title = "^(Authentication Required|Password Required|Unlock Keyring).*" }, 
    float = true, size = "500 300", center = true 
})

hl.window_rule({ 
    match = { title = "^(Confirm|Confirmation|Warning|Error).*" }, 
    float = true, size = "600 350", center = true 
})

hl.window_rule({ 
    match = { class = "^(nwg-look)$" }, 
    float = true, size = "900 600", center = true 
})

hl.window_rule({ 
    match = { class = "^(qt5ct)$" }, 
    float = true, size = "900 600", center = true 
})

hl.window_rule({ 
    match = { class = "^(qt6ct)$" }, 
    float = true, size = "900 600", center = true 
})

hl.window_rule({ 
    match = { class = "^(org\\.gnome\\.tweaks)$" }, 
    float = true, size = "900 600", center = true 
})

hl.window_rule({ 
    match = { class = "^(com\\.mattjakeman\\.ExtensionManager)$" }, 
    float = true, size = "900 600", center = true 
})

hl.window_rule({ 
    match = { class = "^(waypaper)$" }, 
    float = true, size = "900 600", center = true 
})

hl.window_rule({ 
    match = { title = "^(float_term)$" }, 
    float = true, size = "1300 850", center = true, opacity = "0.85 0.90"
})

hl.window_rule({ 
    match = { class = "^(org\\.gnome\\.TextEditor)$" }, 
    float = true, size = "1300 850", center = true 
})

hl.window_rule({ 
    match = { class = "^(org.gnome.Software)$" }, 
    float = true, size = "1300 850", center = true 
})

hl.window_rule({ 
    match = { class = "^(org.gnome.baobab)$" }, 
    float = true, size = "1300 850", center = true 
})

hl.window_rule({
    match = {
        class = "^zen$",
    },
    opacity = "1.0 override 1.0 override",
    no_blur = true,
})