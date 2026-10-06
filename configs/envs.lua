--- @diagnostic disable: undefined-global

-- ============================================================================
-- 🌐 ENVIRONMENT VARIABLES & SESSION CONFIGURATION
-- ============================================================================
-- Configures desktop environment identifiers, GTK/Libadwaita theming, Qt
-- application integration, and hardware acceleration overrides for your NVIDIA GPU.
-- ============================================================================


-- ============================================================================
-- 🖥️ DESKTOP ENVIRONMENT & WAYLAND SESSION
-- ============================================================================
-- Identifies the compositor and session type for xdg-desktop-portal and app menus.
hl.env("XDG_SESSION_TYPE",                    "wayland")
hl.env("XDG_CURRENT_DESKTOP",                 "Hyprland")
hl.env("XDG_SESSION_DESKTOP",                 "Hyprland")
hl.env("XDG_MENU_PREFIX",                     "gnome-")


-- ============================================================================
-- 🎨 GTK & LIBADWAITA THEMING (DARK MODE OVERRIDES)
-- ============================================================================
-- Forces GTK3, GTK4, and Libadwaita applications into Dark Mode and handles
-- proper backend/renderer routing for NVIDIA GPUs.
hl.env("GDK_BACKEND",                         "wayland,x11,*")
-- NOTE: GTK_THEME intentionally omitted. Forcing a GTK3 theme breaks GTK4/Libadwaita apps.
hl.env("ADW_DISABLE_PORTAL",                  "1")
hl.env("GSK_RENDERER",                        "ngl")


-- ============================================================================
-- 🎨 QT APPLICATION INTEGRATION & THEMING
-- ============================================================================
-- Configures Qt apps to render natively on Wayland with proper scaling,
-- qt6ct styling, and window border management.
hl.env("QT_QPA_PLATFORMTHEME",                "qt6ct")
hl.env("QT_QPA_PLATFORM",                     "wayland;xcb")

-- Window appearance & display scaling
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR",         "1")


-- ============================================================================
-- ⚡ NVIDIA GRAPHICS & HARDWARE ACCELERATION
-- ============================================================================
-- Forces hardware rendering, VA-API video decoding, and direct buffer 
-- allocation on your dedicated NVIDIA RTX 3050 graphics card.
hl.env("GBM_BACKEND",                         "nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME",           "nvidia")

-- Hardware video acceleration (VA-API / libva-vdpau-driver)
hl.env("LIBVA_DRIVER_NAME",                   "nvidia")
hl.env("NVD_BACKEND",                         "direct")