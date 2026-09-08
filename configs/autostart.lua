hl.on("hyprland.start", function()
	hl.exec_cmd(
		"dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP QT_QPA_PLATFORMTHEME"
	)
	hl.exec_cmd(
		"systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP QT_QPA_PLATFORMTHEME"
	)
	hl.exec_cmd("systemctl --user start hyprland-session.target")
	hl.exec_cmd("/usr/libexec/polkit-gnome-authentication-agent-1 &")
	hl.exec_cmd("awww-daemon &")
	hl.exec_cmd("wl-paste --watch cliphist store &")
	hl.exec_cmd(
		[[sh -c 'echo "$HOME/.config/hypr/dms/colors.lua" | entr -n "$HOME/.config/hypr/scripts/apply_preset.sh" 0 &' ]]
	)

	for _, setting in ipairs({
		"org.gnome.desktop.interface gtk-theme adw-gtk3-dark",
		"org.gnome.desktop.interface icon-theme WhiteSur",
		"org.gnome.desktop.wm.preferences button-layout ':,,close'",
	}) do
		hl.exec_cmd("gsettings set " .. setting)
	end

	for _, comp in ipairs({ "topbar", "dock", "desktop", "player", "brightness", "volume", "notification" }) do
		hl.exec_cmd(string.format("quickshell -c ~/.config/hypr/quickshell/%s/ &", comp))
	end
end)
