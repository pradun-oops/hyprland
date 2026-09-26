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
            active_border   = "rgb(f6b2df)",
            inactive_border = "rgb(4f444a)",
        },
    },

    -- ========================================================================
    -- 📦 WINDOW GROUPING & GROUPBAR THEME COLORS
    -- ========================================================================
    -- Controls border styling for tabbed/grouped windows and their titlebars.
    group = {
        col = {
            border_active          = "rgb(f6b2df)",
            border_inactive        = "rgb(4f444a)",
            border_locked_active   = "rgb(f5b9a1)",
            border_locked_inactive = "rgb(4f444a)",
        },
        groupbar = {
            col = {
                active           = "rgb(f6b2df)",
                inactive         = "rgb(4f444a)",
                locked_active    = "rgb(f5b9a1)",
                locked_inactive  = "rgb(4f444a)",
            },
        },
    },
})