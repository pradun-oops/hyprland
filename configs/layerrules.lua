hl.layer_rule({
    name    = "quickshell-no-anim",
    match   = { namespace = "^(quickshell)$" },
    no_anim = true,
})

local function apply_blur(namespaces, alpha_threshold)
    for _, ns in ipairs(namespaces) do
        hl.layer_rule({
            name         = ns .. "-blur",
            match        = { namespace = "^(" .. ns .. ")$" },
            blur         = true,
            xray         = false,
            ignore_alpha = alpha_threshold,
        })
    end
end

apply_blur({
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
    "qs-power-menu",
    "qs-digital-wellbeing",
}, 0.01)