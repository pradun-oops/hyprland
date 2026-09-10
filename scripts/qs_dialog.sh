#!/usr/bin/env bash

# ==========================================================
# 🚀 Quickshell Dialog & Widget Manager (qs_dialog.sh)
# Handles lifecycle controls (open, close, toggle) for standalone 
# Quickshell components, dialogs, and OSD windows.
# ==========================================================

set -euo pipefail

# ==========================================================
# 📥 CLI Arguments & Default Fallbacks
# ==========================================================
DIALOG_NAME="${1:-spotlight}"   # Widget folder or file name
ACTION="${2:-open}"             # Target action: open | close | toggle

# ==========================================================
# 🌐 Wayland & Hyprland Environment Setup
# Guarantees runtime socket discovery even when invoked via hotkeys.
# ==========================================================
: "${HYPRLAND_INSTANCE_SIGNATURE:=$(ls -t /tmp/hypr/ 2>/dev/null | head -n 1)}"
export HYPRLAND_INSTANCE_SIGNATURE
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

# ==========================================================
# 🔍 Widget Path Resolution & Validation
# Supports both relative widget names and absolute filesystem paths.
# ==========================================================
BASE_DIR="$HOME/.config/hypr/quickshell"
TARGET_PATH="$([[ "$DIALOG_NAME" == /* ]] && echo "$DIALOG_NAME" || echo "$BASE_DIR/$DIALOG_NAME")"

# Guard: Ensure the requested widget directory or file exists
[[ -e "$TARGET_PATH" ]] || { echo "Error: Widget '$DIALOG_NAME' not found" >&2; exit 1; }
CONFIG_PATH=$(realpath "$TARGET_PATH")

# ==========================================================
# 🔎 Active Process Discovery
# Finds running PID by matching full path or tilde (~)-expanded path,
# filtering out subshells and parent processes.
# ==========================================================
PID=$(pgrep -u "$USER" -f "quickshell.*$CONFIG_PATH" | grep -vE "^($$|$PPID)$" | head -n 1 || true)
if [[ -z "$PID" ]]; then
    SHORT_PATH="${TARGET_PATH/#$HOME/\~}"
    PID=$(pgrep -u "$USER" -f "quickshell.*$SHORT_PATH" | grep -vE "^($$|$PPID)$" | head -n 1 || true)
fi

# ==========================================================
# ⚡ Background Launch Helper
# Launches detached Quickshell instance (-c for dirs, -p for single files).
# ==========================================================
spawn_dialog() {
    if [[ -d "$CONFIG_PATH" ]]; then
        nohup quickshell -c "$CONFIG_PATH" >/dev/null 2>&1 &
    else
        nohup quickshell -p "$CONFIG_PATH" >/dev/null 2>&1 &
    fi
}

# ==========================================================
# 🎮 Lifecycle Dispatcher (Open / Close / Toggle)
# ==========================================================
case "$ACTION" in
    open)   
        [[ -z "$PID" ]] && spawn_dialog 
        ;;
    close)  
        [[ -n "$PID" ]] && kill "$PID" 
        ;;
    toggle) 
        [[ -n "$PID" ]] && kill "$PID" || spawn_dialog 
        ;;
    *)      
        echo "Usage: $0 <dialog_name_or_path> [action: open|toggle|close]" >&2
        exit 1 
        ;;
esac