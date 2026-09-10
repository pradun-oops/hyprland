-- ==========================================================
-- ⚙️ Animation Engine Configuration
-- Preset: Default (Clean, responsive sliding transitions)
-- ==========================================================
hl.config({
    animations = {
        enabled = true,
    },
})

-- ==========================================================
-- 🪟 Window Lifecycle & Motion
-- Controls entry, exit, and dragging/repositioning of windows.
-- ==========================================================
-- Window open transition (slides in smoothly)
hl.animation({ leaf = "windowsIn", enabled = true, speed = 5, bezier = "default", style = "slide" })

-- Window close transition (slightly faster slide-out for snappiness)
hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, bezier = "default", style = "slide" })

-- Window move / tile reposition animation
hl.animation({ leaf = "windowsMove", enabled = true, speed = 6, bezier = "default" })

-- ==========================================================
-- 👁️ Visual Effects & Transitions
-- Manages opacity changes, workspace shifts, and active borders.
-- ==========================================================
-- Opacity / layer fading
hl.animation({ leaf = "fade", enabled = true, speed = 5, bezier = "default" })

-- Workspace switching transition
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "default", style = "slide" })

-- Active border color shift and pulse speed
hl.animation({ leaf = "border", enabled = true, speed = 8, bezier = "default" })