--- @diagnostic disable: undefined-global

-- ============================================================================
-- 🚀 HYPRLAND STARTUP & AUTOSTART CONFIGURATION
-- ============================================================================
-- Manages environment variables, authentication agents, background daemons,
-- GTK theming, and the primary Quickshell UI execution on launch.
-- ============================================================================

hl.on("hyprland.start", function()
    local home = os.getenv("HOME")

    -- ========================================================================
    -- 🌐 SYSTEM ENVIRONMENT & DBUS ACTIVATION
    -- ========================================================================
    -- Ensures Wayland, XDG, and QT variables are cleanly passed to systemd/DBus
    local env_vars = "WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP QT_QPA_PLATFORMTHEME"
    
    hl.exec_cmd("dbus-update-activation-environment --systemd " .. env_vars)
    hl.exec_cmd("systemctl --user import-environment " .. env_vars)
    hl.exec_cmd("systemctl --user start hyprland-session.target")


    -- ========================================================================
    -- 🔐 SECURITY & AUTHENTICATION
    -- ========================================================================
    -- GNOME Polkit agent for GUI privilege escalation (required for secure apps)
    hl.exec_cmd("/usr/libexec/polkit-gnome-authentication-agent-1 &")


    -- ========================================================================
    -- 🛠️ BACKGROUND DAEMONS & UTILITIES
    -- ========================================================================
    hl.exec_cmd("awww-daemon &")                             -- Wallpaper daemon
    hl.exec_cmd("wl-paste --watch cliphist store &")         -- Clipboard manager
    hl.exec_cmd("hypridle &")                                -- Idle management

    -- Live theme watcher: monitors colors.lua and syncs Lenovo LOQ keyboard RGB
    hl.exec_cmd(home .. "/.config/hypr/scripts/theme_watcher.sh &")


    -- ========================================================================
    -- 🎨 GTK THEME & GNOME DESKTOP SETTINGS
    -- ========================================================================
    -- Dynamically applies standard GTK styling to ensure uniform app appearance
    local gnome_settings = {
        "org.gnome.desktop.interface gtk-theme adw-gtk3-dark",
        "org.gnome.desktop.interface icon-theme WhiteSur",
        "org.gnome.desktop.wm.preferences button-layout ':,,close'",
    }

    for _, setting in ipairs(gnome_settings) do
        hl.exec_cmd("gsettings set " .. setting)
    end


    -- ========================================================================
    -- 🖥️ CUSTOM UI SHELL (QUICKSHELL)
    -- ========================================================================
    -- Boots the main custom shell interface overlay
    hl.exec_cmd("quickshell -c " .. home .. "/.config/hypr/quickshell/ &")
end)