--- @diagnostic disable: undefined-global

-- ============================================================================
-- 🎨 DYNAMIC BORDER & WINDOW GROUP THEME CONFIGURATION
-- ============================================================================
-- Maps template-driven color variables (Matugen / Quickshell dynamic theming)
-- to active, inactive, locked, and grouped window border elements.
-- ============================================================================

hl.config({
    -- ========================================================================
    -- 🪟 GENERAL WINDOW BORDER COLORS
    -- ========================================================================
    -- Sets border color themes for standard focused and unfocused windows.
    general = {
        col = {
            active_border   = "rgb(afd18c)",
            inactive_border = "rgb(44483e)",
        },
    },

    -- ========================================================================
    -- 📦 WINDOW GROUPING & GROUPBAR THEME COLORS
    -- ========================================================================
    -- Controls border styling for tabbed/grouped windows and their titlebars.
    group = {
        col = {
            border_active          = "rgb(afd18c)",
            border_inactive        = "rgb(44483e)",
            border_locked_active   = "rgb(a0cfcd)",
            border_locked_inactive = "rgb(44483e)",
        },
        groupbar = {
            col = {
                active           = "rgb(afd18c)",
                inactive         = "rgb(44483e)",
                locked_active    = "rgb(a0cfcd)",
                locked_inactive  = "rgb(44483e)",
            },
        },
    },
})