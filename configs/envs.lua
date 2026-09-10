-- ==========================================================
-- 🌐 Desktop Environment & Wayland Session
-- Identifies the compositor and session type for xdg-desktop-portal
-- and application menu integration.
-- ==========================================================
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_MENU_PREFIX", "gnome-")

-- ==========================================================
-- 🎨 Qt Application Integration & Theming
-- Configures Qt apps to render natively on Wayland with proper
-- scaling, qt6ct styling, and seamless window borders.
-- ==========================================================
-- Theme provider & platform engine (fall back to XWayland if needed)
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")

-- Window appearance & display scaling
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")

-- ==========================================================
-- ⚡ NVIDIA Graphics & Hardware Acceleration
-- Forces hardware rendering, VA-API hardware video decoding,
-- and direct buffer allocation on the dedicated NVIDIA GPU.
-- ==========================================================
-- Direct Rendering Manager (DRM) & GLX provider
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")

-- Hardware video acceleration (VA-API / libva-vdpau-driver)
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("NVD_BACKEND", "direct")