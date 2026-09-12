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
            active_border   = "rgb(afd18c)",
            inactive_border = "rgb(44483e)",
        },
    },

    -- ======================================================
    -- 📑 Window Groups (Tabbed Mode)
    -- Accent states for grouped containers and title bars.
    -- ======================================================
    group = {
        -- Container border colors
        col = {
            border_active          = "rgb(afd18c)",
            border_inactive        = "rgb(44483e)",
            border_locked_active   = "rgb(a0cfcd)",
            border_locked_inactive = "rgb(44483e)",
        },

        -- Top tab indicator / titlebar colors
        groupbar = {
            col = {
                active          = "rgb(afd18c)",
                inactive        = "rgb(44483e)",
                locked_active   = "rgb(a0cfcd)",
                locked_inactive = "rgb(44483e)",
            },
        },
    },
})