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
            active_border   = "rgb({{colors.primary.default.hex_stripped}})",
            inactive_border = "rgb({{colors.surface_variant.default.hex_stripped}})",
        },
    },

    -- ========================================================================
    -- 📦 WINDOW GROUPING & GROUPBAR THEME COLORS
    -- ========================================================================
    -- Controls border styling for tabbed/grouped windows and their titlebars.
    group = {
        col = {
            border_active          = "rgb({{colors.primary.default.hex_stripped}})",
            border_inactive        = "rgb({{colors.surface_variant.default.hex_stripped}})",
            border_locked_active   = "rgb({{colors.tertiary.default.hex_stripped}})",
            border_locked_inactive = "rgb({{colors.surface_variant.default.hex_stripped}})",
        },
        groupbar = {
            col = {
                active           = "rgb({{colors.primary.default.hex_stripped}})",
                inactive         = "rgb({{colors.surface_variant.default.hex_stripped}})",
                locked_active    = "rgb({{colors.tertiary.default.hex_stripped}})",
                locked_inactive  = "rgb({{colors.surface_variant.default.hex_stripped}})",
            },
        },
    },
})