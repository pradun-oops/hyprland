--- @diagnostic disable: undefined-global

-- ============================================================================
-- 🛠️ MISCELLANEOUS & DEBUG CONFIGURATION
-- ============================================================================
-- Manages compositor runtime behavior, power management triggers, window 
-- swallowing rules, rendering flags, and debugging options.
-- ============================================================================

hl.config({
    -- ========================================================================
    -- ⚙️ COMPOSITOR MISCELLANEOUS BEHAVIOR
    -- ========================================================================
    -- Fine-tunes user experience interactions, window swallowing, and display sleep logic.
    misc = {
        -- Adaptive Sync / Variable Refresh Rate (0 = off, 1 = on, 2 = fullscreen only)
        vrr                         = 0,

        -- Smooth window geometry transitions during manual user adjustments
        animate_manual_resizes      = true,
        animate_mouse_windowdragging = true,

        -- Focus management & workspace tracking
        focus_on_activate           = true, -- Shift focus when an app demands attention
        initial_workspace_tracking  = 1,    -- Open new apps on the workspace they were called from

        -- Window swallowing (embed GUI apps launched from your terminal emulator)
        enable_swallow              = true,
        swallow_regex               = "^(org\\.wezfurlong\\.wezterm|kitty)$",

        -- Branding & default splashes
        force_default_wallpaper     = 0,    -- 0 = disable default anime/stock wallpapers
        disable_hyprland_logo       = true, -- Suppress default Hyprland watermark
        disable_splash_rendering    = true, -- Hide splash text on blank workspaces

        -- Wake from DPMS (screen sleep triggers)
        mouse_move_enables_dpms     = true, -- Wake monitor on cursor motion
        key_press_enables_dpms      = true, -- Wake monitor on keypress

        -- Selection clipboard behavior
        middle_click_paste          = true, -- Paste primary selection on middle mouse click
    },

    -- ========================================================================
    -- 🐞 DEBUGGING & REFRESH CONTROLS
    -- ========================================================================
    -- Low-level compositor frame timing and diagnostic options.
    debug = {
        -- Variable Frame Rate (false = render at fixed display refresh rate)
        vfr = false,
    },
})