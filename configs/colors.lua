-- ==========================================================
-- 🎨 Dynamic Color Theming Configuration
-- Injects Material / System palette colors into window borders 
-- and tabbed window groups.
-- ==========================================================
hl.config({
    -- ======================================================
    -- 🪟 General Window Borders
    -- Default outline colors for focused and unfocused windows.
    -- ======================================================
    general = {
        col = {
            active_border   = "rgb(9dcbfc)",
            inactive_border = "rgb(42474e)",
        },
    },

    -- ======================================================
    -- 📑 Window Groups (Tabbed Mode)
    -- Accent states for grouped containers and title bars.
    -- ======================================================
    group = {
        -- Container border colors
        col = {
            border_active          = "rgb(9dcbfc)",
            border_inactive        = "rgb(42474e)",
            border_locked_active   = "rgb(d4bee6)",
            border_locked_inactive = "rgb(42474e)",
        },

        -- Top tab indicator / titlebar colors
        groupbar = {
            col = {
                active          = "rgb(9dcbfc)",
                inactive        = "rgb(42474e)",
                locked_active   = "rgb(d4bee6)",
                locked_inactive = "rgb(42474e)",
            },
        },
    },
})