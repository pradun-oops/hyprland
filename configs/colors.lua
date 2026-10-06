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
            active_border   = "rgb(abd290)",
            inactive_border = "rgb(43483e)",
        },
    },

    -- ========================================================================
    -- 📦 WINDOW GROUPING & GROUPBAR THEME COLORS
    -- ========================================================================
    -- Controls border styling for tabbed/grouped windows and their titlebars.
    group = {
        col = {
            border_active          = "rgb(abd290)",
            border_inactive        = "rgb(43483e)",
            border_locked_active   = "rgb(a0cfcf)",
            border_locked_inactive = "rgb(43483e)",
        },
        groupbar = {
            col = {
                active           = "rgb(abd290)",
                inactive         = "rgb(43483e)",
                locked_active    = "rgb(a0cfcf)",
                locked_inactive  = "rgb(43483e)",
            },
        },
    },
})