local monitor_bindings = {
    { monitor = "HDMI-A-1", start_ws = 1, end_ws = 5 },
    { monitor = "eDP-1",    start_ws = 6, end_ws = 10 },
}

for _, binding in ipairs(monitor_bindings) do
    for ws = binding.start_ws, binding.end_ws do
        local is_default = (ws == binding.start_ws)
        hl.workspace_rule({
            workspace = tostring(ws),
            monitor   = binding.monitor,
            default   = is_default,
        })
    end
end