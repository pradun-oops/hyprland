hl.config({
	input = {
		kb_layout = "us",
		numlock_by_default = false,
		repeat_rate = 50,
		repeat_delay = 200,
		follow_mouse = 1,
		mouse_refocus = false,
		sensitivity = 0,
		accel_profile = "flat",
		touchpad = {
			tap_to_click = true,
			natural_scroll = true,
			tap_and_drag = true,
			drag_lock = true,
			disable_while_typing = true,
			scroll_factor = 0.5,
			clickfinger_behavior = true,
			middle_button_emulation = false,
		},
	},
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })