#!/usr/bin/env bash

if hyprctl activewindow | grep -q "floating: 0"; then
    hyprctl dispatch 'hl.dsp.window.float({ action = "toggle" })'
    hyprctl dispatch 'hl.dsp.window.resize({ x = 1500, y = 900 })'
    hyprctl dispatch 'hl.dsp.window.center()'
else
    hyprctl dispatch 'hl.dsp.window.float({ action = "toggle" })'
fi