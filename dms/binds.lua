hl.bind("CTRL + Print", hl.dsp.exec_cmd("dms screenshot"))
hl.bind("Print", hl.dsp.exec_cmd("dms screenshot full"))
hl.bind("ALT + Print", hl.dsp.exec_cmd("dms screenshot window"))

hl.bind("SUPER + SHIFT + R", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenrecord.sh full"))
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd("~/.config/hypr/scripts/screenrecord.sh area"))

hl.bind("SUPER + space", hl.dsp.exec_cmd("dms ipc call spotlight toggle"))
hl.bind("SUPER + V", hl.dsp.exec_cmd("dms ipc call clipboard toggle"))
hl.bind("SUPER + X", hl.dsp.exec_cmd("dms ipc call powermenu toggle"))
hl.bind("SUPER + N", hl.dsp.exec_cmd("dms ipc call notifications toggle"))
hl.bind("SUPER + SHIFT + N", hl.dsp.exec_cmd("dms ipc call notepad toggle"))
hl.bind("SUPER + M", hl.dsp.exec_cmd("dms ipc call processlist focusOrToggle"))
hl.bind("CTRL + ALT + Delete", hl.dsp.exec_cmd("dms ipc call processlist focusOrToggle"))
hl.bind("SUPER + comma", hl.dsp.exec_cmd("dms ipc call settings focusOrToggle"))
hl.bind("SUPER + SHIFT + Slash", hl.dsp.exec_cmd("dms ipc call keybinds toggle hyprland"))
hl.bind("SUPER + TAB", hl.dsp.exec_cmd("dms ipc call hypr toggleOverview"))

hl.bind("SUPER + ALT + L", hl.dsp.exec_cmd("dms ipc call lock lock"))
hl.bind("SUPER + Y", hl.dsp.exec_cmd("dms ipc call dankdash wallpaper"))

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("dms ipc call audio increment 5"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("dms ipc call audio decrement 5"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("dms ipc call audio mute"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("dms ipc call audio micmute"), { locked = true })

hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("dms ipc call mpris playPause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("dms ipc call mpris next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("dms ipc call mpris previous"), { locked = true })

hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("dms ipc call brightness increment 10 \"\""), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("dms ipc call brightness decrement 10 \"\""), { locked = true, repeating = true })

hl.bind("ALT + XF86MonBrightnessUp", hl.dsp.exec_cmd("ddcutil --bus 5 setvcp 10 + 10"), { repeating = true })
hl.bind("ALT + XF86MonBrightnessDown", hl.dsp.exec_cmd("ddcutil --bus 5 setvcp 10 - 10"), { repeating = true })

hl.bind("SUPER + ALT + space", hl.dsp.exec_cmd("~/.config/hypr/scripts/toggle_backlight.sh"))

hl.bind("SUPER + Return", hl.dsp.exec_cmd("kitty"))
hl.bind("SUPER + B", hl.dsp.exec_cmd("zen-browser"))
hl.bind("SUPER + E", hl.dsp.exec_cmd("nautilus --new-window"))
hl.bind("SUPER + C", hl.dsp.exec_cmd("codium"))
hl.bind("SUPER + O", hl.dsp.exec_cmd("VirtualBox Manager"))
hl.bind("SUPER + W", hl.dsp.exec_cmd("waypaper"))
hl.bind("SUPER + A", hl.dsp.exec_cmd("easyeffects"))

hl.bind("SUPER + T", hl.dsp.exec_cmd("kitty --title \"float_term\""))

hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + SHIFT + E", hl.dsp.exit())
hl.bind("SUPER + SHIFT + P", hl.dsp.dpms({ action = "toggle" }))
hl.bind("SUPER + ALT + R", hl.dsp.exec_cmd("hyprctl reload"))

hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind("SUPER + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind("SUPER + R", hl.dsp.layout("togglesplit"))

hl.bind("SUPER + SHIFT + T", hl.dsp.exec_cmd("hyprctl dispatch togglefloating && hyprctl dispatch resizeactive exact 1300 850 && hyprctl dispatch centerwindow"))

hl.bind("SUPER + H", hl.dsp.focus({ direction = "l" }))
hl.bind("SUPER + L", hl.dsp.focus({ direction = "r" }))
hl.bind("SUPER + K", hl.dsp.focus({ direction = "u" }))
hl.bind("SUPER + J", hl.dsp.focus({ direction = "d" }))

hl.bind("ALT + TAB", hl.dsp.focus({ window = "next" }))

hl.bind("SUPER + SHIFT + H", hl.dsp.window.move({ direction = "l" }))
hl.bind("SUPER + SHIFT + L", hl.dsp.window.move({ direction = "r" }))
hl.bind("SUPER + SHIFT + K", hl.dsp.window.move({ direction = "u" }))
hl.bind("SUPER + SHIFT + J", hl.dsp.window.move({ direction = "d" }))

hl.bind("SUPER + minus", hl.dsp.window.resize({ x = -100, y = 0, relative = true }), { repeating = true })
hl.bind("SUPER + equal", hl.dsp.window.resize({ x = 100, y = 0, relative = true }), { repeating = true })
hl.bind("SUPER + SHIFT + minus", hl.dsp.window.resize({ x = 0, y = -100, relative = true }), { repeating = true })
hl.bind("SUPER + SHIFT + equal", hl.dsp.window.resize({ x = 0, y = 100, relative = true }), { repeating = true })

hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Move window" })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Resize window" })

hl.bind("SUPER + CTRL + H", hl.dsp.focus({ monitor = "l" }))
hl.bind("SUPER + CTRL + L", hl.dsp.focus({ monitor = "r" }))

hl.bind("SUPER + CTRL + SHIFT + H", hl.dsp.window.move({ monitor = "l" }))
hl.bind("SUPER + CTRL + SHIFT + L", hl.dsp.window.move({ monitor = "r" }))

hl.bind("SUPER + CTRL + J", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("SUPER + CTRL + K", hl.dsp.focus({ workspace = "e-1" }))

hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

hl.bind("SUPER + S", hl.dsp.workspace.toggle_special("super"))
hl.bind("SUPER + SHIFT + S", hl.dsp.window.move({ workspace = "special:super" }))

for i = 1, 9 do
    hl.bind("SUPER + " .. i, hl.dsp.focus({ workspace = tostring(i) }))
end
hl.bind("SUPER + 0", hl.dsp.focus({ workspace = "10" }))

for i = 1, 9 do
    hl.bind("SUPER + SHIFT + " .. i, hl.dsp.window.move({ workspace = tostring(i) }))
end
hl.bind("SUPER + SHIFT + 0", hl.dsp.window.move({ workspace = "10" }))

hl.bind("SUPER + SHIFT + G", hl.dsp.exec_cmd("kitty --title \"float_term\" -e ~/.config/hypr/scripts/update_gdm.sh"))

for i = 1, 9 do
    hl.bind("SUPER + ALT + " .. i, hl.dsp.exec_cmd("~/.config/hypr/scripts/apply_preset.sh " .. i))
end

hl.bind("SUPER + SHIFT + T", hl.dsp.exec_cmd("~/.config/hypr/scripts/toggle_float.sh"))