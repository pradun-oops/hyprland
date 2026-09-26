--- @diagnostic disable: undefined-global

-- ============================================================================
-- ⚙️ HYPRLAND CORE COMPOSITOR & AESTHETICS CONFIGURATION
-- ============================================================================
-- Manages window layout rules, visual decorations, blur parameters, 
-- drop shadows, rendering flags, and scrolling layout engine defaults.
-- ============================================================================

hl.config({
    -- ========================================================================
    -- 📐 GENERAL WINDOW SPACING & LAYOUT
    -- ========================================================================
    -- Defines tile gaps, border thickness, layout engine, and tearing behavior.
    general = {
        gaps_in       = 5,             -- Inner spacing between adjacent windows
        gaps_out      = 5,             -- Outer spacing between windows and screen edges
        border_size   = 2,             -- Window border line thickness (px)
        layout        = "scrolling",   -- Active layout engine (PaperWM-style scrolling flow)
        allow_tearing = false,         -- Prevent screen tearing (ideal for non-gaming stability)
    },

    -- ========================================================================
    -- 📜 SCROLLING LAYOUT PARAMETERS
    -- ========================================================================
    -- Configuration specific to your scrolling/column workspace workflow.
    scrolling = {
        column_width             = 0.5,     -- Default column width (50% of the screen width)
        direction                = "right", -- Direction new columns expand toward
        fullscreen_on_one_column = true,    -- Auto-fit to screen when only a single column exists
    },

    -- ========================================================================
    -- ✨ VISUAL DECORATIONS (OPACITY, BLUR & SHADOWS)
    -- ========================================================================
    -- Controls corner rounding, translucency, frosted glass effects, and depth shadows.
    decoration = {
        rounding           = 15,   -- Corner radius for smooth rounded window frames
        active_opacity     = 0.85, -- Translucency level of currently focused window
        inactive_opacity   = 0.85, -- Translucency level of background/unfocused windows
        fullscreen_opacity = 1.0,  -- Solid 100% opacity when viewing fullscreen applications

        -- Frosted glass backdrop blur (optimized for Wayland rendering)
        blur = {
            enabled           = true,
            size              = 6,       -- Blur radius / spread size
            passes            = 3,       -- Number of sampling passes for a smoother frosted look
            ignore_opacity    = true,    -- Blurs background regardless of individual window alpha
            new_optimizations = true,    -- Caches blur textures for reduced GPU overhead
            xray              = false,
            contrast          = 1.0,
            brightness        = 1.0,
            vibrancy          = 0.2,     -- Saturation boost underneath blurred surfaces
            vibrancy_darkness = 0.0,
        },

        -- Soft window drop shadows for layered depth
        shadow = {
            enabled      = true,
            range        = 15,
            render_power = 3,
            offset       = "0 5",            -- Vertical shadow drop offset (x=0, y=5)
            color        = "rgba(00000044)", -- Subtle black shadow with alpha transparency
        },
    },

    -- ========================================================================
    -- 🖥️ RENDERER TUNING
    -- ========================================================================
    -- Low-level surface rendering toggles.
    render = {
        direct_scanout = false, -- Avoid full bypass to keep custom compositor effects stable
    },

    -- ========================================================================
    -- 🔀 LAYOUT FALLBACKS (DWINDLE & MASTER)
    -- ========================================================================
    -- Settings preserved in case of temporarily disabling the scrolling plugin.
    dwindle = {
        preserve_split = true, -- Retain split orientation when closing tiles
    },

    master = {
        mfact = 0.5,           -- Master window width split ratio
    },
})