-- ==========================================================
-- ⚙️ Hyprland Core Compositor & Aesthetics Configuration
-- Manages window layout rules, visual decorations, blur,
-- drop shadows, and layout engine defaults.
-- ==========================================================
hl.config({
    -- ======================================================
    -- 📐 General Window Spacing & Layout
    -- Defines tile gaps, border thickness, and active layout engine.
    -- ======================================================
    general = {
        gaps_in       = 5,          -- Inner spacing between adjacent windows
        gaps_out      = 5,          -- Outer spacing between windows and screen edge
        border_size   = 2,          -- Window border line thickness (px)
        layout        = "scrolling",-- Active layout engine (PaperWM-style scrolling)
        allow_tearing = false,      -- Prevent screen tearing (ideal for non-gaming apps)
    },

    -- ======================================================
    -- 📜 Scrolling Layout Parameters
    -- Configuration specific to the scrolling/column workspace flow.
    -- ======================================================
    scrolling = {
        column_width             = 0.5,   -- Default column width (50% of screen)
        direction                = "right",-- Direction new columns expand toward
        fullscreen_on_one_column = true,  -- Auto-fit to screen when only 1 column exists
    },

    -- ======================================================
    -- ✨ Visual Decorations (Opacity, Blur & Shadows)
    -- Controls corner rounding, translucency, and frosted glass.
    -- ======================================================
    decoration = {
        rounding           = 15,    -- Corner radius for smooth rounded windows
        active_opacity     = 0.80,  -- Opacity of currently focused window
        inactive_opacity   = 0.80,  -- Opacity of background windows
        fullscreen_opacity = 1.0,   -- Solid opacity when viewing fullscreen apps

        -- Frosted glass backdrop blur
        blur = {
            enabled           = true,
            size              = 5,   -- Blur radius / spread
            passes            = 3,   -- Number of sampling passes (smoother blur)
            ignore_opacity    = true,-- Blurs background regardless of window alpha
            new_optimizations = true,-- Caches blur textures for reduced GPU overhead
            xray              = false,
            contrast          = 1.0,
            brightness        = 1.0,
            vibrancy          = 0.2, -- Saturation boost underneath blurred surfaces
            vibrancy_darkness = 0.0,
        },

        -- Soft window drop shadows
        shadow = {
            enabled      = true,
            range        = 15,
            render_power = 3,
            offset       = "0 5",             -- Vertical shadow drop (x=0, y=5)
            color        = "rgba(00000044)",  -- Subtle black shadow with alpha
        },
    },

    -- ======================================================
    -- 🖥️ Renderer Tuning
    -- Low-level surface rendering toggles.
    -- ======================================================
    render = {
        direct_scanout = false, -- Avoid full bypass to keep compositor effects stable
    },

    -- ======================================================
    -- 🔀 Dwindle Layout Fallback
    -- Settings preserved if switching to the standard dwindle tree.
    -- ======================================================
    dwindle = {
        preserve_split = true, -- Retain split orientation when closing tiles
    },

    -- ======================================================
    -- 📑 Master Layout Fallback
    -- Settings preserved if switching to master-stack mode.
    -- ======================================================
    master = {
        mfact = 0.5, -- Master window width split ratio
    },
})