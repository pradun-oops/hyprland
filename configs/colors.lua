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
            active_border   = "rgb(ffb599)",
            inactive_border = "rgb(53433e)",
        },
    },

    -- ========================================================================
    -- 📦 WINDOW GROUPING & GROUPBAR THEME COLORS
    -- ========================================================================
    -- Controls border styling for tabbed/grouped windows and their titlebars.
    group = {
        col = {
            border_active          = "rgb(ffb599)",
            border_inactive        = "rgb(53433e)",
            border_locked_active   = "rgb(d4c78e)",
            border_locked_inactive = "rgb(53433e)",
        },
        groupbar = {
            col = {
                active           = "rgb(ffb599)",
                inactive         = "rgb(53433e)",
                locked_active    = "rgb(d4c78e)",
                locked_inactive  = "rgb(53433e)",
            },
        },
    },
})