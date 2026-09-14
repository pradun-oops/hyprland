--- @diagnostic disable: undefined-global

-- ============================================================================
-- ⌨️ & 🖱️ INPUT DEVICE CONFIGURATION
-- ============================================================================
-- Manages keyboard typing response, mouse pointer behavior, flat acceleration 
-- profiles, trackpad ergonomics, and multi-touch workspace gestures.
-- ============================================================================

hl.config({
    input = {
        -- ========================================================================
        -- ⌨️ KEYBOARD SETTINGS
        -- ========================================================================
        -- Snappy, low-latency repeat rates tuned for rapid coding and navigation.
        kb_layout          = "us",    -- Standard US English layout
        numlock_by_default = false,   -- Keep numlock off upon boot
        repeat_rate        = 50,      -- Key repeats per second while holding down
        repeat_delay       = 200,     -- Milliseconds before repeat begins (ultra responsive)

        -- ========================================================================
        -- 🎯 MOUSE & POINTER BEHAVIOR
        -- ========================================================================
        -- Raw 1:1 input without hardware acceleration for precise muscle memory.
        follow_mouse       = 1,       -- Window focus follows cursor movement
        mouse_refocus      = false,   -- Don't steal focus unless mouse actually crosses borders
        sensitivity        = 0,       -- Flat multiplier (0 = default driver speed)
        accel_profile      = "flat",  -- Disables acceleration curves for consistent precision

        -- ========================================================================
        -- 💻 LAPTOP TRACKPAD ERGONOMICS
        -- ========================================================================
        -- Natural scrolling, tap-to-click, and active palm rejection for your Lenovo setup.
        touchpad = {
            tap_to_click             = true,   -- Tap trackpad surface to left-click
            natural_scroll           = true,   -- Inverted scroll direction (macOS / mobile style)
            tap_and_drag             = true,   -- Double-tap and hold to drag windows/text
            drag_lock                = true,   -- Prevents drop if finger briefly lifts while dragging
            disable_while_typing     = true,   -- Active palm rejection while typing
            scroll_factor            = 0.5,    -- Fine-tuned scroll speed sensitivity
            clickfinger_behavior     = true,   -- 2-finger click = right click, 3-finger = middle click
            middle_button_emulation  = false,  -- Disable simultaneous left+right click middle-click
        },
    },
})

-- ============================================================================
-- 🖐️ MULTI-TOUCH GESTURES
-- ============================================================================
-- Enables fluid 1:1 trackpad workspace swapping.
-- ============================================================================
hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})