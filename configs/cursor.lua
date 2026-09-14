--- @diagnostic disable: undefined-global

-- ============================================================================
-- 🖱️ CURSOR THEME & SIZING CONFIGURATION
-- ============================================================================
-- Configures a uniform mouse cursor appearance across native Wayland 
-- (hyprcursor) and XWayland legacy fallback (xcursor) surfaces.
-- ============================================================================

-- Theme family (matches your custom WhiteSur GTK desktop aesthetic)
hl.env("HYPRCURSOR_THEME", "WhiteSur-cursors")
hl.env("XCURSOR_THEME",    "WhiteSur-cursors")

-- Cursor size scale (24px standard scale)
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_SIZE",    "24")