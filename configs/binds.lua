-- ==========================================
-- Variables & Helpers
-- ==========================================
local home = os.getenv("HOME")
local script_dir = home .. "/.config/hypr/scripts/"

-- Core Applications
local term = "kitty"
local browser = "zen-browser"
local editor = "codium"
local file_manager = "nautilus --new-window"

-- Helper function for script execution
local function run_script(cmd)
    return hl.dsp.exec_cmd(script_dir .. cmd)
end

-- ==========================================
-- Quickshell & System Scripts
-- ==========================================
hl.bind("Print", run_script("screenshot.sh active"))
hl.bind("CTRL + Print", run_script("screenshot.sh area"))
hl.bind("ALT + Print", run_script("screenshot.sh all"))
hl.bind("SUPER + SHIFT + R", run_script("screenrecord.sh full"))
hl.bind("SUPER + CTRL + R", run_script("screenrecord.sh area"))

hl.bind("SUPER + space", run_script("qs_dialog.sh spotlight open"))
hl.bind("SUPER + X", run_script("qs_dialog.sh powermenu open"))
hl.bind("SUPER + I", run_script("qs_dialog.sh connection open"))
hl.bind("SUPER + ALT + C", run_script("qs_dialog.sh control-center toggle"))
hl.bind("SUPER + SHIFT + C", run_script("qs_dialog.sh calendar open"))
hl.bind("SUPER + N", run_script("qs_dialog.sh notification-history open"))
-- CHANGED: Moved from SUPER + K to avoid conflict with Vim navigation
hl.bind("SUPER + slash", run_script("qs_dialog.sh keybinds open")) 
hl.bind("SUPER + tab", run_script("qs_dialog.sh overview open"))
hl.bind("SUPER + ALT + L", run_script("qs_dialog.sh lockscreen open"))
hl.bind("SUPER + W", run_script("qs_dialog.sh wallpaper open"))
hl.bind("SUPER + M", run_script("qs_dialog.sh system-monitor open"))
hl.bind("SUPER + SHIFT + W", run_script("qs_dialog.sh weather open"))
hl.bind("SUPER + P", run_script("qs_dialog.sh setting open"))
hl.bind("SUPER + SHIFT + CTRL + C", run_script("qs_dialog.sh calculator open"))
hl.bind("SUPER + ALT + E", run_script("qs_dialog.sh file-manager open"))
hl.bind("SUPER + V", run_script("qs_dialog.sh clipboard-history open"))
hl.bind("SUPER + ALT + space", run_script("toggle_backlight.sh"))
hl.bind("SUPER + ALT + B", run_script("toggle_topbar.sh"))
hl.bind("SUPER + SHIFT + T", run_script("toggle_float.sh"))

-- ==========================================
-- Hardware Controls (Audio & Brightness)
-- ==========================================
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set +10%"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 10%-"), { locked = true, repeating = true })
hl.bind("ALT + XF86MonBrightnessUp", hl.dsp.exec_cmd("ddcutil setvcp 10 + 10"), { repeating = true })
hl.bind("ALT + XF86MonBrightnessDown", hl.dsp.exec_cmd("ddcutil setvcp 10 - 10"), { repeating = true })

-- ==========================================
-- Application Launchers
-- ==========================================
hl.bind("SUPER + Return", hl.dsp.exec_cmd(term))
hl.bind("SUPER + B", hl.dsp.exec_cmd(browser))
hl.bind("SUPER + E", hl.dsp.exec_cmd(file_manager))
hl.bind("SUPER + C", hl.dsp.exec_cmd(editor))
hl.bind("SUPER + O", hl.dsp.exec_cmd("VirtualBox Manager"))
hl.bind("SUPER + A", hl.dsp.exec_cmd("easyeffects"))
hl.bind("SUPER + SHIFT + B", hl.dsp.exec_cmd("blueman-manager"))
hl.bind("SUPER + T", hl.dsp.exec_cmd(term .. ' --title "float_term"'))
hl.bind("SUPER + SHIFT + G", hl.dsp.exec_cmd(term .. ' --title "float_term" -e ' .. script_dir .. 'update_gdm.sh'))

-- ==========================================
-- Window Management & Workspaces
-- ==========================================
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + SHIFT + E", hl.dsp.exit())
hl.bind("SUPER + SHIFT + P", hl.dsp.dpms({ action = "toggle" }))
hl.bind("SUPER + ALT + R", hl.dsp.exec_cmd("hyprctl reload"))

hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind("SUPER + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind("SUPER + R", hl.dsp.layout("togglesplit"))

-- Focus & Move
hl.bind("SUPER + H", hl.dsp.focus({ direction = "l" }))
hl.bind("SUPER + L", hl.dsp.focus({ direction = "r" }))
hl.bind("SUPER + K", hl.dsp.focus({ direction = "u" })) -- Vim-style up
hl.bind("SUPER + J", hl.dsp.focus({ direction = "d" }))
hl.bind("ALT + TAB", hl.dsp.focus({ window = "next" }))

hl.bind("SUPER + SHIFT + H", hl.dsp.window.move({ direction = "l" }))
hl.bind("SUPER + SHIFT + L", hl.dsp.window.move({ direction = "r" }))
hl.bind("SUPER + SHIFT + K", hl.dsp.window.move({ direction = "u" }))
hl.bind("SUPER + SHIFT + J", hl.dsp.window.move({ direction = "d" }))

-- Resize & Mouse
hl.bind("SUPER + minus", hl.dsp.window.resize({ x = -100, y = 0, relative = true }), { repeating = true })
hl.bind("SUPER + equal", hl.dsp.window.resize({ x = 100, y = 0, relative = true }), { repeating = true })
hl.bind("SUPER + SHIFT + minus", hl.dsp.window.resize({ x = 0, y = -100, relative = true }), { repeating = true })
hl.bind("SUPER + SHIFT + equal", hl.dsp.window.resize({ x = 0, y = 100, relative = true }), { repeating = true })
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Move window" })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Resize window" })

-- Dual Monitor Navigation
hl.bind("SUPER + CTRL + H", hl.dsp.focus({ monitor = "l" }))
hl.bind("SUPER + CTRL + L", hl.dsp.focus({ monitor = "r" }))
hl.bind("SUPER + CTRL + SHIFT + H", hl.dsp.window.move({ monitor = "l" }))
hl.bind("SUPER + CTRL + SHIFT + L", hl.dsp.window.move({ monitor = "r" }))

-- Workspaces
hl.bind("SUPER + CTRL + J", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("SUPER + CTRL + K", hl.dsp.focus({ workspace = "e-1" }))
hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind("SUPER + S", hl.dsp.workspace.toggle_special("super"))
hl.bind("SUPER + SHIFT + S", hl.dsp.window.move({ workspace = "special:super" }))

for i = 1, 9 do
    hl.bind("SUPER + " .. i, hl.dsp.focus({ workspace = tostring(i) }))
    hl.bind("SUPER + SHIFT + " .. i, hl.dsp.window.move({ workspace = tostring(i) }))
    hl.bind("SUPER + ALT + " .. i, run_script("apply_preset.sh " .. i))
end

hl.bind("SUPER + 0", hl.dsp.focus({ workspace = "10" }))
hl.bind("SUPER + SHIFT + 0", hl.dsp.window.move({ workspace = "10" }))
