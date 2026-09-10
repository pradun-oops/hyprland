#!/usr/bin/env bash

# ==========================================================
# 🪟 Smart Floating Window Toggle (toggle_float.sh)
# Toggles floating state for the active window via custom Lua
# dispatchers, setting default dimensions and centering when floated.
# ==========================================================

# ==========================================================
# 🔍 Window State Check & Dispatch Logic
# Checks active window properties via hyprctl to detect
# if the current focused window is currently tiled (floating: 0).
# ==========================================================
if hyprctl activewindow | grep -q "floating: 0"; then
    # ------------------------------------------------------
    # ↗️ Transition: Tiled -> Floating
    # Enable float mode, apply preset dimensions (1500x900), and center
    # ------------------------------------------------------
    hyprctl dispatch 'hl.dsp.window.float({ action = "toggle" })'
    hyprctl dispatch 'hl.dsp.window.resize({ x = 1500, y = 900 })'
    hyprctl dispatch 'hl.dsp.window.center()'
else
    # ------------------------------------------------------
    # ↘️ Transition: Floating -> Tiled
    # Snap the window back into the tiling/scrolling layout
    # ------------------------------------------------------
    hyprctl dispatch 'hl.dsp.window.float({ action = "toggle" })'
fi