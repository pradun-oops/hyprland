--- @diagnostic disable: undefined-global

-- ============================================================================
-- 🖥️ DISPLAY & MONITOR LAYOUT CONFIGURATION
-- ============================================================================
-- Defines resolutions, refresh rates, positioning offsets, scaling factors,
-- and fallback rules for your dual-monitor setup (Acer EK251Q P2 + Laptop panel).
-- ============================================================================

local monitor_configs = {
    -- ========================================================================
    -- 💻 Built-in Laptop Display (eDP-1) — Secondary Screen
    -- Anchored at the left origin coordinate with a custom vertical offset.
    -- ========================================================================
    {
        output   = "eDP-1",
        mode     = "1920x1080@144.001",
        position = "0x693",
        scale    = 1,
        vrr      = 0,
    },

    -- ========================================================================
    -- 🖥️ External Display (HDMI-A-1) — Primary Monitor (Acer EK251Q P2)
    -- Positioned side-by-side to the right of the laptop display.
    -- ========================================================================
    {
        output   = "HDMI-A-1",
        mode     = "1920x1080@143.997",
        position = "1920x693",
        scale    = 1,
        vrr      = 0,
    },
}

-- Dynamically apply explicit physical monitor layouts
for _, config in ipairs(monitor_configs) do
    hl.monitor(config)
end

-- ============================================================================
-- 🔄 DEFAULT FALLBACK RULE
-- ============================================================================
-- Catch-all configuration applied to any dynamically hotplugged displays 
-- not explicitly defined in the layout configuration table above.
-- ============================================================================
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "400x0",
    scale    = 1,
})