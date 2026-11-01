#!/usr/bin/env bash

set -euo pipefail

STATE_FILE="/tmp/rgb_power_state"
CONFIG_FILE="$HOME/.config/hypr/configs/colors.lua"
BRIGHTNESS=2

usage() {
    echo "Usage: $0 {0-9}"
    echo "0 = Adaptive Matugen Theme"
    echo "1 = Matrix Green"
    echo "2 = Cyber Blue"
    echo "3 = Red Alert"
    echo "4 = Synthwave"
    echo "5 = RGB Primary"
    echo "6 = Fire Warning"
    echo "7 = RGB Wave"
    echo "8 = Breathing Green"
    echo "9 = Hue Cycle"
    exit 1
}

get_theme_color() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "ffffff"
        return
    fi

    local hex_color
    hex_color=$(sed -nE 's/.*active_border.*rgb\(([0-9a-fA-F]{6})\).*/\1/p' "$CONFIG_FILE" | head -n 1)

    if [[ "$hex_color" =~ ^[0-9a-fA-F]{6}$ ]]; then
        echo "$hex_color"
    else
        echo "ffffff"
    fi
}

apply_static() {
    legionaura static "$@" --brightness "$BRIGHTNESS"
}

apply_effect() {
    legionaura "$@" --brightness "$BRIGHTNESS"
}

if ! command -v legionaura >/dev/null 2>&1; then
    echo "Error: legionaura not found." >&2
    exit 1
fi

if [[ ! -f "$STATE_FILE" ]]; then
    echo "1" > "$STATE_FILE"
fi

STATE=$(tr -d '[:space:]' < "$STATE_FILE" 2>/dev/null || echo "0")

if [[ "$STATE" != "1" ]]; then
    exit 0
fi

PRESET="${1:-0}"

case "$PRESET" in
    0)
        THEME_COLOR=$(get_theme_color)
        apply_static "$THEME_COLOR" "$THEME_COLOR" "$THEME_COLOR" "$THEME_COLOR"
        ;;
    1) apply_static 00ff44 00cc33 00ff88 00aa22 ;;
    2) apply_static 0077ff 00ccff 0044ff 00ffff ;;
    3) apply_static ff0033 cc0000 ff4444 990000 ;;
    4) apply_static 00ffff ff00ff 00aaff ff44cc ;;
    5) apply_static ff0000 00ff00 0000ff ffff00 ;;
    6) apply_static ff2200 ff6600 ffaa00 ffff00 ;;
    7) apply_effect wave ltr --speed 2 ;;
    8) apply_effect breath 00ff88 --speed 2 ;;
    9) apply_effect hue --speed 2 ;;
    *) usage ;;
esac