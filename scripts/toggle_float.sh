#!/usr/bin/env bash

set -euo pipefail

if ! command -v hyprctl >/dev/null 2>&1; then
    exit 1
fi

ACTIVE_WINDOW="$(hyprctl activewindow 2>/dev/null || true)"

if [[ -z "$ACTIVE_WINDOW" ]]; then
    exit 0
fi

if echo "$ACTIVE_WINDOW" | grep -qE '^[[:space:]]*floating:[[:space:]]*0'; then
    hyprctl dispatch 'hl.dsp.window.float({ action = "toggle" })'
    hyprctl dispatch 'hl.dsp.window.resize({ x = 1500, y = 900 })'
    hyprctl dispatch 'hl.dsp.window.center()'
else
    hyprctl dispatch 'hl.dsp.window.float({ action = "toggle" })'
fi