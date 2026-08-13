#!/usr/bin/env bash

set -euo pipefail

STATE_FILE="/tmp/rgb_power_state"
CONFIG_FILE="$HOME/.config/hypr/dms/colors.conf"
BRIGHTNESS=2

usage() {
    echo "Usage: $0 {0-18}"
    echo
    echo "0  = Adaptive DMS theme color"
    echo "1  = Matrix Green"
    echo "2  = Cyber Blue"
    echo "3  = Hacker Red"
    echo "4  = Neon Cyan/Magenta"
    echo "5  = RGB Classic"
    echo "6  = Sunset Fire"
    echo "7  = Ocean Wave"
    echo "8  = Breathing Green"
    echo "9  = Rainbow Hue"  
}

get_theme_color() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "ffffff"
        return
    fi

    HEX_COLOR="$(
        grep -m 1 -E '^\s*\$primary\s*=' "$CONFIG_FILE" \
            | sed -n 's/.*rgb(\([0-9a-fA-F]\{6\}\)).*/\1/p' \
            | tr -d '[:space:]'
    )"

    if [[ "$HEX_COLOR" =~ ^[0-9a-fA-F]{6}$ ]]; then
        echo "$HEX_COLOR"
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

command -v legionaura >/dev/null 2>&1 || {
    echo "Error: legionaura not found"
    exit 1
}

STATE="$(cat "$STATE_FILE" 2>/dev/null || echo 0)"

if [ "$STATE" != "1" ]; then
    exit 0
fi

PRESET="${1:-}"

case "$PRESET" in
    0)
        THEME_COLOR="$(get_theme_color)"
        apply_static "$THEME_COLOR" "$THEME_COLOR" "$THEME_COLOR" "$THEME_COLOR"
        ;;

    1)
        apply_static 00ff44 00cc33 00ff88 00aa22
        ;;

    2)
        apply_static 0077ff 00ccff 0044ff 00ffff
        ;;

    3)
        apply_static ff0033 cc0000 ff4444 990000
        ;;

    4)
        apply_static 00ffff ff00ff 00aaff ff44cc
        ;;

    5)
        apply_static ff0000 00ff00 0000ff ffff00
        ;;

    6)
        apply_static ff2200 ff6600 ffaa00 ffff00
        ;;

    7)
        apply_effect wave ltr --speed 2
        ;;

    8)
        apply_effect breath 00ff88 --speed 2
        ;;

    9)
        apply_effect hue --speed 2
        ;;   

    *)
        usage
        exit 1
        ;;
esac