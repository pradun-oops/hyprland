hl.layer_rule({
    name = "quickshell-no-anim",
    match = {
        namespace = "^(quickshell)$",    },

    no_anim = true,
})

hl.layer_rule({
    name = "dms-static-shell",
    match = {
        namespace = "^(dms:bar|dms:dock|dms:tray-menu-window)$",    },

    blur = true,
    xray = false,
    ignore_alpha = 0.01,
    blur_popups = true,
})

hl.layer_rule({
    name = "dms-popups",
    match = {
        namespace = "^(dms:control-center|dms:notification-popup|dms:battery|dms:process-list-popout|dms:control-center-widget-library|dms:slideout)$",
    },
    blur = true,
    xray = false,
    ignore_alpha = 0.01,
    blur_popups = true,
})

hl.layer_rule({
    name = "dms-modals",
    match = {
        namespace = "^(dms:keybinds|dms:power-menu|dms:spotlight|dms:clipboard|dms:workspace-overview|dms:osd|dms:notification-center-modal|dms:color-picker|dms:network-info-wired|dms:filebrowser|dms:tooltip|dms:dash|dms:confirm-modal)$",
    },
    blur = true,
    xray = false,
    ignore_alpha = 0.01,
    blur_popups = true,
})

hl.layer_rule({
    name = "dms-desktop-widgets",
    match = {
        namespace = "^(dms:desktop-widget:.*)$",
    },
    blur = true,
    xray = false,
    ignore_alpha = 0.01,
    blur_popups = true,
})