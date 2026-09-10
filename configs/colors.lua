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
            active_border   = "rgb(a2d398)",
            inactive_border = "rgb(42493f)",
        },
    },

    -- ======================================================
    -- 📑 Window Groups (Tabbed Mode)
    -- Accent states for grouped containers and title bars.
    -- ======================================================
    group = {
        -- Container border colors
        col = {
            border_active          = "rgb(a2d398)",
            border_inactive        = "rgb(42493f)",
            border_locked_active   = "rgb(a0cfd3)",
            border_locked_inactive = "rgb(42493f)",
        },

        -- Top tab indicator / titlebar colors
        groupbar = {
            col = {
                active          = "rgb(a2d398)",
                inactive        = "rgb(42493f)",
                locked_active   = "rgb(a0cfd3)",
                locked_inactive = "rgb(42493f)",
            },
        },
    },
})