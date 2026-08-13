hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 5,
        border_size = 2,
        layout = "scrolling",
        allow_tearing = false,
    },
    decoration = {
        rounding = 12,
        active_opacity = 0.85,
        inactive_opacity = 0.85,
        fullscreen_opacity = 1.0,
        blur = {
            enabled = true,
            size = 6,
            passes = 3,
            ignore_opacity = true,
            new_optimizations = true,
            xray = false,
            contrast = 1.0,
            brightness = 1.0,
            vibrancy = 0.2,
            vibrancy_darkness = 0.0,
        },
        shadow = {
            enabled = true,
            range = 15,
            render_power = 3,
            offset = "0 5",
            color = "rgba(00000044)",
        },
    },
    render = {
        direct_scanout = false,
    },
    dwindle = {
        preserve_split = true,
    },
    master = {
        mfact = 0.5,
    },
})