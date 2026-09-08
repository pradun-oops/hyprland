#!/usr/bin/env bash
set -euo pipefail

DIALOG_NAME="${1:-spotlight}"
ACTION="${2:-open}"

: "${HYPRLAND_INSTANCE_SIGNATURE:=$(ls -t /tmp/hypr/ 2>/dev/null | head -n 1)}"
export HYPRLAND_INSTANCE_SIGNATURE
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

BASE_DIR="$HOME/.config/hypr/quickshell"
TARGET_PATH="$([[ "$DIALOG_NAME" == /* ]] && echo "$DIALOG_NAME" || echo "$BASE_DIR/$DIALOG_NAME")"

[[ -e "$TARGET_PATH" ]] || { echo "Error: Widget '$DIALOG_NAME' not found" >&2; exit 1; }
CONFIG_PATH=$(realpath "$TARGET_PATH")

PID=$(pgrep -u "$USER" -f "quickshell.*$CONFIG_PATH" | grep -vE "^($$|$PPID)$" | head -n 1 || true)
if [[ -z "$PID" ]]; then
    SHORT_PATH="${TARGET_PATH/#$HOME/\~}"
    PID=$(pgrep -u "$USER" -f "quickshell.*$SHORT_PATH" | grep -vE "^($$|$PPID)$" | head -n 1 || true)
fi

spawn_dialog() {
    if [[ -d "$CONFIG_PATH" ]]; then
        nohup quickshell -c "$CONFIG_PATH" >/dev/null 2>&1 &
    else
        nohup quickshell -p "$CONFIG_PATH" >/dev/null 2>&1 &
    fi
}

case "$ACTION" in
    open)   [[ -z "$PID" ]] && spawn_dialog ;;
    close)  [[ -n "$PID" ]] && kill "$PID" ;;
    toggle) [[ -n "$PID" ]] && kill "$PID" || spawn_dialog ;;
    *)      echo "Usage: $0 <dialog_name_or_path> [action: open|toggle|close]" >&2; exit 1 ;;
esac