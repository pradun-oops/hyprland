-- ==========================================================
-- 🖥️ Display & Monitor Layout Configuration
-- Defines resolution, refresh rates, positioning offsets,
-- scaling factors, and fallback rules for multi-monitor output.
-- ==========================================================

-- ==========================================================
-- 🔄 Default Fallback Rule
-- Catch-all for hotplugged displays not explicitly configured below.
-- ==========================================================
hl.monitor({ 
    output   = "", 
    mode     = "preferred", 
    position = "400x0", 
    scale    = 1 
})

-- ==========================================================
-- 🖥️ External Display (Primary Workspace / HDMI-A-1)
-- High refresh rate setup positioned to the right of the laptop.
-- ==========================================================
hl.monitor({ 
    output   = "HDMI-A-1", 
    mode     = "1920x1080@143.997", 
    position = "1920x693", 
    scale    = 1, 
    vrr      = 0 
})

-- ==========================================================
-- 💻 Built-in Laptop Display (eDP-1)
-- Internal high refresh panel anchored at the left origin coordinate.
-- ==========================================================
hl.monitor({ 
    output   = "eDP-1", 
    mode     = "1920x1080@144.001", 
    position = "0x693", 
    scale    = 1, 
    vrr      = 0 
})