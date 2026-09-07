hl.config({
    general = {
        col = {
            active_border = "rgb({{colors.primary.default.hex_stripped}})",
            inactive_border = "rgb({{colors.surface_variant.default.hex_stripped}})",
        },
    },
    group = {
        col = {
            border_active = "rgb({{colors.primary.default.hex_stripped}})",
            border_inactive = "rgb({{colors.surface_variant.default.hex_stripped}})",
            border_locked_active = "rgb({{colors.tertiary.default.hex_stripped}})",
            border_locked_inactive = "rgb({{colors.surface_variant.default.hex_stripped}})",
        },
        groupbar = {
            col = {
                active = "rgb({{colors.primary.default.hex_stripped}})",
                inactive = "rgb({{colors.surface_variant.default.hex_stripped}})",
                locked_active = "rgb({{colors.tertiary.default.hex_stripped}})",
                locked_inactive = "rgb({{colors.surface_variant.default.hex_stripped}})",
            },
        },
    },
})
