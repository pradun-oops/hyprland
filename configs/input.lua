-- ==========================================================
-- ⌨️ & 🖱️ Input Device Configuration
-- Manages keyboard typing response, mouse pointer behavior,
-- trackpad ergonomics, and touchpad gestures.
-- ==========================================================
hl.config({
    input = {
        -- ==================================================
        -- ⌨️ Keyboard Settings
        -- Snappy repeat rates tuned for coding and navigation.
        -- ==================================================
        kb_layout          = "us",    -- Standard US English layout
        numlock_by_default = false,   -- Keep numlock off upon boot
        repeat_rate        = 50,      -- Key repeats per second while holding down
        repeat_delay       = 200,     -- Milliseconds before repeat begins (ultra responsive)

        -- ==================================================
        -- 🎯 Mouse & Pointer Behavior
        -- Raw 1:1 input without hardware acceleration.
        -- ==================================================
        follow_mouse       = 1,       -- Window focus follows cursor movement
        mouse_refocus      = false,   -- Don't steal focus unless mouse actually crosses borders
        sensitivity        = 0,       -- Flat multiplier (0 = default driver speed)
        accel_profile      = "flat",  -- Disables acceleration curves for consistent muscle memory

        -- ==================================================
        -- 💻 Laptop Trackpad
        -- Natural scrolling, tap-to-click, and palm rejection.
        -- ==================================================
        touchpad = {
            tap_to_click             = true,   -- Tap trackpad surface to left-click
            natural_scroll           = true,   -- Inverted scroll direction (macOS / mobile style)
            tap_and_drag             = true,   -- Double-tap and hold to drag windows/text
            drag_lock                = true,   -- Prevents drop if finger briefly lifts while dragging
            disable_while_typing     = true,   -- Palm rejection while actively typing
            scroll_factor            = 0.5,    -- Fine-tuned scroll speed sensitivity
            clickfinger_behavior     = true,   -- 2-finger click = right click, 3-finger = middle click
            middle_button_emulation  = false,  -- Disable simultaneous left+right click middle-click
        },
    },
})

-- ==========================================================
-- 🖐️ Multi-Touch Gestures
-- Enables 1:1 trackpad workspace swapping.
-- ==========================================================
-- Swipe 3 fingers left/right to switch workspaces smoothly
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })