--- @diagnostic disable: undefined-global

-- ============================================================================
-- ⚙️ ANIMATION ENGINE CONFIGURATION
-- ============================================================================
-- Preset: Default (Clean, responsive sliding transitions and fluid motion)
-- ============================================================================

hl.config({
    animations = {
        enabled = true,
    },
})


-- ============================================================================
-- 🪟 WINDOW LIFECYCLE & MOTION
-- ============================================================================
-- Controls entry, exit, dragging, and tile repositioning animations.
-- ============================================================================

-- Window open transition (smooth slide-in effect)
hl.animation({ leaf = "windowsIn", enabled = true, speed = 5, bezier = "default", style = "slide" })

-- Window close transition (slightly faster slide-out for UI snappiness)
hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, bezier = "default", style = "slide" })

-- Window move / tile reposition animation
hl.animation({ leaf = "windowsMove", enabled = true, speed = 6, bezier = "default" })


-- ============================================================================
-- 👁️ VISUAL EFFECTS & TRANSITIONS
-- ============================================================================
-- Manages opacity fading, workspace switching shifts, and active border color pulses.
-- ============================================================================

-- Opacity / layer fading transition
hl.animation({ leaf = "fade", enabled = true, speed = 5, bezier = "default" })

-- Workspace switching sliding transition
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "default", style = "slide" })

-- Active border color shift and pulse speed
hl.animation({ leaf = "border", enabled = true, speed = 8, bezier = "default" })