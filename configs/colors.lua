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
            active_border   = "rgb(ffb3b4)",
            inactive_border = "rgb(524343)",
        },
    },

    -- ========================================================================
    -- 📦 WINDOW GROUPING & GROUPBAR THEME COLORS
    -- ========================================================================
    -- Controls border styling for tabbed/grouped windows and their titlebars.
    group = {
        col = {
            border_active          = "rgb(ffb3b4)",
            border_inactive        = "rgb(524343)",
            border_locked_active   = "rgb(e5c18d)",
            border_locked_inactive = "rgb(524343)",
        },
        groupbar = {
            col = {
                active           = "rgb(ffb3b4)",
                inactive         = "rgb(524343)",
                locked_active    = "rgb(e5c18d)",
                locked_inactive  = "rgb(524343)",
            },
        },
    },
})