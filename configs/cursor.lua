-- ==========================================================
-- 🖱️ Cursor Theme & Sizing Configuration
-- Configures uniform mouse appearance across native Wayland 
-- (hyprcursor) and XWayland legacy fallback (xcursor).
-- ==========================================================

-- Theme family (matches your GTK WhiteSur aesthetic)
hl.env("HYPRCURSOR_THEME", "WhiteSur-cursors")
hl.env("XCURSOR_THEME", "WhiteSur-cursors")

-- Cursor size scale (24px standard HiDPI scale)
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_SIZE", "24")