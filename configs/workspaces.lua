--- @diagnostic disable: undefined-global

-- ============================================================================
-- 🖥️ WORKSPACE MONITOR BINDING CONFIGURATION
-- ============================================================================
-- Maps virtual workspaces to specific physical displays in a multi-monitor setup:
--   • External Monitor (HDMI-A-1) : Workspaces 1 – 5 (Primary Display)
--   • Laptop Display   (eDP-1)    : Workspaces 6 – 10 (Secondary Display)
-- ============================================================================

local monitor_bindings = {
    { monitor = "HDMI-A-1", start_ws = 1, end_ws = 5 },
    { monitor = "eDP-1",    start_ws = 6, end_ws = 10 },
}

-- Dynamically apply workspace-to-monitor rules from configuration table
for _, binding in ipairs(monitor_bindings) do
    for ws = binding.start_ws, binding.end_ws do
        hl.workspace_rule({
            workspace = tostring(ws),
            monitor   = binding.monitor,
        })
    end
end