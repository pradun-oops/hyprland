hl.on("hyprland.start", function()
    -- ==========================================================
    -- 🌐 System Environment & DBus
    -- Ensures proper integration with systemd user sessions,
    -- screen sharing (xdg-desktop-portal), and Qt/GTK theming.
    -- ==========================================================
    hl.exec_cmd(
        "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP QT_QPA_PLATFORMTHEME"
    )
    hl.exec_cmd(
        "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP QT_QPA_PLATFORMTHEME"
    )
    hl.exec_cmd("systemctl --user start hyprland-session.target")

    -- ==========================================================
    -- 🔐 Security & Authentication
    -- Starts the GNOME polkit agent for GUI privilege escalation 
    -- (needed for apps that prompt for your sudo password).
    -- ==========================================================
    hl.exec_cmd("/usr/libexec/polkit-gnome-authentication-agent-1 &")

    -- ==========================================================
    -- 🛠️ Background Services & Utilities
    -- Initializes your wallpaper, clipboard manager, idle daemon, and watchers.
    -- ==========================================================
    -- Start animated wallpaper daemon
    hl.exec_cmd("awww-daemon &")
    
    -- Start clipboard history listener
    hl.exec_cmd("wl-paste --watch cliphist store &")

    -- Start Hyprland idle management daemon
    hl.exec_cmd("hypridle &")
    
    -- Live theme reloader (watches colors.lua and applies presets)
    hl.exec_cmd(
        [[sh -c 'echo "$HOME/.config/hypr/dms/colors.lua" | entr -n "$HOME/.config/hypr/scripts/apply_preset.sh" 0 &' ]]
    )

    -- ==========================================================
    -- 🎨 GTK Theme & GNOME Settings
    -- Enforces a consistent look across all GTK applications.
    -- ==========================================================
    for _, setting in ipairs({
        "org.gnome.desktop.interface gtk-theme adw-gtk3-dark",
        "org.gnome.desktop.interface icon-theme WhiteSur",
        "org.gnome.desktop.wm.preferences button-layout ':,,close'",
    }) do
        hl.exec_cmd("gsettings set " .. setting)
    end

    -- ==========================================================
    -- 🖥️ Custom UI Shell
    -- Launches your custom Quickshell environment.
    -- ==========================================================
    hl.exec_cmd("quickshell -c ~/.config/hypr/quickshell/ &")
end)