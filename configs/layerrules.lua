hl.layer_rule({
    name = "quickshell-no-anim",
    match = {
        namespace = "^(quickshell)$",
    },
    no_anim = true,
})

hl.layer_rule({
    name = "qs-brightness-osd-blur",
    match = {
        namespace = "^(qs-brightness-osd)$",
    },
    blur = true,
    xray = false,
    ignore_alpha = 0.01,
})

hl.layer_rule({
    name = "qs-volume-osd-blur",
    match = {
        namespace = "^(qs-volume-osd)$",
    },
    blur = true,
    xray = false,
    ignore_alpha = 0.01,
})

hl.layer_rule({
    name = "qs-bar-blur",
    match = {
        namespace = "^(qs-bar)$",
    },
    blur = true,
    xray = false,
    ignore_alpha = 0.01,
})

hl.layer_rule({
    name = "qs-dock-blur",
    match = {
        namespace = "^(qs-dock)$",
    },
    blur = true,
    xray = false,
    ignore_alpha = 0.01,
})

hl.layer_rule({
    name = "qs-notifications-blur",
    match = {
        namespace = "^(qs-notifications)$",
    },
    blur = true,
    xray = false,
    ignore_alpha = 0.01,
})

hl.layer_rule({
    name = "qs-desktop-dashboard",
    match = {
        namespace = "^(qs-desktop-dashboard)$",
    },
    blur = true,
    xray = false,
    ignore_alpha = 0.01,
})

hl.layer_rule({
    name = "notification-center",
    match = {
        namespace = "^(notification-center)$",
    },
    blur = true,
    xray = false,
    ignore_alpha = 0.01,
})

hl.layer_rule({
    name = "qs-keybinds-blur",
    match = {
        namespace = "^(qs-keybinds|keybinds)$",
    },
    blur = true,
    xray = false,
    ignore_alpha = 0.01,
})

hl.layer_rule({
    name = "qs-spotlight-blur",
    match = {
        namespace = "^(qs-spotlight|spotlight)$",
    },
    blur = true,
    xray = false,
    ignore_alpha = 0.01,
})

hl.layer_rule({
    name = "qs-power-menu-blur",
    match = {
        namespace = "^(qs-power-menu)$",
    },
    blur = true,
    xray = false,
    ignore_alpha = 0.02,
})