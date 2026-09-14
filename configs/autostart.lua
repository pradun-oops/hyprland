--- @diagnostic disable: undefined-global

-- ============================================================================
-- 🚀 HYPRLAND STARTUP & AUTOSTART CONFIGURATION
-- ============================================================================

hl.on("hyprland.start", function()
    -- ========================================================================
    -- 🌐 SYSTEM ENVIRONMENT & DBUS ACTIVATION
    -- ========================================================================
    hl.exec_cmd(
        "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP QT_QPA_PLATFORMTHEME"
    )
    hl.exec_cmd(
        "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP QT_QPA_PLATFORMTHEME"
    )
    hl.exec_cmd("systemctl --user start hyprland-session.target")

    -- ========================================================================
    -- 🔐 SECURITY & AUTHENTICATION
    -- ========================================================================
    hl.exec_cmd("/usr/libexec/polkit-gnome-authentication-agent-1 &")

    -- ========================================================================
    -- 🛠️ BACKGROUND DAEMONS & UTILITIES
    -- ========================================================================
    hl.exec_cmd("awww-daemon &")
    hl.exec_cmd("wl-paste --watch cliphist store &")
    hl.exec_cmd("hypridle &")
    
    -- Live theme watcher: monitors colors.lua and syncs keyboard RGB automatically
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/theme_watcher.sh &")

    -- ========================================================================
    -- 🎨 GTK THEME & GNOME DESKTOP SETTINGS
    -- ========================================================================
    local gnome_settings = {
        "org.gnome.desktop.interface gtk-theme adw-gtk3-dark",
        "org.gnome.desktop.interface icon-theme WhiteSur",
        "org.gnome.desktop.wm.preferences button-layout ':,,close'",
    }

    for _, setting in ipairs(gnome_settings) do
        hl.exec_cmd("gsettings set " .. setting)
    end

    -- ========================================================================
    -- 🖥️ CUSTOM UI SHELL
    -- ========================================================================
    hl.exec_cmd("quickshell -c ~/.config/hypr/quickshell/ &")
end)