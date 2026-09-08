hl.on("hyprland.start", function()
    -- 1. Systemd & DBus Environment Setup (Crucial for screen sharing and portals)
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP QT_QPA_PLATFORMTHEME")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP QT_QPA_PLATFORMTHEME")
    hl.exec_cmd("systemctl --user start hyprland-session.target")
    
    -- 2. Core Daemons, Agents, and Hardware overrides
    hl.exec_cmd("/usr/libexec/polkit-gnome-authentication-agent-1 &")
    hl.exec_cmd("awww-daemon &")
    hl.exec_cmd("wl-paste --watch cliphist store &")
    
    -- 3. GTK and Theme Settings
    -- hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme prefer-dark")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface icon-theme WhiteSur")
    hl.exec_cmd("gsettings set org.gnome.desktop.wm.preferences button-layout ':,,close'")
    
    -- 4. Dynamic Color Preset Watcher
    hl.exec_cmd([[sh -c 'echo "$HOME/.config/hypr/dms/colors.lua" | entr -n "$HOME/.config/hypr/scripts/apply_preset.sh" 0 &' ]])
    
    -- 5. Autostart Quickshell Widgets
    hl.exec_cmd("quickshell -c ~/.config/hypr/quickshell/topbar/ &")
    hl.exec_cmd("quickshell -c ~/.config/hypr/quickshell/dock/ &")
    hl.exec_cmd("quickshell -c ~/.config/hypr/quickshell/desktop/ &")
    hl.exec_cmd("quickshell -c ~/.config/hypr/quickshell/player/ &")
    hl.exec_cmd("quickshell -c ~/.config/hypr/quickshell/brightness/ &")
    hl.exec_cmd("quickshell -c ~/.config/hypr/quickshell/volume/ &")
    hl.exec_cmd("quickshell -c ~/.config/hypr/quickshell/notification/ &")
end)