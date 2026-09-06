#!/usr/bin/env bash

QML_PATH="$HOME/.config/quickshell/spotlight.qml"

# Check if spotlight is already running
if pgrep -f "quickshell.*spotlight.qml" > /dev/null; then
    # Already running: do nothing
    exit 0
else
    # Not running: launch spotlight
    quickshell -p "$QML_PATH" &
fi
