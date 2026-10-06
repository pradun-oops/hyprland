hl.on("hyprland.start", function()
    local home = os.getenv("HOME")

    local env_vars = "WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP QT_QPA_PLATFORMTHEME ADW_DISABLE_PORTAL"
    
    hl.exec_cmd("dbus-update-activation-environment --systemd " .. env_vars)
    hl.exec_cmd("systemctl --user import-environment " .. env_vars)
    hl.exec_cmd("systemctl --user start hyprland-session.target")

    hl.exec_cmd("/usr/libexec/polkit-gnome-authentication-agent-1 &")

    hl.exec_cmd("hyprpm reload -n &")
    hl.exec_cmd("awww-daemon &")
    hl.exec_cmd("wl-paste --watch cliphist store &")
    hl.exec_cmd("hypridle &")

    hl.exec_cmd(home .. "/.config/hypr/scripts/theme_watcher.sh &")

    local gnome_settings = {
        "org.gnome.desktop.interface gtk-theme adw-gtk3-dark",
        "org.gnome.desktop.interface color-scheme 'prefer-dark'",
        "org.gnome.desktop.interface icon-theme WhiteSur",
        "org.gnome.desktop.wm.preferences button-layout ':,,close'",
    }

    for _, setting in ipairs(gnome_settings) do
        hl.exec_cmd("gsettings set " .. setting)
    end

    hl.exec_cmd("quickshell -c " .. home .. "/.config/hypr/quickshell/ &")
end)