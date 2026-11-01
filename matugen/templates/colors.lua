hl.config({
    general = {
        col = {
            active_border   = "rgb({{colors.primary.default.hex_stripped}})",
            inactive_border = "rgba({{colors.surface_variant.default.hex_stripped}}aa)",
        },
    },
    group = {
        col = {
            border_active          = "rgb({{colors.primary.default.hex_stripped}})",
            border_inactive        = "rgba({{colors.surface_variant.default.hex_stripped}}aa)",
            border_locked_active   = "rgb({{colors.tertiary.default.hex_stripped}})",
            border_locked_inactive = "rgba({{colors.surface_variant.default.hex_stripped}}aa)",
        },
        groupbar = {
            col = {
                active           = "rgb({{colors.primary.default.hex_stripped}})",
                inactive         = "rgba({{colors.surface_variant.default.hex_stripped}}aa)",
                locked_active    = "rgb({{colors.tertiary.default.hex_stripped}})",
                locked_inactive  = "rgba({{colors.surface_variant.default.hex_stripped}}aa)",
            },
        },
    },
})