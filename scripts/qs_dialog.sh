#!/usr/bin/env bash

# Dynamic Quickshell Dialog Manager Script
# Usage: ./qs_dialog.sh <dialog_name_or_path> [action: open|toggle|close]
# Example: ./qs_dialog.sh notification open
# Example: ./qs_dialog.sh notification-history toggle

DIALOG_NAME="${1:-spotlight}"
ACTION="${2:-open}"

# Base directory for all Quickshell widgets
BASE_DIR="$HOME/.config/hypr/quickshell"

# 1. Resolve Target Path (Supports full path or widget folder name)
if [[ "$DIALOG_NAME" == /* ]]; then
    TARGET_PATH="$DIALOG_NAME"
else
    TARGET_PATH="$BASE_DIR/$DIALOG_NAME"
fi

# Verify widget folder or file exists
if [ ! -e "$TARGET_PATH" ]; then
    echo "Error: Widget '$DIALOG_NAME' not found in $BASE_DIR" >&2
    exit 1
fi

# Get canonical absolute path (resolves symlinks)
CONFIG_PATH=$(realpath "$TARGET_PATH")

# 2. Locate running process specifically for this widget
PID=$(pgrep -u "$USER" -f "quickshell.*$CONFIG_PATH" | grep -v "^$$$" | grep -v "^$PPID$" | head -n 1)

# Fallback process search in case it was launched with standard ~ notation
if [ -z "$PID" ]; then
    SHORT_PATH="${TARGET_PATH/#$HOME/\~}"
    PID=$(pgrep -u "$USER" -f "quickshell.*$SHORT_PATH" | grep -v "^$$$" | grep -v "^$PPID$" | head -n 1)
fi

# 3. Handle Actions
case "$ACTION" in
    open)
        if [ -z "$PID" ]; then
            quickshell -c "$CONFIG_PATH" &
        fi
        ;;
    close)
        if [ -n "$PID" ]; then
            kill "$PID"
        fi
        ;;
    toggle)
        if [ -n "$PID" ]; then
            kill "$PID"
        else
            quickshell -c "$CONFIG_PATH" &
        fi
        ;;
    *)
        echo "Usage: $0 <dialog_name_or_path> [action: open|toggle|close]"
        exit 1
        ;;
esac