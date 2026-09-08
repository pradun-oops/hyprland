hl.layer_rule({
	name = "quickshell-no-anim",
	match = { namespace = "^(quickshell)$" },
	no_anim = true,
})

local function apply_blur(namespaces, alpha)
	for _, ns in ipairs(namespaces) do
		hl.layer_rule({
			name = ns .. "-blur",
			match = { namespace = "^(" .. ns .. ")$" },
			blur = true,
			xray = false,
			ignore_alpha = alpha,
		})
	end
end

apply_blur({
	"qs-brightness-osd",
	"qs-volume-osd",
	"qs-bar",
	"qs-dock",
	"qs-notifications",
	"qs-desktop-dashboard",
	"notification-center",
	"qs-keybinds",
	"keybinds",
	"qs-spotlight",
	"spotlight",
	"qs-calendar",
	"qs-network-center",
	"qs-control-center",
	"qs-notification-center",
	"qs-bluetooth-center",
	"qs-sysmon",
	"qs-weather",
	"qs-config",
	"qs-wallselect",
	"qs-drawer",
	"qs-calculator",
	"qs-filemanager",
	"qs-clipboard",
}, 0.01)

apply_blur({ "qs-power-menu" }, 0.02)